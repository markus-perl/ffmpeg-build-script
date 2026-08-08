# shellcheck shell=bash
build_cmake() {
    if build "cmake" "${VER_CMAKE[0]}"; then
        CXXFLAGS_BACKUP=$CXXFLAGS
        export CXXFLAGS+=" -std=c++11"
        download "https://github.com/Kitware/CMake/releases/download/v$CURRENT_PACKAGE_VERSION/cmake-$CURRENT_PACKAGE_VERSION.tar.gz"
        execute ./configure --prefix="${WORKSPACE}" --parallel="${MJOBS}" -- -DCMAKE_USE_OPENSSL=OFF
        execute make -j "$MJOBS"
        execute make install
        build_done "cmake" "$CURRENT_PACKAGE_VERSION"
        export CXXFLAGS=$CXXFLAGS_BACKUP
    fi
}
