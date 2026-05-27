#!/usr/bin/env python3
import json
import sys
from datetime import datetime, timedelta

raw = sys.stdin.read()
out_dir = sys.argv[1] if len(sys.argv) > 1 else '.'

events = []
for line in raw.split('\n'):
    line = line.rstrip('\r')
    if not line.strip():
        continue
    parts = line.split('\t')
    if len(parts) < 3:
        continue
    start_str, end_str, summary = parts[0], parts[1], '\t'.join(parts[2:])
    try:
        start = datetime.strptime(start_str, '%Y-%m-%d %H:%M:%S')
        end = datetime.strptime(end_str, '%Y-%m-%d %H:%M:%S')
    except ValueError:
        continue
    if end <= start:
        continue
    events.append((start, end, summary))

START_DATE = datetime(2026, 5, 23).date()
NOW = datetime.now()
TODAY = NOW.date()

days_data = {}
d = START_DATE
while d <= TODAY:
    days_data[d] = {
        'date': d.isoformat(),
        'work_hrs': 0.0,
        'weighted_hrs': 0.0,
        'sleep_hrs': 0.0,
    }
    d += timedelta(days=1)

def split_by_day(start, end):
    cur = start
    while cur < end:
        next_midnight = datetime.combine(cur.date() + timedelta(days=1), datetime.min.time())
        chunk_end = min(end, next_midnight)
        hrs = (chunk_end - cur).total_seconds() / 3600.0
        yield cur.date(), hrs
        cur = chunk_end

for start, end, summary in events:
    summ_lower = summary.strip().lower()
    if summ_lower == 'sleep':
        for date, hrs in split_by_day(start, end):
            if date in days_data:
                days_data[date]['sleep_hrs'] += hrs
    elif '★' in summary:  # ★
        score = summary.count('★')
        if score > 5:
            score = 5
        for date, hrs in split_by_day(start, end):
            if date in days_data:
                days_data[date]['work_hrs'] += hrs
                days_data[date]['weighted_hrs'] += hrs * (score / 5.0)

result_days = []
for date in sorted(days_data.keys(), reverse=True):
    d = days_data[date]
    is_today = (date == TODAY)
    if is_today:
        elapsed = (NOW - datetime.combine(date, datetime.min.time())).total_seconds() / 3600.0
        awake = max(0.0, elapsed - d['sleep_hrs'])
    else:
        awake = max(0.0, 24.0 - d['sleep_hrs'])

    d['awake_hrs'] = round(awake, 2)
    d['work_hrs'] = round(d['work_hrs'], 2)
    d['weighted_hrs'] = round(d['weighted_hrs'], 2)
    d['sleep_hrs'] = round(d['sleep_hrs'], 2)
    d['mobilization'] = round(d['work_hrs'] / awake, 4) if awake > 0 else None
    d['efficiency'] = round(d['weighted_hrs'] / d['work_hrs'], 4) if d['work_hrs'] > 0 else None
    d['partial'] = is_today
    result_days.append(d)

output = {
    'last_updated': NOW.strftime('%Y-%m-%d %H:%M'),
    'days': result_days,
}

with open(f'{out_dir}/data.json', 'w') as f:
    json.dump(output, f, indent=2)

with open(f'{out_dir}/data.js', 'w') as f:
    f.write('window.DASHBOARD_DATA = ')
    json.dump(output, f, indent=2)
    f.write(';\n')

print(f'Wrote {len(result_days)} days, {len(events)} events parsed.', file=sys.stderr)
