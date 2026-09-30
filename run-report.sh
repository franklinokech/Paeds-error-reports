#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

REPORT="$(pwd)/tmp/ErrorReport.csv"

# Remove any stale report so we can tell whether this run produced one
rm -f "$REPORT"

docker compose up

if [ ! -f "$REPORT" ]; then
  echo
  echo "Report not found at $REPORT"
  read -rp "Press Enter to close..." _
  exit 1
fi

echo
echo "Opening $REPORT in LibreOffice Calc..."

# setsid detaches LibreOffice from this shell's process group,
# so it survives the terminal closing.
setsid libreoffice --calc "$REPORT" >/dev/null 2>&1 &

# Give LibreOffice a moment to actually appear on screen
sleep 3

echo "Done."
read -rp "Press Enter to close this window..." _