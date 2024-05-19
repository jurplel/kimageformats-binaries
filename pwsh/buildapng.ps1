#!/usr/bin/env pwsh

# Clone
git clone https://github.com/jurplel/QtApng.git
cd QtApng
git checkout 250f218ceeefdf2a6e66b596799abd279adea033


# Build

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

$argDeviceArchs = $env:universalBinary ? "QMAKE_APPLE_DEVICE_ARCHS=x86_64 arm64" : $null
qmake CONFIG+=libpng_static $argDeviceArchs

if ($IsWindows) {
    nmake
} else {
    make
}
cd ..
