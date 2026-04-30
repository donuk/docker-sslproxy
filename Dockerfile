FROM caddy:2

RUN cat > /entrypoint.sh <<'EOF'
#!/bin/sh
set -e

LOGFILE=/tmp/caddy.log
ERROR_PATTERNS='rateLimited|too many certificates|certificate has already been requested'
FALLBACK_MARKER=/tmp/ssl_fallback_marker
RETRY_INTERVAL=$((6 * 60 * 60)) # 6 hours in seconds

render_caddyfile_le() {
  cat > /etc/caddy/Caddyfile <<CADDYFILE
$DOMAIN {
	reverse_proxy $BACKEND
}
CADDYFILE
}

render_caddyfile_selfsigned() {
  cat > /etc/caddy/Caddyfile <<CADDYFILE
$DOMAIN {
	reverse_proxy $BACKEND
	tls internal
}
CADDYFILE
}

start_caddy() {
  "$@" > "$LOGFILE" 2>&1 &
  CADDY_PID=$!
  echo $CADDY_PID > /tmp/caddy.pid
}

monitor_errors() {
  while kill -0 $CADDY_PID 2>/dev/null; do
    if grep -qE "$ERROR_PATTERNS" "$LOGFILE"; then
      echo "Detected certificate issuance rate limiting error; killing caddy."
      kill $CADDY_PID
      wait $CADDY_PID 2>/dev/null || true
      return 1
    fi
    sleep 5
  done
  return 0
}

run_caddy_with_letsencrypt_until_error() {
  echo "[INFO] Running with Let's Encrypt certificates."
  render_caddyfile_le
  start_caddy "$@"
  CADDY_PID=$(cat /tmp/caddy.pid)
  monitor_errors
  MONITOR_STATUS=$?
  if [ $MONITOR_STATUS -eq 1 ]; then
    echo "[WARN] Let's Encrypt failed, switching to self-signed certificates."
    date +%s > "$FALLBACK_MARKER"
    MODE=selfsigned
    wait $CADDY_PID 2>/dev/null || true
    return 1
  else
    echo "[INFO] Caddy exited cleanly (Let's Encrypt mode), exiting loop."
    wait $CADDY_PID 2>/dev/null || true
    exit 0
  fi
}

run_caddy_selfsigned_for_6hours() {
  echo "[INFO] Running with self-signed certificates."
  render_caddyfile_selfsigned
  start_caddy "$@"
  CADDY_PID=$(cat /tmp/caddy.pid)
  # Calculate remaining wait time
  LAST_FAIL=$(cat "$FALLBACK_MARKER" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  ELAPSED=$((NOW - LAST_FAIL))
  TO_WAIT=$((RETRY_INTERVAL - ELAPSED))
  # Wait for caddy to exit or for retry interval
  while kill -0 $CADDY_PID 2>/dev/null; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_FAIL))
    if [ "$ELAPSED" -ge "$RETRY_INTERVAL" ]; then
      echo "[INFO] 6 hours elapsed, retrying Let's Encrypt."
      MODE=letsencrypt
      kill $CADDY_PID
      wait $CADDY_PID 2>/dev/null || true
      return 1
    fi
    sleep 5
  done
  if ! kill -0 $CADDY_PID 2>/dev/null; then
    echo "[INFO] Caddy exited (self-signed mode), exiting loop."
    wait $CADDY_PID 2>/dev/null || true
    exit 0
  fi
}

run_caddy() {
  run_caddy_with_letsencrypt_until_error "$@" || run_caddy_selfsigned_for_6hours "$@"
}

tail_logs() {
  while [ ! -f "$LOGFILE" ]; do
    sleep 1
  done
  tail -f $LOGFILE
}
main() {
  tail_logs &
  echo "Starting Caddy SSL proxy loop..."
  while ! run_caddy "$@"; do
    echo "Starting over";
  done
}

main "$@"

EOF


RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
