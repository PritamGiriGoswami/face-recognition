from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date

class AdminLogin(BaseModel):
    email: str
    password: str

class AdminLoginResponse(BaseModel):
    token: str
    email: str

class AdminStatsResponse(BaseModel):
    total_users: int
    today_present: int
    today_absent: int
    late_arrivals: int
    currently_checked_in: int
    total_attendance_records: int

class UserCreate(BaseModel):
    name: str
    email: str
    class_name: Optional[str] = None
    department: Optional[str] = None
    face_image_base64: str # Base64 encoded image

class UserUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    class_name: Optional[str] = None
    department: Optional[str] = None
    is_active: Optional[bool] = None

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    class_name: Optional[str] = None
    department: Optional[str] = None
    face_image_base64: Optional[str] = None
    is_active: bool = True
    created_at: datetime

    class Config:
        from_attributes = True

class AttendanceCheckIn(BaseModel):
    face_image_base64: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class AttendanceResponse(BaseModel):
    id: int
    user_id: Optional[int] = None
    name: str
    class_name: Optional[str] = None
    department: Optional[str] = None
    check_in_time: datetime
    check_out_time: Optional[datetime]
    date: date
    status: Optional[str] = None
    is_late: bool = False

    class Config:
        from_attributes = True

class SettingSchema(BaseModel):
    id: int
    office_latitude: float
    office_longitude: float
    office_radius: float
    late_after: str
    webhook_url: Optional[str] = ""
    purge_raw_images: bool
    strict_geofence: bool

    class Config:
        from_attributes = True

class SettingUpdate(BaseModel):
    office_latitude: Optional[float] = None
    office_longitude: Optional[float] = None
    office_radius: Optional[float] = None
    late_after: Optional[str] = None
    webhook_url: Optional[str] = None
    purge_raw_images: Optional[bool] = None
    strict_geofence: Optional[bool] = None

class DashboardUserDetail(BaseModel):
    id: int
    name: str
    email: str
    class_name: Optional[str] = None
    department: Optional[str] = None
    face_image_base64: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class DashboardStats(BaseModel):
    total_working_days: int
    present_days: int
    late_days: int
    absent_days: int
    attendance_percentage: float
    late_threshold: str

class DashboardDailyRecord(BaseModel):
    date: date
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    status: str
    is_late: bool

class DashboardMonthlyAnalytic(BaseModel):
    month: str
    present: int
    late: int
    absent: int

class UserDashboardResponse(BaseModel):
    user: DashboardUserDetail
    stats: DashboardStats
    daily_records: List[DashboardDailyRecord]
    monthly_analytics: List[DashboardMonthlyAnalytic]

class ClassCreate(BaseModel):
    name: str

class ClassResponse(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True

class DepartmentCreate(BaseModel):
    name: str

class DepartmentResponse(BaseModel):
    id: int
    name: str

    class Config:
        from_attributes = True

class DeviceCreate(BaseModel):
    device_id: str
    name: str
    battery_level: Optional[int] = 100
    temperature: Optional[float] = 36.5

class DeviceHeartbeat(BaseModel):
    device_id: str
    name: str
    battery_level: int
    temperature: float

class DeviceResponse(BaseModel):
    id: int
    device_id: str
    name: str
    status: str
    battery_level: int
    temperature: float
    last_active: datetime

    class Config:
        from_attributes = True

class DeviceAction(BaseModel):
    action: str # e.g. "restart_camera", "force_sync", "wipe_cache"

class AlertResponse(BaseModel):
    id: int
    type: str
    message: str
    timestamp: datetime
    is_read: bool

    class Config:
        from_attributes = True

class QRCheckIn(BaseModel):
    user_id: str  # This could be email or ID from QR
    latitude: Optional[float] = None
    longitude: Optional[float] = None
