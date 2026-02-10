# PHash
[![Hex.pm](https://img.shields.io/hexpm/v/phash)](https://hex.pm/packages/phash)
[![Hex.pm](https://img.shields.io/hexpm/dt/phash)](https://hex.pm/packages/phash)
[![CI](https://github.com/vaartis/phash_ex/workflows/CI/badge.svg)](https://github.com/vaartis/phash_ex/actions)

This library provides NIF bindings to [phash](https://phash.org) and is provided under the same license (GNU GPL).

## Installation

The package can be installed by adding `phash` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phash, "~> 0.1"}
  ]
end
```

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
