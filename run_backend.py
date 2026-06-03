#!/usr/bin/env python3
"""
Startup script for Face Recognition Attendance Backend API.
Runs the FastAPI server with uvicorn.
"""
import os
import sys
import socket

if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))

    local_ip = socket.gethostbyname(socket.gethostname())
    print("=" * 60)
    print("  Face Recognition Attendance API")
    print("=" * 60)
    print(f"  Local access:    http://127.0.0.1:{port}")
    print(f"  Network access:  http://{local_ip}:{port}")
    print(f"  API docs:        http://127.0.0.1:{port}/docs")
    print()
    print("  For Flutter app (Android emulator): http://10.0.2.2:8000")
    print("  For Flutter app (real device):      http://YOUR_COMPUTER_IP:8000")
    print()
    print("  [Firebase Firestore]")
    print("  Set FIREBASE_CREDENTIALS env var to path of your")
    print("  Firebase service account JSON file, or use ADC.")
    print("=" * 60)
    print()

    uvicorn.run(
        "backend.main:app",
        host=host,
        port=port,
        reload=False,
        log_level="info",
        workers=1,
    )
