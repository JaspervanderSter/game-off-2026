param(
	[Parameter(Mandatory = $true)][string]$BuildDir,
	[string]$Gcc = "gcc"
)

$ErrorActionPreference = "Stop"
$BuildDir = (New-Item -ItemType Directory -Force $BuildDir).FullName
foreach ($archive in @("vorbis-tools-1.4.3", "libogg-1.3.6", "libvorbis-1.3.7")) {
	& tar -xf (Join-Path $PSScriptRoot "$archive.tar.gz") -C $BuildDir
	if ($LASTEXITCODE -ne 0) { throw "Could not extract $archive." }
}

$tools = Join-Path $BuildDir "vorbis-tools-1.4.3"
$ogg = Join-Path $BuildDir "libogg-1.3.6"
$vorbis = Join-Path $BuildDir "libvorbis-1.3.7"
# skeleton.c requires config.h. Windows x64 is little-endian.
$config = @'
#define PACKAGE "vorbis-tools"
#define VERSION "1.4.3"
'@
Set-Content -LiteralPath (Join-Path $BuildDir "config.h") -Value $config -Encoding ASCII

# Vorbis-tools 1.4.3 calls this cleanup on every platform. Its Windows UTF-8
# implementation has no cached charset to free and does not define the symbol.
$compat = Join-Path $BuildDir "windows-charset.c"
Set-Content -LiteralPath $compat -Value "void convert_free_charset(void) {}" -Encoding ASCII

$encoderSources = @("oggenc", "audio", "encode", "platform", "resample", "skeleton") |
	ForEach-Object { "$tools/oggenc/$_.c" }
$sharedSources = @("charset", "iconvert", "utf8", "getopt", "getopt1") |
	ForEach-Object { "$tools/share/$_.c" }
$vorbisSources = @(
	"mdct", "smallft", "block", "envelope", "window", "lsp", "lpc", "analysis",
	"synthesis", "psy", "info", "floor1", "floor0", "res0", "mapping0",
	"registry", "codebook", "sharedbook", "lookup", "bitrate", "vorbisenc"
) | ForEach-Object { "$vorbis/lib/$_.c" }
$flags = @(
	"-m64", "-O2", "-static", "-s", "-Wl,--no-insert-timestamp",
	"-DHAVE_CONFIG_H", "-I$BuildDir", "-I$tools/include", "-I$ogg/include",
	"-I$vorbis/include", "-I$vorbis/lib"
)

& $Gcc @flags @encoderSources @sharedSources @vorbisSources $compat "$ogg/src/bitwise.c" "$ogg/src/framing.c" -o "$BuildDir/oggenc.exe"
if ($LASTEXITCODE -ne 0) { throw "Could not build oggenc.exe." }
