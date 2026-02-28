defmodule Mix.Tasks.Compile.PHash do
  @doc """
  If the files don't exist or are older then sources, recompile them.

  FIXME: This seems to run every time when tests are run, strangely.
  """
  def run(_args) do
    priv = Path.join(__DIR__, "priv/")

    # Detect platform-specific library extensions
    {lib_ext, lib_name} =
      case :os.type() do
        {:unix, :darwin} -> {".dylib", "libpHash.dylib"}
        {:unix, _} -> {".so.1.0.0", "libpHash.so.1.0.0"}
        {:win32, _} -> {".dll", "libpHash.dll"}
      end

    files = [
      {"c_lib/pHash/src/pHash.cpp", "#{priv}/#{lib_name}"},
      {"c_lib/phash_nifs.cpp", "#{priv}/phash_nifs.so"}
    ]

    should_rebuild =
      Enum.any?(
        files,
        fn {from, result} ->
          convert_time = fn {{year, month, day}, {hour, minute, second}} ->
            %{
              DateTime.now!("Etc/UTC")
              | year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            }
          end

          not File.exists?(result) or
            (
              from_dt = convert_time.(File.stat!(from).mtime)
              to_dt = convert_time.(File.stat!(result).mtime)

              DateTime.compare(from_dt, to_dt) == :gt
            )
        end
      )

    if should_rebuild do
      # Detect Homebrew paths on macOS
      {homebrew_paths, cmake_extra_args} =
        case :os.type() do
          {:unix, :darwin} ->
            # Try to get Homebrew prefix
            homebrew_prefix =
              case System.cmd("brew", ["--prefix"], stderr_to_stdout: true) do
                {prefix, 0} -> String.trim(prefix)
                _ -> "/opt/homebrew"
              end

            # Get paths for required libraries
            get_lib_prefix = fn lib_name, default_name ->
              case System.cmd("brew", ["--prefix", lib_name], stderr_to_stdout: true) do
                {prefix, 0} -> String.trim(prefix)
                _ -> "#{homebrew_prefix}/opt/#{default_name}"
              end
            end

            libpng_prefix = get_lib_prefix.("libpng", "libpng")
            libjpeg_prefix = get_lib_prefix.("jpeg", "jpeg")
            libtiff_prefix = get_lib_prefix.("libtiff", "libtiff")

            paths = %{
              include: [
                "#{libpng_prefix}/include",
                "#{libjpeg_prefix}/include",
                "#{libtiff_prefix}/include"
              ],
              lib: [
                "#{libpng_prefix}/lib",
                "#{libjpeg_prefix}/lib",
                "#{libtiff_prefix}/lib"
              ]
            }

            cmake_args = [
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
              "-DCMAKE_CXX_FLAGS=-I#{Enum.join(paths.include, " -I")}",
              "-DCMAKE_EXE_LINKER_FLAGS=-L#{Enum.join(paths.lib, " -L")}",
              "-DCMAKE_SHARED_LINKER_FLAGS=-L#{Enum.join(paths.lib, " -L")}"
            ]

            {paths, cmake_args}

          _ ->
            {%{include: [], lib: []}, []}
        end

      with {_, 0} <-
             System.cmd(
               "cmake",
               [
                 "-DCMAKE_BUILD_TYPE=Release",
                 "-DBUILD_SHARED_LIBS=FALSE",
                 "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
               ] ++
                 cmake_extra_args ++ ["."],
               cd: "c_lib/pHash",
               stderr_to_stdout: true,
               into: IO.stream(:stdio, :line)
             ),
           {_, 0} <-
             System.cmd(
               "cmake",
               ["--build", ".", "--target", "pHash"],
               cd: "c_lib/pHash",
               stderr_to_stdout: true,
               into: IO.stream(:stdio, :line)
             ),
           phash_lib_path <- find_phash_library("c_lib/pHash", lib_ext),
           copy_phash_library(phash_lib_path, priv, lib_name, lib_ext),
           erlang_root <-
             to_string(:code.root_dir() ++ ~c"/erts-" ++ :erlang.system_info(:version)),
           compiler <- detect_compiler(),
           compiler_flags <- build_compiler_flags(erlang_root, priv, homebrew_paths, lib_name),
           {_, 0} <-
             System.cmd(
               compiler,
               compiler_flags,
               cd: "c_lib",
               stderr_to_stdout: true,
               into: IO.stream(:stdio, :line)
             ) do
        :ok
      else
        _ -> {:error, ["compilation failed"]}
      end
    else
      :ok
    end
  end

  defp copy_phash_library(source_path, priv_dir, _lib_name, _lib_ext) do
    # On macOS with versioned dylib, we need to handle versioning
    case :os.type() do
      {:unix, :darwin} ->
        # Get the directory containing the source library
        source_dir = Path.dirname(source_path)

        # Look for the actual versioned library file (not symlink)
        versioned_lib = Path.join(source_dir, "libpHash.1.0.0.dylib")

        if File.exists?(versioned_lib) and File.lstat!(versioned_lib).type != :symlink do
          # Copy the versioned library
          dest_versioned = Path.join(priv_dir, "libpHash.1.0.0.dylib")
          File.cp!(versioned_lib, dest_versioned)

          # Create a symlink libpHash.dylib -> libpHash.1.0.0.dylib
          dest_symlink = Path.join(priv_dir, "libpHash.dylib")
          if File.exists?(dest_symlink), do: File.rm!(dest_symlink)
          File.ln_s!("libpHash.1.0.0.dylib", dest_symlink)
        else
          # Fallback: just copy the source file
          File.cp!(source_path, Path.join(priv_dir, "libpHash.dylib"))
        end

      _ ->
        # For Linux/Windows, use the provided lib_name
        File.cp!(source_path, Path.join(priv_dir, Path.basename(source_path)))
    end
  end

  defp find_phash_library(base_dir, lib_ext) do
    # On macOS, CMake might put the library in different locations
    # Also, on macOS the versioned library name is used (e.g., libpHash.1.0.0.dylib)
    possible_paths = [
      "#{base_dir}/Release/libpHash#{lib_ext}",
      "#{base_dir}/Release/libpHash.1.0.0#{lib_ext}",
      "#{base_dir}/libpHash#{lib_ext}",
      "#{base_dir}/libpHash.1.0.0#{lib_ext}",
      "#{base_dir}/Debug/libpHash#{lib_ext}",
      "#{base_dir}/Debug/libpHash.1.0.0#{lib_ext}"
    ]

    Enum.find(possible_paths, fn path ->
      File.exists?(path)
    end) || raise "Could not find compiled pHash library in any expected location"
  end

  defp detect_compiler do
    # Prefer clang++ on macOS, g++ elsewhere
    case :os.type() do
      {:unix, :darwin} ->
        case System.find_executable("clang++") do
          nil -> "g++"
          path -> path
        end

      _ ->
        "g++"
    end
  end

  defp build_compiler_flags(erlang_root, priv, homebrew_paths, _lib_name) do
    base_flags = [
      "phash_nifs.cpp",
      "-I#{erlang_root}/include",
      "-IpHash/src",
      "-IpHash/third-party/CImg"
    ]

    # Add Homebrew include paths on macOS
    include_flags =
      Enum.flat_map(Map.get(homebrew_paths, :include, []), fn path ->
        ["-I#{path}"]
      end)

    lib_search_flags =
      case :os.type() do
        {:unix, :darwin} ->
          # On macOS, link against the library in priv and add Homebrew lib paths
          lib_paths =
            Enum.flat_map(Map.get(homebrew_paths, :lib, []), fn path ->
              ["-L#{path}"]
            end)

          lib_paths ++
            [
              "-L#{priv}",
              "-lpHash",
              "-lpng",
              "-ljpeg",
              "-ltiff"
            ]

        _ ->
          [
            "-LpHash/Release",
            "-lpHash"
          ]
      end

    link_flags =
      case :os.type() do
        {:unix, :darwin} ->
          [
            "-dynamiclib",
            "-undefined",
            "dynamic_lookup",
            "-Wl,-rpath,@loader_path"
          ]

        _ ->
          [
            "-fpic",
            "-shared",
            "-Wl,-rpath=#{priv}"
          ]
      end

    output_flag = ["-o#{priv}/phash_nifs.so"]

    base_flags ++ include_flags ++ lib_search_flags ++ link_flags ++ output_flag
  end
