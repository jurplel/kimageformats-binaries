#!/usr/bin/env pwsh

$qtVersion = [version](qmake -query QT_VERSION)
Write-Host "Detected Qt Version $qtVersion"

$kfGitRef =
    $qtVersion -ge [version]'6.6.0' ? 'v6.10.0' :
    $qtVersion -ge [version]'6.5.0' ? 'v6.8.0' :
    'v5.116.0'
$kfMajorVer = $kfGitRef -like 'v5.*' ? 5 : 6
$kimgLibExt =
    $IsWindows ? '.dll' :
    $IsMacOS -and $kfMajorVer -ge 6 ? '.dylib' :
    '.so'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $kfGitRef

# Apply patch to cmake file for vcpkg libraw
if (-Not $IsWindows) {
    patch CMakeLists.txt "../util/kimageformats$kfMajorVer-find-libraw-vcpkg.patch"
}


# dependencies
if ($IsWindows) {
    if ($env:buildArch -eq 'Arm64') {
        # CMake needs QT_HOST_PATH when cross-compiling
        $env:QT_HOST_PATH = (qmake -query QT_HOST_PREFIX)
    }
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja pkgconfiglite

    # Workaround for https://developercommunity.visualstudio.com/t/10664660
    $env:CXXFLAGS += " -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR"
    $env:CFLAGS += " -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR"
} elseif ($IsMacOS) {
    brew update
    brew install ninja

    if ($qtVersion -lt [version]'6.5.3') {
        # Workaround for QTBUG-117484
        sudo xcode-select --switch /Applications/Xcode_14.3.1.app
    }
} else {
    sudo apt-get install ninja-build
}


& "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kfGitRef
& "$env:GITHUB_WORKSPACE/pwsh/get-vcpkg-deps.ps1"
& "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1" $kfGitRef

# Resolve pthread error on linux
if (-Not $IsWindows) {
    $env:CXXFLAGS += ' -pthread'
}

$argQt6 = $qtVersion.Major -eq 6 ? '-DBUILD_WITH_QT6=ON' : $null
$argDeviceArchs = $IsMacOS -and $env:buildArch -eq 'Universal' ? '-DCMAKE_OSX_ARCHITECTURES=x86_64' : $null

# Build kimageformats
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=ON $argQt6 -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" $argDeviceArchs .

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

    [Environment]::SetEnvironmentVariable("KF${kfMajorVer}Archive_DIR", [Environment]::GetEnvironmentVariable("KF${kfMajorVer}Archive_DIR_ARM"))

    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed_arm64" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=ON $argQt6 -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET="arm64-osx" -DCMAKE_OSX_ARCHITECTURES="arm64" .

    ninja
    ninja install

    Write-Host "Combining kimageformats binaries to universal"

    $prefix = "installed/lib/plugins/imageformats"
    $prefix_arm = "installed_arm64/lib/plugins/imageformats"

    # Combine the two binaries and copy them to the output folder
    $files = Get-ChildItem "$prefix" -Recurse -Filter "*$kimgLibExt"
    foreach ($file in $files) {
        $name = $file.Name
        lipo -create "$file" "$prefix_arm/$name" -output "$prefix_out/$name"
        lipo -info "$prefix_out/$name"
    }

    # Combine karchive binaries too and send them to output
    $name = "libKF${kfMajorVer}Archive.$kfMajorVer.dylib"
    lipo -create "karchive/installed/lib/$name" "karchive/installed_arm64/lib/$name" -output "$prefix_out/$name"
    lipo -info "$prefix_out/$name"
} else {
    # Copy binaries from installed to output folder
    $files = Get-ChildItem "installed/lib" -Recurse -Filter "*$kimgLibExt"
    foreach ($file in $files) {
        cp $file $prefix_out
    }

    # Copy karchive stuff to output as well
    if ($IsWindows) {
        cp karchive/bin/*.dll $prefix_out
        # Also copy all the vcpkg DLLs on windows, since it's apparently not static by default
        cp "$env:VCPKG_ROOT/installed/$env:VCPKG_DEFAULT_TRIPLET/bin/*.dll" $prefix_out
    } elseif ($IsMacOS) {
        cp karchive/bin/libKF${kfMajorVer}Archive.$kfMajorVer.dylib $prefix_out
    } else {
        cp karchive/bin/libKF${kfMajorVer}Archive.so.$kfMajorVer $prefix_out
    }
}

# Fix linking on macOS
if ($IsMacOS) {
    $karchLibName = "libKF${kfMajorVer}Archive.$kfMajorVer"
    $libDirName = $kfMajorVer -le 5 -and $qtVersion.Major -ge 6 ? '' : 'lib' # empty name results in double slash in path which is intentional

    install_name_tool -change "$(Get-Location)/karchive/installed/$libDirName/$karchLibName.dylib" "@rpath/$karchLibName.dylib" "$prefix_out/kimg_kra$kimgLibExt"
    install_name_tool -change "$(Get-Location)/karchive/installed/$libDirName/$karchLibName.dylib" "@rpath/$karchLibName.dylib" "$prefix_out/kimg_ora$kimgLibExt"

    if ($IsMacOS -and $env:buildArch -eq 'Universal') {
        install_name_tool -change "$(Get-Location)/karchive/installed_arm64/$libDirName/$karchLibName.dylib" "@rpath/$karchLibName.dylib" "$prefix_out/kimg_kra$kimgLibExt"
        install_name_tool -change "$(Get-Location)/karchive/installed_arm64/$libDirName/$karchLibName.dylib" "@rpath/$karchLibName.dylib" "$prefix_out/kimg_ora$kimgLibExt"
    }
}

# Fix linking on Linux
if ($IsLinux) {
    patchelf --set-rpath '$ORIGIN' "$prefix_out/libKF${kfMajorVer}Archive.so.$kfMajorVer"

    $files = Get-ChildItem "$prefix_out" -Recurse -Filter "kimg_*$kimgLibExt"
    foreach ($file in $files) {
        patchelf --set-rpath '$ORIGIN/../../lib' $file
    }
}

if ($IsWindows) {
    Write-Host "`nDetecting plugin dependencies..."
    & "$env:GITHUB_WORKSPACE/pwsh/scankimgdeps.ps1" $prefix_out
}
