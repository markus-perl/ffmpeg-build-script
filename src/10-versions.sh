# shellcheck shell=bash
##
## Package versions and tarball SHA-256 checksums.
##
## One VER_<PACKAGE>=("<version>" "<sha256>") array per entry in
## PACKAGE_BUILD_ORDER, in the same order. <PACKAGE> is the name passed to
## build(), uppercased, with every non-alphanumeric character replaced by an
## underscore - download() derives the array name from it mechanically, so the
## two must stay in sync. Element 0 is the version, element 1 the checksum.
##
## The checksum is the one of the downloaded archive, not of its contents. An
## empty checksum means "not pinned yet" and skips verification for that
## download. Deliberately no associative arrays here: /bin/bash on macOS is
## still 3.2, where "declare -A" is a fatal error - indexed arrays are fine.
##
# Unpinned on purpose: the script tracks the latest FFMPEG_MAJOR_VERSION.x release
# rather than one fixed tarball, so there is no single checksum to pin here. See
# FFMPEG_MAJOR_VERSION in 00-header.sh and the resolution in 40-cli.sh.
# shellcheck disable=SC2034 # read indirectly by download(), see the note above
VER_FFMPEG=("$FFMPEG_VERSION" "")

## build tools
VER_GIFLIB=("6.1.3" "b65b66b99f0424b93525f987386f22fc5efb9da2bfc92ad4a532249aaffbab0e")
VER_PKG_CONFIG=("0.29.2" "6fc69c01688c9458a57eb9a1664c9aba372ccda420a02bf4429fe610e7e7d591")
# yasm is pinned to a master commit rather than a release: 1.3.0 is from 2019 and its
# libyasm/bitvect.h declares an enumeration constant named "false", which C23 rejects, so
# it does not build on GCC 15 (Ubuntu 26.04). Upstream guarded that on __STDC_VERSION__
# but has published no release since. A commit archive has no generated configure, so
# build_yasm bootstraps with autogen.sh and the entry sits after automake below.
VER_YASM=("09d1bc90ed53d0ec3e9b074f111058cbf262ed56" "5908256a2db37ca6f6b60025ee2a4a81a52ff8588e08776ce37c2551f00ab2e0")
VER_NASM=("3.02" "87336eba53b4acfe917424ab5d500d2b0054d9f5148d35c2273ccf2cfb712f0d")
VER_ZLIB=("1.4" "02dd159783677a749c04adbdd02b55b8a2bcc7e054f51b76b549199a916ad584")
# xz, for liblzma. Note 5.6.0 and 5.6.1 carried the xz-utils backdoor (CVE-2024-3094);
# this is well past both, and the tarball is pinned by checksum like every other package.
VER_XZ=("5.8.4" "0014c7886930454fe8bd4228665b51af55eeae560ea135c9c4cd33f55b2591d9")
# 1.0.8 is the last release from sourceware and has been current since 2019; the successor
# repository at gitlab.com/bzip2/bzip2 has never tagged one.
VER_BZIP2=("1.0.8" "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269")
VER_M4=("1.4.21" "38ae59f7a30bf9c108193cc5c25fbb06014f21e230c7ede2eff614f7b7c37ed8")
VER_AUTOCONF=("2.73" "259ddfa3bddc799cfb81489cc0f17dfdf1bd6d1505dda53c0f45ff60d6a4f9a7")
VER_AUTOMAKE=("1.20" "00c0e397a3c0096b1b9167eb4a5ecb87a66fe50888d939c4e02111e603936570")
VER_LIBTOOL=("2.6.2" "24adb3aa9ae035c70faba344af57d73215eb89281045af6c7ccd307751f8b0bf")
VER_GETTEXT=("1.0" "85d99b79c981a404874c02e0342176cf75c7698e2b51fe41031cf6526d974f1a")
VER_OPENSSL=("4.1.0" "2a54158eb6861c07cefc92f1a1d68b12d5ecc0883d53c61a092995b221c7d5fe")
VER_GMP=("6.3.0" "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898")
VER_NETTLE=("4.0" "3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094")
VER_GNUTLS=("3.8.13" "ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e")
VER_CMAKE=("4.5.0" "424352d6133e8455e020da787008e8dc67abb18820af3532572ab35657e49213")

