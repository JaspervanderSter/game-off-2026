# Bundled Windows encoder

`oggenc.exe` is the Xiph.Org Vorbis Tools 1.4.3 encoder for Windows x64.
It links libogg 1.3.6 and libvorbis 1.3.7 and supports the WAV input used by
Tuning Fork. The source archives and license texts accompany the executable.
The encoder runs as a separate process.

The archives are the original [Xiph.Org releases](https://www.xiph.org/downloads/).

| Archive | SHA-256 |
| --- | --- |
| `vorbis-tools-1.4.3.tar.gz` | `a1fe3ddc6777bdcebf6b797e7edfe0437954b24756ffcc8c6b816b63e0460dde` |
| `libogg-1.3.6.tar.gz` | `83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638` |
| `libvorbis-1.3.7.tar.gz` | `0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab` |

To rebuild the encoder from this directory, use PowerShell, tar and a MinGW-w64
x64 GCC toolchain. The bundled binary was built with GCC 8.1.0.

```powershell
.\build-windows.ps1 -BuildDir .\build -Gcc C:\path\to\mingw64\bin\gcc.exe
```

This writes `build/oggenc.exe`. The build script generates the Windows
configuration and supplies the charset cleanup symbol absent from the upstream
Windows implementation. Copy the rebuilt executable to `../oggenc.exe`
to update the repository's bundled encoder.
