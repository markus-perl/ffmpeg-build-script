# Contributing

Thanks for wanting to improve `ffmpeg-build-script`. This file covers how to report a problem
and how to get a pull request merged.

This project is maintained in my spare time. Please keep that in mind for response times, and
also for the scope limits below — they exist so the script stays maintainable, not to be
unwelcoming.

**Security problems do not go in the issue tracker.** See [SECURITY.md](SECURITY.md) for how to
report those privately.

## Before you open an issue

**Supported systems.** Bug reports are only accepted for **macOS**, **Ubuntu >= 24.04** and
**Debian >= 13**. Ubuntu 24.04 is what runs in CI. Fedora, RHEL and its clones, openSUSE, Arch
and Alpine generally work and the README lists install commands for them, but I have no way to
reproduce or maintain fixes there. Reports for other systems will most likely be closed unless
they come with a patch.

Older releases are not tested, and parts of the build quietly fall away on them rather than
failing. Ubuntu 22.04 is the clearest example: its meson is 0.61.2, below the 0.63 that
libplacebo requires, so that filter is skipped. The script says what it skipped and why, which is
easy to miss in a long log — check for that before reporting a missing feature.

**Rebuild from scratch first.** A large share of reported failures are stale build state. Run

```bash
$ ./build-ffmpeg --cleanup
```

and try again before reporting. Note that this discards every downloaded tarball as well.

**Check that it is not a missing dependency.** FFmpeg's `configure` drops what it cannot find
instead of failing, so a "missing codec" is usually an absent build dependency on the host, not
a bug. Compare your host against the [prerequisites in the README](README.md#1-install-the-prerequisites-1).

### What to include

- Operating system and version, and the CPU architecture (`uname -a`).
- The script version (`./build-ffmpeg --version`) or the commit you built from.
- The **full command line** you ran, including any environment variables.
- The build output around the failure — the last ~50 lines are usually enough. The failing
  package's own log is printed by `execute` when a command fails, so include that too.
- For "feature X is missing" reports: the output of `./workspace/bin/ffmpeg -buildconf`.

## What changes are welcome

Welcome:

- Fixes for build failures on the supported systems.
- Version bumps of the bundled packages, with the checksum updated.
- New codecs and filter libraries that a meaningful number of people would use.
- Documentation fixes.

Please open an issue to discuss first:

- New command line options or environment variables.
- Anything that changes the layout of `packages/` or `workspace/`, or the install step.
- Large refactorings. They are hard to review against a script whose only real test is a
  one-hour build.

Out of scope:

- Support for systems other than the ones listed above, unless you are willing to maintain it.
- Turning the script into a general-purpose build system, or splitting it into multiple files.
- Shipping prebuilt binaries.

## Development setup

There is nothing to install for the project itself — the script bootstraps its own toolchain
into `workspace/`. For the checks CI runs you need two pinned tools:

| Tool | Version | Purpose |
| --- | --- | --- |
| [`shfmt`](https://github.com/mvdan/sh) | 3.12.0 | formatting, reads `.editorconfig` |
| [`shellcheck`](https://www.shellcheck.net/) | 0.11.0 | linting at `--severity=style` |

```bash
# macOS
$ brew install shfmt shellcheck

# Debian and Ubuntu
$ sudo apt install shfmt shellcheck
```

If your distribution ships different versions, download the pinned releases the way
[`.github/workflows/build.yml`](.github/workflows/build.yml) does — a different version can
report different findings.

Optionally, make `git blame` skip the pure-formatting commits:

```bash
$ git config blame.ignoreRevsFile .git-blame-ignore-revs
```

## Coding guidelines

The script is one bash file, and it has to keep running everywhere it currently runs:

- **Target bash 3.2.** macOS still ships it. No associative arrays (`declare -A` is a *fatal*
  error there), no `${var^^}`, no `mapfile`/`readarray`, no `**` globstar.
- **Assume both GNU and BSD userland.** `sed -i` and `tar --wildcards` differ between Linux and
  macOS. Use the script's `apply_inline_patch` helper rather than `sed -i`.
- **Use the existing helpers** — `build`, `download`, `execute`, `build_done`, `command_exists`.
  New packages should read like their neighbours.
- **Pin what you add.** Every package carries a `VER_<NAME>=("<version>" "<sha256>")` entry.
  Obtain the checksum by hashing the archive you actually downloaded.
- **Bump `SCRIPT_VERSION`** when you change build behaviour — but only if it is not already
  ahead of the latest release tag. It names the *next* release, not the current commit, so a
  batch of unreleased commits shares one bump. Check `git tag | tail -1` first: bumping again
  while master is already ahead skips a version, and the release workflow refuses to publish
  a tag that does not match `SCRIPT_VERSION`.

[AGENTS.md](AGENTS.md) documents the internals in more depth — the anatomy of a package
function, the license and capability gates, the build order array, and the traps that are easy
to fall into. It is written for AI coding agents, but it is the most complete description of how
the script is put together, so it is worth reading before a non-trivial change.

## Testing your change

Always, and they take seconds:

```bash
$ bash -n build-ffmpeg
$ shfmt -d build-ffmpeg web-install.sh web-install-gpl-and-non-free.sh
$ shellcheck --severity=style build-ffmpeg web-install.sh web-install-gpl-and-non-free.sh
```

`shfmt` must produce no diff and `shellcheck` no findings — the scripts are currently clean at
that level, so anything reported is a regression.

Then build. A full build takes well over an hour, so use the incremental loop while iterating:
delete only the lockfile of the package you touched and rerun.

```bash
$ rm packages/foo.done
$ SKIPINSTALL=yes ./build-ffmpeg --build
```

Useful environment variables: `SKIPINSTALL=yes` (never touch system binaries), `NUMJOBS=n`,
`SKIPRAV1E=yes` (skips the slow Rust build), `AUTOINSTALL=yes`. The equivalent flags are
`--skip-install` and `--auto-install`.

Before opening the pull request, do one full build from a clean tree in the license mode your
change affects, and verify the result:

```bash
$ ./build-ffmpeg --cleanup
$ SKIPINSTALL=yes ./build-ffmpeg --build --enable-gpl-and-non-free
$ ./workspace/bin/ffmpeg -buildconf
```

Confirm your feature actually appears in `-buildconf`. A missing dependency degrades silently
into a dropped feature rather than a failed build, so a green exit code proves little.

If your change can affect the LGPL path, build without `--enable-gpl-and-non-free` too. The two
modes build different TLS stacks and are not interchangeable.

## Pull requests

- Branch off `master` and target `master`.
- One logical change per pull request.
- Say in the description **which systems you built on** and paste the relevant part of
  `-buildconf` when you added or changed a feature.
- Do not commit `packages/`, `workspace/` or `build/`; they are gitignored. If you find a
  `.git.bak` directory and no `.git`, a build died — move it back before committing.
- CI runs the lint job plus five full builds (native Linux, native macOS, Docker, CUDA Docker,
  full-static). It takes a while; a failure there is a real failure, not flakiness, in almost
  every case.

### Commit messages

Imperative mood, one line, no scope prefix. Match the existing log:

```
Build gperf, which fontconfig needs on Linux
Restore ffplay by going back to SDL2, and enable lcms2 and libunibreak
```

Add a body when the *why* is not obvious from the subject. Pure-formatting commits are recorded
in `.git-blame-ignore-revs`.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](LICENSE) that covers this project.

Note that the script can produce non-free and unredistributable binaries when built with
`--enable-gpl-and-non-free`. That applies to the *output* of the script, not to the script
itself — see https://ffmpeg.org/legal.html.
