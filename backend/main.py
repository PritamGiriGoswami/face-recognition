from fastapi import FastAPI, Depends, Header, HTTPException, Query, Response, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from typing import List
from datetime import datetime, date, time, timedelta
import csv
import hashlib
import io
import json
import math
import os
import secrets


from backend import schemas, face_engine, security, database as db_module
from backend.models import (
    doc_to_dict,
    collection_ref,
    doc_ref,
    COLLECTION_ADMINS,
    COLLECTION_USERS,
    COLLECTION_ATTENDANCE,
    COLLECTION_SETTINGS,
    COLLECTION_CLASSES,
    COLLECTION_DEPARTMENTS,
    COLLECTION_DEVICES,
    COLLECTION_ALERTS,
    SETTINGS_DOC_ID,
)

app = FastAPI(title="Face Recognition Attendance API")

@app.get("/api/health")
def health_check():
    return {
        "status": "ok",
        "service": "Face Recognition Attendance API",
        "deepface_available": face_engine.HAS_DEEPFACE,
    }

@app.get("/")
def root_health():
    return {"status": "ok", "message": "Face Recognition Attendance API is running"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_firestore_db():
    db = db_module.get_firestore()
    yield db


import urllib.request
import urllib.error

def fire_webhook_in_background(
    webhook_url: str,
    user_name: str,
    action: str,
    is_late: bool,
    lat: float | None = None,
    lon: float | None = None,
    distance: float | None = None,
):
    if not webhook_url or not webhook_url.startswith("http"):
        return
    try:
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        headers = {'Content-Type': 'application/json', 'User-Agent': 'FastAPI-Attendance'}

        if "discord.com" in webhook_url:
            color = 16753920 if is_late else 3066993
            if action == "Checked Out":
                color = 3447003

            title = f"🚪 {action}"
            status_text = "⏰ Late Arrival" if is_late else "✅ On Time"
            if action == "Checked Out":
                status_text = "🚪 Left Work"

            embed = {
                "title": title,
                "color": color,
                "fields": [
                    {"name": "Employee", "value": user_name, "inline": True},
                    {"name": "Status", "value": status_text, "inline": True},
                    {"name": "Recorded Time", "value": now_str, "inline": False}
                ],
                "footer": {"text": "AI Attendance Guard"}
            }
            if lat is not None and lon is not None:
                dist_str = f"{distance:.1f} meters away" if distance is not None else "N/A"
                embed["fields"].append({
                    "name": "Location Auditing",
                    "value": f"📍 Coordinates: `{lat:.5f}, {lon:.5f}`\n📏 Distance: `{dist_str}`",
                    "inline": False
                })
            payload = {"embeds": [embed]}
        else:
            status_text = "*LATE ARRIVAL*" if is_late else "*ON TIME*"
            if action == "Checked Out":
                status_text = "*Checked Out*"

            dist_val = f"{distance:.1f}" if distance is not None else "0"
            loc_str = f" at coordinates `{lat:.5f}, {lon:.5f}` ({dist_val}m away)" if lat is not None else ""
            msg = f"👤 *{user_name}* recorded *{action}*{loc_str}. Status: {status_text} | Recorded at: `{now_str}`"
            payload = {
                "text": msg,
                "blocks": [
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": msg
                        }
                    }
                ]
            }

        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(webhook_url, data=data, headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=5) as response:
            response.read()
    except Exception as e:
        print(f"Error firing webhook payload: {e}")

OFFICE_LATITUDE = float(os.getenv("OFFICE_LATITUDE", "22.5726"))
OFFICE_LONGITUDE = float(os.getenv("OFFICE_LONGITUDE", "88.3639"))
OFFICE_RADIUS_METERS = float(os.getenv("OFFICE_RADIUS_METERS", "100.0"))

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371000.0
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = (math.sin(delta_phi / 2.0) ** 2 +
         math.cos(phi1) * math.cos(phi2) *
         math.sin(delta_lambda / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

def parse_filter_date(value: str | None, fallback: date | None = None) -> date | None:
    if value is None or not value.strip():
        return fallback
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Invalid date: {value}")

def parse_late_after(value: str) -> time:
    try:
        return time.fromisoformat(value)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="late_after must use HH:MM or HH:MM:SS format",
        )

def csv_value(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if value is None:
        return ""
    return str(value)

def pdf_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

def build_simple_pdf(title: str, lines: list[str]) -> bytes:
    content_lines = ["BT", "/F1 16 Tf", "50 790 Td", f"({pdf_escape(title)}) Tj"]
    content_lines.extend(["/F1 9 Tf", "0 -24 Td"])
    for line in lines[:42]:
        content_lines.append(f"({pdf_escape(line[:110])}) Tj")
        content_lines.append("0 -14 Td")
    content_lines.append("ET")
    stream = "\n".join(content_lines).encode("latin-1", errors="replace")

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 842] "
        b"/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        b"<< /Length " + str(len(stream)).encode("ascii") + b" >>\nstream\n"
        + stream + b"\nendstream",
    ]

    pdf = bytearray(b"%PDF-1.4\n")
    offsets = [0]
    for index, obj in enumerate(objects, start=1):
        offsets.append(len(pdf))
        pdf.extend(f"{index} 0 obj\n".encode("ascii"))
        pdf.extend(obj)
        pdf.extend(b"\nendobj\n")
    xref_offset = len(pdf)
    pdf.extend(f"xref\n0 {len(objects) + 1}\n".encode("ascii"))
    pdf.extend(b"0000000000 65535 f \n")
    for offset in offsets[1:]:
        pdf.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
    pdf.extend(
        f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\n"
        f"startxref\n{xref_offset}\n%%EOF\n".encode("ascii")
    )
    return bytes(pdf)


