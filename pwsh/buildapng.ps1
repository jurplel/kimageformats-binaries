#! /usr/bin/pwsh

# Clone
git clone https://github.com/jurplel/QtApng.git
cd QtApng
git checkout 31bdace25eee2c35a351008c3886823f65e39447



# Build

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

qmake "CONFIG += libpng_static" QMAKE_APPLE_DEVICE_ARCHS="x86_64 arm64"
if ($IsWindows) {
    nmake
} else {
    make
}
cd ..
