#!/usr/bin/env pwsh

$qtVersion = ((qmake --version -split '\n')[1] -split ' ')[3]

# Clone
git clone https://github.com/jurplel/QtApng.git
cd QtApng
git checkout 6a83caf22111cb8054753b925c2dfbcd9b92e038

# Dependencies
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja pkgconfiglite
} elseif ($IsMacOS) {
    brew update
    brew install ninja
} else {
    sudo apt-get install ninja-build
}

# Build
$argApngQt6 = $qtVersion -like '5.*' ? "-DAPNG_QT6=OFF" : $null
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release $argApngQt6
ninja -C build

if ($env:universalBinary -eq 'true') {
    cmake -B build_arm64 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64
    ninja -C build_arm64
}

# Copy output
$outputDir = "output"
mkdir $outputDir
$files = Get-ChildItem -Path "build/plugins/imageformats" | Where-Object { $_.Extension -in ".dylib", ".dll", ".so" }
foreach ($file in $files) {
    if ($env:universalBinary -eq 'true') {
        $name = $file.Name
        lipo -create "$file" "build_arm64/plugins/imageformats/$name" -output "$outputDir/$name"
        lipo -info "$outputDir/$name"
    } else {
        Copy-Item -Path $file -Destination $outputDir
    }
}
