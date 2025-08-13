#!/bin/bash

install_ares_all() {
  shopt -s nullglob  # Ensures no error if no .ipk files are found
  echo "🔍 Searching for .ipk files in: $(pwd)"

  found=false
  start_time=$(date +%s)
  
  for ipk in *.ipk; do
    found=true
    echo "📦 Installing: $ipk"
    if ares-install --device newLG "$ipk"; then
      echo "✅ Successfully installed: $ipk"
    else
      echo "❌ Failed to install: $ipk"
    fi
  done

  if ! $found; then
    echo "⚠️  No .ipk files found."
  fi

end_time=$(date +%s)
total_duration=$((end_time - start_time))
echo "🎉 All installations attempted in ⏱ ${total_duration}s."
}

