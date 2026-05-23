from fastapi import FastAPI, Depends, Header, HTTPException, Query, Response, status, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import desc
from typing import List
from datetime import datetime, date, time
import csv
import hashlib
import io
import json
import math
import os
import secrets

import firebase_admin
from firebase_admin import credentials

try:
    # Initialize Firebase Admin with default credentials or a service account
    firebase_app = firebase_admin.initialize_app()
    print("Firebase Admin SDK initialized.")
except ValueError:
    # App already initialized
    pass
except Exception as e:
    print(f"Firebase Admin SDK initialization skipped/failed: {e}")

from backend import models, schemas, database, face_engine, security
from backend.database import engine

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="Face Recognition Attendance API")

# Enable CORS for Flutter App
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency
get_db = database.get_db

def ensure_user_columns():
    with engine.begin() as connection:
        existing_columns = {
            row[1] for row in connection.exec_driver_sql("PRAGMA table_info(users)")
        }
        if "face_image_base64" not in existing_columns:
            connection.exec_driver_sql(
                "ALTER TABLE users ADD COLUMN face_image_base64 TEXT"
            )
        if "class_name" not in existing_columns:
            connection.exec_driver_sql(
                "ALTER TABLE users ADD COLUMN class_name VARCHAR"
            )
        if "department" not in existing_columns:
            connection.exec_driver_sql(
                "ALTER TABLE users ADD COLUMN department VARCHAR"
            )
        if "is_active" not in existing_columns:
            connection.exec_driver_sql(
                "ALTER TABLE users ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT 1"
            )

ensure_user_columns()

def ensure_settings_table():
    db = database.SessionLocal()
    try:
        models.Base.metadata.create_all(bind=engine)
        setting = db.query(models.Setting).filter(models.Setting.id == 1).first()
        if setting is None:
            db.add(models.Setting(
                id=1,
                office_latitude=22.5726,
                office_longitude=88.3639,
                office_radius=100.0,
                late_after="09:15",
                webhook_url="",
                purge_raw_images=False,
                strict_geofence=False,
            ))
            db.commit()
    except Exception as e:
        print(f"Error seeding settings table: {e}")
    finally:
        db.close()

ensure_settings_table()

def seed_classes_departments_devices():
    db = database.SessionLocal()
    try:
        # Seed Classes
        default_classes = ["CS-A", "CS-B", "ECE-1", "MECH-2", "MBA-Finance"]
        for c_name in default_classes:
            existing = db.query(models.ClassModel).filter(models.ClassModel.name == c_name).first()
            if not existing:
                db.add(models.ClassModel(name=c_name))
        
        # Seed Departments
        default_departments = ["Engineering", "Human Resources", "Finance", "Operations", "Administration"]
        for d_name in default_departments:
            existing = db.query(models.Department).filter(models.Department.name == d_name).first()
            if not existing:
                db.add(models.Department(name=d_name))

        # Seed Devices
        default_devices = [
            {
                "device_id": "kiosk_main_lobby",
                "name": "Main Lobby Entrance Kiosk",
                "status": "Online",
                "battery_level": 95,
                "temperature": 38.2,
            },
            {
                "device_id": "tablet_south_gate",
                "name": "South Gate Tablet",
                "status": "Offline",
                "battery_level": 12,
                "temperature": 31.4,
            }
        ]
        for dev in default_devices:
            existing = db.query(models.Device).filter(models.Device.device_id == dev["device_id"]).first()
            if not existing:
                db.add(models.Device(
                    device_id=dev["device_id"],
                    name=dev["name"],
                    status=dev["status"],
                    battery_level=dev["battery_level"],
                    temperature=dev["temperature"],
                    last_active=datetime.utcnow()
                ))
        db.commit()
    except Exception as e:
        print(f"Error seeding workspace parameters: {e}")
    finally:
        db.close()

seed_classes_departments_devices()



def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode("utf-8")).hexdigest()

