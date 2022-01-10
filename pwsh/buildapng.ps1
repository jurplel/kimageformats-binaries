#! /usr/bin/pwsh

# Clone
git clone https://github.com/Skycoder42/QtApng
cd QtApng
git checkout $(git tag | select -last 1)



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
