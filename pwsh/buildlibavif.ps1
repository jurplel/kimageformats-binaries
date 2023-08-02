#!/usr/bin/env pwsh

if (-Not (Get-Command meson)) {
    python -m pip install meson
}

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja wget
} elseif ($IsMacOS) {
    brew install ninja nasm
} else {
    sudo apt-get install ninja-build nasm
}

# Clone
git clone https://github.com/AOMediaCodec/libavif.git
cd libavif
git checkout v0.11.1

cd ext

# Build libyuv
git clone --single-branch https://chromium.googlesource.com/libyuv/libyuv
cd libyuv
git checkout 464c51a0

mkdir build
cd build
cmake -G Ninja -DBUILD_SHARED_LIBS=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" ..
ninja

cd ../../

# Build dav1d
cd ext

git clone -b 1.0.0 --depth 1 https://code.videolan.org/videolan/dav1d.git

cd dav1d

if ($IsWindows) {
    wget https://www.nasm.us/pub/nasm/releasebuilds/2.14/win64/nasm-2.14-win64.zip
    7z e -y nasm-2.14-win64.zip
}

if ($IsMacOS) {
    # arm64 cross build
    mkdir build-arm64
    cd build-arm64

    $env:CFLAGS="-arch arm64"
    meson --default-library=static --buildtype release --cross-file="../../../../../util/arm64-darwin-clang.meson" -Denable_tools=false -Denable_tests=false ..
    $env:CFLAGS=""
    ninja

    cd ..

    # x86_64 build
    mkdir build-x86_64
    cd build-x86_64

    meson --default-library=static --buildtype release -Denable_tools=false -Denable_tests=false ..
    ninja

    cd ..

    # combine to create universal binary
    mkdir build
    cd build
    mkdir src
    cd src
    lipo -create ../../build-arm64/src/libdav1d.a ../../build-x86_64/src/libdav1d.a -output libdav1d.a

    cd ../

    cp -r ../build-x86_64/include include/
} else {
    # Just a normal build
    mkdir build
    cd build
    meson --default-library=static --buildtype release -Denable_tools=false -Denable_tests=false ..
    ninja
}

cd ../../

# Build libavif 

mkdir ../build
cd ../build

cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" ..

ninja
$env:DESTDIR = "installed/"
ninja install

$env:libavif_DIR = "$PWD/installed/usr/local/lib/cmake/libavif"

cd ../../

