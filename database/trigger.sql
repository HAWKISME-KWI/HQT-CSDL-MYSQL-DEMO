DELIMITER //
CREATE TRIGGER trg_users_updated
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //

CREATE TRIGGER trg_courts_updated
BEFORE UPDATE ON courts
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //

CREATE TRIGGER trg_bookings_updated
BEFORE UPDATE ON bookings
FOR EACH ROW
BEGIN
    SET NEW.updated_at = CURRENT_TIMESTAMP;
END //

CREATE TRIGGER trg_booking_insert
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO activity_logs(user_id, action)
    VALUES (NEW.user_id, CONCAT('Booking ID ', NEW.booking_id, ' created with status ', NEW.status));
END //

CREATE TRIGGER trg_booking_status_change
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO activity_logs(user_id, action)
        VALUES (NEW.user_id, CONCAT('Booking ID ', NEW.booking_id, ' status changed from ', OLD.status, ' to ', NEW.status));
    END IF;
END //

CREATE TRIGGER trg_no_overlap
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM bookings
    WHERE court_id = NEW.court_id
      AND status = 'BOOKED'
      AND (start_time < NEW.end_time AND end_time > NEW.start_time);
    IF v_count > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Court already booked';
    END IF;
END //

CREATE TRIGGER trg_booking_notify_insert
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO notifications(user_id, title, content)
    VALUES (NEW.user_id, 'Đặt sân thành công', 'Yêu cầu đặt sân của bạn đang chờ xác nhận.');
    INSERT INTO notifications(user_id, title, content)
    SELECT c.owner_id, 'Có đơn đặt sân mới', CONCAT('Sân ', c.court_name, ' có đơn đặt mới cần duyệt.')
    FROM courts c
    WHERE c.court_id = NEW.court_id AND c.owner_id IS NOT NULL;
    INSERT INTO notifications(user_id, title, content)
    SELECT u.user_id, 'Có đơn đặt sân mới', CONCAT('Sân ', c.court_name, ' có đơn đặt mới cần duyệt.')
    FROM courts c
    CROSS JOIN users u
    WHERE c.court_id = NEW.court_id
      AND u.role = 'MANAGER'
      AND (c.owner_id IS NULL OR c.owner_id != u.user_id);
END //
CREATE TRIGGER trg_booking_notify_update
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
    IF OLD.status != NEW.status THEN
        INSERT INTO notifications(user_id, title, content)
        VALUES (NEW.user_id, 'Cập nhật trạng thái đặt sân',
                CONCAT('Đơn đặt sân của bạn đã được cập nhật từ ', OLD.status, ' sang ', NEW.status));
    END IF;
END //

DELIMITER ;