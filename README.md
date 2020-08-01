# PHash
[![Hex.pm](https://img.shields.io/hexpm/v/phash)](https://hex.pm/packages/phash)
[![Hex.pm](https://img.shields.io/hexpm/dt/phash)](https://hex.pm/packages/phash)

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

Note that this requires you to have GCC/G++ and CMake installed to build the C++ code of the library. Any dependencies
that pHash by itself requires may also need to be installed (the CMake build script will tell exactly which are needed).
