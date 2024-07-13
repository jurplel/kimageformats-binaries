#!/usr/bin/env pwsh

$kde_vers = 'v5.116.0'

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
    if ($env:buildArch -eq 'Arm64') {
        # CMake needs QT_HOST_PATH when cross-compiling
        $env:QT_HOST_PATH = [System.IO.Path]::GetFullPath("$env:QT_ROOT_DIR\..\$((Split-Path -Path $env:QT_ROOT_DIR -Leaf) -replace '_arm64', '_64')")
    }
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja pkgconfiglite

    # Workaround for https://developercommunity.visualstudio.com/t/10664660
    $env:CXXFLAGS += " -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR"
    $env:CFLAGS += " -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR"
} elseif ($IsMacOS) {
    brew update
    brew install ninja
} else {
    sudo apt-get install ninja-build
}


& "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
& "$env:GITHUB_WORKSPACE/pwsh/get-vcpkg-deps.ps1"
& "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1" $kde_vers

if ((qmake --version -split '\n')[1][17] -eq '6') {
    $qt6flag = "-DBUILD_WITH_QT6=ON"
}

# Resolve pthread error on linux
if (-Not $IsWindows) {
    $env:CXXFLAGS += ' -pthread'
}

# Build kimageformats
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=ON $qt6flag -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" .

ninja
ninja install

# Location of actual plugin files
$prefix_out = "output"

# Make output folder
mkdir -p $prefix_out

# Build arm64 version as well and macos and lipo them together
if ($IsMacOS -and $env:buildArch -eq 'Universal') {
    Write-Host "Building arm64 binaries"

    rm -rf CMakeFiles/
    rm -rf CMakeCache.txt
    
    $env:KF5Archive_DIR = $env:KF5Archive_DIR_ARM

    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed_arm64" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=ON $qt6flag -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET="arm64-osx" -DCMAKE_OSX_ARCHITECTURES="arm64" .

    ninja
    ninja install

    Write-Host "Combining kimageformats binaries to universal"

    $prefix = "installed/lib/plugins/imageformats"
    $prefix_arm = "installed_arm64/lib/plugins/imageformats"

    # Combine the two binaries and copy them to the output folder
    $files = Get-ChildItem "$prefix" -Recurse -Filter *.so
    foreach ($file in $files) {
        $name = $file.Name
        lipo -create "$file" "$prefix_arm/$name" -output "$prefix_out/$name"
        lipo -info "$prefix_out/$name"
    }

    # Combine karchive binaries too and send them to output
    $files = Get-ChildItem "karchive/installed/lib/" -Recurse -Filter *.dylib
    foreach ($file in $files) {
        $name = $file.Name
        lipo -create "$file" "karchive/installed_arm64/lib/$name" -output "$prefix_out/$name"
        lipo -info "$prefix_out/$name"
    }
} else {
    # Copy binaries from installed to output folder
    $files = dir ./installed/ -recurse | where {$_.extension -in ".dylib",".dll",".so"}
    foreach ($file in $files) {
        cp $file $prefix_out
    }

    # Copy karchive stuff to output as well
    if ($IsWindows) {
        cp karchive/bin/*.dll $prefix_out
        # Also copy all the vcpkg DLLs on windows, since it's apparently not static by default
        cp "$env:VCPKG_ROOT/installed/$env:VCPKG_DEFAULT_TRIPLET/bin/*.dll" $prefix_out
    } elseif ($IsMacOS) {
        cp karchive/bin/*.dylib $prefix_out
    } else {
        $env:KF5LibLoc = Split-Path -Path (Get-Childitem -Include libKF5Archive.so.5 -Recurse -ErrorAction SilentlyContinue)[0]
        cp $env:KF5LibLoc/* $prefix_out
    }
}

# Fix linking on macOS
if ($IsMacOS) {
    install_name_tool -change /Users/runner/work/kimageformats-binaries/kimageformats-binaries/kimageformats/karchive/installed//libKF5Archive.5.dylib @rpath/libKF5Archive.5.dylib output/kimg_kra.so
    install_name_tool -change /Users/runner/work/kimageformats-binaries/kimageformats-binaries/kimageformats/karchive/installed//libKF5Archive.5.dylib @rpath/libKF5Archive.5.dylib output/kimg_ora.so

    if ($IsMacOS -and $env:buildArch -eq 'Universal') {
        install_name_tool -change /Users/runner/work/kimageformats-binaries/kimageformats-binaries/kimageformats/karchive/installed_arm64//libKF5Archive.5.dylib @rpath/libKF5Archive.5.dylib output/kimg_kra.so
        install_name_tool -change /Users/runner/work/kimageformats-binaries/kimageformats-binaries/kimageformats/karchive/installed_arm64//libKF5Archive.5.dylib @rpath/libKF5Archive.5.dylib output/kimg_ora.so
    }
}

if ($IsWindows) {
    Write-Host "`nDetecting plugin dependencies..."
    & "$env:GITHUB_WORKSPACE/pwsh/scankimgdeps.ps1" $prefix_out
}
