defmodule PHashTest do
  use ExUnit.Case
  doctest PHash

  @test_image_path "test/fixtures/test_image.png"

  describe "image_file_hash/1" do
    test "successfully hashes an existing image file" do
      assert {:ok, hash} = PHash.image_file_hash(@test_image_path)
      assert is_integer(hash)
      assert hash > 0
    end

    test "returns consistent hash for the same image" do
      {:ok, hash1} = PHash.image_file_hash(@test_image_path)
      {:ok, hash2} = PHash.image_file_hash(@test_image_path)
      assert hash1 == hash2
    end

    test "returns error for non-existent file" do
      assert {:error, :enoent} = PHash.image_file_hash("nonexistent.png")
    end

    test "returns error for directory path" do
      assert {:error, :eisdir} = PHash.image_file_hash("test/fixtures")
    end
  end

  describe "image_file_hash!/1" do
    test "returns hash directly on success" do
      hash = PHash.image_file_hash!(@test_image_path)
      assert is_integer(hash)
      assert hash > 0
    end

    test "raises error for non-existent file" do
      assert_raise PHash.HashingError, fn ->
        PHash.image_file_hash!("nonexistent.png")
      end
    end
  end

  describe "image_binary_hash/1" do
    test "successfully hashes image binary data" do
      image_data = File.read!(@test_image_path)
      assert {:ok, hash} = PHash.image_binary_hash(image_data)
      assert is_integer(hash)
      assert hash > 0
    end

    test "produces same hash as file-based hashing" do
      {:ok, file_hash} = PHash.image_file_hash(@test_image_path)
      image_data = File.read!(@test_image_path)
      {:ok, binary_hash} = PHash.image_binary_hash(image_data)
      assert file_hash == binary_hash
    end

    test "accepts extension option" do
      image_data = File.read!(@test_image_path)
      assert {:ok, hash} = PHash.image_binary_hash(image_data, extension: ".png")
      assert is_integer(hash)
      assert hash > 0
    end
  end

  describe "image_binary_hash!/1" do
    test "returns hash directly on success" do
      image_data = File.read!(@test_image_path)
      hash = PHash.image_binary_hash!(image_data)
      assert is_integer(hash)
      assert hash > 0
    end
  end

  describe "image_hash_distance/2" do
    test "returns 0 for identical hashes" do
      {:ok, hash} = PHash.image_file_hash(@test_image_path)
      assert PHash.image_hash_distance(hash, hash) == 0
    end

    test "returns positive distance for different hashes" do
      # Create two different hashes by using different numbers
      # (In a real scenario, these would be hashes from different images)
      hash1 = 0xFF00FF00FF00FF00
      hash2 = 0x00FF00FF00FF00FF

      distance = PHash.image_hash_distance(hash1, hash2)
      assert is_integer(distance)
      assert distance > 0
    end

    test "distance is symmetric" do
      hash1 = 0xFF00FF00FF00FF00
      hash2 = 0x00FF00FF00FF00FF

      dist1 = PHash.image_hash_distance(hash1, hash2)
      dist2 = PHash.image_hash_distance(hash2, hash1)

      assert dist1 == dist2
    end

    test "hamming distance calculation is correct" do
      # Two hashes that differ by exactly 4 bits
      # Use positive numbers with known bit differences
      # 240
      hash1 = 0b11110000
      # 255, differs in 4 bits
      hash2 = 0b11111111

      assert PHash.image_hash_distance(hash1, hash2) == 4
    end
  end

  describe "integration test" do
    test "complete workflow: hash and compare images" do
      # Hash the same image twice
      {:ok, hash1} = PHash.image_file_hash(@test_image_path)

      # Read as binary and hash
      image_data = File.read!(@test_image_path)
      {:ok, hash2} = PHash.image_binary_hash(image_data)

      # Both methods should produce the same hash
      assert hash1 == hash2

      # Distance should be 0 for identical images
      assert PHash.image_hash_distance(hash1, hash2) == 0
    end
  end
end
