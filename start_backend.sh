#!/usr/bin/env bash
# Face Recognition Attendance API - Startup Script (macOS/Linux)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================================"
echo "  Face Recognition Attendance API - Startup"
echo "============================================================"
echo ""

# Get local IP
IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}' | head -1)
echo "Local access:    http://127.0.0.1:8000"
echo "Network access:  http://$IP:8000"
echo "API docs:        http://127.0.0.1:8000/docs"
echo ""
echo "For Flutter (Android emulator): http://10.0.2.2:8000"
echo "For Flutter (real device):      http://$IP:8000"
echo ""
echo "============================================================"
echo ""

python run_backend.py
