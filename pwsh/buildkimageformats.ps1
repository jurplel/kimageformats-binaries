#! /usr/bin/pwsh

# remember to update modified cmakelists each version change
$kde_vers = 'v5.90.0'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git

cp -Force ./CMakeLists1.txt kimageformats/CMakeLists.txt
cp -Force ./CMakeLists2.txt kimageformats/src/imageformats/CMakeLists.txt

cd kimageformats
git checkout $kde_vers

# Get dependencies
if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    
    & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
    & "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1"
    & "$env:VCPKG_ROOT/vcpkg.exe" install libheif libavif libjxl openexr
} else {
    brew update
    brew install nasm libheif openexr jpeg-xl libavif karchive

    if ($IsMacOS) {
        brew install ninja 
    } else {
        $env:PKG_CONFIG_PATH += ":/home/linuxbrew/.linuxbrew/lib/pkgconfig"
        sudo apt-get install ninja-build
    }

    & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
}


# Build

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}


cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DKIMAGEFORMATS_HEIF=ON -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .

ninja


# Move some dependencies around
if ($IsMacOS) {
    mv libavif/build/installed/usr/local/lib/libavif.dylib kimageformats/bin/

    mv karchive/bin/*.dylib kimageformats/bin/
} elseif ($IsLinux) {
    mv libavif/build/installed/libavif.so kimageformats/bin/
    mv karchive/bin/*.so kimageformats/bin/
} elseif ($IsWindows) {
    mv kimageformats/bin/imageformats/aom.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/avif.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/heif.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/libde265.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/libx265.dll kimageformats/bin/
}

find .