defmodule Mix.Tasks.Compile.PHash do
  @doc """
  If the files don't exist or are older then sources, recompile them.

  FIXME: This seems to run every time when tests are run, strangely.
  """
  def run(_args) do
    priv = Path.join(File.cwd!(), "priv/")

    files = [
      {"c_lib/pHash/src/pHash.cpp", "#{priv}/libpHash.so.1.0.0"},
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
      with {_, 0} <-
             System.cmd(
               "cmake",
               ["-DCMAKE_BUILD_TYPE=Release", "-DBUILD_SHARED_LIBS=FALSE", "."],
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
             "c_lib/pHash/Release/libpHash.so.1.0.0",
             "#{priv}/libpHash.so.1.0.0"
           ),
           erlang_root <-
             to_string(:code.root_dir() ++ '/erts-' ++ :erlang.system_info(:version)),
           {_, 0} <-
             System.cmd(
               "g++",
               [
                 "phash_nifs.cpp",
                 "-I#{erlang_root}/include",
                 "-IpHash/src",
                 "-IpHash/third-party/CImg",
                 "-LpHash/Release",
                 "-lpHash",
                 "-fpic",
                 "-shared",
                 "-Wl,-rpath=#{priv}",
                 "-o#{priv}/phash_nifs.so"
               ],
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
end

defmodule PHash.MixProject do
  use Mix.Project

  def project do
    [
      app: :phash,
      version: "0.1.1",
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
        licenses: ["GPL-3"],
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
