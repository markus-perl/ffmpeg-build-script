# Security Policy

## What this project is, for security purposes

`ffmpeg-build-script` is a build script. It downloads roughly 70 source archives over HTTPS,
verifies them against SHA-256 checksums pinned in the script, compiles them, and links the
result into a static FFmpeg binary. It runs with the privileges of whoever invokes it, and the
optional install step asks for `sudo` to copy the binaries into `/usr/local/bin`.

That shape determines what is in scope below.

## Supported versions

Only the latest commit on `master` is supported. Please confirm that the issue still exists
there before reporting — checksums, package versions and download URLs change often.

| Version | Supported |
| --- | --- |
| `master` | yes |
| tagged releases | no, upgrade to `master` |

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately through GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/markus-perl/ffmpeg-build-script/security).
2. Click **Report a vulnerability**.
3. Describe the issue, the impact, and how to reproduce it.

This creates a private advisory that only you and the maintainer can see.

Please include:

- The commit you tested.
- Your operating system and architecture.
- A reproduction — the exact command line, and a minimal patch or proof of concept if you have one.
- What an attacker gains, and what access they need to start with.

### Response

This project is maintained in spare time, so please expect a first response within about two
weeks. Fixes ship as a normal commit to `master`; if the issue warrants it, a GitHub Security
Advisory is published alongside it, crediting you unless you ask otherwise.

## In scope

- A pinned checksum that does not match the archive the URL serves, or a package downloaded
  with no checksum where one is possible.
- Downloads over plain HTTP, or any path where a man-in-the-middle could substitute a source
  archive without the build failing.
- Command injection or unquoted expansion in the script that lets an attacker-controlled value —
  an environment variable, a file name in the working directory, a downloaded archive's contents —
  execute arbitrary commands.
- Unsafe handling of the `sudo` install step, or the script writing outside its own directory
  when not installing.
- Insecure use of the temporary and working directories (`packages/`, `workspace/`), for example
  a predictable path an unprivileged local user could pre-create to influence the build.
- Anything in `.github/workflows/` that could let a pull request run with repository secrets.

## Out of scope

- **Vulnerabilities in FFmpeg itself or in the libraries it links.** Report those upstream —
  FFmpeg's process is at https://ffmpeg.org/security.html. If a pinned version here is affected
  by a known CVE, that is welcome as a **normal public issue or pull request** bumping the
  version; it is not a vulnerability in this script.
- Outdated bundled package versions with no known exploited vulnerability. Open a regular issue
  or send a version bump.
- The fact that `--enable-gpl-and-non-free` produces a binary you may not redistribute. That is
  a licensing matter, see https://ffmpeg.org/legal.html.
- The one-line installers piping `curl` into `bash`. This is a documented, deliberate
  convenience; clone the repository and inspect it first if you would rather not.
- Reports that amount to "the script runs code from the internet". That is what a source build
  is. Concrete weaknesses in *how* it does so are in scope, per the list above.
- Systems other than macOS, Debian and Ubuntu, unless the issue clearly affects those too.
