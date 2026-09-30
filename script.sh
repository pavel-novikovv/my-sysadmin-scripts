#!/bin/bash
set -euo pipefail

readonly INTERVAL=10
readonly LOG_FILE="${LOG_FILE:-monitor.log}"

fail() {
    echo "monitor: $1" >&2
    exit 1
}

for cmd in free df uptime; do
    command -v "$cmd" >/dev/null 2>&1 || fail "не найдена команда $cmd"
done

touch "$LOG_FILE" 2>/dev/null || fail "нет прав на запись в $LOG_FILE"

snapshot() {
    echo "--- $(date '+%Y-%m-%d %H:%M:%S') ---"
    free -h
    df -h
    uptime
    echo
}

while true; do
    snapshot >> "$LOG_FILE"
    sleep "$INTERVAL"
done
