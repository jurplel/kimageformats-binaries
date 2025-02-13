#!/usr/bin/env pwsh

$qtVersion = [version](qmake -query QT_VERSION)

$kfGitRef = $args[0]

# Clone
git clone https://invent.kde.org/frameworks/extra-cmake-modules.git
cd extra-cmake-modules
git checkout $kfGitRef

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

$argQt6 = $qtVersion.Major -eq 6 ? '-DBUILD_WITH_QT6=ON' : $null
$argDeviceArchs = $IsMacOS -and $env:buildArch -eq 'Universal' ? '-DCMAKE_OSX_ARCHITECTURES=x86_64;arm64' : $null

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DCMAKE_BUILD_TYPE=Release $argQt6 $argDeviceArchs .

if ($IsWindows) {
    ninja install
} else {
    sudo ninja install
}
$env:ECM_DIR = "$PWD/installed/share/ECM"

cd ../