def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()


def get_settings_singleton(db):
    ref = doc_ref(db, COLLECTION_SETTINGS, SETTINGS_DOC_ID)
    snap = ref.get()
    if snap.exists:
        return doc_to_dict(snap)
    return None

def init_settings(db):
    ref = doc_ref(db, COLLECTION_SETTINGS, SETTINGS_DOC_ID)
    if not ref.get().exists:
        ref.set({
            "office_latitude": 22.5726,
            "office_longitude": 88.3639,
            "office_radius": 100.0,
            "late_after": "09:15",
            "webhook_url": "",
            "purge_raw_images": False,
            "strict_geofence": False,
        })

def init_seed_data(db):
    default_classes = ["CS-A", "CS-B", "ECE-1", "MECH-2", "MBA-Finance"]
    for c_name in default_classes:
        existing = collection_ref(db, COLLECTION_CLASSES).where("name", "==", c_name).limit(1).get()
        if not existing:
            collection_ref(db, COLLECTION_CLASSES).add({"name": c_name})

    default_departments = ["Engineering", "Human Resources", "Finance", "Operations", "Administration"]
    for d_name in default_departments:
        existing = collection_ref(db, COLLECTION_DEPARTMENTS).where("name", "==", d_name).limit(1).get()
        if not existing:
            collection_ref(db, COLLECTION_DEPARTMENTS).add({"name": d_name})

    default_devices = [
        {"device_id": "kiosk_main_lobby", "name": "Main Lobby Entrance Kiosk", "status": "Online", "battery_level": 95, "temperature": 38.2},
        {"device_id": "tablet_south_gate", "name": "South Gate Tablet", "status": "Offline", "battery_level": 12, "temperature": 31.4},
    ]
    for dev in default_devices:
        existing = collection_ref(db, COLLECTION_DEVICES).where("device_id", "==", dev["device_id"]).limit(1).get()
        if not existing:
            dev["last_active"] = datetime.utcnow()
            collection_ref(db, COLLECTION_DEVICES).add(dev)

def init_admin(db):
    admin_email = os.getenv("ADMIN_EMAIL", "admin@gurukul.local")
    admin_password = os.getenv("ADMIN_PASSWORD", "admin123")
    existing = collection_ref(db, COLLECTION_ADMINS).where("email", "==", admin_email).limit(1).get()
    if not existing:
        collection_ref(db, COLLECTION_ADMINS).add({
            "email": admin_email,
            "password_hash": hash_password(admin_password),
            "token": None,
            "created_at": datetime.utcnow(),
        })

try:
    db_instance = db_module.get_firestore()
    init_settings(db_instance)
    init_seed_data(db_instance)
    init_admin(db_instance)
except Exception as e:
    print(f"Firebase not available for seeding: {e}")
    print("Server will start but DB operations will fail until Firebase is configured.")


def get_current_admin(
    authorization: str | None = Header(default=None),
    db=Depends(get_firestore_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin login required",
        )
    token = authorization.removeprefix("Bearer ").strip()
    admins = collection_ref(db, COLLECTION_ADMINS).where("token", "==", token).limit(1).get()
    for a in admins:
        return doc_to_dict(a)
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired admin session",
    )


def get_user_by_email(db, email: str):
    users = collection_ref(db, COLLECTION_USERS).where("email", "==", email).limit(1).get()
    for u in users:
        return doc_to_dict(u)
    return None

def get_user_by_id(db, user_id: str):
    ref = doc_ref(db, COLLECTION_USERS, user_id)
    snap = ref.get()
    if snap.exists:
        return doc_to_dict(snap)
    return None

def get_active_users(db):
    return list(collection_ref(db, COLLECTION_USERS).where("is_active", "==", True).stream())

def get_all_users(db):
    return list(collection_ref(db, COLLECTION_USERS).stream())

def get_attendance_records(db, user_id: str | None = None, date_filter: date | None = None):
    ref = collection_ref(db, COLLECTION_ATTENDANCE)
    if user_id and date_filter:
        return list(ref.where("user_id", "==", user_id).where("date", "==", date_filter.isoformat()).stream())
    if user_id:
        return list(ref.where("user_id", "==", user_id).stream())
    if date_filter:
        return list(ref.where("date", "==", date_filter.isoformat()).stream())
    return list(ref.stream())


@app.post("/api/admin/login", response_model=schemas.AdminLoginResponse)
def admin_login(credentials: schemas.AdminLogin, db=Depends(get_firestore_db)):
    admins = collection_ref(db, COLLECTION_ADMINS).where("email", "==", credentials.email).limit(1).get()
    admin = None
    admin_doc_id = None
    for a in admins:
        admin = a.to_dict()
        admin_doc_id = a.id
        break
    if admin is None or admin.get("password_hash") != hash_password(credentials.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin email or password",
        )
    new_token = secrets.token_urlsafe(32)
    doc_ref(db, COLLECTION_ADMINS, admin_doc_id).update({"token": new_token})
    return {"token": new_token, "email": admin["email"]}


