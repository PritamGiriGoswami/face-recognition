from flask import Flask, render_template, request, jsonify, redirect, url_for
import cv2
import face_recognition
import numpy as np
import sqlite3
import os
import json
from datetime import datetime
import base64
from PIL import Image
import io

app = Flask(__name__)
app.config['SECRET_KEY'] = 'your-secret-key-here'

# Database initialization
def init_db():
    conn = sqlite3.connect('attendance.db')
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE,
            face_encoding TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            name TEXT,
            check_in_time TIMESTAMP,
            check_out_time TIMESTAMP,
            date DATE,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    conn.commit()
    conn.close()

# Create uploads directory for face images
if not os.path.exists('uploads'):
    os.makedirs('uploads')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/register')
def register():
    return render_template('register.html')

@app.route('/attendance')
def attendance():
    return render_template('attendance.html')

@app.route('/dashboard')
def dashboard():
    return render_template('dashboard.html')

@app.route('/api/register', methods=['POST'])
def api_register():
    try:
        data = request.get_json()
        name = data.get('name')
        email = data.get('email')
        department = data.get('department', '')
        phone = data.get('phone', '')
        face_image = data.get('face_image')  # Base64 encoded image
        
        if not name or not email or not face_image:
            return jsonify({'success': False, 'message': 'Missing required fields'}), 400
        
        # Decode base64 image
        image_data = base64.b64decode(face_image.split(',')[1])
        image = Image.open(io.BytesIO(image_data))
        
        # Convert to numpy array
        image_array = np.array(image)
        
        # Detect face and get encoding
        face_locations = face_recognition.face_locations(image_array)
        if not face_locations:
            return jsonify({'success': False, 'message': 'No face detected in image'}), 400
        
        face_encodings = face_recognition.face_encodings(image_array, face_locations)
        if not face_encodings:
            return jsonify({'success': False, 'message': 'Could not encode face'}), 400
        
        # Convert encoding to string for storage
        face_encoding_str = json.dumps(face_encodings[0].tolist())
        
        # Save to database
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        
        # Check if user already exists
        cursor.execute('SELECT id FROM users WHERE email = ?', (email,))
        existing_user = cursor.fetchone()
        
        if existing_user:
            return jsonify({'success': False, 'message': 'User with this email already exists'}), 400
        
        cursor.execute('INSERT INTO users (name, email, face_encoding) VALUES (?, ?, ?)',
                      (name, email, face_encoding_str))
        conn.commit()
        conn.close()
        
        return jsonify({'success': True, 'message': f'User {name} registered successfully'})
    
    except Exception as e:
        print(f"Registration error: {str(e)}")
        return jsonify({'success': False, 'message': f'Registration failed: {str(e)}'}), 500

@app.route('/api/check_attendance', methods=['POST'])
def api_check_attendance():
    try:
        data = request.get_json()
        face_image = data.get('face_image')  # Base64 encoded image
        
        if not face_image:
            return jsonify({'success': False, 'message': 'No image provided'}), 400
        
        # Decode base64 image
        image_data = base64.b64decode(face_image.split(',')[1])
        image = Image.open(io.BytesIO(image_data))
        image_array = np.array(image)
        
        # Detect face in uploaded image
        face_locations = face_recognition.face_locations(image_array)
        if not face_locations:
            return jsonify({'success': False, 'message': 'No face detected'}), 400
        
        face_encodings = face_recognition.face_encodings(image_array, face_locations)
        if not face_encodings:
            return jsonify({'success': False, 'message': 'Could not encode face'}), 400
        
        uploaded_face_encoding = face_encodings[0]
        
        # Get all registered users
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        cursor.execute('SELECT id, name, face_encoding FROM users')
        users = cursor.fetchall()
        conn.close()
        
        # Compare with registered faces
        for user in users:
            user_id, user_name, stored_encoding_str = user
            stored_encoding = np.array(json.loads(stored_encoding_str))
            
            # Compare faces
            matches = face_recognition.compare_faces([stored_encoding], uploaded_face_encoding, tolerance=0.6)
            
            if matches[0]:
                # Record attendance
                current_time = datetime.now()
                today = current_time.date()
                
                conn = sqlite3.connect('attendance.db')
                cursor = conn.cursor()
                
                # Check if already checked in today
                cursor.execute('''
                    SELECT id, check_in_time, check_out_time FROM attendance 
                    WHERE user_id = ? AND date = ?
                ''', (user_id, today))
                
                existing_record = cursor.fetchone()
                
                if existing_record:
                    record_id, check_in_time, check_out_time = existing_record
                    if check_out_time is None:
                        # Check out
                        cursor.execute('''
                            UPDATE attendance SET check_out_time = ? WHERE id = ?
                        ''', (current_time, record_id))
                        message = f"Check-out recorded for {user_name}"
                    else:
                        message = f"{user_name} already checked out today"
                else:
                    # Check in
                    cursor.execute('''
                        INSERT INTO attendance (user_id, name, check_in_time, date)
                        VALUES (?, ?, ?, ?)
                    ''', (user_id, user_name, current_time, today))
                    message = f"Check-in recorded for {user_name}"
                
                conn.commit()
                conn.close()
                
                return jsonify({
                    'success': True,
                    'message': message,
                    'user_name': user_name,
                    'time': current_time.strftime('%H:%M:%S')
                })
        
        return jsonify({'success': False, 'message': 'Face not recognized'}), 404
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/attendance_data')
def api_attendance_data():
    try:
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        cursor.execute('''
            SELECT a.name, a.check_in_time, a.check_out_time, a.date,
                   CASE 
                       WHEN a.check_out_time IS NULL THEN 'Present'
                       ELSE 'Checked Out'
                   END as status
            FROM attendance a
            ORDER BY a.date DESC, a.check_in_time DESC
        ''')
        attendance_records = cursor.fetchall()
        conn.close()
        
        records = []
        for record in attendance_records:
            records.append({
                'name': record[0],
                'check_in': record[1],
                'check_out': record[2],
                'date': record[3],
                'status': record[4]
            })
        
        return jsonify({'success': True, 'records': records})
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@app.route('/api/users')
def api_users():
    try:
        conn = sqlite3.connect('attendance.db')
        cursor = conn.cursor()
        cursor.execute('SELECT id, name, email, created_at FROM users')
        users = cursor.fetchall()
        conn.close()
        
        user_list = []
        for user in users:
            user_list.append({
                'id': user[0],
                'name': user[1],
                'email': user[2],
                'created_at': user[3]
            })
        
        return jsonify({'success': True, 'users': user_list})
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

if __name__ == '__main__':
    init_db()
    app.run(debug=True, host='0.0.0.0', port=5000) 