# PHash
[![Hex.pm](https://img.shields.io/hexpm/v/phash)](https://hex.pm/packages/phash)
[![Hex.pm](https://img.shields.io/hexpm/dt/phash)](https://hex.pm/packages/phash)
[![CI](https://github.com/vaartis/phash_ex/workflows/CI/badge.svg)](https://github.com/vaartis/phash_ex/actions)

This library provides NIF bindings to [phash](https://phash.org) and is provided under the same license (GNU GPL).

## Installation

### From Hex.pm (Recommended)

The package can be installed by adding `phash` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phash, "~> 0.1"}
  ]
end
```

Then run `mix deps.get` and the library will build automatically. **All required source files are included in the Hex package** - you don't need to worry about git submodules.

### From Source (Development)

If you're contributing to this library, clone the repository and initialize git submodules:

```bash
git clone https://github.com/vaartis/phash_ex.git
cd phash_ex
git submodule update --init --recursive
mix deps.get
mix compile
```

> **Note:** Git submodules are only needed for development. Users installing from Hex.pm get all source files automatically.

## Requirements

This library requires the following to be installed on your system:

### All Platforms
- GCC/G++ or Clang (C++ compiler)
- CMake (version 3.5 or higher)

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install build-essential cmake libpng-dev libjpeg-dev libtiff-dev
```

### macOS
```bash
brew install cmake libpng jpeg libtiff
```

The build system will automatically detect and configure the appropriate library paths for your platform.

## Testing

Run the test suite:

```bash
mix test
```

The project includes comprehensive tests covering:
- Image file hashing
- Binary data hashing
- Hash distance calculations
- Error handling
- Integration tests
