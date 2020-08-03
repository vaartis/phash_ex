defmodule PHash do
  use Unsafe.Generator, docs: true

  alias PHash.NIFs

  @doc """
  Reads an image from a path and produces a hash that can be compared
  with another hash via `PHash.image_hash_distance/2`.
  """
  def image_file_hash(image_path) when is_binary(image_path) do
    if File.exists?(image_path) do
      if File.dir?(image_path) do
        {:error, :eisdir}
      else
        NIFs.image_hash(image_path)
      end
    else
      {:error, :enoent}
    end
  end

  @doc """
  Write the image binary data to a temporary file and produces the same result
  as `PHash.image_file_hash/1` using that file.

  ## Options:
  - `extension` - an extension to be added to the temporary file created (e.g. ".gif")
                  (default: "").
  """
  def image_binary_hash(image_data, opts \\ []) when is_binary(image_data) do
    Temp.track!()

    ext = opts[:extension] || ""

    result =
      with {:ok, file_path} <-
             Temp.open([prefix: "phash", suffix: ext], &IO.binwrite(&1, image_data)) do
        image_file_hash(file_path)
      end

    Temp.cleanup()

    result
  end

  @doc """
  Calculates the hamming distance between two image hashes.
  """
  def image_hash_distance(hash_a, hash_b)
      when is_integer(hash_a) and is_integer(hash_b) and hash_a > 0 and hash_b > 0 do
    NIFs.image_hash_distance(hash_a, hash_b)
  end

  @unsafe [
    {:image_file_hash, 1, :unwrap},
    {:image_binary_hash, [1, 2], :unwrap}
  ]

  defp unwrap({:ok, result}), do: result
  defp unwrap({:error, err}), do: raise(PHash.HashingError, err)
end

defmodule PHash.HashingError do
  defexception [:message]

  @impl true
  def exception(error) do
    %PHash.HashingError{
      message: "Hashing failed: #{error}"
    }
  end
end
