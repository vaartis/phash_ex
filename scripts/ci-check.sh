#!/bin/bash
# Local CI check script
# This script simulates the CI environment to help catch issues before pushing

set -e  # Exit on error

echo "🔍 Starting local CI checks..."
echo ""

# Check for git submodules
echo "1️⃣ Checking git submodules..."
if [ ! -f "c_lib/pHash/CMakeLists.txt" ]; then
  echo "   ⚠️  pHash submodule not initialized!"
  echo "   Running: git submodule update --init --recursive"
  git submodule update --init --recursive
else
  echo "   ✅ Git submodules are initialized"
fi
echo ""

# Check for required system dependencies
echo "2️⃣ Checking system dependencies..."
check_command() {
  if command -v $1 &> /dev/null; then
    echo "   ✅ $1 found"
  else
    echo "   ❌ $1 not found - please install it"
    return 1
  fi
}

check_command cmake
check_command cc
check_command c++
echo ""

# Check for library dependencies (best effort)
echo "3️⃣ Checking for required libraries..."
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  if command -v brew &> /dev/null; then
    for lib in libpng jpeg libtiff; do
      if brew list $lib &> /dev/null; then
        echo "   ✅ $lib installed (Homebrew)"
      else
        echo "   ⚠️  $lib not found - install with: brew install $lib"
      fi
    done
  else
    echo "   ℹ️  Homebrew not found, skipping library check"
  fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  for lib in libpng-dev libjpeg-dev libtiff-dev; do
    if dpkg -l | grep -q "^ii  $lib"; then
      echo "   ✅ $lib installed"
    else
      echo "   ⚠️  $lib not found - install with: sudo apt-get install $lib"
    fi
  done
fi
echo ""

# Get dependencies
echo "4️⃣ Fetching dependencies..."
mix deps.get
echo ""

# Check formatting
echo "5️⃣ Checking code formatting..."
if mix format --check-formatted; then
  echo "   ✅ Code formatting is correct"
else
  echo "   ❌ Code formatting issues found"
  echo "   Run 'mix format' to fix"
  exit 1
fi
echo ""

# Clean build
echo "6️⃣ Running clean build..."
mix clean
if mix compile --warnings-as-errors; then
  echo "   ✅ Compilation successful"
else
  echo "   ❌ Compilation failed"
  exit 1
fi
echo ""

# Run tests
echo "7️⃣ Running tests..."
if mix test; then
  echo "   ✅ All tests passed"
else
  echo "   ❌ Tests failed"
  exit 1
fi
echo ""

# Verify library loads
echo "8️⃣ Verifying library loads correctly..."
if mix run -e '
  {:ok, hash} = PHash.image_file_hash("test/fixtures/test_image.png")
  IO.puts("   ✅ Successfully computed hash: #{hash}")
  
  distance = PHash.image_hash_distance(hash, hash)
  if distance == 0 do
    IO.puts("   ✅ Distance test passed")
  else
    IO.puts("   ❌ Distance should be 0, got #{distance}")
    exit(1)
  end
'; then
  echo ""
else
  echo "   ❌ Library load verification failed"
  exit 1
fi

echo "✨ All CI checks passed! You're ready to push."
echo ""
