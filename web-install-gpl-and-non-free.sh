#!/bin/bash
# Helper script to download and run the build-ffmpeg script.
#
# By default the latest GitHub release is used. Set FFMPEG_BUILD_SCRIPT_REF to
# a release tag (for example "v9.0.3") to pin a release, or to a branch name
# (for example "master") to try unreleased work.

make_dir() {
    if [ ! -d "$1" ]; then
        if ! mkdir "$1"; then
            printf "\n Failed to create dir %s" "$1"
            exit 1
        fi
    fi
}

command_exists() {
    if ! [[ -x $(command -v "$1") ]]; then
        return 1
    fi

    return 0
}

# Print the tag of the newest release. "/releases/latest" is a plain redirect to
# "/releases/tag/<tag>", so the tag can be read back out of the resolved URL --
# no api.github.com call, which would be rate limited to 60/hour per IP and
# would break CI runners behind a shared address, and no jq.
resolve_latest_tag() {
    curl -fsSL -o /dev/null --write-out '%{url_effective}' \
        "$REPO/releases/latest" | sed 's|.*/releases/tag/||'
}

TARGET='ffmpeg-build'
REPO='https://github.com/markus-perl/ffmpeg-build-script'
TARBALL='ffmpeg-build-script.tar.gz'
REF="${FFMPEG_BUILD_SCRIPT_REF:-latest}"

for REQUIRED in curl tar sed; do
    if ! command_exists "$REQUIRED"; then
        echo "$REQUIRED not installed."
        exit 1
    fi
done

# $REF is interpolated straight into the download URL, and curl resolves ".."
# before sending the request, so an unsanitized value would escape this
# repository entirely and fetch somebody else's archive instead.
#
# A ref here is one tag or branch name, so anything with a slash is rejected
# along with the traversal. That does mean branch names containing a slash are
# not supported; use a tag, or clone the repository.
case "$REF" in
-* | *..* | */*)
    echo "Invalid FFMPEG_BUILD_SCRIPT_REF: '$REF'"
    echo "Expected one release tag (for example v9.0.3) or branch name (for example master)."
    exit 1
    ;;
esac

echo "ffmpeg-build-script-downloader v0.3"
echo "========================================="
echo ""

echo "First we create the ffmpeg build directory $TARGET"
make_dir "$TARGET"
cd "$TARGET" || exit 1

echo "Now we download the build script ($REF)"
echo ""

# GitHub generates an archive for every tag and branch, so a release needs no
# uploaded asset and there is nothing that can be missing: if the ref exists,
# its archive exists. .gitattributes export-ignore applies to these archives,
# so what arrives is only what a build actually needs.
case "$REF" in
latest)
    if ! TAG=$(resolve_latest_tag) || [ -z "$TAG" ] || [ "$TAG" != "${TAG#*/}" ]; then
        echo "Failed to resolve the latest release of $REPO"
        exit 1
    fi
    echo "Latest release is $TAG"
    ARCHIVE_URL="$REPO/archive/refs/tags/$TAG.tar.gz"
    ;;
v[0-9]*)
    ARCHIVE_URL="$REPO/archive/refs/tags/$REF.tar.gz"
    ;;
*)
    ARCHIVE_URL="$REPO/archive/refs/heads/$REF.tar.gz"
    ;;
esac

if ! curl -fsSL -o "$TARBALL" "$ARCHIVE_URL"; then
    echo "Failed to download $ARCHIVE_URL"
    exit 1
fi

echo ""
echo "Now we extract and execute the build script"
echo ""

# --strip-components=1 (GNU and BSD tar) drops the archive's top-level
# directory, so the tree lands directly in $TARGET and packages/ plus
# workspace/ end up where they always did.
if ! tar -xzf "$TARBALL" --strip-components=1; then
    echo "Failed to extract $TARBALL"
    exit 1
fi

rm -f "$TARBALL"

./build-ffmpeg --build --enable-gpl-and-non-free
