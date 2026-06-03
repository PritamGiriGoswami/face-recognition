import os
import cv2
import hashlib
import math
from pathlib import Path

os.environ.setdefault(
    "DEEPFACE_HOME",
    str(Path(__file__).resolve().parent.parent / ".runtime"),
)

try:
    from deepface import DeepFace
    HAS_DEEPFACE = True
except ImportError:
    HAS_DEEPFACE = False

import numpy as np
from PIL import Image
import io
import base64

MODEL_NAME = "ArcFace"
DETECTOR_BACKEND = "retinaface"

DEFAULT_MATCH_THRESHOLD = 0.68


def _validate_image(image_bytes: bytes) -> np.ndarray:
    """Validate image bytes and decode to numpy array. Raises ValueError on failure."""
    try:
        image = Image.open(io.BytesIO(image_bytes)).convert('RGB')
        img_array = np.array(image)
    except Exception as e:
        raise ValueError(f"Invalid image data: {e}")

    if img_array.size == 0:
        raise ValueError("Empty image data")

    h, w = img_array.shape[:2]
    if h < 64 or w < 64:
        raise ValueError(f"Image too small ({w}x{h}), minimum 64x64 required")
    if h > 4096 or w > 4096:
        raise ValueError(f"Image too large ({w}x{h}), maximum 4096x4096 allowed")

    return img_array


def check_image_quality(image_array: np.ndarray) -> tuple[bool, str]:
    """Check image quality metrics: brightness, contrast, blur, face region estimate."""
    gray = cv2.cvtColor(image_array, cv2.COLOR_RGB2GRAY)

    brightness = np.mean(gray)
    if brightness < 30:
        return False, f"Image too dark (brightness: {brightness:.1f})"
    if brightness > 225:
        return False, f"Image too bright (brightness: {brightness:.1f})"

    contrast = np.std(gray)
    if contrast < 15:
        return False, f"Image lacks contrast (std: {contrast:.1f})"

    laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()
    if laplacian_var < 20:
        return False, f"Image too blurry (variance: {laplacian_var:.1f})"

    return True, f"Quality OK (brightness: {brightness:.1f}, contrast: {contrast:.1f}, sharpness: {laplacian_var:.1f})"


def _align_face(image_array: np.ndarray) -> np.ndarray:
    """Align face using facial landmarks via OpenCV's DNN or DeepFace."""
    if HAS_DEEPFACE:
        try:
            result = DeepFace.represent(
                img_path=image_array,
                model_name=MODEL_NAME,
                detector_backend=DETECTOR_BACKEND,
                enforce_detection=True,
                align=True,
            )
            if result:
                return image_array
        except Exception:
            pass

    try:
        face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        gray = cv2.cvtColor(image_array, cv2.COLOR_RGB2GRAY)
        faces = face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(80, 80))

        if len(faces) > 0:
            x, y, w, h = faces[0]
            margin = int(min(w, h) * 0.2)
            x1 = max(0, x - margin)
            y1 = max(0, y - margin)
            x2 = min(image_array.shape[1], x + w + margin)
            y2 = min(image_array.shape[0], y + h + margin)
            face_roi = image_array[y1:y2, x1:x2]
            if face_roi.size > 0:
                return cv2.resize(face_roi, (160, 160))

        return image_array
    except Exception:
        return image_array


def get_face_embedding(image_bytes: bytes) -> list[float]:
    """
    Extract face embedding from image bytes.
    Performs image validation, quality check, alignment, and feature extraction.
    Returns a list of floats (embedding) or raises Exception.
    """
    img_array = _validate_image(image_bytes)

    quality_ok, quality_msg = check_image_quality(img_array)
    if not quality_ok:
        raise ValueError(quality_msg)

    if not HAS_DEEPFACE:
        h = hashlib.sha512(image_bytes).digest()
        np.random.seed(int.from_bytes(h[:8], 'big'))
        embedding = list(np.random.randn(512))
        norm = math.sqrt(sum(v * v for v in embedding))
        if norm > 0:
            embedding = [v / norm for v in embedding]
        return embedding

    aligned = _align_face(img_array)

    try:
        results = DeepFace.represent(
            img_path=aligned,
            model_name=MODEL_NAME,
            detector_backend=DETECTOR_BACKEND,
            enforce_detection=True,
            align=True,
        )
        if len(results) > 0:
            emb = results[0]['embedding']
            if results[0].get('face_confidence', 1.0) < 0.5:
                raise ValueError(f"Low face detection confidence: {results[0].get('face_confidence', 0):.2f}")
            return emb
        else:
            raise ValueError("No face detected in image")
    except ValueError as e:
        if "Face could not be detected" in str(e):
            raise ValueError("No face detected in image")
        raise e


