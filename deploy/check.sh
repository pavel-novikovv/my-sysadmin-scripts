#!/bin/bash
set -uo pipefail

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
readonly REPO_DIR
HOST_IP=$(hostname -I | awk '{print $1}')
readonly HOST_IP

run() {
    if [[ -t 1 ]]; then
        printf '\n\033[1;32m$ %s\033[0m\n' "$1"
    else
        printf '\n$ %s\n' "$1"
    fi
    bash -c "$1" 2>&1
}

repo() {
    run "git -C $REPO_DIR log --oneline"
    run "MAX_ITERATIONS=1 LOG_FILE=/tmp/check-monitor.log $REPO_DIR/script.sh && head -6 /tmp/check-monitor.log && rm -f /tmp/check-monitor.log"
}

part1() {
    run "docker build -t my-script $REPO_DIR 2>&1 | tail -3"
    run "docker run --rm -e MAX_ITERATIONS=1 my-script /usr/local/bin/script.sh"
    run "docker ps -a --filter name=my-app"
    run "cat /proc/mdstat"
    run "sudo vgs && sudo lvs"
    run "df -h /mnt/raid /mnt/logs"
}

part2() {
    run "sudo nginx -t"
    run "curl -skI https://$HOST_IP"
    run "systemctl status my-app --no-pager | head -5"
    run "journalctl -u my-app -n 4 --no-pager"
    run "tail -n 3 /var/log/nginx/access.log"
}

case "${1:-all}" in
    part1) part1 ;;
    part2) part2 ;;
    all) repo; part1; part2 ;;
    *) echo "использование: $0 [part1|part2|all]" >&2; exit 1 ;;
esac