## video library
VER_DAV1D=("1.5.4" "a1d5b63d2d38ec9bd03acf643caa51fa22edd1e89c5a109c4807717216bbec07")
VER_SVTAV1=("4.3.0" "95ce8fc2381ba707e65ac8b9b2e165915bfbe9cd4d2f7b0f58d64ce31bd98f6d")
VER_RAV1E=("0.8.1" "06d1523955fb6ed9cf9992eace772121067cca7e8926988a1ee16492febbe01e")
VER_X264=("0480cb05" "b336cdb04eeca5d15a53db323bc716fd7a1dae7bf19df0a8a41379d2d65e05d0")
VER_X265=("b81f650" "540de59b5004274f70a4fe229e86c7602d49b5b1a96112fd95a9dcdb5c9f1dc9")
# The bitbucket archive URL needs the full commit hash, VER_X265 is its short form.
X265_COMMIT=b81f650e21e8aacbe6a9ad04ce14aefc05b932c0
# openh264 tags "2.5.1" without a "v" exist as GitHub *releases* only; every git
# tag, and therefore every archive URL, carries the "v" prefix. 2.7.0 is the
# newest tag, 2.5.1 is a later-published patch of the older 2.5 branch.
VER_OPENH264=("2.7.0" "5178775c8b440073e70920e97d195efff721c0e56d0a78cc82c919e95d54924d")
# H.266/VVC encoder. Note the pkg-config module is libvvenc and ffmpeg requires >= 1.6.1.
VER_VVENC=("1.14.0" "dd43d061d59dbc0d9b9ae5b99cb40672877dd811646228938f065798939ee174")
VER_LIBVPX=("1.17.0" "1020f184046187baa2985dbde38e0691f49c44088bca7a1842b0236c6081dc0a")
VER_XVIDCORE=("1.3.7" "abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d")
VER_VID_STAB=("1.1.2" "96db34d48a9e3aa13736a48744b56dfb76731ac9bb5193c716de8534c9fd709d")
# Homebrew patch that vid_stab needs on Apple Silicon, pinned by URL to a commit.
VER_VID_STAB_PATCH=("" "45c16a2b64ba67f7ca5335c2f602d8d5186c29b38188b3cc7aff5df60aecaf60")
VER_FREI0R=("3.7.1" "5543917de48d2e8cc2fa02794240a3613447d00458bc2cf606aef20f4b8da515")
# The official AOM release tarball is published at a stable storage URL and is
# checksum-pinned like every other package in the script.
VER_AV1=("3.15.3" "12c01dc731ed7b5a999e28120b45bf58a002ba3435a4ba2cfbc1e084a27c9c04")
VER_ZIMG=("3.0.6" "be89390f13a5c9b2388ce0f44a5e89364a20c1c57ce46d382b1fcc3967057577")
VER_LIBVMAF=("3.2.1" "5df7386911bc15fd1ca783132528748d219768ae4fc5f8e0b61184f041648092")