def seed_admin_account():
    db = database.SessionLocal()
    try:
        admin_email = os.getenv("ADMIN_EMAIL", "admin@gurukul.local")
        admin_password = os.getenv("ADMIN_PASSWORD", "admin123")
        existing_admin = db.query(models.Admin).filter(
            models.Admin.email == admin_email
        ).first()
        if existing_admin is None:
            db.add(models.Admin(
                email=admin_email,
                password_hash=hash_password(admin_password),
            ))
            db.commit()
    finally:
        db.close()

seed_admin_account()

def get_current_admin(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Admin login required",
        )
    token = authorization.removeprefix("Bearer ").strip()
    admin = db.query(models.Admin).filter(models.Admin.token == token).first()
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired admin session",
        )
    return admin


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


# Geo-fencing Configurations
OFFICE_LATITUDE = float(os.getenv("OFFICE_LATITUDE", "22.5726"))
OFFICE_LONGITUDE = float(os.getenv("OFFICE_LONGITUDE", "88.3639"))
OFFICE_RADIUS_METERS = float(os.getenv("OFFICE_RADIUS_METERS", "100.0"))


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great circle distance in meters between two points 
    on the earth (specified in decimal degrees)
    """
    R = 6371000.0  # radius of Earth in meters
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

def attendance_query(
    db: Session,
    start_date: date | None = None,
    end_date: date | None = None,
    class_name: str | None = None,
    department: str | None = None,
):
    query = db.query(models.Attendance, models.User).outerjoin(
        models.User, models.Attendance.user_id == models.User.id
    )
    if start_date is not None:
        query = query.filter(models.Attendance.date >= start_date)
    if end_date is not None:
        query = query.filter(models.Attendance.date <= end_date)
    if class_name:
        query = query.filter(models.User.class_name == class_name.strip())
    if department:
        query = query.filter(models.User.department == department.strip())
    return query

def attendance_status(record: models.Attendance) -> str:
    if record.check_out_time is None:
        return "Present"
    return "Checked Out"

def is_late(record: models.Attendance, late_after: time) -> bool:
    return record.check_in_time is not None and record.check_in_time.time() > late_after

def attendance_payload(record: models.Attendance, user: models.User | None, late_after: time):
    return {
        "id": record.id,
        "user_id": record.user_id,
        "name": record.name,
        "class_name": user.class_name if user else None,
        "department": user.department if user else None,
        "check_in_time": record.check_in_time,
        "check_out_time": record.check_out_time,
        "date": record.date,
        "status": attendance_status(record),
        "is_late": is_late(record, late_after),
    }

def filtered_attendance_rows(
    db: Session,
    start_date: date | None,
    end_date: date | None,
    class_name: str | None,
    department: str | None,
    status_filter: str | None,
    late_after: time,
):
    rows = attendance_query(
        db,
        start_date=start_date,
        end_date=end_date,
        class_name=class_name,
        department=department,
    ).order_by(desc(models.Attendance.date), desc(models.Attendance.check_in_time)).all()

    payloads = [
        attendance_payload(record, user, late_after)
        for record, user in rows
    ]
    if status_filter:
        normalized = status_filter.strip().lower()
        if normalized == "late":
            payloads = [row for row in payloads if row["is_late"]]
        else:
            payloads = [
                row for row in payloads
                if (row["status"] or "").lower() == normalized
            ]
    return payloads

def user_query(
    db: Session,
    class_name: str | None = None,
    department: str | None = None,
):
    query = db.query(models.User)
    if class_name:
        query = query.filter(models.User.class_name == class_name.strip())
    if department:
        query = query.filter(models.User.department == department.strip())
    return query

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

@app.post("/api/admin/login", response_model=schemas.AdminLoginResponse)
def admin_login(credentials: schemas.AdminLogin, db: Session = Depends(get_db)):
    admin = db.query(models.Admin).filter(
        models.Admin.email == credentials.email
    ).first()
    if admin is None or admin.password_hash != hash_password(credentials.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin email or password",
        )
    admin.token = secrets.token_urlsafe(32)
    db.commit()
    return {"token": admin.token, "email": admin.email}

@app.post("/api/admin/logout")
def admin_logout(
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    admin.token = None
    db.commit()
    return {"success": True}

@app.get("/api/admin/stats", response_model=schemas.AdminStatsResponse)
def get_admin_stats(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    today = datetime.utcnow().date()
    parsed_start = parse_filter_date(start_date, today)
    parsed_end = parse_filter_date(end_date, parsed_start)
    late_after_time = parse_late_after(late_after)
    users = user_query(db, class_name=class_name, department=department).all()
    total_users = len(users)
    active_user_ids = {user.id for user in users if user.is_active}
    records = filtered_attendance_rows(
        db,
        start_date=parsed_start,
        end_date=parsed_end,
        class_name=class_name,
        department=department,
        status_filter=None,
        late_after=late_after_time,
    )
    present_user_ids = {row["user_id"] for row in records if row["user_id"] in active_user_ids}
    currently_checked_in = sum(
        1 for row in records
        if row["date"] == today and row["check_out_time"] is None
    )
    return {
        "total_users": total_users,
        "today_present": len(present_user_ids),
        "today_absent": max(len(active_user_ids) - len(present_user_ids), 0),
        "late_arrivals": sum(1 for row in records if row["is_late"]),
        "currently_checked_in": currently_checked_in,
        "total_attendance_records": len(records),
    }

@app.post("/api/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    # Check if user exists
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    try:
        # Extract face embedding
        image_bytes = face_engine.base64_to_bytes(user.face_image_base64)
        embedding = face_engine.get_face_embedding(image_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail="Failed to process image")

    # Fetch global settings to check GDPR purging options
    settings = db.query(models.Setting).filter(models.Setting.id == 1).first()
    purge = settings.purge_raw_images if settings else False

    # Encrypt biometric embedding at rest
    encrypted_encoding = security.encrypt_embedding(embedding)

    # Save user
    new_user = models.User(
        name=user.name,
        email=user.email,
        class_name=user.class_name.strip() if user.class_name else None,
        department=user.department.strip() if user.department else None,
        face_encoding=encrypted_encoding,
        face_image_base64=None if purge else user.face_image_base64,
        is_active=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return new_user


@app.post("/api/check_in")
def check_attendance(
    attendance_in: schemas.AttendanceCheckIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    # Retrieve settings dynamically
    settings = db.query(models.Setting).filter(models.Setting.id == 1).first()
    office_lat = settings.office_latitude if settings else OFFICE_LATITUDE
    office_lon = settings.office_longitude if settings else OFFICE_LONGITUDE
    office_rad = settings.office_radius if settings else OFFICE_RADIUS_METERS
    strict_geo = settings.strict_geofence if settings else (os.getenv("STRICT_GEOFENCE", "false").lower() == "true")

    # Geo-fencing Validation
    distance = None
    if attendance_in.latitude is not None and attendance_in.longitude is not None:
        distance = haversine_distance(
            attendance_in.latitude,
            attendance_in.longitude,
            office_lat,
            office_lon
        )
        if distance > office_rad:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Geo-fence check failed. You are {distance:.1f} meters away from the office. Allowed radius: {office_rad} meters."
            )
    else:
        # Check strict geo-fencing
        if strict_geo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="GPS coordinates are strictly required to mark attendance."
            )

    try:
        image_bytes = face_engine.base64_to_bytes(attendance_in.face_image_base64)
        
        # 1. Perform Passive Software-Based Anti-Spoofing Check
        is_live, liveness_msg = face_engine.check_anti_spoofing(image_bytes)
        if not is_live:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=liveness_msg
            )
            
        uploaded_embedding = face_engine.get_face_embedding(image_bytes)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
     
    users = db.query(models.User).filter(models.User.is_active.is_(True)).all()
     
    matched_user = None
    for user in users:
        try:
            # Check for backward compatibility with plain-text JSON vectors
            if user.face_encoding.startswith("["):
                stored_embedding = json.loads(user.face_encoding)
            else:
                stored_embedding = security.decrypt_embedding(user.face_encoding)
        except Exception as e:
            print(f"Error decrypting embedding for user {user.id}: {e}")
            continue
             
        if face_engine.compare_embeddings(stored_embedding, uploaded_embedding):
            matched_user = user
            break
             
    if not matched_user:
        raise HTTPException(status_code=404, detail="Face not recognized")
         
    current_time = datetime.utcnow()
    today = current_time.date()
     
    # Check for existing attendance today
    existing_record = db.query(models.Attendance).filter(
        models.Attendance.user_id == matched_user.id,
        models.Attendance.date == today
    ).first()
     
    if existing_record:
        if existing_record.check_out_time is None:
            existing_record.check_out_time = current_time
            db.commit()
             
            # Fire Discord/Slack notification in background
            if settings and settings.webhook_url:
                background_tasks.add_task(
                    fire_webhook_in_background,
                    settings.webhook_url,
                    matched_user.name,
                    "Checked Out",
                    False,
                    attendance_in.latitude,
                    attendance_in.longitude,
                    distance
                )
                 
            return {"success": True, "message": f"Check-out recorded for {matched_user.name}", "user_name": matched_user.name}
        else:
            return {"success": True, "message": f"{matched_user.name} already checked out today", "user_name": matched_user.name}
    else:
        new_record = models.Attendance(
            user_id=matched_user.id,
            name=matched_user.name,
            check_in_time=current_time,
            date=today
        )
        db.add(new_record)
        db.commit()
         
        # Check late status dynamically
        late_threshold_str = settings.late_after if settings else "09:15"
        late_threshold = parse_late_after(late_threshold_str)
        is_late_val = current_time.time() > late_threshold
         
        # Fire Discord/Slack notification in background
        if settings and settings.webhook_url:
            background_tasks.add_task(
                fire_webhook_in_background,
                settings.webhook_url,
                matched_user.name,
                "Checked In",
                is_late_val,
                attendance_in.latitude,
                attendance_in.longitude,
                distance
            )
             
        return {"success": True, "message": f"Check-in recorded for {matched_user.name}", "user_name": matched_user.name}


@app.post("/api/check_in_qr")
def check_in_qr(
    qr_in: schemas.QRCheckIn,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    # Retrieve settings dynamically
    settings = db.query(models.Setting).filter(models.Setting.id == 1).first()
    office_lat = settings.office_latitude if settings else OFFICE_LATITUDE
    office_lon = settings.office_longitude if settings else OFFICE_LONGITUDE
    office_rad = settings.office_radius if settings else OFFICE_RADIUS_METERS
    strict_geo = settings.strict_geofence if settings else (os.getenv("STRICT_GEOFENCE", "false").lower() == "true")

    # Geo-fencing Validation (same as check_in)
    distance = None
    if qr_in.latitude is not None and qr_in.longitude is not None:
        distance = haversine_distance(
            qr_in.latitude,
            qr_in.longitude,
            office_lat,
            office_lon
        )
        if distance > office_rad:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Geo-fence check failed. You are {distance:.1f} meters away from the office. Allowed radius: {office_rad} meters."
            )
    else:
        # Check strict geo-fencing
        if strict_geo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="GPS coordinates are strictly required to mark attendance."
            )

    # Find user by email (assuming QR contains email)
    user = db.query(models.User).filter(models.User.email == qr_in.user_id, models.User.is_active.is_(True)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found or inactive")

    current_time = datetime.utcnow()
    today = current_time.date()

    # Check for existing attendance today
    existing_record = db.query(models.Attendance).filter(
        models.Attendance.user_id == user.id,
        models.Attendance.date == today
    ).first()

    if existing_record:
        if existing_record.check_out_time is None:
            existing_record.check_out_time = current_time
            db.commit()
             
            # Fire Discord/Slack notification in background
            if settings and settings.webhook_url:
                background_tasks.add_task(
                    fire_webhook_in_background,
                    settings.webhook_url,
                    user.name,
                    "Checked Out",
                    False,
                    qr_in.latitude,
                    qr_in.longitude,
                    distance
                )
                 
            return {"success": True, "message": f"Check-out recorded for {user.name} via QR", "user_name": user.name}
        else:
            return {"success": True, "message": f"{user.name} already checked out today via QR", "user_name": user.name}
    else:
        new_record = models.Attendance(
            user_id=user.id,
            name=user.name,
            check_in_time=current_time,
            date=today
        )
        db.add(new_record)
        db.commit()
         
        # Check late status dynamically
        late_threshold_str = settings.late_after if settings else "09:15"
        late_threshold = parse_late_after(late_threshold_str)
        is_late_val = current_time.time() > late_threshold
         
        # Fire Discord/Slack notification in background
        if settings and settings.webhook_url:
            background_tasks.add_task(
                fire_webhook_in_background,
                settings.webhook_url,
                user.name,
                "Checked In",
                is_late_val,
                qr_in.latitude,
                qr_in.longitude,
                distance
            )
             
        return {"success": True, "message": f"Check-in recorded for {user.name} via QR", "user_name": user.name}


@app.get("/api/attendance", response_model=List[schemas.AttendanceResponse])
def get_attendance(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    parsed_start = parse_filter_date(start_date)
    parsed_end = parse_filter_date(end_date)
    return filtered_attendance_rows(
        db,
        start_date=parsed_start,
        end_date=parsed_end,
        class_name=class_name,
        department=department,
        status_filter=status_filter,
        late_after=parse_late_after(late_after),
    )

@app.get("/api/reports/attendance.csv")
def export_attendance_csv(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    rows = filtered_attendance_rows(
        db,
        start_date=parse_filter_date(start_date),
        end_date=parse_filter_date(end_date),
        class_name=class_name,
        department=department,
        status_filter=status_filter,
        late_after=parse_late_after(late_after),
    )
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Date",
        "Name",
        "Class",
        "Department",
        "Check In",
        "Check Out",
        "Status",
        "Late",
    ])
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
        headers={
            "Content-Disposition": "attachment; filename=attendance_report.csv"
        },
    )

@app.get("/api/reports/attendance.pdf")
def export_attendance_pdf(
    start_date: str | None = Query(default=None),
    end_date: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    department: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    late_after: str = Query(default="09:15"),
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    rows = filtered_attendance_rows(
        db,
        start_date=parse_filter_date(start_date),
        end_date=parse_filter_date(end_date),
        class_name=class_name,
        department=department,
        status_filter=status_filter,
        late_after=parse_late_after(late_after),
    )
    lines = [
        "Date        Name                 Class       Department       In              Out             Status       Late"
    ]
    for row in rows:
        lines.append(
            f"{csv_value(row['date']):<11} "
            f"{csv_value(row['name'])[:20]:<20} "
            f"{csv_value(row['class_name'])[:10]:<10} "
            f"{csv_value(row['department'])[:16]:<16} "
            f"{csv_value(row['check_in_time'])[11:19]:<8} "
            f"{csv_value(row['check_out_time'])[11:19]:<8} "
            f"{csv_value(row['status'])[:12]:<12} "
            f"{'Yes' if row['is_late'] else 'No'}"
        )
    if len(rows) > 42:
        lines.append(f"... {len(rows) - 42} more records in CSV export")
    return Response(
        content=build_simple_pdf("Attendance Report", lines),
        media_type="application/pdf",
        headers={
            "Content-Disposition": "attachment; filename=attendance_report.pdf"
        },
    )

@app.get("/api/users", response_model=List[schemas.UserResponse])
def get_users(
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return db.query(models.User).all()

@app.patch("/api/users/{user_id}", response_model=schemas.UserResponse)
def update_user(
    user_id: int,
    user_update: schemas.UserUpdate,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if user_update.email is not None:
        email = user_update.email.strip()
        if not email:
            raise HTTPException(status_code=400, detail="Email is required")
        existing_user = db.query(models.User).filter(
            models.User.email == email,
            models.User.id != user_id,
        ).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already registered")
        user.email = email

    if user_update.name is not None:
        name = user_update.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Name is required")
        user.name = name
        db.query(models.Attendance).filter(
            models.Attendance.user_id == user_id
        ).update({"name": name})

    if user_update.class_name is not None:
        class_name = user_update.class_name.strip()
        user.class_name = class_name or None

    if user_update.department is not None:
        department = user_update.department.strip()
        user.department = department or None

    if user_update.is_active is not None:
        user.is_active = user_update.is_active

    db.commit()
    db.refresh(user)
    return user

@app.delete("/api/users/{user_id}")
def delete_user(
    user_id: int,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    db.query(models.Attendance).filter(
        models.Attendance.user_id == user_id
    ).delete()
    db.delete(user)
    db.commit()
    return {"success": True, "message": "User deleted"}

@app.get("/api/admin/settings", response_model=schemas.SettingSchema)
def get_settings(
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    setting = db.query(models.Setting).filter(models.Setting.id == 1).first()
    if setting is None:
        raise HTTPException(status_code=404, detail="Settings not found")
    return setting

@app.put("/api/admin/settings", response_model=schemas.SettingSchema)
def update_settings(
    settings_update: schemas.SettingUpdate,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    setting = db.query(models.Setting).filter(models.Setting.id == 1).first()
    if setting is None:
        raise HTTPException(status_code=404, detail="Settings not found")
    
    if settings_update.office_latitude is not None:
        setting.office_latitude = settings_update.office_latitude
    if settings_update.office_longitude is not None:
        setting.office_longitude = settings_update.office_longitude
    if settings_update.office_radius is not None:
        setting.office_radius = settings_update.office_radius
    if settings_update.late_after is not None:
        setting.late_after = settings_update.late_after.strip()
    if settings_update.webhook_url is not None:
        setting.webhook_url = settings_update.webhook_url.strip()
    if settings_update.purge_raw_images is not None:
        setting.purge_raw_images = settings_update.purge_raw_images
    if settings_update.strict_geofence is not None:
        setting.strict_geofence = settings_update.strict_geofence
        
    db.commit()
    db.refresh(setting)
    return setting

@app.get("/api/dashboard", response_model=schemas.UserDashboardResponse)
def get_user_dashboard(email: str = Query(...), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    records = db.query(models.Attendance).filter(models.Attendance.user_id == user.id).all()
    
    settings = db.query(models.Setting).filter(models.Setting.id == 1).first()
    late_threshold_str = settings.late_after if settings else "09:15"
    late_threshold = parse_late_after(late_threshold_str)
    
    # Calculate stats
    total_present = len(records)
    total_late = sum(
        1 for r in records
        if r.check_in_time and r.check_in_time.time() > late_threshold
    )
    
    # Calculate weekdays since user registration
    start_date = user.created_at.date()
    today = datetime.utcnow().date()
    if start_date > today:
        start_date = today
        
    from datetime import timedelta
    total_weekdays = 0
    curr = start_date
    while curr <= today:
        if curr.weekday() < 5: # Mon-Fri
            total_weekdays += 1
        curr += timedelta(days=1)
        
    if total_weekdays == 0:
        total_weekdays = 1
        
    attendance_percentage = round((total_present / total_weekdays) * 100, 2)
    if attendance_percentage > 100:
        attendance_percentage = 100.0
        
    absent_days = max(total_weekdays - total_present, 0)
    
    # Group by month for analytics
    monthly_analytics = {}
    for record in records:
        month_name = record.date.strftime("%B %Y")
        if month_name not in monthly_analytics:
            monthly_analytics[month_name] = {"present": 0, "late": 0}
        monthly_analytics[month_name]["present"] += 1
        if record.check_in_time and record.check_in_time.time() > late_threshold:
            monthly_analytics[month_name]["late"] += 1
            
    # Format daily records for response
    daily_records = []
    for r in records:
        daily_records.append({
            "date": r.date,
            "check_in_time": r.check_in_time,
            "check_out_time": r.check_out_time,
            "status": "Checked Out" if r.check_out_time else "Present",
            "is_late": r.check_in_time.time() > late_threshold if r.check_in_time else False
        })
        
    # Sort daily records by date descending
    daily_records.sort(key=lambda x: x["date"], reverse=True)
    
    return {
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "class_name": user.class_name,
            "department": user.department,
            "face_image_base64": user.face_image_base64,
            "is_active": user.is_active,
            "created_at": user.created_at
        },
        "stats": {
            "total_working_days": total_weekdays,
            "present_days": total_present,
            "late_days": total_late,
            "absent_days": absent_days,
            "attendance_percentage": attendance_percentage,
            "late_threshold": late_threshold_str
        },
        "daily_records": daily_records,
        "monthly_analytics": [
            {
                "month": month,
                "present": data["present"],
                "late": data["late"],
                "absent": max(0, 22 - data["present"])
            }
            for month, data in monthly_analytics.items()
        ]
    }

@app.get("/api/classes", response_model=List[schemas.ClassResponse])
def get_classes(db: Session = Depends(get_db)):
    return db.query(models.ClassModel).all()

@app.post("/api/classes", response_model=schemas.ClassResponse)
def create_class(
    cls_in: schemas.ClassCreate,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    cls = models.ClassModel(name=cls_in.name.strip())
    db.add(cls)
    db.commit()
    db.refresh(cls)
    return cls

@app.delete("/api/classes/{class_id}")
def delete_class(
    class_id: int,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    cls = db.query(models.ClassModel).filter(models.ClassModel.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")
    db.delete(cls)
    db.commit()
    return {"success": True}

@app.get("/api/departments", response_model=List[schemas.DepartmentResponse])
def get_departments(db: Session = Depends(get_db)):
    return db.query(models.Department).all()

@app.post("/api/departments", response_model=schemas.DepartmentResponse)
def create_department(
    dept_in: schemas.DepartmentCreate,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    dept = models.Department(name=dept_in.name.strip())
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return dept

@app.delete("/api/departments/{dept_id}")
def delete_department(
    dept_id: int,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    dept = db.query(models.Department).filter(models.Department.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    db.delete(dept)
    db.commit()
    return {"success": True}

@app.get("/api/devices", response_model=List[schemas.DeviceResponse])
def get_devices(
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    return db.query(models.Device).all()

@app.post("/api/devices/{device_id}/action")
def perform_device_action(
    device_id: str,
    action_in: schemas.DeviceAction,
    admin: models.Admin = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    dev = db.query(models.Device).filter(models.Device.device_id == device_id).first()
    if not dev:
        raise HTTPException(status_code=404, detail="Device not found")
    return {"success": True, "message": f"Action {action_in.action} sent to device"}

import cv2
import threading
import time

latest_frame = None
camera_lock = threading.Lock()

def camera_thread_func():
    global latest_frame
    cap = cv2.VideoCapture(0)
    
    frame_count = 0
    face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    
    while True:
        ret, frame = cap.read()
        if not ret:
            time.sleep(0.1)
            continue
            
        if frame_count % 30 == 0: # Every 30 frames
            try:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = face_cascade.detectMultiScale(gray, 1.1, 4)
                
                if len(faces) > 0:
                    for (x, y, w, h) in faces:
                        cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 0, 255), 2)
                        cv2.putText(frame, "Unknown", (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)
                    
                    db = database.SessionLocal()
                    # Only alert if there hasn't been one recently to avoid spam
                    last_alert = db.query(models.Alert).order_by(models.Alert.timestamp.desc()).first()
                    if not last_alert or (datetime.utcnow() - last_alert.timestamp).total_seconds() > 10:
                        alert = models.Alert(type="unknown_person", message="Unknown person detected in Live Camera.")
                        db.add(alert)
                        db.commit()
                    db.close()
            except Exception as e:
                pass
                
        frame_count += 1
        
        ret, buffer = cv2.imencode('.jpg', frame)
        if ret:
            with camera_lock:
                latest_frame = buffer.tobytes()
        
        time.sleep(0.03)

# Background camera thread
threading.Thread(target=camera_thread_func, daemon=True).start()

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

@app.get("/api/admin/alerts", response_model=List[schemas.AlertResponse])
def get_alerts(db: Session = Depends(get_db)):
    return db.query(models.Alert).order_by(models.Alert.timestamp.desc()).limit(20).all()

@app.post("/api/admin/alerts/{alert_id}/read")
def mark_alert_read(alert_id: int, db: Session = Depends(get_db)):
    alert = db.query(models.Alert).filter(models.Alert.id == alert_id).first()
    if alert:
        alert.is_read = True
        db.commit()
    return {"success": True}


