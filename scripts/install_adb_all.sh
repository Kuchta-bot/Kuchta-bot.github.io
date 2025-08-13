#!/bin/bash

install_adb_all() {
  shopt -s nullglob  # Ensures no error if no .apk files are found
  echo "🔍 Searching for .apk files in: $(pwd)"

  found=false
  start_time=$(date +%s)

  for apk in *.apk; do
    found=true
    echo "📦 Installing: $apk"
    adb install -r "$apk"
    echo "✅ Done: $apk"
  done

  if ! $found; then
    echo "⚠️  No .apk files found."
  fi

end_time=$(date +%s)
total_duration=$((end_time - start_time))
echo "🎉 All installations attempted in ⏱ ${total_duration}s."
}
