# AGENTS.md

Instructions for AI coding agents working in this repository.

## What this repo is

A single POSIX-ish bash script, `build-ffmpeg`, that downloads, builds and statically
links FFmpeg and ~70 of its dependencies from source, plus the Dockerfiles and CI that
exercise it. There is no application code, no test suite, and no build system of its
own — the script *is* the project.

## Repository layout

| Path | What it is |
| --- | --- |
| `build-ffmpeg` | **The script.** ~2,200 lines. Almost every change goes here. |
| `web-install.sh`, `web-install-gpl-and-non-free.sh` | One-liner installers that curl and run `build-ffmpeg`. |
| `Dockerfile`, `cuda-ubuntu.dockerfile`, `full-static.dockerfile`, `export.dockerfile` | Container builds, all exercised by CI. |
| `.github/workflows/build.yml` | Lint + five full builds (Linux, macOS, Docker, CUDA Docker, full-static). |
| `README.md` | 70 KB of end-user documentation. Not contributor docs. |
| `.editorconfig` | shfmt reads its indent keys from here. |
| `packages/`, `workspace/`, `build/` | **Build output. Gitignored. Never read or edit these.** `packages/` holds ~70 extracted upstream source trees; grepping it will bury you in unrelated code. |
| `docs/`, `plans/` | Gitignored scratch notes. Not part of the project. |

When searching the repo, restrict the search to the tracked files. `git ls-files` is the
reliable filter; a bare `grep -r .` is not.

## Style and tooling

- **Formatting is enforced.** `shfmt` (v3.12.0) must produce no diff. It reads
  `.editorconfig`: 4-space indent, `binary_next_line = false`, `switch_case_indent = false`.
  Run `shfmt -d build-ffmpeg web-install.sh web-install-gpl-and-non-free.sh` before finishing.
- **ShellCheck is enforced at `--severity=style`**, its strictest level, pinned to v0.11.0.
  The scripts are currently clean, so anything it reports is a regression you introduced.
  Prefer fixing over silencing; if a `# shellcheck disable=` really is warranted, give it a
  reason comment on the same line.
- **Target `/bin/bash` 3.2.** macOS still ships bash 3.2, so no associative arrays
  (`declare -A` is a *fatal* error there), no `${var^^}`, no `mapfile`/`readarray`,
  no `**` globstar.
- **Both GNU and BSD userland.** `sed -i` and `tar --wildcards` behave differently.
  Use the `apply_inline_patch` helper instead of `sed -i`. Where `sed -i.backup` does
  appear it is deliberate and portable — leave it.

## How the script is structured

Read in this order: the `VER_*` table at the top → the helpers → the `build_*` functions →
`PACKAGE_BUILD_ORDER` and its dispatch loop → the FFmpeg configure block at the bottom.

### The version/checksum table

Every package has one `VER_<PACKAGE>=("<version>" "<sha256>")` array near the top of the
file. `download()` derives the array name from the package name mechanically — uppercased,
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

1. Add `VER_<NAME>=("<version>" "<sha256>")` to the table, in the section matching where it
   will be built.
2. Write `build_<name>()` following the anatomy above, next to its neighbours in the same section.
3. Add `<name>` to `PACKAGE_BUILD_ORDER` **in the position where it must be built** — the array
   is the actual build order and dependencies are not resolved, only ordered.
4. If the package name contains a `-`, the function name uses `_` (`pkg-config` →
   `build_pkg_config`, entry `pkg_config`, `VER_PKG_CONFIG`). The dispatch loop calls
   `"build_${PACKAGE}"` verbatim.
5. Get the checksum by downloading the archive and hashing it — do not invent one, and do not
   leave it empty unless the URL genuinely produces unstable bytes (as `av1` does; say so in a
   comment when you do).
6. Bump `SCRIPT_VERSION`.

Prefer `--disable-shared --enable-static` and disabling docs, tests, examples and CLI tools:
everything here is a static link into one binary and nothing else consumes these installs.

## Testing a change

A full build takes well over an hour, so do not casually run one.

- **Syntax and lint** — always, they are seconds: `bash -n build-ffmpeg`, then `shfmt -d` and
  `shellcheck --severity=style` as spelled out above.
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
