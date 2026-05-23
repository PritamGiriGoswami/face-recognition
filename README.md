# Face Recognition-Based Attendance System

A modern, automated attendance tracking system using face recognition technology. This system provides a touchless, efficient, and secure way to manage attendance in schools, offices, and other organizations.

## ✅ Main Features

### Automated Attendance Tracking
- Replaces manual entry (pen-paper or typing)
- Reduces human error in marking attendance
- Instant face recognition and attendance recording

### Improved Accuracy and Efficiency
- Ensures only real-time, verified attendance
- Minimizes chances of proxy or fake entries
- High accuracy face detection and recognition

### Time-Saving
- Instant recognition saves time in schools, offices, or events
- Automated check-in/check-out system
- Real-time processing

### Touchless System (Post-COVID Friendly)
- No physical contact needed, unlike fingerprint or ID cards
- Safer in health-sensitive environments
- Hygienic attendance marking

### Real-Time Monitoring
- Admins can check who is present/absent instantly
- Live dashboard with attendance statistics
- Can be integrated with alerts or notifications

### Smart Data Management
- Automatically stores data with time & date stamps
- Useful for reports, payroll, academic records, etc.
- Export functionality for data analysis

### Security Enhancement
- Helps monitor unauthorized access
- Keeps a visual record of every person detected
- Secure face data storage

## 🚀 Quick Start

### Option 1: Simplified Version (Recommended for Windows)

The simplified version uses basic image processing and doesn't require complex dependencies.

1. **Install Dependencies:**
   ```bash
   pip install -r requirements_simple.txt
   ```

2. **Run the Application:**
   ```bash
   python app_simple.py
   ```

3. **Access the System:**
   - Open your browser and go to `http://localhost:5000`
   - Register new users with their face photos
   - Mark attendance using face recognition

### Option 2: Full Version (Advanced Face Recognition)

For the full version with advanced face recognition capabilities:

1. **Install CMake (Required for dlib):**
   - Windows: Download from [cmake.org](https://cmake.org/download/)
   - Make sure to add CMake to your PATH during installation
   - Linux: `sudo apt install cmake`
   - macOS: `brew install cmake`

2. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run the Application:**
   ```bash
   python app.py
   ```

## 📁 Project Structure

```
face-recognition-attendance/
├── app.py                 # Full version with advanced face recognition
├── app_simple.py          # Simplified version (recommended)
├── requirements.txt       # Dependencies for full version
├── requirements_simple.txt # Dependencies for simplified version
├── attendance.db          # SQLite database (created automatically)
├── templates/             # HTML templates
│   ├── index.html         # Home page
│   ├── register.html      # User registration page
│   ├── attendance.html    # Attendance marking page
│   └── dashboard.html     # Admin dashboard
├── static/                # Static files
│   ├── css/
│   │   └── style.css      # Main stylesheet
│   └── js/
│       ├── main.js        # Home page JavaScript
│       ├── register.js    # Registration page JavaScript
│       ├── attendance.js  # Attendance page JavaScript
│       └── dashboard.js   # Dashboard JavaScript
└── uploads/               # Uploaded face images (created automatically)
```

## 🎯 How It Works

### 1. User Registration
- Users visit the registration page
- They capture their face photo using the webcam
- System extracts face features and stores them securely
- User information is saved to the database

### 2. Attendance Marking
- Users visit the attendance page
- System activates the webcam for face detection
- User's face is compared with registered faces
- If matched, attendance is automatically recorded
- System handles both check-in and check-out

### 3. Dashboard & Reports
- Admin dashboard shows real-time attendance data
- View recent attendance records
- Export attendance data
- Monitor registered users

## 🔧 Technical Details

### Face Recognition Methods

#### Simplified Version (app_simple.py)
- Uses OpenCV for basic image processing
- Extracts histogram features from face images
- Creates MD5 hash for face comparison
- Suitable for basic attendance tracking

#### Full Version (app.py)
- Uses the `face_recognition` library
- Advanced face encoding and comparison
- Higher accuracy and reliability
- Requires CMake and dlib installation

### Database Schema

```sql
-- Users table
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    face_encoding TEXT,  -- or face_hash for simplified version
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Attendance table
CREATE TABLE attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    name TEXT,
    check_in_time TIMESTAMP,
    check_out_time TIMESTAMP,
    date DATE,
    FOREIGN KEY (user_id) REFERENCES users (id)
);
```

## 🌟 Key Advantages

### For Organizations
- **Cost-Effective**: Reduces administrative overhead
- **Accurate**: Eliminates manual errors and proxy attendance
- **Scalable**: Can handle large numbers of users
- **Secure**: Prevents unauthorized access

### For Users
- **Convenient**: No need to carry cards or remember passwords
- **Fast**: Instant recognition and attendance marking
- **Hygienic**: Touchless system
- **Reliable**: Works 24/7

### For Administrators
- **Real-time Monitoring**: Live attendance tracking
- **Comprehensive Reports**: Detailed attendance analytics
- **Easy Management**: Simple user interface
- **Data Export**: Flexible data export options

## 🔒 Security Features

- Face data is stored as encrypted hashes
- No raw face images are stored in the database
- Secure API endpoints with proper validation
- Session management and access control

## 📱 Browser Compatibility

- Chrome (recommended)
- Firefox
- Safari
- Edge

**Note**: Webcam access requires HTTPS in production environments.

## 🚀 Deployment

### Local Development
```bash
python app_simple.py
```

### Production Deployment
1. Set up a production web server (nginx, Apache)
2. Use WSGI server (gunicorn, uwsgi)
3. Configure HTTPS for webcam access
4. Set up proper database (PostgreSQL, MySQL)

## 🐛 Troubleshooting

### Common Issues

1. **Camera not working:**
   - Check browser permissions
   - Ensure HTTPS in production
   - Try different browsers

2. **Face recognition not working:**
   - Ensure good lighting
   - Face should be clearly visible
   - Check camera quality

3. **Installation issues:**
   - Use the simplified version for Windows
   - Install CMake for the full version
   - Check Python version compatibility

### Error Messages

- **"No face detected"**: Ensure face is clearly visible in camera
- **"Face not recognized"**: User may not be registered or lighting is poor
- **"Camera access denied"**: Check browser permissions

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review browser console for JavaScript errors
3. Check Python console for backend errors
4. Ensure all dependencies are properly installed

## 🔄 Future Enhancements

- Mobile app integration
- Advanced analytics and reporting
- Integration with HR systems
- Multi-location support
- Real-time notifications
- Advanced security features

## 📄 License

This project is open source and available under the MIT License.

---

**Note**: This system is designed for educational and organizational use. For production deployment, ensure compliance with local privacy and data protection regulations. 