#! /usr/bin/pwsh

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja
    python -m pip install meson
    choco install wget
} elseif ($IsMacOS) {
    brew install ninja
} else {
    sudo apt-get install ninja-build
}

# Clone
git clone https://github.com/novomesk/qt-avif-image-plugin
cd qt-avif-image-plugin
git checkout ffda69508b2b7299d041fa1360259c2c9c6c8c3c

if ($IsWindows) {    
    # libyuv
    cd ext\libavif\ext\libyuv
    mkdir build
    cd build
    cmake -G "NMake Makefiles" -DBUILD_SHARED_LIBS=0 -DCMAKE_BUILD_TYPE=Release ..
    nmake yuv
    copy yuv.lib libyuv.a

    # dav1d
    cd ..\..\dav1d
    wget https://www.nasm.us/pub/nasm/releasebuilds/2.14/win64/nasm-2.14-win64.zip
    7z e -y nasm-2.14-win64.zip
    mkdir build
    cd build
    meson --default-library=static --buildtype release ..
    ninja
    
    # libavif
    cd ..\..\..\
    mkdir build-ro
    cd build-ro
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON -DAVIF_LOCAL_LIBYUV=ON ..
    ninja
    copy avif.lib libavif.a 
    
    # plugin
    cd ..\..\..\qtbuild_5.15.2-ro
    qmake qt-avif-image-plugin_local_alternative-libavif-ro.pro
    nmake
} else {
    ./build_libqavif_static.sh
    make
    sudo make install
}