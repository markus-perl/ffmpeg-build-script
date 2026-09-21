# shellcheck shell=bash
# HOMEPAGE: https://github.com/markus-perl/ffmpeg-build-script
# LICENSE: https://github.com/markus-perl/ffmpeg-build-script/blob/main/LICENSE

# Sourced by ../build-ffmpeg. Every fragment is linted as its own file, so a
# global defined here and read from a later fragment looks unused; each one
# therefore carries its own SC2034 disable rather than the file having a
# blanket one, so that a global which becomes genuinely dead still gets
# reported once its disable is removed.
#
# SC2329 (never-invoked function) needs no disable any more: ShellCheck only
# raises it for a file it can prove is not sourced, which among the fragments
# is only 95-ffmpeg.sh (it ends in "exit 0"), and that one defines no
# functions. If it ever fires again, bring the disable back.
# shellcheck disable=SC2034 # $PROGNAME is read by later fragments
PROGNAME=$(basename "$0")
# The major FFmpeg release line this script is built and tested against. The
# exact release within it is never pinned here: 40-cli.sh resolves the latest
# FFMPEG_MAJOR_VERSION.x release from https://ffmpeg.org/releases/ at the start
# of every build, via latest_ffmpeg_version() in 30-helpers.sh.
# shellcheck disable=SC2034 # $FFMPEG_MAJOR_VERSION is read by later fragments
FFMPEG_MAJOR_VERSION=9
# Placeholder until 40-cli.sh resolves the real release; shown by --list-packages
# and --help, which run before that resolution and must not trigger it themselves.
# shellcheck disable=SC2034 # $FFMPEG_VERSION is read by later fragments
FFMPEG_VERSION="$FFMPEG_MAJOR_VERSION.x"
# shellcheck disable=SC2034 # $SCRIPT_VERSION is read by later fragments
SCRIPT_VERSION=9.0.11
