#!/usr/bin/env pwsh
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"

    if ([Environment]::Is64BitOperatingSystem -and ($env:forceWin32 -ne 'true')) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }

} elseif ($IsMacOS) {
    $env:VCPKG_DEFAULT_TRIPLET = "x64-osx-universal"
}


# Build using vcpkg
if ($IsWindows) {
    $vcpkgexec = "vcpkg.exe"
} else {
    $vcpkgexec = "vcpkg"
}
& "$env:VCPKG_ROOT/$vcpkgexec" --overlay-triplets=util/ install openexr

