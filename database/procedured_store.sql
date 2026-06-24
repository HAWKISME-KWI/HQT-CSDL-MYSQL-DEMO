DROP PROCEDURE IF EXISTS sp_search_bookings;
DROP PROCEDURE IF EXISTS sp_filter_courts;
DROP PROCEDURE IF EXISTS sp_get_court_schedule;
DROP PROCEDURE IF EXISTS sp_daily_revenue;
DROP PROCEDURE IF EXISTS sp_top_courts;
DROP PROCEDURE IF EXISTS sp_book_court;
DROP PROCEDURE IF EXISTS sp_approve_booking;
DROP PROCEDURE IF EXISTS sp_reject_booking;
DROP PROCEDURE IF EXISTS sp_cancel_booking_customer;
DROP PROCEDURE IF EXISTS sp_cancel_booking_powerfull;
DROP PROCEDURE IF EXISTS sp_complete_booking;
DROP PROCEDURE IF EXISTS sp_add_court;
DROP PROCEDURE IF EXISTS sp_update_court;
DROP PROCEDURE IF EXISTS sp_delete_court;

DELIMITER //
CREATE PROCEDURE sp_search_bookings(
    IN p_user_id CHAR(36),
    IN p_from_date DATETIME,
    IN p_to_date DATETIME,
    IN p_status VARCHAR(20),
    IN p_court_id CHAR(36),
    IN p_owner_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT
        b.booking_id,
        c.court_name,
        u.username AS user_name,
        u.phone_number,
        b.start_time,
        b.end_time,
        b.status,
        fn_calculate_booking_cost(b.court_id, b.start_time, b.end_time) AS total_cost
    FROM bookings b
    JOIN courts c ON b.court_id = c.court_id
    JOIN users u ON b.user_id = u.user_id
    WHERE (p_user_id IS NULL OR b.user_id = p_user_id)
        AND (p_from_date IS NULL OR b.start_time >= p_from_date)
        AND (p_to_date IS NULL OR b.end_time <= p_to_date)
        AND (p_status IS NULL OR b.status = p_status)
        AND (p_court_id IS NULL OR b.court_id = p_court_id)
        AND (p_owner_id IS NULL OR c.owner_id = p_owner_id)
    ORDER BY b.start_time DESC;
END //

CREATE PROCEDURE sp_book_court(
    IN p_user_id CHAR(36),
    IN p_court_id CHAR(36),
    IN p_start DATETIME,
    IN p_end DATETIME
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_available BOOLEAN;
    SET v_available = fn_is_court_available(p_court_id, p_start, p_end);
    IF NOT v_available THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Court is already booked';
    END IF;
    INSERT INTO bookings(user_id, court_id, start_time, end_time, status)
    VALUES (p_user_id, p_court_id, p_start, p_end, 'PENDING');
END //
CREATE PROCEDURE sp_filter_courts(
    IN p_surface VARCHAR(20),
    IN p_size VARCHAR(10),
    IN p_min_price DECIMAL(10,2),
    IN p_max_price DECIMAL(10,2),
    IN p_is_free BOOLEAN
)
READS SQL DATA
BEGIN
    SELECT
        c.court_id,
        c.court_name,
        c.address,
        c.court_surfaces_type AS surface,
        c.court_sizes_type AS size,
        c.price_per_hour,
        c.image_url,
        NOT EXISTS (
            SELECT 1 FROM bookings b
            WHERE b.court_id = c.court_id
            AND b.status = 'BOOKED'
            AND b.start_time <= DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 HOUR)
            AND b.end_time >= CURRENT_TIMESTAMP
        ) AS is_currently_free,
        u.phone_number AS owner_phone
    FROM courts c
    LEFT JOIN users u ON c.owner_id = u.user_id
    WHERE c.is_active = TRUE
        AND (p_surface IS NULL OR c.court_surfaces_type = p_surface)
        AND (p_size IS NULL OR c.court_sizes_type = p_size)
        AND (p_min_price IS NULL OR c.price_per_hour >= p_min_price)
        AND (p_max_price IS NULL OR c.price_per_hour <= p_max_price)
        AND (p_is_free IS NULL OR
            (p_is_free = TRUE AND NOT EXISTS (
                SELECT 1 FROM bookings b
                WHERE b.court_id = c.court_id
                AND b.status = 'BOOKED'
                AND b.start_time <= DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 HOUR)
                AND b.end_time >= CURRENT_TIMESTAMP
            ))
            OR (p_is_free = FALSE AND EXISTS (
                SELECT 1 FROM bookings b
                WHERE b.court_id = c.court_id
                AND b.status = 'BOOKED'
                AND b.start_time <= DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 HOUR)
                AND b.end_time >= CURRENT_TIMESTAMP
            ))
        );
