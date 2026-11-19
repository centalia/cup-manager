#!/bin/bash
set -euo pipefail

DOWNLOADER=""

download_file(){
  local url="$1"
  local file="$2"
  local expected_size="${3:-}"
  local rc
  local actual_size

  echo "==> Checking curl or wget"
  if command -v curl >/dev/null 2>&1; then
    echo "==> curl found"
    DOWNLOADER="curl"

    elif command -v wget >/dev/null 2>&1; then
      echo "==> wget found"
      DOWNLOADER="wget"
  else
    echo "Error: curl or wget not found"
    return 1
  fi

if [ "$DOWNLOADER" = "curl" ]; then
    curl -L -f -o "$file" "$url"
else
    wget -O "$file" "$url"
fi
rc="$?"

if [ "$rc" -ne 0 ]; then
  echo "Error: download failed ($DOWNLOADER exited with code $rc)"
  echo "==> Cleaning..."
  rm -f "$file"
  return 1
fi

if ! [ -f "$file" ]; then
    echo "File not found after download: $file"
    return 1
fi

actual_size=$(stat -c "%s" "$file")
  if [ -z "$expected_size" ]; then
    if [ "$actual_size" -le 0 ]; then
      echo "Error: downloaded file is empty"
      echo "==> Cleaning..."
      rm -f "$file"
      return 1
    fi
  else
    if [ "$actual_size" -ne "$expected_size" ]; then
      echo "Error: size mismatch (expected $expected_size, got $actual_size)"
      echo "==> Cleaning..."
      rm -f "$file"
      return 1
    fi
  fi

  return 0
}