end

defmodule PHash.MixProject do
  use Mix.Project

  def project do
    [
      app: :phash,
      version: "0.1.4",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:p_hash] ++ Mix.compilers(),
      description: """
      Bindings to the C++ pHash library (phash.org).
      """,
      source_url: "https://github.com/vaartis/phash_ex/",
      package: [
        maintainers: ["vaartis"],
        links: %{
          "GitHub" => "https://github.com/vaartis/phash_ex/"
        },
        licenses: ["GPL-3.0-or-later"],
        files:
          [
            "lib",
            "test",
            "priv",
            "mix.exs",
            "README.md",
            "LICENSE",
            "c_lib/*.cpp",
            "c_lib/pHash/COPYING",
            "c_lib/pHash/CMakeLists.txt",
            "c_lib/pHash/third-party/",
            "c_lib/pHash/src/",
            # These need to be here because it doesn't build without them
            "c_lib/pHash/examples/",
            "c_lib/pHash/bindings/CMakeLists.txt"
          ] ++
            Enum.reject(
              Path.wildcard("c_lib/pHash/bindings/java/**/*"),
              fn path -> Path.extname(path) in [".so", ".java"] or File.dir?(path) end
            )
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:temp, "~> 0.4"},
      {:ex_doc, "~> 0.22", only: :dev},
      {:unsafe, "~> 1.0"}
    ]
  end
end
