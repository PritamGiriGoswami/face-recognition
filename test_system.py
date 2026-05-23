#!/usr/bin/env python3
"""
Test script for Face Recognition Attendance System
This script verifies that all components are working correctly.
"""

import sys
import os
import sqlite3
import cv2
import numpy as np
from PIL import Image
import hashlib

def test_imports():
    """Test if all required modules can be imported"""
    print("Testing module imports...")
    
    try:
        import flask
        print("✓ Flask imported successfully")
    except ImportError as e:
        print(f"✗ Flask import failed: {e}")
        return False
    
    try:
        import cv2
        print("✓ OpenCV imported successfully")
    except ImportError as e:
        print(f"✗ OpenCV import failed: {e}")
        return False
    
    try:
        import numpy as np
        print("✓ NumPy imported successfully")
    except ImportError as e:
        print(f"✗ NumPy import failed: {e}")
        return False
    
    try:
        from PIL import Image
        print("✓ Pillow imported successfully")
    except ImportError as e:
        print(f"✗ Pillow import failed: {e}")
        return False
    
    return True

def test_database():
    """Test database creation and operations"""
    print("\nTesting database operations...")
    
    try:
        # Test database connection
        conn = sqlite3.connect(':memory:')
        cursor = conn.cursor()
        
        # Test table creation
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS test_users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                email TEXT UNIQUE,
                face_hash TEXT
            )
        ''')
        print("✓ Database table created successfully")
        
        # Test data insertion
        cursor.execute('INSERT INTO test_users (name, email, face_hash) VALUES (?, ?, ?)',
                      ('Test User', 'test@example.com', 'test_hash'))
        print("✓ Data insertion successful")
        
        # Test data retrieval
        cursor.execute('SELECT * FROM test_users WHERE email = ?', ('test@example.com',))
        result = cursor.fetchone()
        if result:
            print("✓ Data retrieval successful")
        else:
            print("✗ Data retrieval failed")
            return False
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"✗ Database test failed: {e}")
        return False

def test_image_processing():
    """Test image processing capabilities"""
    print("\nTesting image processing...")
    
    try:
        # Create a test image
        test_image = np.zeros((100, 100, 3), dtype=np.uint8)
        test_image[:] = (128, 128, 128)  # Gray color
        
        # Test OpenCV operations
        gray = cv2.cvtColor(test_image, cv2.COLOR_RGB2GRAY)
        resized = cv2.resize(gray, (50, 50))
        hist = cv2.calcHist([gray], [0], None, [256], [0, 256])
        
        print("✓ OpenCV image processing successful")
        
        # Test PIL operations
        pil_image = Image.fromarray(test_image)
        pil_image.save('test_image.jpg')
        
        if os.path.exists('test_image.jpg'):
            os.remove('test_image.jpg')
            print("✓ PIL image processing successful")
        else:
            print("✗ PIL image save failed")
            return False
        
        return True
        
    except Exception as e:
        print(f"✗ Image processing test failed: {e}")
        return False

def test_face_processing():
    """Test face processing functions"""
    print("\nTesting face processing...")
    
    try:
        # Import face processing functions from app_simple
        from app_simple import get_face_features, compare_faces
        
        # Create a test face image (simple pattern)
        test_face = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        
        # Test feature extraction
        face_hash = get_face_features(test_face)
        if face_hash:
            print("✓ Face feature extraction successful")
        else:
            print("✗ Face feature extraction failed")
            return False
        
        # Test face comparison
        result = compare_faces(face_hash, face_hash)
        if result:
            print("✓ Face comparison successful")
        else:
            print("✗ Face comparison failed")
            return False
        
        return True
        
    except Exception as e:
        print(f"✗ Face processing test failed: {e}")
        return False

def test_flask_app():
    """Test Flask application"""
    print("\nTesting Flask application...")
    
    try:
        from app_simple import app
        
        with app.test_client() as client:
            # Test home page
            response = client.get('/')
            if response.status_code == 200:
                print("✓ Home page accessible")
            else:
                print(f"✗ Home page failed: {response.status_code}")
                return False
            
            # Test register page
            response = client.get('/register')
            if response.status_code == 200:
                print("✓ Register page accessible")
            else:
                print(f"✗ Register page failed: {response.status_code}")
                return False
            
            # Test attendance page
            response = client.get('/attendance')
            if response.status_code == 200:
                print("✓ Attendance page accessible")
            else:
                print(f"✗ Attendance page failed: {response.status_code}")
                return False
            
            # Test dashboard page
            response = client.get('/dashboard')
            if response.status_code == 200:
                print("✓ Dashboard page accessible")
            else:
                print(f"✗ Dashboard page failed: {response.status_code}")
                return False
        
        return True
        
    except Exception as e:
        print(f"✗ Flask app test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("=" * 50)
    print("Face Recognition Attendance System - System Test")
    print("=" * 50)
    
    tests = [
        ("Module Imports", test_imports),
        ("Database Operations", test_database),
        ("Image Processing", test_image_processing),
        ("Face Processing", test_face_processing),
        ("Flask Application", test_flask_app)
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        print(f"\n{'='*20} {test_name} {'='*20}")
        if test_func():
            passed += 1
            print(f"✓ {test_name} PASSED")
        else:
            print(f"✗ {test_name} FAILED")
    
    print("\n" + "=" * 50)
    print(f"Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! The system is ready to use.")
        print("\nTo start the application, run:")
        print("python app_simple.py")
        print("\nThen open your browser to: http://localhost:5000")
    else:
        print("❌ Some tests failed. Please check the errors above.")
        print("\nTroubleshooting tips:")
        print("1. Make sure all dependencies are installed: pip install -r requirements_simple.txt")
        print("2. Check if Python is properly installed")
        print("3. Ensure you have camera access for face recognition")
    
    print("=" * 50)

if __name__ == "__main__":
    main() 