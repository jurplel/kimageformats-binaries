#! /usr/bin/pwsh

$kde_vers = 'v5.90.0'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $kde_vers


if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja
} elseif ($IsMacOS) {
    brew update
    brew install ninja
} else {
    sudo apt-get install ninja-build
}


# dependencies
if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }

    # update vcpkg
    & "$env:VCPKG_ROOT/bootstrap-vcpkg.bat"
    
    & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
} else {
    brew install extra-cmake-modules

    if (!$IsMacOS) {
        $env:PKG_CONFIG_PATH += ":/home/linuxbrew/.linuxbrew/lib/pkgconfig"
    }
}

& "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1"


# Build kimageformats

cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DKIMAGEFORMATS_HEIF=ON -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .

ninja

# Copy karchive stuff to output
if ($IsWindows) {
    cp karchive/bin/*.dll  bin/
}