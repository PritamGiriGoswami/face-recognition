-- Users Table
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    face_encoding TEXT,  -- Secure face data storage
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Attendance Table
CREATE TABLE attendance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    name TEXT,
    check_in_time TIMESTAMP,
    check_out_time TIMESTAMP,
    date DATE,
    FOREIGN KEY (user_id) REFERENCES users (id)
);