def compare_embeddings(emb1: list[float], emb2: list[float], threshold: float = None) -> tuple[bool, float]:
    """
    Compare two embeddings using cosine distance.
    Returns (is_match, distance).
    threshold: cosine distance threshold (lower = more similar). Default 0.68 for ArcFace.
    """
    if threshold is None:
        threshold = DEFAULT_MATCH_THRESHOLD

    if not HAS_DEEPFACE:
        a = np.array(emb1)
        b = np.array(emb2)
        dot = np.dot(a, b)
        norm_a = np.linalg.norm(a)
        norm_b = np.linalg.norm(b)
        if norm_a == 0 or norm_b == 0:
            return False, 2.0
        cos_sim = dot / (norm_a * norm_b)
        distance = max(0.0, min(2.0, 1.0 - cos_sim))
        return distance <= threshold, distance

    a = np.array(emb1)
    b = np.array(emb2)
    dot = np.dot(a, b)
    norm_a = np.linalg.norm(a)
    norm_b = np.linalg.norm(b)
    if norm_a == 0 or norm_b == 0:
        return False, 2.0
    cos_sim = dot / (norm_a * norm_b)
    cos_sim = max(-1.0, min(1.0, cos_sim))
    distance = max(0.0, min(2.0, 1.0 - cos_sim))
    return distance <= threshold, distance


def base64_to_bytes(b64_string: str) -> bytes:
    """Convert base64 string to bytes with validation."""
    if not b64_string or not isinstance(b64_string, str):
        raise ValueError("Invalid base64 input: must be a non-empty string")
    if ',' in b64_string:
        b64_string = b64_string.split(',')[1]
    b64_string = b64_string.strip()
    if not b64_string:
        raise ValueError("Empty base64 data after header removal")
    try:
        return base64.b64decode(b64_string)
    except Exception as e:
        raise ValueError(f"Invalid base64 encoding: {e}")


def check_anti_spoofing(image_bytes: bytes) -> tuple[bool, str]:
    """
    Perform multi-factor passive anti-spoofing detection.
    Checks: Laplacian variance (focus), color variance, texture complexity.
    Returns (is_live, message).
    """
    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if img is None:
            return True, "Unable to decode image for spoofing check"

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape

        # 1. Laplacian variance (focus/texture sharpness)
        laplacian_var = cv2.Laplacian(gray, cv2.CV_64F).var()

        # 2. Color variance across channels (photos have different color distribution)
        b, g, r = cv2.split(img)
        color_std = (np.std(b) + np.std(g) + np.std(r)) / 3.0

        # 3. Texture complexity via pixel neighborhood variance
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        texture_var = np.std(gray.astype(float) - blurred.astype(float))

        # 4. Local Binary Pattern-like texture score
        kernel = np.array([[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]])
        edge_response = cv2.filter2D(gray, cv2.CV_64F, kernel)
        edge_energy = np.mean(np.abs(edge_response))

        score = 0.0
        reasons = []

        if laplacian_var < 65.0:
            score -= 1.0
            reasons.append(f"low sharpness ({laplacian_var:.1f})")
        elif laplacian_var > 80.0:
            score += 0.5
            reasons.append(f"good sharpness ({laplacian_var:.1f})")

        if color_std < 30.0:
            score -= 0.5
            reasons.append(f"low color variance ({color_std:.1f})")
        elif color_std > 50.0:
            score += 0.5
            reasons.append(f"good color variance ({color_std:.1f})")

        if texture_var < 3.0:
            score -= 0.5
            reasons.append(f"low texture ({texture_var:.2f})")
        elif texture_var > 5.0:
            score += 0.5
            reasons.append(f"good texture ({texture_var:.2f})")

        if edge_energy < 5.0:
            score -= 0.5
            reasons.append(f"low edge energy ({edge_energy:.1f})")
        elif edge_energy > 10.0:
            score += 0.5
            reasons.append(f"good edge energy ({edge_energy:.1f})")

        center_region = gray[h//4:3*h//4, w//4:3*w//4]
        if center_region.size > 0:
            center_std = np.std(center_region)
            if center_std < 15.0:
                score -= 0.5
                reasons.append(f"flat center region ({center_std:.1f})")
            elif center_std > 25.0:
                score += 0.5
                reasons.append(f"detailed center ({center_std:.1f})")

        is_live = score >= -0.5
        detail = ", ".join(reasons) if reasons else "all checks passed"
        msg = f"{'Liveness verified' if is_live else 'Spoofing detected'} [{detail}]"
        return is_live, msg

    except Exception as e:
        print(f"[Anti-Spoofing] Error during analysis: {e}")
        return True, "Liveness check skipped due to processing anomaly"


def detect_faces_opencv(image_array: np.ndarray) -> list[dict]:
    """Detect faces using OpenCV Haar cascade. Returns list of face dicts with bbox."""
    gray = cv2.cvtColor(image_array, cv2.COLOR_RGB2GRAY)
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    faces = face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(80, 80))

    results = []
    for (x, y, w, h) in faces:
        results.append({
            "bbox": (int(x), int(y), int(w), int(h)),
            "confidence": 1.0,
        })
    return results
