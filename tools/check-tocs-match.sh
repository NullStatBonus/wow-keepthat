#!/bin/sh
# Fails if the per-client TOC files list different files. Usage: tools/check-tocs-match.sh
dir=KeepThat
# Per-client data files (Data\X_Era.lua, Data\X_Forever.lua) count as the same entry.
entries() { grep -v -e '^#' -e '^[[:space:]]*$' "$1" | tr -d '\r' | sed -E 's/_(Era|Forever)\.lua$/_CLIENT.lua/'; }
base=$(entries "$dir/KeepThat_Camelot.toc")
status=0
for toc in "$dir"/KeepThat_*.toc; do
  if [ "$base" = "$(entries "$toc")" ]; then echo "ok       $(basename "$toc")"; else echo "DIFFERS  $(basename "$toc")"; status=1; fi
done
exit $status
