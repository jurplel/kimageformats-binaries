#! /usr/bin/pwsh

python -m pip install meson

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja wget
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
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON -DAVIF_LOCAL_LIBYUV=ON -DAVIF_ENABLE_WERROR=OFF ..
    ninja
    copy avif.lib libavif.a 
    
    # plugin
    cd ..\..\..\qtbuild_5.15.2-ro
    qmake qt-avif-image-plugin_local_alternative-libavif-ro.pro
    nmake
} else {
    brew install nasm
    if (!$IsMacOS) {
        $env:PKG_CONFIG_PATH += ":/home/linuxbrew/.linuxbrew/lib/pkgconfig"
    }

    echo 'We are going to build libyuv.a'
    cd ext/libavif/ext/libyuv
    mkdir build
    cd build
  
    cmake -G Ninja -DBUILD_SHARED_LIBS=0 -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" ..
    ninja yuv

    cd ../../../

    echo 'We are going to build libdav1d.a'
    cd ext/dav1d
    mkdir build
    cd build

    $env:CFLAGS = "-arch x86_64 -arch arm64"
    meson --default-library=static --buildtype release ..
    Remove-Item Env:\CFLAGS

    ninja

    cd ../../../

    echo 'We are going to build libavif.a'
    mkdir build-ro
    cd build-ro
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON -DAVIF_LOCAL_LIBYUV=ON -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" ..
    ninja

    cd ../../../
    
    echo 'We are going to build qt-avif-image-plugin'
    cd qtbuild_6.2.2-ro
    
    qmake QMAKE_APPLE_DEVICE_ARCHS="x86_64 arm64" .
    make
}