from sqlalchemy import Boolean, Column, Integer, String, DateTime, Date, ForeignKey, Text, Float
from sqlalchemy.orm import relationship
from datetime import datetime
from .database import Base

class Admin(Base):
    __tablename__ = "admins"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    token = Column(String, unique=True, index=True, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    class_name = Column(String, index=True, nullable=True)
    department = Column(String, index=True, nullable=True)
    face_encoding = Column(Text, nullable=False) # JSON string representation of embedding
    face_image_base64 = Column(Text, nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    attendances = relationship("Attendance", back_populates="user")

class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    name = Column(String)
    check_in_time = Column(DateTime)
    check_out_time = Column(DateTime, nullable=True)
    date = Column(Date)

    user = relationship("User", back_populates="attendances")

class Setting(Base):
    __tablename__ = "settings"

    id = Column(Integer, primary_key=True, index=True)
    office_latitude = Column(Float, default=22.5726, nullable=False)
    office_longitude = Column(Float, default=88.3639, nullable=False)
    office_radius = Column(Float, default=100.0, nullable=False)
    late_after = Column(String, default="09:15", nullable=False)
    webhook_url = Column(String, default="", nullable=True)
    purge_raw_images = Column(Boolean, default=False, nullable=False)
    strict_geofence = Column(Boolean, default=False, nullable=False)

class ClassModel(Base):
    __tablename__ = "classes"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)

class Department(Base):
    __tablename__ = "departments"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)

class Device(Base):
    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    device_id = Column(String, unique=True, index=True, nullable=False)
    name = Column(String, nullable=False)
    status = Column(String, default="Online", nullable=False)
    battery_level = Column(Integer, default=100, nullable=False)
    temperature = Column(Float, default=36.5, nullable=False)
    last_active = Column(DateTime, default=datetime.utcnow, nullable=False)

class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    type = Column(String, default="unknown_person", nullable=False)
    message = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)
