#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIST_ID="95dbfa27f404d923bb270929d7bf72a8"

EVENTS_TMP=$(mktemp)
ERR_TMP=$(mktemp)
trap 'rm -f "$EVENTS_TMP" "$ERR_TMP"' EXIT

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Pulling Evidence. calendar via osascript ..."

set +e
osascript >"$EVENTS_TMP" 2>"$ERR_TMP" <<'APPLESCRIPT'
on fmt(d)
    set y to year of d as integer
    set m to (month of d) as integer
    set dy to day of d
    set hh to hours of d
    set mm to minutes of d
    set ss to seconds of d
    set monthStr to text -2 thru -1 of ("0" & m)
    set dayStr to text -2 thru -1 of ("0" & dy)
    set hourStr to text -2 thru -1 of ("0" & hh)
    set minStr to text -2 thru -1 of ("0" & mm)
    set secStr to text -2 thru -1 of ("0" & ss)
    return (y as text) & "-" & monthStr & "-" & dayStr & " " & hourStr & ":" & minStr & ":" & secStr
end fmt

set startDate to current date
set startDate's year to 2026
set startDate's month to May
set startDate's day to 23
set startDate's hours to 0
set startDate's minutes to 0
set startDate's seconds to 0

set endDate to (current date) + (1 * days)

set outputLines to {}
tell application "Calendar"
    tell calendar "Evidence."
        set theEvents to (every event whose start date >= startDate and start date <= endDate)
        repeat with anEvent in theEvents
            set s to start date of anEvent
            set e to end date of anEvent
            set summ to summary of anEvent
            set end of outputLines to my fmt(s) & tab & my fmt(e) & tab & summ
        end repeat
    end tell
end tell

set AppleScript's text item delimiters to linefeed
set outputText to outputLines as text
set AppleScript's text item delimiters to ""
return outputText
APPLESCRIPT
OSA_EXIT=$?
set -e

# Guard: bail before touching local data.json or gist if osascript failed.
if [ "$OSA_EXIT" -ne 0 ]; then
  echo "ERROR: osascript exited $OSA_EXIT — aborting (local data + gist untouched)."
  echo "stderr:"; cat "$ERR_TMP"
  exit 1
fi
if [ ! -s "$EVENTS_TMP" ]; then
  echo "ERROR: osascript produced no output — aborting (likely TCC denied; local data + gist untouched)."
  echo "stderr:"; cat "$ERR_TMP"
  exit 1
fi

EVENT_COUNT=$(wc -l < "$EVENTS_TMP" | tr -d ' ')
echo "Got $EVENT_COUNT events. Building data.json ..."

python3 "$SITE_DIR/build_data.py" "$SITE_DIR" < "$EVENTS_TMP"

echo "Publishing to gist $GIST_ID ..."
python3 -c "
import json, sys
content = open('$SITE_DIR/data.json').read()
json.dump({'files': {'data.json': {'content': content}}}, sys.stdout)
" | gh api -X PATCH "/gists/$GIST_ID" --input - >/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done. Live: https://abhiram2006.github.io/seeyuhS2/"
