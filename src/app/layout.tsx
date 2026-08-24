import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { Toaster } from "@/components/ui/toaster";
import { QueryProvider } from "@/components/query-provider";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Zerexa Video - 视频、专栏与动态社区",
  description:
    "Zerexa Video 是一个开源的视频、专栏与动态社区，提供弹幕互动、点赞投币收藏、合集与公投等功能。",
  keywords: [
    "Zerexa Video",
    "视频",
    "弹幕",
    "社区",
    "Material You",
    "Win8 Metro",
  ],
  authors: [{ name: "Zerexa Video" }],
  icons: { icon: "/logo.svg" },
  openGraph: {
    title: "Zerexa Video",
    description: "视频、专栏与动态社区",
    siteName: "Zerexa Video",
    type: "website",
  },
};

// Inline theme bootstrap script - runs before paint to avoid FOUC.
// Reads from localStorage and sets data-theme + dark class on <html>.
const themeBootstrap = `
(function () {
  try {
    var t = localStorage.getItem("zv-theme");
    t = t ? JSON.parse(t) : null;
    var theme = (t && t.state && t.state.theme) || "zerexa";
    document.documentElement.setAttribute("data-theme", theme);
    if (theme === "dark") document.documentElement.classList.add("dark");
  } catch (e) {
    document.documentElement.setAttribute("data-theme", "zerexa");
  }
})();
`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeBootstrap }} />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground`}
      >
        <QueryProvider>
          {children}
          <Toaster />
        </QueryProvider>
      </body>
    </html>
  );
}
