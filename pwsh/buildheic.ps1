#! /usr/bin/pwsh

# Clone
git clone --depth 1 https://github.com/novomesk/qt-heic-image-plugin.git
cd qt-heic-image-plugin
git checkout 79fc828f6365d26045ad79acb80eb91a1251fdad

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja
} elseif ($IsMacOS) {
    brew install ninja
} else {
    sudo apt-get install ninja-build
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


if ($IsWindows) {
    cd qtbuild_5.15.2/
    qmake qt-heic-image-plugin_win64.pro 
    nmake
} else {
    $currentDir = ([string]$PWD).Replace('\', '/')
    qmake QMAKE_APPLE_DEVICE_ARCHS="x86_64 arm64" QMAKE_LIBDIR=3rdparty/install/lib/ "INCLUDEPATH += $currentDir/3rdparty/install/include/" qt-heic-image-plugin.pro
    make
}

# Copy libheif stuff to output (It's not compiled statically I guess?)
if ($IsWindows) {
    cp ../3rdparty/install/bin/*.dll  plugins/
} elseif ($IsMacOS) {
    cp 3rdparty/lib/*.dylib plugins/
}