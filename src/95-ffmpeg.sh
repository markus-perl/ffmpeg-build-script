# shellcheck shell=bash
##
## FFmpeg
##

# --extra-version is appended to whatever version string ffmpeg derives for
# itself, and it used to be passed unconditionally. e24c341 ("version display
# fix") restricted it to macOS because on Linux the result was a doubled/wrong
# version in `ffmpeg -version`; on macOS it is what makes the version show up at
# all. Linux builds therefore intentionally carry no extra version tag. See also
# the .git -> .git.bak dance below, which keeps ffmpeg from describing *this*
# repository instead of its own tree.

EXTRA_VERSION=""
if [[ "$OSTYPE" == "darwin"* ]]; then
    EXTRA_VERSION="${FFMPEG_VERSION}"
fi

if [ -d "$CWD/.git" ]; then
    echo -e "\nTemporarily moving .git dir to .git.bak to workaround ffmpeg build bug" #causing ffmpeg version number to be wrong
    mv "$CWD/.git" "$CWD/.git.bak"
    # Restore .git even if the build fails and exits early.
    trap 'if [ -d "$CWD/.git.bak" ]; then mv "$CWD/.git.bak" "$CWD/.git"; fi' EXIT
fi

# Unlike every dependency above, ffmpeg deliberately takes part in none of the
# .done bookkeeping: no build() guard, no build_done(). CONFIGURE_OPTIONS is
# assembled from the command-line flags and from which dependencies actually got
# built, so a cached ffmpeg from a previous run would not correspond to the
# options requested this time. It is rebuilt unconditionally, and the banner
# below is a plain echo rather than build() so the "already built, remove the
# lockfile" message can never appear for it.
echo ""
echo "building ffmpeg - version $FFMPEG_VERSION"
echo "======================="
# ffmpeg is downloaded outside of build(), so tell download() which SHA_ entry to
# use for the integrity check.
# shellcheck disable=SC2034 # read by download() in 30-helpers.sh
CURRENT_PACKAGE_NAME="ffmpeg"
download "https://github.com/FFmpeg/FFmpeg/archive/refs/tags/n$FFMPEG_VERSION.tar.gz" "FFmpeg-release-$FFMPEG_VERSION.tar.gz"
# shellcheck disable=SC2086

execute ./configure "${CONFIGURE_OPTIONS[@]}" \
    --disable-debug \
    --disable-shared \
    --enable-pthreads \
    --enable-static \
    --enable-version3 \
    --extra-cflags="${CFLAGS}" \
    --extra-ldexeflags="${LDEXEFLAGS}" \
    --extra-ldflags="${LDFLAGS}" \
    --extra-libs="${EXTRALIBS}" \
    --pkgconfigdir="$WORKSPACE/lib/pkgconfig" \
    --pkg-config-flags="--static" \
    --prefix="${WORKSPACE}" \
    --extra-version="${EXTRA_VERSION}"

execute make -j "$MJOBS"
execute make install

if [ -d "$CWD/.git.bak" ]; then
    mv "$CWD/.git.bak" "$CWD/.git"
fi

INSTALL_FOLDER="/usr" # not recommended, overwrites system ffmpeg package
if [[ "$OSTYPE" == "darwin"* ]]; then
    INSTALL_FOLDER="/usr/local"
else
    if [ -d "$HOME/.local" ]; then # systemd-standard user path
        INSTALL_FOLDER="$HOME/.local"
    elif [ -d "/usr/local" ]; then
        INSTALL_FOLDER="/usr/local"
    fi
fi

verify_binary_type

echo ""
echo "Building done. The following binaries can be found here:"
echo "- ffmpeg: $WORKSPACE/bin/ffmpeg"
echo "- ffprobe: $WORKSPACE/bin/ffprobe"
if [ -f "$WORKSPACE/bin/ffplay" ]; then
    echo "- ffplay: $WORKSPACE/bin/ffplay"
else
    echo "- ffplay: not built (SDL2 was not available at configure time)"
fi
echo ""

INSTALL_NOW=0
if [[ "$AUTOINSTALL" == "yes" ]]; then
    INSTALL_NOW=1
    echo "Automatically installing these binaries because the --auto-install option was used or AUTOINSTALL=yes was run."
elif [[ ! "$SKIPINSTALL" == "yes" ]]; then
    # The prompt defaults to yes, so an empty answer means "install". That makes a
    # failed read dangerous rather than harmless: at EOF - a non-interactive shell,
    # stdin from /dev/null or a pipe, CI, cron - read returns non-zero and leaves
    # response empty, which matches the "" branch below and would overwrite the
    # system binaries unattended. So only ask when there is a terminal to ask, and
    # still guard the read itself in case it fails for another reason.
    if [ -t 0 ]; then
        read -r -p "Install these binaries to your $INSTALL_FOLDER folder? Existing binaries will be replaced. [Y/n] " response || response=n
        case $response in
        "" | [yY][eE][sS] | [yY])
            INSTALL_NOW=1
            ;;
        esac
    else
        echo "Not installing these binaries: this is not an interactive shell, so the install prompt was skipped."
        echo "Pass --auto-install (or set AUTOINSTALL=yes) to install without being asked."
    fi
else
    echo "Skipping install of these binaries because the --skip-install option was used or SKIPINSTALL=yes was run."
fi

if [ "$INSTALL_NOW" = 1 ]; then
    if command_exists "sudo" && [[ $INSTALL_FOLDER == /usr* ]]; then
        SUDO=sudo
    fi
    if ! $SUDO cp "$WORKSPACE/bin/ffmpeg" "$INSTALL_FOLDER/bin/ffmpeg"; then
        echo "Error: Failed to install ffmpeg to $INSTALL_FOLDER/bin/ffmpeg" >&2
        exit 1
    fi
    if ! $SUDO cp "$WORKSPACE/bin/ffprobe" "$INSTALL_FOLDER/bin/ffprobe"; then
        echo "Error: Failed to install ffprobe to $INSTALL_FOLDER/bin/ffprobe" >&2
        exit 1
    fi
    if [ -f "$WORKSPACE/bin/ffplay" ]; then
        if ! $SUDO cp "$WORKSPACE/bin/ffplay" "$INSTALL_FOLDER/bin/ffplay"; then
            echo "Error: Failed to install ffplay to $INSTALL_FOLDER/bin/ffplay" >&2
            exit 1
        fi
    else
        echo "ffplay was not built (SDL2 missing at configure time), skipping its install."
    fi
    # shellcheck disable=SC2086 # MANPAGES is an integer literal set in 20-globals.sh/40-cli.sh
    if [ $MANPAGES = 1 ]; then
        if [ -d "$WORKSPACE/share/man/man1" ] && compgen -G "$WORKSPACE/share/man/man1/ff*" >/dev/null; then
            $SUDO mkdir -p "$INSTALL_FOLDER/share/man/man1"
            if ! $SUDO cp "$WORKSPACE/share/man/man1"/ff* "$INSTALL_FOLDER/share/man/man1"; then
                echo "Error: Failed to install the manpages to $INSTALL_FOLDER/share/man/man1" >&2
                exit 1
            fi
            if command_exists "mandb"; then
                $SUDO mandb -q
            fi
        else
            echo "No manpages were built, skipping their install."
        fi
    fi
    echo "Done. FFmpeg is now installed to your system."
fi

exit 0
