/usr/bin/env pwsh

$kde_vers = 'v5.108.0'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $kde_vers

# Apply patch to cmake file for vcpkg libraw
if (-Not $IsWindows) {
    patch CMakeLists.txt ../util/kimageformats-find-libraw-vcpkg.patch 
}


# dependencies
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja pkgconfiglite
} elseif ($IsMacOS) {
    brew update
    brew install ninja
} else {
    sudo apt-get install ninja-build
}


& "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
& "$env:GITHUB_WORKSPACE/pwsh/get-vcpkg-deps.ps1"

if ($env:forceWin32 -ne 'true') {
    & "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1" $kde_vers
}

# HEIF not necessary on macOS since it ships with HEIF support
if ($IsMacOS) {
    $heifOn = "OFF"
} else {
    $heifOn = "ON"
}

if ((qmake --version -split '\n')[1][17] -eq '6') {
    $qt6flag = "-DBUILD_WITH_QT6=ON"
}

# Resolve pthread error on linux
if (-Not $IsWindows) {
    $env:CXXFLAGS += ' -pthread'
}

# Build kimageformats
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=$heifOn $qt6flag -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" .

ninja
ninja install

# Location of actual plugin files
$prefix = "installed/lib/plugins/imageformats/"
$prefix_out = "output/"

# Make output folder
mkdir -p $prefix_out

# Build arm64 version as well and macos and lipo them together
if ($env:universalBinary) {
    Write-Host "Building arm64 binaries"

    rm -rf CMakeFiles/
    rm -rf CMakeCache.txt

    $env:KF5Archive_DIR = $env:KF5Archive_DIR_ARM

    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed_arm64" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=$heifOn $qt6flag -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET="arm64-osx" -DCMAKE_OSX_ARCHITECTURES="arm64" .

    ninja
    ninja install

    Write-Host "Combining kimageformats binaries to universal"

    $prefix_arm = "installed_arm64/lib/plugins/imageformats/"

    $files = Get-ChildItem "$prefix" -Recurse -Filter *.so
    foreach ($file in $files) {
        lipo -create "$file" "$prefix_arm/$name" -output "$prefix_out/$name"
        lipo -info "$prefix_out/$name"
    }
} else {
# Copy shared libs from installed to output folder
    $files = Get-ChildItem "$prefix" -Recurse
    foreach ($file in $files) {
        cp $file $prefix_out
    }
}


# Copy karchive stuff to output as well
if ($IsWindows) {
    cp karchive/bin/*.dll $prefix_out
} elseif ($IsMacOS) {
    cp karchive/bin/*.dylib $prefix_out
} else {
    $env:KF5LibLoc = Split-Path -Path (Get-Childitem -Include libKF5Archive.so.5 -Recurse -ErrorAction SilentlyContinue)[0]
    cp $env:KF5LibLoc/* $prefix_out
}