## audio library
VER_LV2=("1.18.10" "78c51bcf21b54e58bb6329accbb4dae03b2ed79b520f9a01e734bd9de530953f")
VER_WAFLIB=("aeef9f5f" "5d3c1da4bf509c025c242e3482859692b3b6ae4e325dc1c9d413d01e2d13fcfc")
VER_SERD=("0.32.10" "d17b99ef250e4dffcdd08c8eaad2459a1519c1ff2553fa91176ce71ac0dd0739")
VER_PCRE=("8.45" "4e6ce03e0336e8b4a3d6c2b70b1c5e18590a5673a98186da90d4f33c23defc09")
VER_ZIX=("0.8.2" "a2464cdc11fa359b5e713b3c82bf0b476952efe397a02374ddbc1b62eee04f13")
VER_SORD=("0.16.22" "040fb3f369dd49a7717eb28ca0a66766352e25e760729903fc8a01e117122901")
VER_SRATOM=("0.6.22" "4a88bde345370584b279895c2cb8f7f8341d2b31b6ca50e128faea02f02d3e76")
VER_LILV=("0.28.0" "006065dcb59ccaad5463e6bb4598160e41dd6474a959838e74820f60a849bfdb")
# The LADSPA SDK has no upstream git repository and no release tags; ladspa.org
# only ever publishes a versioned tarball, which is why this URL does not follow
# the GitHub-tag pattern used everywhere else. The filename carries the version,
# so the bytes are stable and hashable (verified by downloading it twice), and
# the ladspa.h inside is byte-identical to the one in Debian's ladspa-sdk
# 1.17 orig tarball. The GitHub copies that turn up in a search are all distro
# packaging forks or vendored snapshots, none of them authoritative.
VER_LADSPA=("1.17" "27d24f279e4b81bd17ecbdcc38e4c42991bb388826c0b200067ce0eb59d3da5b")
VER_OPENCORE=("0.1.6" "483eb4061088e2b34b358e47540b5d495a96cd468e361050fae615b1809dc4a1")
VER_LAME=("4.0" "3df5124d5ad3a98312ffd7ba6a9b36230e4f8a3e66d3ce0f425e336c32d216eb")
VER_OPUS=("1.6.1" "6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1")
VER_LIBOGG=("1.3.6" "5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061")
VER_LIBVORBIS=("1.3.7" "0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab")
VER_LIBTHEORA=("1.2.0" "279327339903b544c28a92aeada7d0dcfd0397b59c2f368cc698ac56f515906e")
VER_FDK_AAC=("3.0.0" "70b95857b958fb8f794489307a87845dde4cc1fcea060f3f29f40e4b2fe16c82")
VER_SOXR=("0.1.3" "b111c15fdc8c029989330ff559184198c161100a59312f5dc19ddeb9b5a15889")
VER_TWOLAME=("0.4.0" "cc35424f6019a88c6f52570b63e1baf50f62963a3eac52a03a800bb070d7c87d")
VER_LIBMYSOFA=("1.3.5" "f29508c335c83d8703f943ffc9ca783ac39aca84e851357f13a55af0f8143137")
VER_RUBBERBAND=("4.0.0" "24300f48a8014b7c863b573a9647e61b1b19b37875e2cdd92005e64c6424d266")
VER_LIBOPENMPT=("0.8.10" "976d259288c40cd285771f77d09eff3d02514511d5677ecfcfb53be5013317e2")
VER_LIBGME=("0.6.5" "a133f19278222136ba0d8c27b64a07987ba05fec9d2e6d293ccd8cabdd97ddbb")
VER_CHROMAPRINT=("1.6.2" "7f92ea1141429b43f695a1ba56d5058132f89fae5f137ce705afc57734f6b5fa")
VER_OPENAL=("1.25.2" "fb27e5839aa11f0e5b9d33756965291fad5d6909ab928ea1f796f4a1a6877894")
# libpulse is not built from source (see build_libpulse); this only feeds the .done
# guard, the same way VER_VAAPI does.
VER_LIBPULSE=("1" "")

## image library
VER_LIBPNG=("1.6.59" "86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad")
VER_LCMS2=("2.20" "18ff5504fa9cc8a2b1f3591180d90ead16c8a2ea78e530523b46eab70e1ca6b9")
VER_LIBJXL=("0.13.0" "24d18c9af2d1f5a17730b3f8d3f70a5c16e5ac303f5d9d5fe9dc00cf7ca82af2")
VER_LIBWEBP=("1.6.0" "e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564")
VER_OPENJPEG=("2.5.4" "a695fbe19c0165f295a8531b1e4e855cd94d0875d2f88ec4b61080677e27188a")

## other library
VER_LIBSDL=("2.32.10" "5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165")
VER_FREETYPE2=("2.15.0" "93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5")
VER_LIBSNAPPY=("1.3.1" "893f708a0bf4b5529d555ffcee390e940e932fcf90261f682604475a76cd0247")
VER_LIBSSH=("0.12.2" "49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f")

## text shaping and subtitle library
VER_LIBXML2=("2.15.4" "98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821")
VER_FRIBIDI=("1.0.18" "1de5e8073d035388b71d0b2d452b1da1f8caeea8a7702997b401fe1b6250727f")
VER_HARFBUZZ=("15.1.0" "0fc7c565443a5f4be7da65ac5ee5bd737d9b158dc908708b7689a0a5796b0c8d")
VER_GPERF=("3.3" "fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8")
VER_FONTCONFIG=("2.18.3" "4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3")
VER_LIBUNIBREAK=("8.0.1" "ac0dcc96c395bc86ff7f86f6b91d8b45bc8c39db775f3f1e73f947a11520737b")
VER_LIBASS=("0.17.5" "2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc")
VER_VAPOURSYNTH=("82" "8994fbcfa2fcaa5dc94109e547060521f60829a0899747e98e351bed72bd9611")
VER_AVISYNTH=("3.7.6" "8c019a934189688e73fe1cd85e6768cc0bc120fe1f4a3310c889060283c9e083")
VER_SRT=("1.5.7" "017cd1e437ef2073a4dd10ddf7b55e86bc3d6ebac0393d13bd22f6a57055d32b")
VER_ZVBI=("0.2.46" "817a26118e2654155ee761cd39414885986a4315fdb6617af5314090ddfffd10")
# libbluray's only mandatory dependency, and a separate package because it cannot be
# anything else: see the comment on build_libudfread.
VER_LIBUDFREAD=("1.2.0" "bb477cbd4cfbfc7787d9d05b71ee5e70430f5cfebf1297497f7e83547958050f")
VER_LIBBLURAY=("1.5.0" "f676408e91a5d321abf8b8d4dfdae36205c297dab5c54c3ec519639025f474a2")

