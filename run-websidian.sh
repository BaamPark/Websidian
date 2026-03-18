#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/home/deck/websidian"
FRONTEND_DIR="$BASE_DIR/frontend"
BACKEND_DIR="$BASE_DIR/backend"
LOG_DIR="$BASE_DIR/logs"
PID_DIR="$BASE_DIR/.pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

FRONTEND_PID_FILE="$PID_DIR/frontend.pid"
BACKEND_PID_FILE="$PID_DIR/backend.pid"

is_running() {
  local pid_file="$1"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi
  return 1
}

start_service() {
  local name="$1"
  local dir="$2"
  local npm_script="$3"
  local pid_file="$4"
  local log_file="$5"

  if is_running "$pid_file"; then
    echo "$name already running (PID $(cat "$pid_file"))"
    return 0
  fi

  echo "Starting $name..."
  (
    cd "$dir"
    nohup npm run "$npm_script" >> "$log_file" 2>&1 &
    echo $! > "$pid_file"
  )

  sleep 1
  if is_running "$pid_file"; then
    echo "$name started (PID $(cat "$pid_file"))"
  else
    echo "Failed to start $name. Check log: $log_file"
    return 1
  fi
}

stop_service() {
  local name="$1"
  local pid_file="$2"

  if ! is_running "$pid_file"; then
    echo "$name is not running"
    rm -f "$pid_file"
    return 0
  fi

  local pid
  pid="$(cat "$pid_file")"
  echo "Stopping $name (PID $pid)..."
  kill "$pid" 2>/dev/null || true

  for _ in {1..10}; do
    if kill -0 "$pid" 2>/dev/null; then
      sleep 1
    else
      break
    fi
  done

  if kill -0 "$pid" 2>/dev/null; then
    echo "$name did not stop gracefully, force killing..."
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$pid_file"
  echo "$name stopped"
}

status_service() {
  local name="$1"
  local pid_file="$2"

  if is_running "$pid_file"; then
    echo "$name: RUNNING (PID $(cat "$pid_file"))"
  else
    echo "$name: STOPPED"
  fi
}

start_all() {
  start_service "backend" "$BACKEND_DIR" "start" "$BACKEND_PID_FILE" "$LOG_DIR/backend.log"
  start_service "frontend" "$FRONTEND_DIR" "start" "$FRONTEND_PID_FILE" "$LOG_DIR/frontend.log"
  echo ""
  echo "Logs:"
  echo "  tail -f $LOG_DIR/backend.log"
  echo "  tail -f $LOG_DIR/frontend.log"
}

stop_all() {
  stop_service "frontend" "$FRONTEND_PID_FILE"
  stop_service "backend" "$BACKEND_PID_FILE"
}

status_all() {
  status_service "backend" "$BACKEND_PID_FILE"
  status_service "frontend" "$FRONTEND_PID_FILE"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") {start|stop|restart|status}

Commands:
  start    Start backend and frontend with npm start and nohup
  stop     Stop both services
  restart  Restart both services
  status   Show running status
EOF
}

cmd="${1:-start}"
case "$cmd" in
  start)
    start_all
    ;;
  stop)
    stop_all
    ;;
  restart)
    stop_all || true
    start_all
    ;;
  status)
    status_all
    ;;
  *)
    usage
    exit 1
    ;;
esac
