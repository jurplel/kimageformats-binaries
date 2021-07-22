#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/extra-cmake-modules.git
cd extra-cmake-modules
git checkout $(git describe --abbrev=0).substring(0, 7)

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/ci/pwsh/vcvars.ps1"
}

# Build
cmake -G Ninja .

ninja install

if ($IsWindows) {
    $env:ECM_DIR = "$PWD\installed\Program Files (x86)\ECM\share\ECM"
}

cd ../