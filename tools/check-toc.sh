#!/bin/sh
# Verifies a TOC: it has an Interface line, every file it lists exists, and every .lua file in
# the addon folder is listed (Locales/Example.lua is a template and Libs/ is loaded by embeds.xml, so both are exempt).
# Usage: tools/check-toc.sh [path/to/file.toc]   (run from the repository root)
toc="${1:-KeepThat/KeepThat_Camelot.toc}"
dir=$(dirname "$toc")
status=0
listed=$(grep -v -e '^#' -e '^[[:space:]]*$' "$toc" | tr -d '\r' | tr '\\' '/')
for entry in $listed; do
  if [ -f "$dir/$entry" ]; then echo "ok       $entry"; else echo "MISSING  $entry"; status=1; fi
done
grep -q '^## Interface: ' "$toc" || { echo "MISSING  ## Interface line"; status=1; }
for file in $(cd "$dir" && find . -name '*.lua' | sed 's|^\./||' | sort); do
  [ "$file" = "Locales/Example.lua" ] && continue
  case "$file" in Libs/*) continue ;; esac
  # Each TOC loads only its own client's data files.
  case "$(basename "$toc")" in
    *_Vanilla.toc) case "$file" in Data/*_Forever.lua) continue ;; esac ;;
    *_Camelot.toc) case "$file" in Data/*_Era.lua) continue ;; esac ;;
  esac
  printf '%s\n' "$listed" | grep -qx "$file" || { echo "UNLISTED $file (not in $(basename "$toc"))"; status=1; }
done
exit $status
