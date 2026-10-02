#!/bin/bash
set -euo pipefail

# ==============================================================================
# NNTS - Native Telemetry & Log Ingestion Utility
# Directly queries and streams macOS Unified Logging System (os_log)
# ==============================================================================

SUBSYSTEM="com.almosteleven.nnts"
BUNDLE_ID="com.almosteleven.nnts"
PREDICATE="subsystem == \"${SUBSYSTEM}\" or process == \"NNTS\""

usage() {
    cat << EOF
NNTS — Telemetry & Log Monitor

Usage:
  ./scripts/monitor_telemetry.sh [command] [options]

Commands:
  stream          Stream live application telemetry logs in real time
  errors [time]   Show errors and faults from the unified log (default: 30m)
  summary [time]  Aggregate log metrics & category breakdown (default: 1h)
  json [time]     Dump structured ndjson log records for log ingestion
  help            Show this help message

Examples:
  ./scripts/monitor_telemetry.sh stream
  ./scripts/monitor_telemetry.sh errors 15m
  ./scripts/monitor_telemetry.sh summary 2h
  ./scripts/monitor_telemetry.sh json 1h > telemetry.jsonl
EOF
}

COMMAND="${1:-stream}"

case "$COMMAND" in
    stream)
        echo "📡 Streaming live telemetry for ${SUBSYSTEM} (Press Ctrl+C to stop)..."
        echo "=================================================================="
        log stream \
            --predicate "${PREDICATE}" \
            --style compact \
            --level debug \
            --color always
        ;;

    errors)
        TIME_WINDOW="${2:-30m}"
        echo "🔍 Ingesting errors and faults from the last ${TIME_WINDOW}..."
        echo "=================================================================="
        log show \
            --predicate "(${PREDICATE}) and (messageType == error or messageType == fault)" \
            --last "${TIME_WINDOW}" \
            --style compact \
            --color always
        ;;

    summary)
        TIME_WINDOW="${2:-1h}"
        echo "📊 Telemetry Metrics & Category Summary (Last ${TIME_WINDOW}):"
        echo "=================================================================="
        
        TMP_FILE=$(mktemp /tmp/mps_telemetry_XXXXXX.json)
        trap 'rm -f "$TMP_FILE"' EXIT
        
        log show \
            --predicate "${PREDICATE}" \
            --last "${TIME_WINDOW}" \
            --style ndjson > "$TMP_FILE" 2>/dev/null || true

        if [ ! -s "$TMP_FILE" ]; then
            echo "ℹ️  No telemetry records found in the last ${TIME_WINDOW}."
            exit 0
        fi

        python3 -c "
import json, sys

total = 0
categories = {}
levels = {}
errors = []

with open('$TMP_FILE', 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            record = json.loads(line)
            total += 1
            cat = record.get('category', 'Uncategorized')
            lvl = record.get('messageType', 'info')
            msg = record.get('eventMessage', '')

            categories[cat] = categories.get(cat, 0) + 1
            levels[lvl] = levels.get(lvl, 0) + 1
            if lvl in ['error', 'fault']:
                errors.append(f'[{cat}] {msg}')
        except Exception:
            continue

print(f'Total Log Events Ingested: {total}')
print('\n[Breakdown by Log Level]')
for lvl, count in sorted(levels.items(), key=lambda x: -x[1]):
    print(f'  • {lvl.upper():<8}: {count}')

print('\n[Breakdown by Architecture Category]')
for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
    print(f'  • {cat:<24}: {count}')

if errors:
    print(f'\n⚠️  Recent Errors/Faults ({len(errors)}):')
    for err in errors[:10]:
        print(f'  - {err}')
    if len(errors) > 10:
        print(f'  ... and {len(errors) - 10} more.')
else:
    print('\n✅ Zero application errors or faults detected.')
"
        ;;

    json)
        TIME_WINDOW="${2:-1h}"
        log show \
            --predicate "${PREDICATE}" \
            --last "${TIME_WINDOW}" \
            --style ndjson
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo "❌ Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
