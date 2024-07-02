#!/usr/bin/env pwsh

$qtVersion = ((qmake --version -split '\n')[1] -split ' ')[3]

# Clone
git clone https://github.com/jurplel/QtApng.git
cd QtApng
git checkout 6a83caf22111cb8054753b925c2dfbcd9b92e038

# Dependencies
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

# Build
$argApngQt6 = $qtVersion -like '5.*' ? "-DAPNG_QT6=OFF" : $null
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release $argApngQt6
ninja -C build

if ($IsMacOS -and $env:buildArch -eq 'Universal') {
    cmake -B build_arm64 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64
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
    }
}
