PRAGMA journal_mode=WAL;

CREATE TABLE role (
    role_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE staff (
    staff_id INTEGER PRIMARY KEY AUTOINCREMENT,
    staff_no TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    phone TEXT,
    department TEXT,
    password_hash TEXT NOT NULL
);

CREATE TABLE staff_role (
    staff_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    PRIMARY KEY (staff_id, role_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
    FOREIGN KEY (role_id) REFERENCES role(role_id)
);

CREATE TABLE refresh_token (
    token_id INTEGER PRIMARY KEY AUTOINCREMENT,
    staff_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

CREATE TABLE exam_session (
    exam_session_id INTEGER PRIMARY KEY AUTOINCREMENT,
    course_code TEXT NOT NULL,
    exam_date TEXT NOT NULL,
    start_time TEXT NOT NULL,
    end_time TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    semester INTEGER NOT NULL,
    exam_type TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'SCHEDULED'
);

CREATE TABLE venue (
    venue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    venue_name TEXT NOT NULL,
    building TEXT NOT NULL,
    capacity INTEGER NOT NULL
);

CREATE TABLE course_lecturer (
    course_code TEXT NOT NULL,
    staff_id INTEGER NOT NULL,
    PRIMARY KEY (course_code, staff_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

CREATE TABLE student (
    computer_number TEXT PRIMARY KEY,
    national_id TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    program TEXT NOT NULL,
    school TEXT NOT NULL,
    year_of_study INTEGER NOT NULL,
    email TEXT,
    phone TEXT,
    photo_path TEXT NOT NULL,
    qr_token TEXT NOT NULL,
    status TEXT NOT NULL,
    password_hash TEXT,
    account_activated INTEGER NOT NULL DEFAULT 0,
    activated_at TEXT
);

CREATE TABLE invigilator_assignment (
    exam_session_id INTEGER NOT NULL,
    venue_id INTEGER NOT NULL,
    staff_id INTEGER NOT NULL,
    PRIMARY KEY (exam_session_id, venue_id, staff_id),
    FOREIGN KEY (exam_session_id) REFERENCES exam_session(exam_session_id),
    FOREIGN KEY (venue_id) REFERENCES venue(venue_id),
    FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
);

CREATE TABLE student_venue_allocation (
    computer_number TEXT NOT NULL,
    exam_session_id INTEGER NOT NULL,
    venue_id INTEGER NOT NULL,
    seat_number TEXT,
    PRIMARY KEY (computer_number, exam_session_id),
    FOREIGN KEY (computer_number) REFERENCES student(computer_number),
    FOREIGN KEY (exam_session_id) REFERENCES exam_session(exam_session_id),
    FOREIGN KEY (venue_id) REFERENCES venue(venue_id)
);

CREATE TABLE examination_pass (
    pass_id INTEGER PRIMARY KEY AUTOINCREMENT,
    computer_number TEXT NOT NULL,
    academic_year TEXT NOT NULL,
    semester INTEGER NOT NULL,
    qr_token TEXT NOT NULL,
    qr_jti TEXT NOT NULL UNIQUE,
    generated_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    UNIQUE (computer_number, academic_year, semester),
    FOREIGN KEY (computer_number) REFERENCES student(computer_number)
);

CREATE TABLE attendance (
    attendance_id INTEGER PRIMARY KEY AUTOINCREMENT,
    computer_number TEXT,
    exam_session_id INTEGER NOT NULL,
    check_in_venue_id INTEGER NOT NULL,
    verified_by_staff_id INTEGER NOT NULL,
    check_in_time TEXT NOT NULL,
    verification_method TEXT NOT NULL CHECK(verification_method IN ('COMPUTER','QR_CODE','FACIAL_RECOGNITION','QR_AND_FACE','QR_AND_FACIAL')),
    attendance_status TEXT NOT NULL CHECK(attendance_status IN ('PRESENT','ABSENT','LATE','WRONG_VENUE')),
    scripts_submitted INTEGER DEFAULT 0,
    alert_message TEXT,
    FOREIGN KEY (computer_number) REFERENCES student(computer_number),
    FOREIGN KEY (exam_session_id) REFERENCES exam_session(exam_session_id),
    FOREIGN KEY (check_in_venue_id) REFERENCES venue(venue_id),
    FOREIGN KEY (verified_by_staff_id) REFERENCES staff(staff_id)
);

CREATE TABLE incident (
    incident_id INTEGER PRIMARY KEY AUTOINCREMENT,
    exam_session_id INTEGER NOT NULL,
    venue_id INTEGER,
    computer_number TEXT,
    reported_by_staff_id INTEGER NOT NULL,
    incident_type TEXT NOT NULL CHECK(incident_type IN ('CHEATING','PHONE_FOUND','WRONG_VENUE','MEDICAL_EMERGENCY','DISTURBANCE','LATE_ARRIVAL','OTHER')),
    description TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'MINOR',
    evidence_path TEXT,
    occurred_at TEXT NOT NULL,
    FOREIGN KEY (exam_session_id) REFERENCES exam_session(exam_session_id),
    FOREIGN KEY (venue_id) REFERENCES venue(venue_id),
    FOREIGN KEY (computer_number) REFERENCES student(computer_number),
    FOREIGN KEY (reported_by_staff_id) REFERENCES staff(staff_id)
);
