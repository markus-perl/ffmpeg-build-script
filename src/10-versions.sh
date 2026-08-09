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
# shellcheck disable=SC2034 # read indirectly by download(), see the note above
VER_FFMPEG=("$FFMPEG_VERSION" "d97647ace36a307f17ba2bca052d68937487bed8682e1eb9b6737076a9c442b7")

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
VER_ZLIB=("1.3.2" "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16")
# xz, for liblzma. Note 5.6.0 and 5.6.1 carried the xz-utils backdoor (CVE-2024-3094);
# this is well past both, and the tarball is pinned by checksum like every other package.
VER_XZ=("5.8.3" "3d3a1b973af218114f4f889bbaa2f4c037deaae0c8e815eec381c3d546b974a0")
# 1.0.8 is the last release from sourceware and has been current since 2019; the successor
# repository at gitlab.com/bzip2/bzip2 has never tagged one.
VER_BZIP2=("1.0.8" "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269")
VER_M4=("1.4.21" "38ae59f7a30bf9c108193cc5c25fbb06014f21e230c7ede2eff614f7b7c37ed8")
VER_AUTOCONF=("2.73" "259ddfa3bddc799cfb81489cc0f17dfdf1bd6d1505dda53c0f45ff60d6a4f9a7")
VER_AUTOMAKE=("1.18.1" "63e585246d0fc8772dffdee0724f2f988146d1a3f1c756a3dc5cfbefa3c01915")
VER_LIBTOOL=("2.6.2" "24adb3aa9ae035c70faba344af57d73215eb89281045af6c7ccd307751f8b0bf")
VER_GETTEXT=("1.0" "85d99b79c981a404874c02e0342176cf75c7698e2b51fe41031cf6526d974f1a")
VER_OPENSSL=("4.0.1" "d8dee4712f66b113ab2060ca693febcfbf81edb08c323c1a87e7526364d0fef8")
VER_GMP=("6.3.0" "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898")
VER_NETTLE=("4.0" "3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094")
VER_GNUTLS=("3.8.13" "ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e")
VER_CMAKE=("4.4.2" "1db9e61e60b6e0874c86386340b910382f3c5e75b9fbfb44d122063129a2789d")

## video library
VER_DAV1D=("1.5.4" "a1d5b63d2d38ec9bd03acf643caa51fa22edd1e89c5a109c4807717216bbec07")
VER_SVTAV1=("4.2.0" "c7b13c4a84bd3751aa35fcc72be13e6875467e7c2216879251a486e5b1e4e740")
VER_RAV1E=("0.8.1" "06d1523955fb6ed9cf9992eace772121067cca7e8926988a1ee16492febbe01e")
VER_X264=("0480cb05" "b336cdb04eeca5d15a53db323bc716fd7a1dae7bf19df0a8a41379d2d65e05d0")
VER_X265=("b81f650" "540de59b5004274f70a4fe229e86c7602d49b5b1a96112fd95a9dcdb5c9f1dc9")
# The bitbucket archive URL needs the full commit hash, VER_X265 is its short form.
X265_COMMIT=b81f650e21e8aacbe6a9ad04ce14aefc05b932c0
# openh264 tags "2.5.1" without a "v" exist as GitHub *releases* only; every git
# tag, and therefore every archive URL, carries the "v" prefix. 2.6.0 is the
# newest tag, 2.5.1 is a later-published patch of the older 2.5 branch.
VER_OPENH264=("2.6.0" "558544ad358283a7ab2930d69a9ceddf913f4a51ee9bf1bfb9e377322af81a69")
# H.266/VVC encoder. Note the pkg-config module is libvvenc and ffmpeg requires >= 1.6.1.
VER_VVENC=("1.14.0" "dd43d061d59dbc0d9b9ae5b99cb40672877dd811646228938f065798939ee174")
VER_LIBVPX=("1.16.0" "7a479a3c66b9f5d5542a4c6a1b7d3768a983b1e5c14c60a9396edc9b649e015c")
VER_XVIDCORE=("1.3.7" "abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d")
VER_VID_STAB=("1.1.2" "96db34d48a9e3aa13736a48744b56dfb76731ac9bb5193c716de8534c9fd709d")
# Homebrew patch that vid_stab needs on Apple Silicon, pinned by URL to a commit.
VER_VID_STAB_PATCH=("" "45c16a2b64ba67f7ca5335c2f602d8d5186c29b38188b3cc7aff5df60aecaf60")
VER_FREI0R=("3.2.3" "898f80e5fdae6108a2d9b2317649af576a4b5e636c73429ee11b64397a596e12")
# av1 cannot be pinned: googlesource.com's +archive endpoint regenerates the
# tarball on every request with different bytes, so no hash is ever stable.
VER_AV1=("3.14.1" "")
VER_ZIMG=("3.0.6" "be89390f13a5c9b2388ce0f44a5e89364a20c1c57ce46d382b1fcc3967057577")
VER_LIBVMAF=("3.2.0" "a28f93f3b4fa65601be324587072e32a6a704a304ba7b1aec9b70b3f709bc1dc")

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
VER_FDK_AAC=("2.0.3" "829b6b89eef382409cda6857fd82af84fabb63417b08ede9ea7a553f811cb79e")
VER_SOXR=("0.1.3" "b111c15fdc8c029989330ff559184198c161100a59312f5dc19ddeb9b5a15889")
VER_TWOLAME=("0.4.0" "cc35424f6019a88c6f52570b63e1baf50f62963a3eac52a03a800bb070d7c87d")
VER_RUBBERBAND=("4.0.0" "24300f48a8014b7c863b573a9647e61b1b19b37875e2cdd92005e64c6424d266")
VER_LIBOPENMPT=("0.8.7" "275c29ef47be9992f62a35fcc96f7ca05c06d2fd05c9298b8dee9f743f75b089")
VER_LIBGME=("0.6.5" "a133f19278222136ba0d8c27b64a07987ba05fec9d2e6d293ccd8cabdd97ddbb")
VER_CHROMAPRINT=("1.6.1" "7065ec9db48ac1fa929ec6c42afcd966605b1bfe48b6d5e64c25378a05f4fb02")
VER_OPENAL=("1.25.2" "fb27e5839aa11f0e5b9d33756965291fad5d6909ab928ea1f796f4a1a6877894")
# libpulse is not built from source (see build_libpulse); this only feeds the .done
# guard, the same way VER_VAAPI does.
VER_LIBPULSE=("1" "")

