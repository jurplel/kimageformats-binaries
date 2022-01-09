#! /usr/bin/pwsh

# Clone
git clone --depth 1 https://github.com/novomesk/qt-heic-image-plugin.git
cd qt-heic-image-plugin
git checkout 79fc828f6365d26045ad79acb80eb91a1251fdad

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

# build libheif and stuff
cd 3rdparty
mkdir build
mkdir download
mkdir install
cd build
$currentDir = ([string]$PWD).Replace('\', '/')
cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release -DEXTERNALS_DOWNLOAD_DIR="$currentDir/../download" -DINSTALL_ROOT="$currentDir/../install"
ninja

cd ..\..

# plugin
cd qtbuild_5.15.2/
qmake qt-heic-image-plugin_win64.pro 

if ($IsWindows) {
    nmake
} else {
    make
}

