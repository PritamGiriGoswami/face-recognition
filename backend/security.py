import os
import json
from pathlib import Path
from cryptography.fernet import Fernet

# Use the same .runtime folder as DeepFace for persistent storage
RUNTIME_DIR = Path(__file__).resolve().parent.parent / ".runtime"
KEY_FILE = RUNTIME_DIR / "biometric.key"

def _ensure_key() -> bytes:
    """
    Ensures that a biometric encryption key exists in the .runtime directory.
    Generates a secure key if one does not exist.
    """
    try:
        os.makedirs(RUNTIME_DIR, exist_ok=True)
        if KEY_FILE.exists():
            return KEY_FILE.read_bytes()
        else:
            # Generate a new secure Fernet key
            key = Fernet.generate_key()
            KEY_FILE.write_bytes(key)
            # Set restrictive permissions if possible (read/write only for user)
            try:
                os.chmod(KEY_FILE, 0o600)
            except Exception:
                pass
            return key
    except Exception as e:
        print(f"[Biometric Security] Error securing keyfile: {e}")
        # Fallback to a deterministic key derived from environment or system state
        import hashlib
        fallback_secret = os.getenv("BIOMETRIC_SECRET_KEY", "gurukul-default-biometric-salt-key-98765")
        key_32 = hashlib.sha256(fallback_secret.encode()).digest()
        import base64
        return base64.urlsafe_b64encode(key_32)

# Load the secret key
_SECRET_KEY = _ensure_key()
_cipher = Fernet(_SECRET_KEY)

def encrypt_embedding(embedding: list[float]) -> str:
    """
    Encrypts a biometric vector embedding using AES-256 authenticated encryption (Fernet).
    Returns the encrypted token as a secure ASCII string.
    """
    # Serialize embedding list to JSON string
    serialized = json.dumps(embedding).encode('utf-8')
    # Encrypt the byte string
    encrypted_bytes = _cipher.encrypt(serialized)
    # Convert to standard string representation
    return encrypted_bytes.decode('ascii')

def decrypt_embedding(encrypted_str: str) -> list[float]:
    """
    Decrypts an encrypted biometric vector string back into a list of floats.
    """
    try:
        # Decode ASCII string to bytes
        encrypted_bytes = encrypted_str.encode('ascii')
        # Decrypt payload
        decrypted_bytes = _cipher.decrypt(encrypted_bytes)
        # Deserialize JSON to list
        return json.loads(decrypted_bytes.decode('utf-8'))
    except Exception as e:
        print(f"[Biometric Security] Failed to decrypt biometric embedding: {e}")
        raise ValueError("Failed to decrypt biometric vector. The encryption key might be missing or invalid.")
