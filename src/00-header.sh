# shellcheck shell=bash
# HOMEPAGE: https://github.com/markus-perl/ffmpeg-build-script
# LICENSE: https://github.com/markus-perl/ffmpeg-build-script/blob/master/LICENSE

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
# shellcheck disable=SC2034 # $FFMPEG_VERSION is read by later fragments
FFMPEG_VERSION=9.0.1
# shellcheck disable=SC2034 # $SCRIPT_VERSION is read by later fragments
SCRIPT_VERSION=9.0.6
