# AGENTS.md

Instructions for AI coding agents working in this repository.

## What this repo is

A bash script, `build-ffmpeg`, that downloads, builds and statically links FFmpeg and ~70
of its dependencies from source, plus the Dockerfiles and CI that exercise it. There is no
application code, no test suite, and no build system of its own — the script *is* the
project.

The script is not one file: `build-ffmpeg` is a thin entry point that `source`s the
fragments under `src/` in an explicit order. There is **no assembly or codegen step** —
the fragments are the source, sourced at runtime. Users always get the whole tree (release
tarball, `git clone`, or the Dockerfiles' `COPY src`).

## Repository layout

| Path | What it is |
| --- | --- |
| `build-ffmpeg` | Entry point only: resolves `SCRIPT_DIR`, checks `src/` exists, sources the fragments in order. Edit it only to add, remove or reorder a fragment. |
| `src/` | **The script.** Almost every change goes here — see the fragment list below. |
| `web-install.sh`, `web-install-gpl-and-non-free.sh` | One-liner installers. They resolve the **latest release**, download GitHub's auto-generated archive for that tag, extract it and run `build-ffmpeg` from it. They do not fetch anything from `master`. |
| `Dockerfile`, `cuda-ubuntu.dockerfile`, `full-static.dockerfile`, `export.dockerfile` | Container builds, all exercised by CI. |
| `.github/workflows/build.yml` | `lint`, then six full builds: `build-linux`, `build-linux-with-system-libs`, `build-macos`, `build-docker`, `build-cuda-ubuntu-docker`, `build-full-static`, then `release-version-check` on `v*` tags only. |
| `README.md` | End-user documentation. Not contributor docs. |
| `.editorconfig` | shfmt reads its indent keys from here. |
| `.gitattributes` | `export-ignore` entries that keep repo infrastructure out of the release tarball `git archive` builds. Nothing the build needs may be listed there. |
| `packages/`, `workspace/`, `build/` | **Build output. Gitignored. Never read or edit these.** `packages/` holds ~70 extracted upstream source trees; grepping it will bury you in unrelated code. Not to be confused with `src/packages/`, which is script source — the `.gitignore` entries are anchored (`/packages`) precisely so they do not swallow it. |
| `docs/`, `plans/` | Gitignored scratch notes. Not part of the project. |

When searching the repo, restrict the search to the tracked files. `git ls-files` is the
reliable filter; a bare `grep -r .` is not.

## Releases vs master

`master` holds unreleased work; users get releases.

**Releases are drafted and published by hand.** Nothing is uploaded to them and nothing
needs to be: GitHub generates a source archive for every tag, so if the tag exists its
archive exists. `.gitattributes` `export-ignore` applies to those archives, which is what
keeps repo infrastructure out of what users download.

The installers resolve the newest release from the `/releases/latest` redirect, which
points at `/releases/tag/<tag>`, and then fetch `/archive/refs/tags/<tag>.tar.gz`. Do not
replace that with an `api.github.com` lookup: it is rate-limited to 60/hr per IP, breaks CI
runners behind shared NAT, and would add a `jq` dependency.

The `release-version-check` job asserts that a pushed tag matches `SCRIPT_VERSION` *in the
tagged commit*, read from `src/00-header.sh` (`v9.0.3` requires `SCRIPT_VERSION=9.0.3`), so
master carrying the next
release's version is legal while a mismatched tag fails. It does not gate on the builds —
there is no artifact to withhold, so it reports in seconds instead of after an hour.

## Style and tooling

- **Formatting is enforced.** `shfmt` (v3.12.0) must produce no diff. It reads
  `.editorconfig`: 4-space indent, `binary_next_line = false`, `switch_case_indent = false`.
  Run `shfmt -d build-ffmpeg web-install.sh web-install-gpl-and-non-free.sh src/` before
  finishing.
- **ShellCheck is enforced at `--severity=style`**, its strictest level, pinned to v0.11.0.
  Run it as `shellcheck -x --severity=style build-ffmpeg web-install.sh
  web-install-gpl-and-non-free.sh src/*.sh src/packages/*.sh`. **The fragments have to be
  named on the command line.** `-x` follows the `source` lines only to resolve definitions
  for the file being checked; it emits no diagnostics for the sourced files, so `-x` on the
  entry point alone lints the loader and nothing else. Each fragment therefore carries a
  `# shellcheck shell=bash` directive (fragments have no shebang), and the handful of
  variables that are set in one fragment and read in another carry a narrow
  `# shellcheck disable=` with a reason on the same line. The `# shellcheck source=`
  directives in the entry point stay — they make `-x` resolve the loader's own call graph.
  The scripts are currently clean, so anything it reports is a regression you introduced.
  Prefer fixing over silencing; if a `# shellcheck disable=` really is warranted, give it a
  reason comment on the same line.
- **Package consistency is enforced too**, in the same `lint` job, because both failures it
  catches are silent and only surface at download time — up to an hour into a build.
  `./build-ffmpeg --list-packages | grep MISSING` must print nothing: `download()` derives
  `VER_<PACKAGE>` from the name passed to `build()`, and when the two disagree it finds no
  checksum and fetches the tarball **unverified** instead of failing. The job also checks
  that every variable interpolated into a `download` URL is assigned somewhere — `X265_COMMIT`
  was not, once, and the URL collapsed to `get/.tar.gz`.
- **Target `/bin/bash` 3.2.** macOS still ships bash 3.2, so no associative arrays
  (`declare -A` is a *fatal* error there), no `${var^^}`, no `mapfile`/`readarray`,
  no `**` globstar.
- **Both GNU and BSD userland.** `sed -i` and `tar --wildcards` behave differently.
  Use the `apply_inline_patch` helper instead of `sed -i`. Where `sed -i.backup` does
  appear it is deliberate and portable — leave it.

## How the script is structured

`build-ffmpeg` sources these, in exactly this order. Read them in the same order:

| Fragment | What is in it |
| --- | --- |
| `src/00-header.sh` | Banner comment, `PROGNAME`, `FFMPEG_VERSION`, `SCRIPT_VERSION`. |
| `src/10-versions.sh` | Every `VER_*` version/checksum array, plus `X265_COMMIT`. One central table. |
| `src/20-globals.sh` | `CWD`/`PACKAGES`/`WORKSPACE`/`CFLAGS`/`LDFLAGS`/…, the small predicates (`version_gte`, `command_exists`, `cxx_supports_flag`), Apple Silicon detection and `MJOBS` detection. |
| `src/30-helpers.sh` | `make_dir` … `download`, `execute`, `build`, `build_done`, `verify_binary_type`, `cleanup`. |
| `src/40-cli.sh` | `usage()`, the version banner, the argument loop, the preflight `command_exists` checks. |
| `src/packages/*.sh` | The `build_*` functions, grouped by the sections the monolith already used: `10-build-tools`, `20-tls`, `25-cmake`, `30-video`, `40-audio`, `50-image`, `55-other`, `60-text-subtitle`, `70-optical`, `75-zmq`, `80-hwaccel`. |
| `src/90-build-order.sh` | `PACKAGE_BUILD_ORDER` and the dispatch loop. |
| `src/95-ffmpeg.sh` | The FFmpeg configure/make/install, the binary verification and the install-to-system prompt. |

Rules the entry point encodes, none of them cosmetic:

- **Order is load-bearing.** The dispatch loop and the FFmpeg block only work once every
  function and variable above them exists.
- **Nothing is wrapped in a subshell or a function.** Fragments are sourced into the
  current shell because the package functions mutate `CONFIGURE_OPTIONS`,
  `CFLAGS`/`LDFLAGS`/`CXXFLAGS`, `EXTRALIBS`, `PATH` and the `OPENSSL_*` exports, and
  `download()` leaves the shell inside the extracted source directory.
- **The source list is explicit, never a glob.** Glob order depends on `LC_COLLATE`, and an
  in-place upgrade over an existing `ffmpeg-build/` tree leaves renamed-away fragments
  behind — an explicit list makes those orphans inert.
- **`CWD=$(pwd)` in `src/20-globals.sh` is the invocation directory** and decides where
  `packages/` and `workspace/` are created. `SCRIPT_DIR` in the entry point exists only to
  locate the fragments. Do not conflate them.
- A fragment carries no shebang and is never executable on its own. It starts with a
  `# shellcheck shell=bash` directive instead, which is what lets it be linted on its own.
- **A fragment that fails to load is fatal.** Each `source` line is followed by
  `|| fragment_failed <name>`, which aborts when the file is missing or unreadable and is a
  no-op otherwise — a sourced file's exit status is that of its last command, which for
  `src/90-build-order.sh` is the dispatch loop, so the status itself cannot be trusted.

### The version/checksum table

Every package has one `VER_<PACKAGE>=("<version>" "<sha256>")` array in
`src/10-versions.sh`. `download()` derives the array name from the package name mechanically — uppercased,
every non-alphanumeric replaced by `_` — so the name passed to `build()` and the array name
must stay in sync or the checksum silently goes unchecked. An empty checksum means
"not pinned yet" and skips verification.

The checksum is of the *downloaded archive*, not its contents.

### Anatomy of a package function

```bash
build_foo() {
    if ! $NONFREE_AND_GPL; then return; fi     # optional license gate
    if ! command_exists "meson"; then return; fi   # optional capability gate

    if build "foo" "${VER_FOO[0]}"; then
        download "https://.../foo-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --disable-shared --enable-static
        execute make -j "$MJOBS"
        execute make install
        build_done "foo" "$CURRENT_PACKAGE_VERSION"
    fi
    CONFIGURE_OPTIONS+=("--enable-libfoo")     # OUTSIDE the if — see below
}
```

Rules this shape encodes:

- `build()` returns non-zero when `packages/foo.done` already records this version, so the
  body is skipped on a rerun. It also sets `CURRENT_PACKAGE_NAME` / `CURRENT_PACKAGE_VERSION`,
  which `download()` reads to find the checksum. **Always build the URL from
  `$CURRENT_PACKAGE_VERSION`, never from a literal version** — that is what keeps the URL,
  the `.done` file and the checksum consistent.
- `CONFIGURE_OPTIONS+=(...)` goes **outside** the `if build ... fi` block. Inside it, a cached
  package would silently drop its `--enable-` flag from the FFmpeg configure line.
- `execute` runs a command, captures its output, and aborts the script on failure. Use it for
  every build step. Bare commands are for cheap shell plumbing (`cd`, `mkdir`) only.
- `download()` extracts the tarball **and cds into it**, so the function continues in the
  source directory. Anything that needs a different directory `cd`s explicitly afterwards.
- The package functions run **in the current shell, not a subshell**, on purpose: they mutate
  global state that later packages and the final configure depend on — `CONFIGURE_OPTIONS`,
  `CFLAGS`/`LDFLAGS`/`CXXFLAGS`, `EXTRALIBS`, `PATH`, the `OPENSSL_*` exports — and the working
  directory carries over from `download()`. Wrapping one in a subshell changes behavior.

### The gates

| Gate | Meaning |
| --- | --- |
| `if ! $NONFREE_AND_GPL; then return; fi` | GPL/non-free only (`--enable-gpl-and-non-free`). |
| `if $NONFREE_AND_GPL; then return; fi` | LGPL path only. Used by the gmp/nettle/gnutls chain, which is the mirror image of openssl. |
| `if [ -n "$LDEXEFLAGS" ]; then return; fi` | Skipped in `--full-static` builds. Used for packages whose filters `dlopen()` plugins at runtime (frei0r, ladspa), which a static binary cannot do. |
| `if $DISABLE_LV2; then return; fi` | The LV2 stack (`--disable-lv2`). |
| `if ! command_exists "x"; then return; fi` | Optional on hosts lacking a tool (python3, meson, cargo, nvcc). |
| `if [[ ! "$OSTYPE" == "linux-gnu" ]]; then return; fi` | Linux-only hardware accel. |

Exactly one TLS stack is built per license mode, because FFmpeg's configure refuses both at
once: `--enable-gpl-and-non-free` → gettext + openssl; default LGPL → gmp + nettle + gnutls.

## Adding a package

1. Add `VER_<NAME>=("<version>" "<sha256>")` to `src/10-versions.sh`, in the section
   matching where it will be built.
2. Write `build_<name>()` following the anatomy above, next to its neighbours in the
   matching `src/packages/*.sh` fragment. A new fragment also has to be added to the source
   list in `build-ffmpeg`, in the right position — it is not picked up automatically.
3. Add `<name>` to `PACKAGE_BUILD_ORDER` in `src/90-build-order.sh` **in the position where
   it must be built** — the array is the actual build order and dependencies are not
   resolved, only ordered.
4. If the package name contains a `-`, the function name uses `_` (`pkg-config` →
   `build_pkg_config`, entry `pkg_config`, `VER_PKG_CONFIG`). The dispatch loop calls
   `"build_${PACKAGE}"` verbatim.
5. Get the checksum by downloading the archive and hashing it — do not invent one, and do not
   leave it empty unless the URL genuinely produces unstable bytes (as `av1` does; say so in a
   comment when you do).
6. Bump `SCRIPT_VERSION` — but only if it is not already ahead of the latest release tag.
   It names the *next* release, not the current commit, so a whole batch of unreleased
   commits shares one bump. Check `git tag | tail -1` first: bumping again while master is
   already ahead skips a version and makes the `release-version-check` job's tag assertion fail.

Prefer `--disable-shared --enable-static` and disabling docs, tests, examples and CLI tools:
everything here is a static link into one binary and nothing else consumes these installs.

## Testing a change

A full build takes well over an hour, so do not casually run one.

- **Syntax and lint** — always, they are seconds: `bash -n` on `build-ffmpeg` and on every
  fragment you touched, then `shfmt -d` and `shellcheck -x --severity=style` as spelled out
  above.
- **One package** — a full build leaves `packages/*.done` lockfiles behind. Delete just the one
  you touched (`rm packages/foo.done`) and rerun `./build-ffmpeg --build …`; every other package
  is skipped and only yours rebuilds. This is the fast iteration loop.
- **From scratch** — `./build-ffmpeg --cleanup` wipes `packages/` and `workspace/`. Note that
  this also discards every downloaded tarball.
- **Useful env vars** — `SKIPINSTALL=yes` (never touch system binaries), `NUMJOBS=n`,
  `SKIPRAV1E=yes` (skips the slow Rust build), `AUTOINSTALL=yes`.
- **Verifying the result** — `./workspace/bin/ffmpeg -buildconf` is what CI checks. Confirm that
  the feature you added actually shows up there; a missing dependency usually degrades silently
  into a dropped feature rather than a failed build.

Never run the install step, and never write outside the repo, unless explicitly asked.

## Traps worth knowing

- **Silent feature loss.** FFmpeg's configure drops what it cannot find instead of failing.
  A build can report success and be missing ffplay, a TLS backend, or the Vulkan filters.
  Check `-buildconf`, not the exit code.
- **`.git` is moved to `.git.bak` during the FFmpeg build** so FFmpeg does not describe *this*
  repository in its version string. An `EXIT` trap restores it. If you find a `.git.bak` and no
  `.git`, a build died — move it back.
- **The LGPL build currently has no TLS backend.** `build_gnutls` builds gnutls but the
  `--enable-gnutls` line is commented out, and gnutls is skipped entirely on arm64. Both are
  documented in place. Do not "fix" the comment-out without addressing the arm64 asymmetry.
- **Cached downloads are never auto-deleted.** A checksum mismatch on a cached file aborts with
  instructions rather than silently re-downloading.

## Commits

Imperative mood, one line, no scope prefix, no trailer — match `git log`:
`Build gperf, which fontconfig needs on Linux`. Pure-formatting commits get added to
`.git-blame-ignore-revs`.
