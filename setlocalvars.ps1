#! /usr/bin/pwsh

$env:GITHUB_WORKSPACE = $PWD

git clone https://github.com/Microsoft/vcpkg.git
if ($IsWindows) {
    & "./vcpkg/bootstrap-vcpkg.bat"
} else {
    & "./vcpkg/bootstrap-vcpkg.sh"
}
$env:VCPKG_ROOT = Join-Path $PWD /vcpkg

# missing stuff, including pkgconfig