# Building PHash

This document describes the build process and platform-specific considerations for building the pHash library.

## Platform Support

This library has been tested and works on:
- **macOS** (Apple Silicon and Intel)
- **Linux** (Ubuntu, Debian, and similar distributions)

## Build Requirements

### All Platforms

- **Elixir** 1.10 or higher
- **Erlang/OTP** 23 or higher
- **CMake** 3.5 or higher
- **C++ Compiler** (GCC, Clang, or compatible)

### System Libraries

The following image processing libraries are required:

- **libpng** - PNG image support
- **libjpeg** - JPEG image support  
- **libtiff** - TIFF image support

## Installation Instructions

### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake libpng-dev libjpeg-dev libtiff-dev
```

### macOS

Using Homebrew:

```bash
brew install cmake libpng jpeg libtiff
```

### Fedora/RHEL/CentOS

```bash
sudo dnf install gcc-c++ cmake libpng-devel libjpeg-devel libtiff-devel
```

### Arch Linux

```bash
sudo pacman -S base-devel cmake libpng libjpeg-turbo libtiff
```

## Build Process

The build process is handled automatically by Mix when you run:

```bash
mix deps.get
mix compile
```

### Build Steps

The custom Mix compiler performs the following steps:

1. **CMake Configuration** - Configures the pHash C++ library with appropriate flags for your platform
2. **Library Compilation** - Builds the pHash shared library
3. **NIF Compilation** - Compiles the Erlang NIF bindings
4. **Library Installation** - Copies compiled libraries to the `priv/` directory

### Platform-Specific Behavior

#### macOS

- Automatically detects Homebrew library paths
- Uses `clang++` compiler by default
- Handles versioned `.dylib` files (e.g., `libpHash.1.0.0.dylib`)
- Creates symbolic links for library loading

#### Linux

- Uses `g++` compiler by default
- Produces standard `.so` files
- Library paths are typically standard system locations

## Troubleshooting

### CMake Version Error

If you see an error about CMake version compatibility, ensure you have CMake 3.5 or higher:

```bash
cmake --version
```

### Missing Libraries

If compilation fails with "file not found" errors for `png.h`, `jpeglib.h`, or `tiffio.h`, install the development packages for these libraries as described above.

### macOS: Library Not Loaded

If you see an error about `@rpath/libpHash.1.0.0.dylib`, try:

```bash
mix clean
mix compile
```

This ensures the library is properly copied with the correct rpath settings.

## Development

### Clean Build

To perform a clean build:

```bash
mix clean
rm -rf c_lib/pHash/CMakeCache.txt c_lib/pHash/CMakeFiles c_lib/pHash/Release
mix compile
```

### Running Tests

```bash
mix test
```

### Continuous Integration

The project includes GitHub Actions workflows that test building and running on Ubuntu with multiple Elixir/OTP versions. See `.github/workflows/ci.yml` for details.

## Technical Details

### Build Script Location

The custom compiler is defined in `mix.exs` under `Mix.Tasks.Compile.PHash`.

### Compiled Artifacts

After building, you should see the following in the `priv/` directory:

**macOS:**
- `libpHash.1.0.0.dylib` - The versioned pHash library
- `libpHash.dylib` - Symbolic link to the versioned library
- `phash_nifs.so` - The Erlang NIF library

**Linux:**
- `libpHash.so.1.0.0` - The pHash library
- `phash_nifs.so` - The Erlang NIF library

### Build Cache

Mix will only rebuild if source files have changed. To force a rebuild:

```bash
mix clean
mix compile
```

## Contributing

When modifying the build process:

1. Test on both macOS and Linux
2. Run the full test suite: `mix test`
3. Ensure the CI passes on GitHub Actions
4. Update this document if adding new requirements or platforms
