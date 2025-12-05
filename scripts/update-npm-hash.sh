#!/usr/bin/env bash
# Script to update the npmDepsHash in flake.nix
# Run this after modifying package.json or package-lock.json

set -euo pipefail

FLAKE_FILE="flake.nix"

echo "Computing npm dependencies hash..."

# Use nix to compute the hash
HASH=$(nix-prefetch-npm-deps package-lock.json 2>/dev/null || true)

if [ -z "$HASH" ]; then
    echo "Error: Could not compute hash. Make sure nix is installed and package-lock.json exists."
    echo ""
    echo "Alternative: Run 'nix build' and copy the hash from the error message."
    exit 1
fi

echo "Computed hash: $HASH"

# Update the flake.nix file
if grep -q 'npmDepsHash = pkgs.lib.fakeHash;' "$FLAKE_FILE"; then
    sed -i "s|npmDepsHash = pkgs.lib.fakeHash;|npmDepsHash = \"$HASH\";|" "$FLAKE_FILE"
    echo "Updated $FLAKE_FILE with new hash"
elif grep -q 'npmDepsHash = "sha256-' "$FLAKE_FILE"; then
    sed -i "s|npmDepsHash = \"sha256-[^\"]*\";|npmDepsHash = \"$HASH\";|" "$FLAKE_FILE"
    echo "Updated $FLAKE_FILE with new hash"
else
    echo "Could not find npmDepsHash in $FLAKE_FILE"
    echo "Please manually update the npmDepsHash to: $HASH"
    exit 1
fi

echo "Done! You can now run 'nix build' to build the application."