## zmq library
VER_LIBZMQ=("4.3.5" "6653ef5910f17954861fe72332e68b03ca6e4d9c7160eb3a8de5a5a913bfab43")

## HWaccel library
VER_VULKAN_HEADERS=("1.4.368" "5c5c6f64fcce28a24cc934143a048707af036a858e4ed11d7f71fe016006ecda")
# SPIRV-Headers is tagged "vulkan-sdk-<version>", so the version here carries no
# "v" prefix and build_spirv_headers prepends the tag prefix instead.
VER_SPIRV_HEADERS=("1.4.363.0" "5b3a0d099f5c7649e29c0938476c462e71d66ad89a0bde42fa1ba3eb476956c9")
VER_SPIRV_TOOLS=("1.4.363.0" "e6c83a215538fbfd265ccf398d3877985055df1273dbed73912bd05307664688")
VER_GLSLANG=("16.6.0" "9c09b901149c729df745057dafa815278aaa101b84d2b6e14f16a42de52f97f2")
VER_LIBPLACEBO=("7.387.0" "f9e62d3774a9c4cfd198ec3abaa88294aaade2e31c04d5ab02bcf4abc98b1df5")
# libplacebo's git submodules, which the GitHub tag archive does not contain and
# for which upstream publishes no bundled release tarball. Pinned here as ordinary
# downloads so nothing has to be fetched unpinned (or with pip) during the build -
# see build_libplacebo for which of the six submodules are needed and why. The
# versions are the exact commits the v7.387.0 gitlink points at, resolved to their
# upstream tags: jinja 15206881 = 3.1.6, markupsafe 297fc8e3 = 3.0.3,
# fast_float 97b54ca9 = v8.2.2.
VER_LIBPLACEBO_JINJA=("3.1.6" "2074b22a72caa65474902234b320d73463d6d4c223ee49f4b433495758356337")
VER_LIBPLACEBO_MARKUPSAFE=("3.0.3" "f1d9d06c34515dd3ad210ec769da613057b536d11d6c039183b87757a883a254")
VER_LIBPLACEBO_FAST_FLOAT=("8.2.2" "e64b5fff88e04959154adbd5fb83331d91f2e04ac06454671cdfcbdff172b158")
VER_NV_CODEC=("13.1.15.0" "52532ceade3d5c1af62624986f13cf01b63c910576b08c0c278756c5e4b41ad0")
# vaapi is a marker package: nothing is downloaded, so it has no checksum.
VER_VAAPI=("1" "")
VER_AMF=("1.5.3" "eb7d7d14c239117478f229cf174dc359fa2ba1e0817a7cb16277cc5251709f0f")
# The oneVPL dispatcher, renamed from oneVPL to libvpl upstream (github.com/intel/oneVPL
# now 301s to intel/libvpl). ffmpeg 9.0 wants "vpl >= 2.6"; this is 2.17.
VER_LIBVPL=("2.17.0" "4de3e2faf1e8307fb282e4a43f443191810f6a6b0a484fffa7995ba1c814c6ec")
VER_OPENCL_HEADERS=("2026.05.29" "d9e6c48357de5002da11ce45de600e0c3ffe6ab4f628a3b9fe2b38603161658a")
VER_OPENCL_ICD_LOADER=("2026.05.29" "48fd0c5181db7cd046f4f731d5955694892e10998d49d09ee0d997e7e04fd939")

## speech recognition
# whisper.cpp, for the af_whisper filter. Built last - see the comment on the
# "whisper" entry in PACKAGE_BUILD_ORDER - so its array sits last here too.
VER_WHISPER=("1.9.5" "ff1a9053feb509ff9d7729703355541ae9690073a6b1c40eb692c962e0dc1720")
