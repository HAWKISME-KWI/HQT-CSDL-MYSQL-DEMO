CREATE TABLE users (
    user_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    role ENUM('GUEST','CUSTOMER','MANAGER','COURT_MANAGER') DEFAULT 'CUSTOMER',
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
CREATE TABLE courts (
    court_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    court_name VARCHAR(255) NOT NULL,
    address TEXT NOT NULL,
    court_surfaces_type ENUM('PVC','WOOD','CEMENT','SYNTHETIC_RESIN') DEFAULT 'PVC',
    court_sizes_type ENUM('SINGLE','DOUBLE') DEFAULT 'SINGLE',
    price_per_hour DECIMAL(10,2) NOT NULL CHECK (price_per_hour > 0),
    price_per_three_hours DECIMAL(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    image_url TEXT,
    owner_id CHAR(36),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT check_price_range CHECK (price_per_three_hours > price_per_hour),
    FOREIGN KEY (owner_id) REFERENCES users(user_id) ON DELETE SET NULL
);
CREATE TABLE bookings (
    booking_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    court_id CHAR(36) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    status ENUM('BOOKED','CANCELLED','COMPLETED','PENDING','REJECTED') DEFAULT 'PENDING',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (court_id) REFERENCES courts(court_id) ON DELETE CASCADE,
    CONSTRAINT check_time_range CHECK (end_time > start_time)
);
CREATE TABLE activity_logs (
    log_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36),
    action TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL
);
CREATE TABLE notifications (
    notification_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

--Index
CREATE INDEX idx_booking_time ON bookings(start_time, end_time);
CREATE INDEX idx_booking_court ON bookings(court_id);
CREATE INDEX idx_booking_status ON bookings(status);
CREATE INDEX idx_booking_user ON bookings(user_id);
CREATE INDEX idx_booking_status_time ON bookings(status, start_time);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_phone ON users(phone_number);
CREATE INDEX idx_courts_owner ON courts(owner_id);
CREATE INDEX idx_courts_active ON courts(is_active);
CREATE INDEX idx_courts_surface ON courts(court_surfaces_type);
CREATE INDEX idx_courts_size ON courts(court_sizes_type);
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_created ON notifications(created_at);
CREATE INDEX idx_activity_user ON activity_logs(user_id);
CREATE INDEX idx_activity_created ON activity_logs(created_at);