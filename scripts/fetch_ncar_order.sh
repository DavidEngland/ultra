#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <order_id> [target_dir]"
  echo "Example: $0 dee002994255 data/sheba/raw/ncar_eol_dee002994255"
  exit 1
fi

ORDER_ID="$1"
TARGET_DIR="${2:-data/sheba/raw/ncar_eol_${ORDER_ID}}"
BASE_URL="https://data.eol.ucar.edu/pub/download/data/${ORDER_ID}"

mkdir -p "${TARGET_DIR}"

# Parse downloadable file names from order page and fetch sequentially.
mapfile -t files < <(curl -fsSL "${BASE_URL}/" | rg -o 'href="[^"]+"' | sed -E 's/^href="(.*)"$/\1/' | rg -v '^https?://|^mailto:|/$|^\.|^\?|^#' | sort -u)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No downloadable files found at ${BASE_URL}/"
  exit 2
fi

echo "Order ${ORDER_ID}: downloading ${#files[@]} files sequentially"
for f in "${files[@]}"; do
  echo "Downloading ${f}"
  wget --no-netrc --no-cache --show-progress -O "${TARGET_DIR}/${f}" "${BASE_URL}/${f}"
done

shasum -a 256 "${TARGET_DIR}"/* > "${TARGET_DIR}/SHA256SUMS.txt"
echo "Done. Saved files to ${TARGET_DIR}"
echo "Checksums: ${TARGET_DIR}/SHA256SUMS.txt"
