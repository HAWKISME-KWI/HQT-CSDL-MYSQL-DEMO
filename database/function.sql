DROP FUNCTION IF EXISTS fn_calculate_booking_cost;
DROP FUNCTION IF EXISTS fn_is_court_available;

DELIMITER //

CREATE FUNCTION fn_calculate_booking_cost(
    p_court_id CHAR(36),
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_price_per_hour DECIMAL(10,2);
    DECLARE v_price_per_3h DECIMAL(10,2);
    DECLARE v_hours DECIMAL(10,2);
    DECLARE v_full_blocks INT;
    DECLARE v_remaining_hours DECIMAL(10,2);
    DECLARE v_cost DECIMAL(10,2);

    SELECT price_per_hour, price_per_three_hours
    INTO v_price_per_hour, v_price_per_3h
    FROM courts
    WHERE court_id = p_court_id;

    SET v_hours = TIMESTAMPDIFF(SECOND, p_start_time, p_end_time) / 3600;
    SET v_full_blocks = FLOOR(v_hours / 3);
    SET v_remaining_hours = v_hours - (v_full_blocks * 3);

    SET v_cost = (v_full_blocks * v_price_per_3h) + (v_remaining_hours * v_price_per_hour);
    RETURN v_cost;
END //

CREATE FUNCTION fn_is_court_available(
    p_court_id CHAR(36),
    p_start TIMESTAMP,
    p_end TIMESTAMP
)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM bookings
    WHERE court_id = p_court_id
      AND status = 'BOOKED'
      AND (start_time < p_end AND end_time > p_start);
    RETURN v_count = 0;
END //

DELIMITER ;