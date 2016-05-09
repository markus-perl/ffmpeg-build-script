#!/bin/bash
# Helper script to download and run the build-ffmpeg script.

make_dir () {
    if [ ! -d $1 ]; then
        if ! mkdir $1; then            
            printf "\n Failed to create dir %s" "$1";
            exit 1
        fi
    fi    
}

command_exists() {
    if ! [[ -x $(command -v "$1") ]]; then
        return 1
    fi

    return 0
}

TARGET='ffmpeg-build'

if ! command_exists "curl"; then
    echo "curl not installed.";
    exit 1
fi

echo "Creating ffmpeg build directory"
make_dir $TARGET
cd $TARGET

bash <(curl -s https://raw.githubusercontent.com/markus-perl/ffmpeg-build-script/master/build-ffmpeg) --build

