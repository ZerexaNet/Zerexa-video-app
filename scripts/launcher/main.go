// Command zerexa-launcher is a tiny single-binary launcher for Windows,
// Linux, and macOS that bundles a Node.js runtime + Next.js standalone
// build and runs `node standalone/server.js`.
//
// Build (cross-compile from any OS):
//   GOOS=windows GOARCH=amd64 go build -o zerexa-video-server-win-x64.exe
//   GOOS=linux   GOARCH=amd64 go build -o zerexa-video-server-linux-x64
//
// The payload (a base64-encoded tar.gz containing `node`, `standalone/`,
// and `run.sh`/`run.bat`) is appended after the literal marker line
// __PAYLOAD_BELOW__ at the end of the binary.
//
// At runtime the launcher:
//   1. Finds the marker line in its own executable.
//   2. Reads the base64 payload after it.
//   3. Decodes and untars into ~/.zerexa-video-server/<hash>/ (cached).
//   4. exec()s run.sh (Linux/macOS) or run.bat (Windows) inside that dir.
package main

import (
        "archive/tar"
        "bytes"
        "compress/gzip"
        "crypto/sha256"
        "encoding/base64"
        "encoding/hex"
        "fmt"
        "io"
        "os"
        "os/exec"
        "path/filepath"
        "runtime"
        "strings"
)

const (
        // Use a long, unique marker so it doesn't accidentally appear in the
        // Go binary's string-constant table (where __PAYLOAD_BELOW__ did).
        marker   = "===ZEREXA-VIDEO-SERVER-PAYLOAD-BELOW-THIS-LINE-V1==="
        cacheDir = ".zerexa-video-server"
)

func main() {
        exePath, err := os.Executable()
        if err != nil {
                fmt.Fprintln(os.Stderr, "ERROR: cannot determine executable path:", err)
                os.Exit(1)
        }

        payload, err := readEmbeddedPayload(exePath)
        if err != nil {
                fmt.Fprintln(os.Stderr, "ERROR:", err)
                os.Exit(1)
        }
        if len(payload) == 0 {
                fmt.Fprintln(os.Stderr, "ERROR: payload is empty (this binary was not bundled with the tar.gz).")
                os.Exit(1)
        }

        // Hash the payload so we re-extract only when the binary changes
        hash := sha256.Sum256(payload)
        hashStr := hex.EncodeToString(hash[:])[:12]

        home, err := os.UserHomeDir()
        if err != nil {
                home = "."
        }
        extractDir := filepath.Join(home, cacheDir, hashStr)

        // Pick the platform launcher script
        runScript := filepath.Join(extractDir, "run.sh")
        if runtime.GOOS == "windows" {
                runScript = filepath.Join(extractDir, "run.bat")
        }

        // Re-extract if missing
        if _, err := os.Stat(runScript); os.IsNotExist(err) {
                fmt.Fprintf(os.Stderr, "Extracting to %s ...\n", extractDir)
                if err := os.MkdirAll(extractDir, 0o755); err != nil {
                        fmt.Fprintln(os.Stderr, "ERROR mkdir:", err)
                        os.Exit(1)
                }
                if err := extractTarGz(payload, extractDir); err != nil {
                        fmt.Fprintln(os.Stderr, "ERROR extract:", err)
                        os.Exit(1)
                }
        } else if err != nil {
                fmt.Fprintln(os.Stderr, "ERROR stat:", err)
                os.Exit(1)
        }

        // exec the platform-specific launcher script
        cmd := exec.Command(runScript, os.Args[1:]...)
        cmd.Dir = extractDir
        cmd.Stdin = os.Stdin
        cmd.Stdout = os.Stdout
        cmd.Stderr = os.Stderr
        cmd.Env = os.Environ()
        if err := cmd.Run(); err != nil {
                if exitErr, ok := err.(*exec.ExitError); ok {
                        os.Exit(exitErr.ExitCode())
                }
                fmt.Fprintln(os.Stderr, "ERROR run:", err)
                os.Exit(1)
        }
}

// readEmbeddedPayload locates the literal marker line in the binary and
// returns the base64-decoded payload bytes that follow it.
//
// We read the whole binary into memory (a 100 MB binary is fine on any
// modern machine) and use bytes.Index to find the marker. Reading line by
// line would not work because the payload is a single ~150 MB base64 line,
// far exceeding bufio.Reader's 64 KB buffer.
func readEmbeddedPayload(exePath string) ([]byte, error) {
        data, err := os.ReadFile(exePath)
        if err != nil {
                return nil, err
        }

        // Find the LAST occurrence of the marker (the launcher binary may
        // embed the marker as a string constant; the appended payload is
        // always after the binary section, i.e. at the very end of the file).
        idx := bytes.LastIndex(data, []byte(marker))
        if idx == -1 {
                return nil, fmt.Errorf("payload marker not found in %s", exePath)
        }

        // Start of payload: after marker + optional newline
        start := idx + len(marker)
        if start < len(data) && data[start] == '\n' {
                start++
        }
        if start < len(data) && data[start] == '\r' {
                start++
        }

        // Strip any trailing whitespace
        end := len(data)
        for end > start && (data[end-1] == '\n' || data[end-1] == '\r' || data[end-1] == ' ' || data[end-1] == '\t') {
                end--
        }

        if start >= end {
                return nil, nil
        }

        // The payload may optionally have trailing newlines that we just
        // stripped; remove any in-line whitespace too.
        cleaned := strings.Map(func(r rune) rune {
                switch r {
                case ' ', '\t', '\n', '\r':
                        return -1
                }
                return r
        }, string(data[start:end]))

        return base64.StdEncoding.DecodeString(cleaned)
}

// extractTarGz decompresses a gzip-encoded tar into dir.
func extractTarGz(payload []byte, dir string) error {
        gz, err := gzip.NewReader(bytesReader(payload))
        if err != nil {
                return err
        }
        defer gz.Close()

        tr := tar.NewReader(gz)
        for {
                hdr, err := tr.Next()
                if err == io.EOF {
                        break
                }
                if err != nil {
                        return err
                }
                target := filepath.Join(dir, hdr.Name)

                // Prevent path traversal
                cleanDir := filepath.Clean(dir)
                if !strings.HasPrefix(target, cleanDir+string(os.PathSeparator)) && target != cleanDir {
                        return fmt.Errorf("entry %q escapes target dir", hdr.Name)
                }

                switch hdr.Typeflag {
                case tar.TypeDir:
                        if err := os.MkdirAll(target, os.FileMode(hdr.Mode)); err != nil {
                                return err
                        }
                case tar.TypeReg, tar.TypeRegA:
                        if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
                                return err
                        }
                        out, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, os.FileMode(hdr.Mode))
                        if err != nil {
                                return err
                        }
                        if _, err := io.Copy(out, tr); err != nil {
                                out.Close()
                                return err
                        }
                        out.Close()
                case tar.TypeSymlink:
                        // Skip symlinks for security on Windows
                }
        }
        return nil
}

// bytesReader returns an io.Reader over a []byte without depending on bytes.
func bytesReader(b []byte) io.Reader {
        return &byteSliceReader{data: b, pos: 0}
}

type byteSliceReader struct {
        data []byte
        pos  int
}

func (r *byteSliceReader) Read(p []byte) (int, error) {
        if r.pos >= len(r.data) {
                return 0, io.EOF
        }
        n := copy(p, r.data[r.pos:])
        r.pos += n
        return n, nil
}