## image library
VER_LIBPNG=("1.6.58" "8c9b05b675ca7301a458df2c2e46f26e1d41ff36b8863f8c33530bc58c2e6225")
VER_LCMS2=("2.19.1" "bfc54f7bab59fbc921012014a8032e4cba4abd46db47d46b76416a8c0b2815c8")
VER_LIBJXL=("0.12.0" "03e9be69a30be4011f559da75328b6d7cea8ad921fabfbd551ce10bf45cdc992")
VER_LIBWEBP=("1.6.0" "e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564")
VER_OPENJPEG=("2.5.4" "a695fbe19c0165f295a8531b1e4e855cd94d0875d2f88ec4b61080677e27188a")

## other library
VER_LIBSDL=("2.32.10" "5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165")
VER_FREETYPE2=("2.14.3" "36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f")
VER_LIBSNAPPY=("1.2.2" "90f74bc1fbf78a6c56b3c4a082a05103b3a56bb17bca1a27e052ea11723292dc")
VER_LIBSSH=("0.12.2" "49560f677d96e3706a904ac2de1116e25f3680937d51e5c92198fcba4a1c1e9f")

## text shaping and subtitle library
VER_LIBXML2=("2.15.3" "78262a6e7ac170d6528ebfe2efccdf220191a5af6a6cd61ea4a9a9a5042c7a07")
VER_FRIBIDI=("1.0.16" "1b1cde5b235d40479e91be2f0e88a309e3214c8ab470ec8a2744d82a5a9ea05c")
VER_HARFBUZZ=("14.3.0" "16070d77cfc4ba1f1e7327e83bf9b3f55898081cabdb94e56a33e04fc8874eae")
VER_GPERF=("3.3" "fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8")
VER_FONTCONFIG=("2.18.3" "4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3")
VER_LIBUNIBREAK=("7.0" "8c9a6e121736cd0d5c890ae3ae96f3f4010a19aa040f1dbded833a62a87717d3")
VER_LIBASS=("0.17.5" "2dca25c0e0c837ddf00b52011b3f82cac1e4ddd3ad018227806b0c2288864acc")
VER_VAPOURSYNTH=("78" "cbd5aa49d43a9e5061c5ea4b03a682322065f3d9b8870c36bfb8afa0f635e066")
VER_AVISYNTH=("3.7.5" "2533fafe5b5a8eb9f14d84d89541252a5efd0839ef62b8ae98f40b9f34b3f3d5")
VER_SRT=("1.5.6" "2c4980c2c4cfd142d21b829d939dc51db9c6628af5967fff62fd7290769569c7")
VER_ZVBI=("0.2.44" "bca620ab670328ad732d161e4ce8d9d9fc832533cb7440e98c50e112b805ac5e")
# libbluray's only mandatory dependency, and a separate package because it cannot be
# anything else: see the comment on build_libudfread.
VER_LIBUDFREAD=("1.2.0" "bb477cbd4cfbfc7787d9d05b71ee5e70430f5cfebf1297497f7e83547958050f")
VER_LIBBLURAY=("1.5.0" "f676408e91a5d321abf8b8d4dfdae36205c297dab5c54c3ec519639025f474a2")