END //
CREATE PROCEDURE sp_get_court_schedule(
    IN p_court_id CHAR(36),
    IN p_date DATE
)
READS SQL DATA
BEGIN
    SELECT b.start_time, b.end_time, b.status
    FROM bookings b
    WHERE b.court_id = p_court_id
      AND DATE(b.start_time) = p_date
      AND b.status IN ('BOOKED', 'PENDING')
    ORDER BY b.start_time;
END //
CREATE PROCEDURE sp_daily_revenue(
    IN from_date DATE,
    IN to_date DATE,
    IN p_owner_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT DATE(b.start_time) AS booking_date,
           COALESCE(SUM(fn_calculate_booking_cost(b.court_id, b.start_time, b.end_time)), 0) AS revenue
    FROM bookings b
    JOIN courts c ON b.court_id = c.court_id
    WHERE b.status = 'COMPLETED'
      AND (from_date IS NULL OR DATE(b.start_time) >= from_date)
      AND (to_date IS NULL OR DATE(b.start_time) <= to_date)
      AND (p_owner_id IS NULL OR c.owner_id = p_owner_id)
    GROUP BY DATE(b.start_time)
    ORDER BY booking_date DESC;
END //
CREATE PROCEDURE sp_top_courts(
    IN limit_count INT,
    IN p_owner_id CHAR(36)
)
READS SQL DATA
BEGIN
    SELECT c.court_id, c.court_name, c.address, u.phone_number AS owner_phone, COUNT(b.booking_id) AS total_bookings
    FROM courts c
    LEFT JOIN users u ON c.owner_id = u.user_id
    LEFT JOIN bookings b ON c.court_id = b.court_id AND b.status = 'COMPLETED'
    WHERE (p_owner_id IS NULL OR c.owner_id = p_owner_id)
    GROUP BY c.court_id, c.court_name, c.address, u.phone_number
    ORDER BY total_bookings DESC
    LIMIT limit_count;
END //
CREATE PROCEDURE sp_reject_booking(
    IN p_booking_id CHAR(36),
    IN p_admin_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_court_owner CHAR(36);

    SELECT role INTO v_role FROM users WHERE user_id = p_admin_id;
    IF v_role NOT IN ('MANAGER', 'COURT_MANAGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only managers or court managers can reject bookings';
    END IF;

    IF v_role = 'COURT_MANAGER' THEN
        SELECT c.owner_id INTO v_court_owner
        FROM bookings b
        JOIN courts c ON b.court_id = c.court_id
        WHERE b.booking_id = p_booking_id;
        IF v_court_owner != p_admin_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the owner of this court';
        END IF;
    END IF;

    UPDATE bookings SET status = 'REJECTED' WHERE booking_id = p_booking_id;
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking not found or not pending';
    END IF;
END //
CREATE PROCEDURE sp_cancel_booking_customer(
    IN p_booking_id CHAR(36),
    IN p_user_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_start_time TIMESTAMP;
    DECLARE v_status VARCHAR(20);

    SELECT start_time, status INTO v_start_time, v_status
    FROM bookings
    WHERE booking_id = p_booking_id AND user_id = p_user_id;
    IF v_start_time IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking not found or not owned by user';
    END IF;

    IF v_status NOT IN ('PENDING', 'BOOKED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot cancel booking with this status';
    END IF;

    IF v_status = 'BOOKED' AND CURRENT_TIMESTAMP > DATE_SUB(v_start_time, INTERVAL 3 HOUR) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot cancel within 3 hours';
    END IF;

    UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
END //
CREATE PROCEDURE sp_cancel_booking_powerfull(
    IN p_booking_id CHAR(36),
    IN p_admin_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_court_owner CHAR(36);

    SELECT role INTO v_role FROM users WHERE user_id = p_admin_id;
    IF v_role NOT IN ('MANAGER', 'COURT_MANAGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only managers or court managers can cancel any booking';
    END IF;

    IF v_role = 'COURT_MANAGER' THEN
        SELECT c.owner_id INTO v_court_owner
        FROM bookings b
        JOIN courts c ON b.court_id = c.court_id
        WHERE b.booking_id = p_booking_id;
        IF v_court_owner != p_admin_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the owner of this court';
        END IF;
    END IF;

    UPDATE bookings SET status = 'CANCELLED' WHERE booking_id = p_booking_id;
END //
CREATE PROCEDURE sp_complete_booking(
    IN p_booking_id CHAR(36),
    IN p_admin_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_court_owner CHAR(36);

    SELECT role INTO v_role FROM users WHERE user_id = p_admin_id;
    IF v_role NOT IN ('MANAGER', 'COURT_MANAGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only managers or court managers can complete any booking';
    END IF;

    IF v_role = 'COURT_MANAGER' THEN
        SELECT c.owner_id INTO v_court_owner
        FROM bookings b
        JOIN courts c ON b.court_id = c.court_id
        WHERE b.booking_id = p_booking_id;
        IF v_court_owner != p_admin_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the owner of this court';
        END IF;
    END IF;

    UPDATE bookings SET status = 'COMPLETED' WHERE booking_id = p_booking_id;
END //
CREATE PROCEDURE sp_add_court(
    IN p_court_name VARCHAR(255),
    IN p_address TEXT,
    IN p_surface VARCHAR(20),
    IN p_size VARCHAR(10),
    IN p_price_per_hour DECIMAL(10,2),
    IN p_price_per_three_hours DECIMAL(10,2),
    IN p_admin_id CHAR(36),
    IN p_image_url TEXT,
    OUT p_court_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_owner_id CHAR(36);

    SELECT role INTO v_role FROM users WHERE user_id = p_admin_id;
    IF v_role NOT IN ('MANAGER', 'COURT_MANAGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only managers or court managers can add courts';
    END IF;

    SET v_owner_id = IF(v_role = 'COURT_MANAGER', p_admin_id, NULL);

    INSERT INTO courts (court_name, address, court_surfaces_type, court_sizes_type,
                        price_per_hour, price_per_three_hours, image_url, owner_id)
    VALUES (p_court_name, p_address, p_surface, p_size, p_price_per_hour,
            p_price_per_three_hours, p_image_url, v_owner_id);
    SELECT court_id INTO p_court_id
    FROM courts
    WHERE court_name = p_court_name
      AND (owner_id = v_owner_id OR (owner_id IS NULL AND v_owner_id IS NULL))
    ORDER BY created_at DESC
    LIMIT 1;
END //
CREATE PROCEDURE sp_update_court(
    IN p_court_id CHAR(36),
    IN p_court_name VARCHAR(255),
    IN p_address TEXT,
    IN p_surface VARCHAR(20),
    IN p_size VARCHAR(10),
    IN p_price_per_hour DECIMAL(10,2),
    IN p_price_per_three_hours DECIMAL(10,2),
    IN p_is_active BOOLEAN,
    IN p_image_url TEXT,
    IN p_admin_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_owner CHAR(36);

    SELECT role INTO v_role FROM users WHERE user_id = p_admin_id;
    IF v_role NOT IN ('MANAGER', 'COURT_MANAGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only managers or court managers can update courts';
    END IF;

    IF v_role = 'COURT_MANAGER' THEN
        SELECT owner_id INTO v_owner FROM courts WHERE court_id = p_court_id;
        IF v_owner != p_admin_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the owner of this court';
        END IF;
    END IF;

    UPDATE courts
    SET court_name = COALESCE(p_court_name, court_name),
        address = COALESCE(p_address, address),
        court_surfaces_type = COALESCE(p_surface, court_surfaces_type),
        court_sizes_type = COALESCE(p_size, court_sizes_type),
        price_per_hour = COALESCE(p_price_per_hour, price_per_hour),
        price_per_three_hours = COALESCE(p_price_per_three_hours, price_per_three_hours),
        is_active = COALESCE(p_is_active, is_active),
        image_url = COALESCE(p_image_url, image_url)
    WHERE court_id = p_court_id;
END //
CREATE PROCEDURE sp_delete_court(
    IN p_court_id CHAR(36),
    IN p_admin_id CHAR(36)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_role VARCHAR(20);
    DECLARE v_owner CHAR(36);
    SELECT role INTO v_role FROM users WHERE user_id = p_admin_id;
    IF v_role NOT IN ('MANAGER', 'COURT_MANAGER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only managers or court managers can delete courts';
    END IF;
    IF v_role = 'COURT_MANAGER' THEN
        SELECT owner_id INTO v_owner FROM courts WHERE court_id = p_court_id;
        IF v_owner != p_admin_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'You are not the owner of this court';
        END IF;
    END IF;
    UPDATE courts SET is_active = FALSE WHERE court_id = p_court_id;
END //
DELIMITER ;