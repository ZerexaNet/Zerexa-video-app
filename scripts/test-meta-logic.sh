#!/usr/bin/env bash
# 本地模拟 workflow 里 "Compute release metadata" 步骤
set -euo pipefail

simulate() {
    local event_name="$1"
    local ref="$2"
    local sha="$3"
    local dispatch_input="${4:-prerelease}"

    IS_RELEASE="false"
    IS_PRERELEASE="true"
    VERSION=""
    TAG_NAME=""
    RELEASE_NAME=""

    if [ "$event_name" = "workflow_dispatch" ]; then
        INPUT_TYPE="$dispatch_input"
        COMMIT_SHORT="${sha:0:6}"
        if [ "$INPUT_TYPE" = "release" ]; then
            IS_RELEASE="true"
            IS_PRERELEASE="false"
            VERSION="manual-${COMMIT_SHORT}"
            TAG_NAME="manual-${COMMIT_SHORT}"
            RELEASE_NAME="Zerexa Video App (manual) ${VERSION}"
        else
            VERSION="0.0.0-pre.${COMMIT_SHORT}"
            TAG_NAME="pre-${COMMIT_SHORT}"
            RELEASE_NAME="Zerexa Video App Pre-release ${COMMIT_SHORT}"
        fi
    elif [[ "$ref" == refs/tags/v* ]]; then
        IS_RELEASE="true"
        IS_PRERELEASE="false"
        VERSION="${ref#refs/tags/}"
        TAG_NAME="${VERSION}"
        RELEASE_NAME="Zerexa Video App ${VERSION}"
    else
        COMMIT_SHORT="${sha:0:6}"
        VERSION="0.0.0-pre.${COMMIT_SHORT}"
        TAG_NAME="pre-${COMMIT_SHORT}"
        RELEASE_NAME="Zerexa Video App Pre-release ${COMMIT_SHORT}"
    fi

    echo "---- $event_name / $ref / $dispatch_input ----"
    echo "  version:       $VERSION"
    echo "  tag:           $TAG_NAME"
    echo "  prerelease:    $IS_PRERELEASE"
    echo "  release name:  $RELEASE_NAME"
}

TEST_SHA="4cef33fabcd1234567890abcdef1234567890ab"

simulate push refs/heads/main "$TEST_SHA"
simulate push refs/tags/v1.0.0 "$TEST_SHA"
simulate push refs/tags/v0.3.1 "$TEST_SHA"
simulate workflow_dispatch refs/heads/main "$TEST_SHA" prerelease
simulate workflow_dispatch refs/heads/main "$TEST_SHA" release
simulate push refs/heads/some-other-branch "$TEST_SHA"
