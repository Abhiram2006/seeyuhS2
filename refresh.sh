#!/usr/bin/env bash
set -euo pipefail

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

osascript <<'APPLESCRIPT' | python3 "$SITE_DIR/build_data.py" "$SITE_DIR"
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
