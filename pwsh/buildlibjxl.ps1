#! /usr/bin/pwsh

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja
} elseif ($IsMacOS) {
    brew install ninja
} else {
    sudo apt-get install ninja-build
}

# Clone
git clone https://github.com/libjxl/libjxl.git
cd libjxl
git checkout bbbdc77a8e41ef95fa0a0f42331a9f2bd8dd1249
git submodule update --init --recursive

# build libjxl
mkdir build
cd build

cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/../installed/" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DJPEGXL_BUNDLE_GFLAGS=ON -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_ENABLE_SJPEG=OFF -DJPEGXL_ENABLE_SKCMS=ON -DJPEGXL_BUNDLE_SKCMS=ON -DJPEGXL_WARNINGS_AS_ERRORS=OFF -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_TOOLS=OFF ..
ninja
ninja install

cd ../

$env:PKG_CONFIG_PATH += ";$PWD/installed/lib/pkgconfig"

cd ../
