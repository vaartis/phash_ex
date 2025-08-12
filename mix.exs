defmodule Mix.Tasks.Compile.PHash do
  @doc """
  If the files don't exist or are older then sources, recompile them.

  FIXME: This seems to run every time when tests are run, strangely.
  """
  def run(_args) do
    priv = Path.join(__DIR__, "priv/")

    files = [
      {"c_lib/pHash/src/pHash.cpp", "#{priv}/libpHash.1.0.0#{shared_lib_ext()}"},
      {"c_lib/phash_nifs.cpp", "#{priv}/phash_nifs#{shared_lib_ext()}"}
    ]

    should_rebuild =
      Enum.any?(
        files,
        fn {from, result} ->
          not File.exists?(result) or
            (
              File.stat!(from).mtime > File.stat!(result).mtime
            )
        end
      )

    if should_rebuild do
      cmake_args =
        if :os.type() == {:unix, :darwin} do
          [
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5",
            "-DCMAKE_BUILD_TYPE=Release",
            "-DBUILD_SHARED_LIBS=FALSE",
            "."
          ]
        else
          ["-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DCMAKE_BUILD_TYPE=Release", "-DBUILD_SHARED_LIBS=FALSE", "."]
        end

      erlang_root =
        to_string(:code.root_dir() ++ ~c"/erts-" ++ :erlang.system_info(:version))

      gpp_args =
        if :os.type() == {:unix, :darwin} do
          [
            "phash_nifs.cpp",
            "-I#{erlang_root}/include",
            "-I#{brew_prefix("libpng")}/include",
            "-I#{brew_prefix("jpeg")}/include",
            "-I#{brew_prefix("libtiff")}/include",
            "-IpHash/src",
            "-IpHash/third-party/CImg",
            "-LpHash/Release",
            "-L#{brew_prefix("libpng")}/lib",
            "-L#{brew_prefix("jpeg")}/lib",
            "-L#{brew_prefix("libtiff")}/lib",
            "-L#{erl_interface_lib_path!()}/lib",
            "-lei",
            "-lpHash",
            "-Wl,-rpath,@loader_path",
            "-undefined",
            "dynamic_lookup",
            "-fpic",
            "-shared",
            "-o",
            "#{priv}/phash_nifs#{shared_lib_ext()}"
          ]
        else
          [
            "phash_nifs.cpp",
            "-I#{erlang_root}/include",
            "-IpHash/src",
            "-IpHash/third-party/CImg",
            "-LpHash/Release",
            "-L#{erl_interface_lib_path!()}/lib",
            "-lei",
            "-lerl_nif",
            "-lpHash",
            "-fpic",
            "-shared",
            "-Wl,-rpath,$ORIGIN",
            "-o#{priv}/phash_nifs#{shared_lib_ext()}"
          ]
        end

      with {_, 0} <-
             System.cmd(
               "cmake",
               cmake_args,
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
           File.cp!(
             "c_lib/pHash/Release/libpHash.1.0.0#{shared_lib_ext()}",
             "#{priv}/libpHash.1.0.0#{shared_lib_ext()}"
           ),
           {_, 0} <-
             System.cmd(
               "g++",
               gpp_args,
               cd: "c_lib",
               stderr_to_stdout: true,
               into: IO.stream(:stdio, :line)
             ),
            File.ln_s(
                "phash_nifs#{shared_lib_ext()}",
                "#{priv}/phash_nifs.so"
            ) do
        :ok
      else
        _ -> {:error, ["compilation failed"]}
      end
    else
      :ok
    end
  end

  defp brew_prefix(lib) do
    {output, 0} = System.cmd("brew", ["--prefix", lib])
    String.trim(output)
  end

  defp shared_lib_ext do
    if :os.type() == {:unix, :darwin}, do: ".dylib", else: ".so"
  end

  defp erl_interface_lib_path! do
    erlang_lib_dir = Path.join(to_string(:code.root_dir()), "lib")

    case File.ls(erlang_lib_dir) do
      {:ok, files} ->
        case Enum.find(files, &String.starts_with?(&1, "erl_interface")) do
          nil ->
            raise "erl_interface lib not found"

          erl_interface_dir ->
            Path.join(erlang_lib_dir, erl_interface_dir)
        end

      {:error, _} ->
        raise "Could not list erlang lib directory"
    end
  end
end

defmodule PHash.MixProject do
  use Mix.Project

  def project do
    [
      app: :phash,
      version: "0.1.3",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:p_hash] ++ Mix.compilers(),
      description: """
      Bindings to the C++ pHash library (phash.org).
      """,
      source_url: "https://github.com/vaartis/phash_ex/",
      package:
        [
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
            ] ++ Enum.reject(
              Path.wildcard("c_lib/pHash/bindings/java/**/*"),
              fn path ->
                Path.extname(path) in [".so", ".java"] or File.dir?(path)
              end
            )
        ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
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
