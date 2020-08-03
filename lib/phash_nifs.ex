defmodule PHash.NIFs do
  @on_load :load_nifs

  def load_nifs do
    lib_path = Path.join(__DIR__, "../priv/phash_nifs")
    :erlang.load_nif(to_charlist(lib_path), 0)
  end

  def image_hash(_image_data), do: raise("image_hash/1 not loaded")

  def image_hash_distance(_a, _b), do: raise("image_hash_distance/2 not loaded")
end
