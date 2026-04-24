#!/bin/bash
# start-solclaw.sh — Start SolClaw without systemd
# To stop: kill $(cat /home/user/solclaw/solclaw.pid)

set -euo pipefail

cd "/home/user/solclaw"

# Stop existing instance if running
if [ -f "/home/user/solclaw/solclaw.pid" ]; then
  OLD_PID=$(cat "/home/user/solclaw/solclaw.pid" 2>/dev/null || echo "")
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Stopping existing SolClaw (PID $OLD_PID)..."
    kill "$OLD_PID" 2>/dev/null || true
    sleep 2
  fi
fi

# Ensure Docker daemon is running
if ! docker info &>/dev/null; then
  echo "Starting Docker daemon..."
  dockerd --host=unix:///var/run/docker.sock --tls=false &>/tmp/dockerd.log &
  DOCKERD_PID=$!
  for i in $(seq 1 15); do
    sleep 1
    docker info &>/dev/null && break
  done
  docker info &>/dev/null || { echo "ERROR: Docker failed to start"; exit 1; }
  echo "Docker started (PID $DOCKERD_PID)"
fi

echo "Starting SolClaw..."
export NODE_EXTRA_CA_CERTS="/home/user/solclaw/config/anthropic-sandbox-ca.pem"
nohup "/opt/node22/bin/node" "/home/user/solclaw/dist/index.js" \
  >> "/home/user/solclaw/logs/solclaw.log" \
  2>> "/home/user/solclaw/logs/solclaw.error.log" &

echo $! > "/home/user/solclaw/solclaw.pid"
echo "SolClaw started (PID $!)"
echo "Logs: tail -f /home/user/solclaw/logs/solclaw.log"