## zmq library
VER_LIBZMQ=("4.3.5" "6653ef5910f17954861fe72332e68b03ca6e4d9c7160eb3a8de5a5a913bfab43")

## HWaccel library
VER_VULKAN_HEADERS=("1.4.358" "a4a92dcd138cece5722d87e26419442a432a819eb0a07b2e93d89d8b7628761f")
# SPIRV-Headers is tagged "vulkan-sdk-<version>", so the version here carries no
# "v" prefix and build_spirv_headers prepends the tag prefix instead.
VER_SPIRV_HEADERS=("1.4.357.0" "4d703067a7e06331ccb37bdfed3f9b7879cc61969a2689ae95c95db34a47ff07")
VER_SPIRV_TOOLS=("1.4.357.0" "d31e7109b6ef3559067e53e520870eafed7c9534d00db9728814b6df03fa4a5e")
VER_GLSLANG=("16.5.0" "01af17195fbeb59e39e31e9506de35bb39dfd35807ea0c9a1a99d7d1183ddd45")
VER_LIBPLACEBO=("7.360.1" "d05fdf90bea2f629eaa2d115e909fd356388ac639e54f77b87a018a6d76224bd")
# libplacebo's git submodules, which the GitHub tag archive does not contain and
# for which upstream publishes no bundled release tarball. Pinned here as ordinary
# downloads so nothing has to be fetched unpinned (or with pip) during the build -
# see build_libplacebo for which of the six submodules are needed and why. The
# versions are the exact commits the v7.360.1 gitlink points at, resolved to their
# upstream tags: jinja 15206881 = 3.1.6, markupsafe 297fc8e3 = 3.0.3,
# fast_float 97b54ca9 = v8.2.2.
VER_LIBPLACEBO_JINJA=("3.1.6" "2074b22a72caa65474902234b320d73463d6d4c223ee49f4b433495758356337")
VER_LIBPLACEBO_MARKUPSAFE=("3.0.3" "f1d9d06c34515dd3ad210ec769da613057b536d11d6c039183b87757a883a254")
VER_LIBPLACEBO_FAST_FLOAT=("8.2.2" "e64b5fff88e04959154adbd5fb83331d91f2e04ac06454671cdfcbdff172b158")
VER_NV_CODEC=("13.1.15.0" "52532ceade3d5c1af62624986f13cf01b63c910576b08c0c278756c5e4b41ad0")
# vaapi is a marker package: nothing is downloaded, so it has no checksum.
VER_VAAPI=("1" "")
VER_AMF=("1.5.2" "8a70b6dc85261e6e6e57769bd81ac1e09c0a4c96bbd5e358ffbc2dee51e8e50a")
# The oneVPL dispatcher, renamed from oneVPL to libvpl upstream (github.com/intel/oneVPL
# now 301s to intel/libvpl). ffmpeg 9.0 wants "vpl >= 2.6"; this is 2.17.
VER_LIBVPL=("2.17.0" "4de3e2faf1e8307fb282e4a43f443191810f6a6b0a484fffa7995ba1c814c6ec")
VER_OPENCL_HEADERS=("2026.05.29" "d9e6c48357de5002da11ce45de600e0c3ffe6ab4f628a3b9fe2b38603161658a")
VER_OPENCL_ICD_LOADER=("2026.05.29" "48fd0c5181db7cd046f4f731d5955694892e10998d49d09ee0d997e7e04fd939")