@app.post("/api/admin/logout")
def admin_logout(
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    doc_ref(db, COLLECTION_ADMINS, admin["id"]).update({"token": None})
    return {"success": True}


@app.get("/api/admin/stats", response_model=schemas.AdminStatsResponse)
def get_admin_stats(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    today = datetime.utcnow().date()
    parsed_start = parse_filter_date(start_date, today)
    parsed_end = parse_filter_date(end_date, parsed_start)
    late_after_time = parse_late_after(late_after)

    all_users = get_all_users(db)
    filtered_users = all_users
    if class_name:
        filtered_users = [u for u in filtered_users if u.get("class_name") == class_name.strip()]
    if department:
        filtered_users = [u for u in filtered_users if u.get("department") == department.strip()]

    total_users = len(filtered_users)
    active_user_ids = {u["id"] for u in filtered_users if u.get("is_active")}

    records = collection_ref(db, COLLECTION_ATTENDANCE).stream()
    filtered_records = []
    for r in records:
        data = r.to_dict()
        data["id"] = r.id
        rd = data.get("date", "")
        try:
            rd_date = date.fromisoformat(rd) if isinstance(rd, str) else rd
        except Exception:
            continue
        if parsed_start and rd_date < parsed_start:
            continue
        if parsed_end and rd_date > parsed_end:
            continue
        if data.get("user_id") not in active_user_ids:
            continue

        check_in = data.get("check_in_time")
        if check_in and isinstance(check_in, str):
            try:
                check_in = datetime.fromisoformat(check_in)
            except Exception:
                check_in = None
        is_late_flag = False
        if check_in and check_in.time() > late_after_time:
            is_late_flag = True
        data["_is_late"] = is_late_flag
        data["_check_in"] = check_in
        data["_date_obj"] = rd_date
        filtered_records.append(data)

    present_user_ids = {r["user_id"] for r in filtered_records if r["user_id"] in active_user_ids}
    currently_checked_in = sum(
        1 for r in filtered_records
        if r.get("_date_obj") == today and r.get("check_out_time") is None
    )

    return {
        "total_users": total_users,
        "today_present": len(present_user_ids),
        "today_absent": max(len(active_user_ids) - len(present_user_ids), 0),
        "late_arrivals": sum(1 for r in filtered_records if r["_is_late"]),
        "currently_checked_in": currently_checked_in,
        "total_attendance_records": len(filtered_records),
    }


@app.post("/api/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db=Depends(get_firestore_db)):
    existing = get_user_by_email(db, user.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    try:
        image_bytes = face_engine.base64_to_bytes(user.face_image_base64)
        embedding = face_engine.get_face_embedding(image_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to process image")

    settings = get_settings_singleton(db)
    purge = settings.get("purge_raw_images", False) if settings else False

    encrypted_encoding = security.encrypt_embedding(embedding)

    doc_data = {
        "name": user.name,
        "email": user.email,
        "class_name": user.class_name.strip() if user.class_name else None,
        "department": user.department.strip() if user.department else None,
        "face_encoding": encrypted_encoding,
        "face_image_base64": None if purge else user.face_image_base64,
        "is_active": True,
        "created_at": datetime.utcnow(),
    }
    ref = collection_ref(db, COLLECTION_USERS).add(doc_data)
    doc_data["id"] = ref[1].id
    return doc_data


@app.post("/api/check_in")
def check_attendance(
    attendance_in: schemas.AttendanceCheckIn,
    background_tasks: BackgroundTasks,
    db=Depends(get_firestore_db),
):
    settings = get_settings_singleton(db)
    office_lat = settings.get("office_latitude", OFFICE_LATITUDE) if settings else OFFICE_LATITUDE
    office_lon = settings.get("office_longitude", OFFICE_LONGITUDE) if settings else OFFICE_LONGITUDE
    office_rad = settings.get("office_radius", OFFICE_RADIUS_METERS) if settings else OFFICE_RADIUS_METERS
    strict_geo = settings.get("strict_geofence", False) if settings else (os.getenv("STRICT_GEOFENCE", "false").lower() == "true")

    distance = None
    if attendance_in.latitude is not None and attendance_in.longitude is not None:
        distance = haversine_distance(
            attendance_in.latitude,
            attendance_in.longitude,
            office_lat,
            office_lon,
        )
        if distance > office_rad:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Geo-fence check failed. You are {distance:.1f} meters away from the office. Allowed radius: {office_rad} meters.",
            )
    else:
        if strict_geo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="GPS coordinates are strictly required to mark attendance.",
            )

    try:
        image_bytes = face_engine.base64_to_bytes(attendance_in.face_image_base64)
        uploaded_embedding = face_engine.get_face_embedding(image_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to process face image")

    match_threshold = face_engine.DEFAULT_MATCH_THRESHOLD
    if settings and settings.get("match_threshold"):
        match_threshold = settings["match_threshold"]

    users = get_active_users(db)
    matched_user = None
    best_distance = 2.0
    for u in users:
        ud = u.to_dict()
        try:
            if ud["face_encoding"].startswith("["):
                stored_embedding = json.loads(ud["face_encoding"])
            else:
                stored_embedding = security.decrypt_embedding(ud["face_encoding"])
        except Exception:
            continue

        is_match, match_distance = face_engine.compare_embeddings(
            stored_embedding, uploaded_embedding, threshold=match_threshold,
        )
        if match_distance < best_distance:
            best_distance = match_distance
        if is_match:
            matched_user = ud
            matched_user["id"] = u.id
            break

    if not matched_user:
        raise HTTPException(status_code=404, detail="Face not recognized")

    current_time = datetime.utcnow()
    today_str = current_time.date().isoformat()

    existing_records = list(
        collection_ref(db, COLLECTION_ATTENDANCE)
        .where("user_id", "==", matched_user["id"])
        .where("date", "==", today_str)
        .stream()
    )

    if existing_records:
        er = existing_records[0]
        er_data = er.to_dict()
        if er_data.get("check_out_time") is None:
            doc_ref(db, COLLECTION_ATTENDANCE, er.id).update({"check_out_time": current_time.isoformat()})

            if settings and settings.get("webhook_url"):
                background_tasks.add_task(
                    fire_webhook_in_background,
                    settings["webhook_url"],
                    matched_user["name"],
                    "Checked Out",
                    False,
                    attendance_in.latitude,
                    attendance_in.longitude,
                    distance,
                )

            return {"success": True, "message": f"Check-out recorded for {matched_user['name']}", "user_name": matched_user["name"]}
        else:
            return {"success": True, "message": f"{matched_user['name']} already checked out today", "user_name": matched_user["name"]}
    else:
        new_record = {
            "user_id": matched_user["id"],
            "name": matched_user["name"],
            "check_in_time": current_time.isoformat(),
            "check_out_time": None,
            "date": today_str,
        }
        collection_ref(db, COLLECTION_ATTENDANCE).add(new_record)

        late_threshold_str = settings.get("late_after", "09:15") if settings else "09:15"
        late_threshold = parse_late_after(late_threshold_str)
        is_late_val = current_time.time() > late_threshold

        if settings and settings.get("webhook_url"):
            background_tasks.add_task(
                fire_webhook_in_background,
                settings["webhook_url"],
                matched_user["name"],
                "Checked In",
                is_late_val,
                attendance_in.latitude,
                attendance_in.longitude,
                distance,
            )

        return {"success": True, "message": f"Check-in recorded for {matched_user['name']}", "user_name": matched_user["name"]}


@app.post("/api/check_in_qr")
def check_in_qr(
    qr_in: schemas.QRCheckIn,
    background_tasks: BackgroundTasks,
    db=Depends(get_firestore_db),
):
    settings = get_settings_singleton(db)
    office_lat = settings.get("office_latitude", OFFICE_LATITUDE) if settings else OFFICE_LATITUDE
    office_lon = settings.get("office_longitude", OFFICE_LONGITUDE) if settings else OFFICE_LONGITUDE
    office_rad = settings.get("office_radius", OFFICE_RADIUS_METERS) if settings else OFFICE_RADIUS_METERS
    strict_geo = settings.get("strict_geofence", False) if settings else (os.getenv("STRICT_GEOFENCE", "false").lower() == "true")

    distance = None
    if qr_in.latitude is not None and qr_in.longitude is not None:
        distance = haversine_distance(
            qr_in.latitude, qr_in.longitude, office_lat, office_lon,
        )
        if distance > office_rad:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Geo-fence check failed. You are {distance:.1f} meters away from the office. Allowed radius: {office_rad} meters.",
            )
    else:
        if strict_geo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="GPS coordinates are strictly required to mark attendance.",
            )

    users = collection_ref(db, COLLECTION_USERS).where("email", "==", qr_in.user_id).where("is_active", "==", True).limit(1).get()
    user = None
    for u in users:
        user = u.to_dict()
        user["id"] = u.id
        break
    if not user:
        raise HTTPException(status_code=404, detail="User not found or inactive")

    current_time = datetime.utcnow()
    today_str = current_time.date().isoformat()

    existing_records = list(
        collection_ref(db, COLLECTION_ATTENDANCE)
        .where("user_id", "==", user["id"])
        .where("date", "==", today_str)
        .stream()
    )

    if existing_records:
        er = existing_records[0]
        er_data = er.to_dict()
        if er_data.get("check_out_time") is None:
            doc_ref(db, COLLECTION_ATTENDANCE, er.id).update({"check_out_time": current_time.isoformat()})
            if settings and settings.get("webhook_url"):
                background_tasks.add_task(
                    fire_webhook_in_background,
                    settings["webhook_url"],
                    user["name"],
                    "Checked Out",
                    False,
                    qr_in.latitude,
                    qr_in.longitude,
                    distance,
                )
            return {"success": True, "message": f"Check-out recorded for {user['name']} via QR", "user_name": user["name"]}
        else:
            return {"success": True, "message": f"{user['name']} already checked out today via QR", "user_name": user["name"]}
    else:
        collection_ref(db, COLLECTION_ATTENDANCE).add({
            "user_id": user["id"],
            "name": user["name"],
            "check_in_time": current_time.isoformat(),
            "check_out_time": None,
            "date": today_str,
        })
        late_threshold_str = settings.get("late_after", "09:15") if settings else "09:15"
        late_threshold = parse_late_after(late_threshold_str)
        is_late_val = current_time.time() > late_threshold
        if settings and settings.get("webhook_url"):
            background_tasks.add_task(
                fire_webhook_in_background,
                settings["webhook_url"],
                user["name"],
                "Checked In",
                is_late_val,
                qr_in.latitude,
                qr_in.longitude,
                distance,
            )
        return {"success": True, "message": f"Check-in recorded for {user['name']} via QR", "user_name": user["name"]}


def _query_attendance(
    db,
    parsed_start,
    parsed_end,
    class_name,
    department,
    status_filter,
    late_after_time,
):
    all_users = get_all_users(db)
    user_map = {}
    for u in all_users:
        user_map[u["id"]] = u

    records = list(collection_ref(db, COLLECTION_ATTENDANCE).stream())
    result = []
    for r in records:
        data = r.to_dict()
        data["id"] = r.id
        rd = data.get("date", "")
        try:
            rd_date = date.fromisoformat(rd) if isinstance(rd, str) else rd
        except Exception:
            continue
        if parsed_start and rd_date < parsed_start:
            continue
        if parsed_end and rd_date > parsed_end:
            continue

        u = user_map.get(data.get("user_id"))
        if class_name and (not u or u.get("class_name") != class_name.strip()):
            continue
        if department and (not u or u.get("department") != department.strip()):
            continue

        check_in = data.get("check_in_time")
        if check_in and isinstance(check_in, str):
            try:
                check_in_dt = datetime.fromisoformat(check_in)
            except Exception:
                check_in_dt = None
        else:
            check_in_dt = check_in

        check_out = data.get("check_out_time")

        is_late_flag = False
        if check_in_dt and check_in_dt.time() > late_after_time:
            is_late_flag = True

        status = "Present" if data.get("check_out_time") is None else "Checked Out"

        if status_filter:
            normalized = status_filter.strip().lower()
            if normalized == "late":
                if not is_late_flag:
                    continue
            elif status.lower() != normalized:
                continue

        result.append({
            "id": data["id"],
            "user_id": data.get("user_id"),
            "name": data.get("name", ""),
            "class_name": u.get("class_name") if u else None,
            "department": u.get("department") if u else None,
            "check_in_time": check_in,
            "check_out_time": check_out,
            "date": rd,
            "status": status,
            "is_late": is_late_flag,
        })

    result.sort(key=lambda x: (x.get("date", ""), x.get("check_in_time", "")), reverse=True)
    return result


@app.get("/api/attendance", response_model=List[schemas.AttendanceResponse])
def get_attendance(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    return _query_attendance(
        db,
        parse_filter_date(start_date),
        parse_filter_date(end_date),
        class_name,
        department,
        status_filter,
        parse_late_after(late_after),
    )


@app.get("/api/reports/attendance.csv")
def export_attendance_csv(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    rows = _query_attendance(
        db,
        parse_filter_date(start_date),
        parse_filter_date(end_date),
        class_name,
        department,
        status_filter,
        parse_late_after(late_after),
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Date", "Name", "Class", "Department", "Check In", "Check Out", "Status", "Late"])
    for row in rows:
        writer.writerow([
            csv_value(row["date"]),
            csv_value(row["name"]),
            csv_value(row["class_name"]),
            csv_value(row["department"]),
            csv_value(row["check_in_time"]),
            csv_value(row["check_out_time"]),
            csv_value(row["status"]),
            "Yes" if row["is_late"] else "No",
        ])
    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=attendance_report.csv"},
    )


@app.get("/api/reports/attendance.pdf")
def export_attendance_pdf(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    rows = _query_attendance(
        db,
        parse_filter_date(start_date),
        parse_filter_date(end_date),
        class_name,
        department,
        status_filter,
        parse_late_after(late_after),
    )
    lines = ["Date        Name                 Class       Department       In              Out             Status       Late"]
    for row in rows:
        lines.append(
            f"{csv_value(row['date']):<11} "
            f"{csv_value(row['name'])[:20]:<20} "
            f"{csv_value(row['class_name'])[:10]:<10} "
            f"{csv_value(row['department'])[:16]:<16} "
            f"{csv_value(row['check_in_time'])[11:19] if row['check_in_time'] else '':<8} "
            f"{csv_value(row['check_out_time'])[11:19] if row['check_out_time'] else '':<8} "
            f"{csv_value(row['status'])[:12]:<12} "
            f"{'Yes' if row['is_late'] else 'No'}"
        )
    if len(rows) > 42:
        lines.append(f"... {len(rows) - 42} more records in CSV export")
    return Response(
        content=build_simple_pdf("Attendance Report", lines),
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=attendance_report.pdf"},
    )


@app.get("/api/users", response_model=List[schemas.UserResponse])
def get_users(
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    users = list(collection_ref(db, COLLECTION_USERS).stream())
    result = []
    for u in users:
        data = u.to_dict()
        data["id"] = u.id
        result.append(data)
    return result


@app.patch("/api/users/{user_id}", response_model=schemas.UserResponse)
def update_user(
    user_id: str,
    user_update: schemas.UserUpdate,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = doc_ref(db, COLLECTION_USERS, user_id)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(status_code=404, detail="User not found")
    user_data = snap.to_dict()

    update_fields = {}
    if user_update.email is not None:
        email = user_update.email.strip()
        if not email:
            raise HTTPException(status_code=400, detail="Email is required")
        existing = get_user_by_email(db, email)
        if existing and existing["id"] != user_id:
            raise HTTPException(status_code=400, detail="Email already registered")
        update_fields["email"] = email

    if user_update.name is not None:
        name = user_update.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Name is required")
        update_fields["name"] = name
        attendance_records = collection_ref(db, COLLECTION_ATTENDANCE).where("user_id", "==", user_id).stream()
        for ar in attendance_records:
            doc_ref(db, COLLECTION_ATTENDANCE, ar.id).update({"name": name})

    if user_update.class_name is not None:
        update_fields["class_name"] = user_update.class_name.strip() or None

    if user_update.department is not None:
        update_fields["department"] = user_update.department.strip() or None

    if user_update.is_active is not None:
        update_fields["is_active"] = user_update.is_active

    if update_fields:
        ref.update(update_fields)

    updated = ref.get()
    data = updated.to_dict()
    data["id"] = updated.id
    return data


@app.delete("/api/users/{user_id}")
def delete_user(
    user_id: str,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = doc_ref(db, COLLECTION_USERS, user_id)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(status_code=404, detail="User not found")

    attendance_records = collection_ref(db, COLLECTION_ATTENDANCE).where("user_id", "==", user_id).stream()
    for ar in attendance_records:
        doc_ref(db, COLLECTION_ATTENDANCE, ar.id).delete()
    ref.delete()
    return {"success": True, "message": "User deleted"}


@app.get("/api/admin/settings", response_model=schemas.SettingSchema)
def get_settings(
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    settings = get_settings_singleton(db)
    if not settings:
        raise HTTPException(status_code=404, detail="Settings not found")
    return settings


@app.put("/api/admin/settings", response_model=schemas.SettingSchema)
def update_settings(
    settings_update: schemas.SettingUpdate,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = doc_ref(db, COLLECTION_SETTINGS, SETTINGS_DOC_ID)
    snap = ref.get()
    if not snap.exists:
        raise HTTPException(status_code=404, detail="Settings not found")

    update_fields = {}
    if settings_update.office_latitude is not None:
        update_fields["office_latitude"] = settings_update.office_latitude
    if settings_update.office_longitude is not None:
        update_fields["office_longitude"] = settings_update.office_longitude
    if settings_update.office_radius is not None:
        update_fields["office_radius"] = settings_update.office_radius
    if settings_update.late_after is not None:
        update_fields["late_after"] = settings_update.late_after.strip()
    if settings_update.webhook_url is not None:
        update_fields["webhook_url"] = settings_update.webhook_url.strip()
    if settings_update.purge_raw_images is not None:
        update_fields["purge_raw_images"] = settings_update.purge_raw_images
    if settings_update.strict_geofence is not None:
        update_fields["strict_geofence"] = settings_update.strict_geofence

    if update_fields:
        ref.update(update_fields)

    updated = ref.get()
    return doc_to_dict(updated)


@app.get("/api/dashboard", response_model=schemas.UserDashboardResponse)
def get_user_dashboard(email: str = Query(...), db=Depends(get_firestore_db)):
    user = get_user_by_email(db, email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    records = list(
        collection_ref(db, COLLECTION_ATTENDANCE)
        .where("user_id", "==", user["id"])
        .stream()
    )

    settings = get_settings_singleton(db)
    late_threshold_str = settings.get("late_after", "09:15") if settings else "09:15"
    late_threshold = parse_late_after(late_threshold_str)

    total_present = len(records)
    total_late = 0
    daily_records = []
    for r in records:
        data = r.to_dict()
        check_in = data.get("check_in_time")
        if check_in and isinstance(check_in, str):
            try:
                check_in_dt = datetime.fromisoformat(check_in)
            except Exception:
                check_in_dt = None
        else:
            check_in_dt = check_in

        is_late_flag = False
        if check_in_dt and check_in_dt.time() > late_threshold:
            is_late_flag = True
            total_late += 1

        check_out = data.get("check_out_time")
        daily_records.append({
            "date": data.get("date"),
            "check_in_time": check_in,
            "check_out_time": check_out,
            "status": "Checked Out" if check_out else "Present",
            "is_late": is_late_flag,
        })

    daily_records.sort(key=lambda x: x["date"] or "", reverse=True)

    created_at = user.get("created_at")
    if isinstance(created_at, str):
        try:
            created_at = datetime.fromisoformat(created_at)
        except Exception:
            created_at = datetime.utcnow()

    start_date = created_at.date() if hasattr(created_at, 'date') else datetime.utcnow().date()
    today = datetime.utcnow().date()
    if start_date > today:
        start_date = today

    total_weekdays = 0
    curr = start_date
    while curr <= today:
        if curr.weekday() < 5:
            total_weekdays += 1
        curr += timedelta(days=1)

    if total_weekdays == 0:
        total_weekdays = 1

    attendance_percentage = round((total_present / total_weekdays) * 100, 2)
    if attendance_percentage > 100:
        attendance_percentage = 100.0

    absent_days = max(total_weekdays - total_present, 0)

    monthly_analytics = {}
    for r in records:
        data = r.to_dict()
        rd = data.get("date", "")
        try:
            rd_date = date.fromisoformat(rd) if isinstance(rd, str) else rd
        except Exception:
            continue
        month_name = rd_date.strftime("%B %Y")
        if month_name not in monthly_analytics:
            monthly_analytics[month_name] = {"present": 0, "late": 0}
        monthly_analytics[month_name]["present"] += 1

        check_in = data.get("check_in_time")
        if check_in and isinstance(check_in, str):
            try:
                check_in_dt = datetime.fromisoformat(check_in)
            except Exception:
                check_in_dt = None
        else:
            check_in_dt = check_in
        if check_in_dt and check_in_dt.time() > late_threshold:
            monthly_analytics[month_name]["late"] += 1

    return {
        "user": {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"],
            "class_name": user.get("class_name"),
            "department": user.get("department"),
            "face_image_base64": user.get("face_image_base64"),
            "is_active": user.get("is_active", True),
            "created_at": user.get("created_at"),
        },
        "stats": {
            "total_working_days": total_weekdays,
            "present_days": total_present,
            "late_days": total_late,
            "absent_days": absent_days,
            "attendance_percentage": attendance_percentage,
            "late_threshold": late_threshold_str,
        },
        "daily_records": daily_records,
        "monthly_analytics": [
            {"month": month, "present": data["present"], "late": data["late"], "absent": max(0, 22 - data["present"])}
            for month, data in monthly_analytics.items()
        ],
    }


@app.get("/api/classes", response_model=List[schemas.ClassResponse])
def get_classes(db=Depends(get_firestore_db)):
    docs = list(collection_ref(db, COLLECTION_CLASSES).stream())
    return [{"id": d.id, "name": d.to_dict().get("name", "")} for d in docs]


@app.post("/api/classes", response_model=schemas.ClassResponse)
def create_class(
    cls_in: schemas.ClassCreate,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = collection_ref(db, COLLECTION_CLASSES).add({"name": cls_in.name.strip()})
    return {"id": ref[1].id, "name": cls_in.name.strip()}


@app.delete("/api/classes/{class_id}")
def delete_class(
    class_id: str,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = doc_ref(db, COLLECTION_CLASSES, class_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Class not found")
    ref.delete()
    return {"success": True}


@app.get("/api/departments", response_model=List[schemas.DepartmentResponse])
def get_departments(db=Depends(get_firestore_db)):
    docs = list(collection_ref(db, COLLECTION_DEPARTMENTS).stream())
    return [{"id": d.id, "name": d.to_dict().get("name", "")} for d in docs]


@app.post("/api/departments", response_model=schemas.DepartmentResponse)
def create_department(
    dept_in: schemas.DepartmentCreate,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = collection_ref(db, COLLECTION_DEPARTMENTS).add({"name": dept_in.name.strip()})
    return {"id": ref[1].id, "name": dept_in.name.strip()}


@app.delete("/api/departments/{dept_id}")
def delete_department(
    dept_id: str,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    ref = doc_ref(db, COLLECTION_DEPARTMENTS, dept_id)
    if not ref.get().exists:
        raise HTTPException(status_code=404, detail="Department not found")
    ref.delete()
    return {"success": True}


@app.get("/api/devices", response_model=List[schemas.DeviceResponse])
def get_devices(
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    docs = list(collection_ref(db, COLLECTION_DEVICES).stream())
    result = []
    for d in docs:
        data = d.to_dict()
        data["id"] = d.id
        result.append(data)
    return result


@app.post("/api/devices/{device_id}/action")
def perform_device_action(
    device_id: str,
    action_in: schemas.DeviceAction,
    admin: dict = Depends(get_current_admin),
    db=Depends(get_firestore_db),
):
    docs = list(collection_ref(db, COLLECTION_DEVICES).where("device_id", "==", device_id).limit(1).stream())
    if not docs:
        raise HTTPException(status_code=404, detail="Device not found")
    return {"success": True, "message": f"Action {action_in.action} sent to device"}


@app.get("/api/admin/alerts", response_model=List[schemas.AlertResponse])
def get_alerts(db=Depends(get_firestore_db)):
    docs = list(collection_ref(db, COLLECTION_ALERTS).order_by("timestamp", direction="DESCENDING").limit(50).stream())
    result = []
    for d in docs:
        data = d.to_dict()
        data["id"] = d.id
        result.append(data)
    return result


@app.post("/api/admin/alerts/{alert_id}/read")
def mark_alert_read(alert_id: str, db=Depends(get_firestore_db)):
    ref = doc_ref(db, COLLECTION_ALERTS, alert_id)
    if ref.get().exists:
        ref.update({"is_read": True})
    return {"success": True}


import cv2
import numpy as np
import threading
import time
import logging
import traceback

logger = logging.getLogger("uvicorn.error")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

latest_frame = None
camera_lock = threading.Lock()
_known_encodings_cache: list[dict] | None = None
_known_encodings_cache_lock = threading.Lock()
_known_encodings_cache_time = 0.0

def _refresh_known_encodings_cache(force: bool = False):
    global _known_encodings_cache, _known_encodings_cache_time
    now = time.time()
    if not force and _known_encodings_cache is not None and (now - _known_encodings_cache_time) < 15.0:
        return
    try:
        db = db_module.get_firestore()
        users = list(collection_ref(db, COLLECTION_USERS).where("is_active", "==", True).stream())
        cache = []
        for u in users:
            ud = u.to_dict()
            try:
                if ud["face_encoding"].startswith("["):
                    emb = json.loads(ud["face_encoding"])
                else:
                    emb = security.decrypt_embedding(ud["face_encoding"])
                cache.append({"user_id": u.id, "name": ud["name"], "embedding": emb})
            except Exception as e:
                logger.warning(f"Failed to decode face for user {u.id}: {e}")
        with _known_encodings_cache_lock:
            _known_encodings_cache = cache
            _known_encodings_cache_time = now
    except Exception as e:
        logger.error(f"Failed to refresh encoding cache: {e}")

def _load_known_encodings() -> list[dict]:
    _refresh_known_encodings_cache()
    with _known_encodings_cache_lock:
        return list(_known_encodings_cache) if _known_encodings_cache else []

def _recognize_face_in_frame(frame: np.ndarray, known_users: list[dict]) -> str | None:
    if not known_users:
        return None
    try:
        ret, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
        if not ret:
            return None
        image_bytes = buffer.tobytes()
        uploaded_emb = face_engine.get_face_embedding(image_bytes)
        for known in known_users:
            is_match, dist = face_engine.compare_embeddings(known["embedding"], uploaded_emb)
            if is_match:
                return known["name"]
    except Exception:
        pass
    return None

def camera_thread_func():
    global latest_frame
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        logger.error("Cannot open camera (index 0). Live camera feed unavailable.")
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 15)

    frame_count = 0
    known_users: list[dict] = []

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.1)
                continue

            if frame_count % 15 == 0:
                known_users = _load_known_encodings()

            if frame_count % 5 == 0:
                try:
                    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
                    faces = face_cascade.detectMultiScale(gray, 1.1, 4, minSize=(80, 80))

                    if len(faces) > 0:
                        for (x, y, w, h) in faces:
                            face_roi = frame[y:y+h, x:x+w]
                            if face_roi.size == 0:
                                continue

                            recognized_name = None
                            if known_users and face_roi.shape[0] >= 80 and face_roi.shape[1] >= 80:
                                try:
                                    ret2, buf2 = cv2.imencode('.jpg', face_roi, [int(cv2.IMWRITE_JPEG_QUALITY), 85])
                                    if ret2:
                                        emb = face_engine.get_face_embedding(buf2.tobytes())
                                        for known in known_users:
                                            is_match, _ = face_engine.compare_embeddings(known["embedding"], emb)
                                            if is_match:
                                                recognized_name = known["name"]
                                                break
                                except Exception:
                                    pass

                            if recognized_name:
                                color = (0, 255, 0)
                                label = recognized_name
                            else:
                                color = (0, 0, 255)
                                label = "Unknown"

                            cv2.rectangle(frame, (x, y), (x+w, y+h), color, 2)
                            cv2.putText(frame, label, (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, color, 2)

                        if len(faces) > 0 and not recognized_name and frame_count % 30 == 0:
                            try:
                                db = db_module.get_firestore()
                                last_alerts = list(
                                    collection_ref(db, COLLECTION_ALERTS)
                                    .order_by("timestamp", direction="DESCENDING")
                                    .limit(1)
                                    .stream()
                                )
                                create_alert = True
                                if last_alerts:
                                    la = last_alerts[0].to_dict()
                                    last_time = la.get("timestamp")
                                    if last_time and isinstance(last_time, str):
                                        try:
                                            last_dt = datetime.fromisoformat(last_time)
                                            if (datetime.utcnow() - last_dt).total_seconds() <= 30:
                                                create_alert = False
                                        except Exception:
                                            pass
                                if create_alert:
                                    collection_ref(db, COLLECTION_ALERTS).add({
                                        "type": "unknown_person",
                                        "message": "Unknown person detected in Live Camera.",
                                        "timestamp": datetime.utcnow().isoformat(),
                                        "is_read": False,
                                    })
                            except Exception as alert_err:
                                logger.error(f"Failed to create alert: {alert_err}")
                except Exception as frame_err:
                    logger.error(f"Camera frame processing error: {frame_err}")

            frame_count += 1

            ret, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
            if ret:
                with camera_lock:
                    latest_frame = buffer.tobytes()

            time.sleep(0.03)
    except Exception as e:
        logger.error(f"Camera thread crashed: {e}\n{traceback.format_exc()}")
    finally:
        cap.release()
        logger.info("Camera thread terminated")

threading.Thread(target=camera_thread_func, daemon=True, name="camera-thread").start()

def generate_frames():
    while True:
        with camera_lock:
            frame = latest_frame
        if frame is None:
            time.sleep(0.1)
            continue
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')
        time.sleep(0.05)

@app.get("/api/admin/live_camera")
def get_live_camera():
    return StreamingResponse(generate_frames(), media_type="multipart/x-mixed-replace; boundary=frame")
