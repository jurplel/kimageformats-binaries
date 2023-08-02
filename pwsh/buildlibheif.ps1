#! /usr/bin/pwsh

# Clone
git clone https://github.com/strukturag/libheif.git
cd libheif
git checkout $(git tag | select -last 1)

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

cd third-party

# Clone libde265
git clone https://github.com/strukturag/libde265.git
cd libde265
git checkout $(git tag | select -last 1)

# Build libde265
mkdir build
cd build

if (!$IsMacOS) {
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/../installed/" -DCMAKE_BUILD_TYPE=Release -DDISABLE_EXECUTABLES=ON -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" ..
}
ninja
ninja install

# unfinished