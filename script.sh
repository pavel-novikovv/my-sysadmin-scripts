#!/bin/bash
set -euo pipefail

readonly INTERVAL=10
readonly LOG_FILE="${LOG_FILE:-monitor.log}"
readonly MAX_ITERATIONS="${MAX_ITERATIONS:-0}"

fail() {
    echo "monitor: $1" >&2
    exit 1
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

[[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || fail "MAX_ITERATIONS должно быть целым числом от 0 (0 - без ограничения)"

for cmd in free df uptime; do
    command -v "$cmd" >/dev/null 2>&1 || fail "не найдена команда $cmd"
done

touch "$LOG_FILE" 2>/dev/null || fail "нет прав на запись в $LOG_FILE"

snapshot() {
    echo "--- $(timestamp) ---"
    free -h
    df -h
    uptime
    echo
}

stop() {
    echo "--- $(timestamp) мониторинг остановлен ---" >> "$LOG_FILE"
    echo "monitor: остановлен"
    exit 0
}

trap stop INT TERM

echo "monitor: пишу замеры в $LOG_FILE каждые $INTERVAL с"

count=0
while true; do
    snapshot >> "$LOG_FILE"
    count=$((count + 1))
    if (( MAX_ITERATIONS > 0 && count >= MAX_ITERATIONS )); then
        echo "monitor: сделано замеров: $count"
        break
    fi
    sleep "$INTERVAL" &
    wait $!
done
