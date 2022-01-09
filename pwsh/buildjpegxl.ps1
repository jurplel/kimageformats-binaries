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
git clone --depth 1 https://github.com/novomesk/qt-jpegxl-image-plugin.git
cd qt-jpegxl-image-plugin
git checkout ab2ede6d84d672bd26dd64b938ea4a818dbef439
git clone --depth 1 https://github.com/libjxl/libjxl.git --recursive
cd libjxl

mkdir build
cd build

cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DJPEGXL_STATIC=ON -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_BUNDLE_GFLAGS=ON -DJPEGXL_ENABLE_BENCHMARK=OFF -DJPEGXL_ENABLE_EXAMPLES=OFF -DJPEGXL_ENABLE_SJPEG=OFF -DJPEGXL_ENABLE_SKCMS=ON -DJPEGXL_BUNDLE_SKCMS=ON -DJPEGXL_WARNINGS_AS_ERRORS=OFF -DCMAKE_C_FLAGS="-DJXL_STATIC_DEFINE -DJXL_THREADS_STATIC_DEFINE" -DCMAKE_CXX_FLAGS="-DJXL_STATIC_DEFINE -DJXL_THREADS_STATIC_DEFINE" ..
ninja jxl-static jxl_threads-static hwy brotlicommon-static brotlidec-static brotlienc-static

cd ../../

qmake qt-jpegxl-image-plugin_appveyor.pro
if ($IsWindows) {
    nmake
} else {
    make
}
