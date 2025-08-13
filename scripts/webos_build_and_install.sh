#!/bin/bash

# Alias for the 'browser' command with arguments for customer and platform
# -p platform (web)
# -f flavour (browser, tizen, webos)
# -c customer (nangu, orange, ...)
# -k configuration / backend platform (devel, stage, production, ...)
# -s skin (default-tv, ...)
# Path to the WebOS config file

# Usage example:
# build_and_install orange stage 13.14.15 newLG
# customer = orange
# configuration = stage
# version = 13.14.15
# device = newLG
# Device name is configured via "ares-setup-device" 

webos_config=~/Git/portal-ngx/build/appinfo.json

webos_build_and_install() {
local customer=${1:-nangu}         # default: orange
local configuration=${2:-herring}     # default: stage
local version=${3:-11.12.13}        # default: 11.12.13
local device=$4

  local orig_dir
  orig_dir="$(pwd)"

  if [[ -z "$customer" || -z "$configuration" || -z "$version" ]]; then
    echo "❗ Usage: build_and_install <customer> <configuration> <version>"
    echo "Example: build_and_install orange stage 13.14.15"
    return 1
  fi

  echo "🔧 Starting build for customer: $customer"
  echo "🔑 Configuration: $configuration"
  echo "📦 Version: $version"

  # Build for webOS
  yarn build -p web -f "webos" -c "$customer" -k "$configuration" -s default-tv || return 1

  # Update version in appinfo.json
  if [[ -f "$webos_config" ]]; then
    # Detect platform and use correct sed command
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS
      sed -i '' "s/\"version\": \".*\"/\"version\": \"$version\"/" "$webos_config"
    else
      # Linux
      sed -i "s/\"version\": \".*\"/\"version\": \"$version\"/" "$webos_config"
    fi
    echo "✅ Version in $webos_config set to $version"
  else
    echo "❌ File $webos_config not found!"
    return 1
  fi

  # Create output directory in home if it doesn't exist
  local output_dir=~/webos_ipk_packages
  mkdir -p "$output_dir"

  # Create package
  ares-package build -o "$output_dir" || return 1

  cd "$output_dir" || return 1

  # Build app name prefix
  local app_prefix="sk.${customer}.app.webos"
  if [[ "$configuration" != "production" ]]; then
    app_prefix="${app_prefix}.${configuration}"
  fi

  # Find IPK file matching the pattern: any name ending with _<version>_all.ipk
  local ipk_file=$(ls -t *_"$version"_all.ipk 2>/dev/null | head -n 1)

  if [[ -z "$ipk_file" ]]; then
    echo "❌ No IPK file found matching *_${version}_all.ipk"
    return 1
  fi

  echo "🚀 Installing app: $ipk_file"
  ares-install --device "$device" "$ipk_file"

  cd "$orig_dir" || return 1
}