#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/extra-cmake-modules.git
cd extra-cmake-modules
git checkout $args[0]

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

# Build
cmake -G Ninja -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" .

if ($IsWindows) {
    ninja install
    $env:ECM_DIR = "$PWD\installed\Program Files (x86)\ECM\share\ECM"
} else {
    sudo ninja install
}

cd ../