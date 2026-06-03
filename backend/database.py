import firebase_admin
from firebase_admin import credentials, firestore
import os
from pathlib import Path

_firestore_client = None
_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True
    try:
        firebase_admin.get_app()
        _firebase_initialized = True
        return True
    except ValueError:
        pass

    cred_path = os.getenv("FIREBASE_CREDENTIALS", "")
    if cred_path and Path(cred_path).exists():
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        return True

    try:
        firebase_admin.initialize_app()
        _firebase_initialized = True
        return True
    except Exception as e:
        print(f"Firebase initialization failed: {e}")
        return False

def get_firestore():
    global _firestore_client
    if _firestore_client is None:
        if not init_firebase():
            raise RuntimeError(
                "Firebase not configured. Set FIREBASE_CREDENTIALS env var "
                "to point to your service account JSON file, or configure "
                "Application Default Credentials."
            )
        _firestore_client = firestore.client()
    return _firestore_client

def get_db():
    yield get_firestore()
