#! /usr/bin/pwsh

# Clone
git clone https://github.com/AOMediaCodec/libavif.git
cd libavif
git checkout $(git tag | select -last 1)

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}

# Get meson
python -m pip install meson
Set-Alias -Name meson -Value "python -m meson"

# Build dav1d
cd ext

if ($IsWindows) {
    $env:Path += ";C:\Program Files\NASM"
    cmd /c dav1d.cmd
} else {
    bash dav1d.cmd
}

# Build libavif 

mkdir ../build
cd ../build

cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DAVIF_CODEC_DAV1D=ON -DAVIF_LOCAL_DAV1D=ON ..
ninja
$env:DESTDIR = "installed/"
ninja install

cd ../../