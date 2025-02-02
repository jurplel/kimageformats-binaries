#!/usr/bin/env pwsh

$qtVersion = [version](qmake -query QT_VERSION)
Write-Host "Detected Qt Version $qtVersion"

# Clone
git clone https://github.com/jurplel/QtApng.git
cd QtApng
git checkout 6a83caf22111cb8054753b925c2dfbcd9b92e038

# Dependencies
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

$argQt6 = $qtVersion.Major -ne 6 ? '-DAPNG_QT6=OFF' : $null
$argDeviceArchs = $IsMacOS -and $env:buildArch -eq 'Universal' ? '-DCMAKE_OSX_ARCHITECTURES=x86_64' : $null

# Build
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release $argQt6 $argDeviceArchs
ninja -C build

if ($IsMacOS -and $env:buildArch -eq 'Universal') {
    cmake -B build_arm64 -G Ninja -DCMAKE_BUILD_TYPE=Release $argQt6 -DCMAKE_OSX_ARCHITECTURES=arm64
    ninja -C build_arm64
}

# Copy output
$outputDir = "output"
mkdir $outputDir
$files = Get-ChildItem -Path "build/plugins/imageformats" | Where-Object { $_.Extension -in ".dylib", ".dll", ".so" }
foreach ($file in $files) {
    if ($IsMacOS -and $env:buildArch -eq 'Universal') {
        $name = $file.Name
        lipo -create "$file" "build_arm64/plugins/imageformats/$name" -output "$outputDir/$name"
        lipo -info "$outputDir/$name"
    } else {
        Copy-Item -Path $file -Destination $outputDir

        # Fix linking on Linux
        if ($IsLinux) {
            patchelf --set-rpath '$ORIGIN/../../lib' (Join-Path -Path $outputDir -ChildPath $file.Name)
        }
    }
}
