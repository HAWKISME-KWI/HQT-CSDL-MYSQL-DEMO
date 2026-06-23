-- ================================================================
-- CHUẨN BỊ DỮ LIỆU (chạy trước khi bắt đầu từng kịch bản)
-- Reset các giá trị về trạng thái ban đầu
-- ================================================================

-- 1. Reset giá sân về 200000 (dùng cho Dirty Read, Lost Update)
UPDATE courts SET price_per_hour = 200000 WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';

-- 2. Đặt trạng thái booking về PENDING (dùng cho Non-Repeatable Read)
UPDATE bookings SET status = 'PENDING' WHERE booking_id = 'b87b5fcc-6f21-11f1-b688-0ade6101e0c7';

-- 3. Xóa bỏ booking mới thêm vào trước đó (dùng cho Phantom Read) nếu có
-- (giả sử không có booking nào khác ngoài dữ liệu mẫu)
-- Xóa các booking có start_time hôm nay lúc 14h (nếu có)
DELETE FROM bookings WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7' AND start_time >= CURDATE() + INTERVAL 14 HOUR;

-- Kiểm tra số booking hiện tại của sân đó trong ngày hôm nay (để so sánh sau)
SELECT COUNT(*) FROM bookings WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7' AND DATE(start_time) = CURDATE();

-- ================================================================
-- 1. DIRTY READ (Đọc dữ liệu chưa commit)
-- ================================================================

-- CỬA SỔ A
SET autocommit = 0;
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  -- Tùy chọn, nhưng B cần level này
START TRANSACTION;
UPDATE courts SET price_per_hour = 250000 WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
-- Chưa commit. Qua cửa sổ B để kiểm tra.

-- CỬA SỔ B (chạy sau khi A đã UPDATE nhưng chưa COMMIT)
SET autocommit = 0;
SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;   -- BẮT BUỘC để thấy dirty read
START TRANSACTION;
SELECT price_per_hour FROM courts WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
-- Kết quả: 250000 (dù chưa commit) -> DIRTY READ

-- Sau đó, quay lại A và ROLLBACK
ROLLBACK;  -- hoặc COMMIT tùy mục đích

-- Xác nhận giá đã trở lại 200000 (trong B hoặc cửa sổ mới)
SELECT price_per_hour FROM courts WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';

-- ================================================================
-- 2. NON-REPEATABLE READ (Đọc khác nhau trong cùng transaction)
-- ================================================================

-- CỬA SỔ A
SET autocommit = 0;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- Cần level này để xảy ra
START TRANSACTION;
SELECT status FROM bookings WHERE booking_id = 'b87b5fcc-6f21-11f1-b688-0ade6101e0c7';
-- Lần 1: status = PENDING

-- CỬA SỔ B (chạy sau khi A đã đọc lần 1)
SET autocommit = 0;
START TRANSACTION;
UPDATE bookings SET status = 'BOOKED' WHERE booking_id = 'b87b5fcc-6f21-11f1-b688-0ade6101e0c7';
COMMIT;

-- Quay lại CỬA SỔ A, đọc tiếp
SELECT status FROM bookings WHERE booking_id = 'b87b5fcc-6f21-11f1-b688-0ade6101e0c7';
-- Lần 2: status = BOOKED -> khác lần 1 -> NON-REPEATABLE READ

COMMIT;  -- Kết thúc A

-- ================================================================
-- 3. PHANTOM READ (Số lượng dòng thay đổi)
-- ================================================================

-- CỬA SỔ A
SET autocommit = 0;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- Cần level này
START TRANSACTION;
SELECT COUNT(*) FROM bookings WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7' AND DATE(start_time) = CURDATE();
-- Lần 1: ghi lại số lượng (giả sử là 2)

-- CỬA SỔ B (chạy sau)
SET autocommit = 0;
START TRANSACTION;
INSERT INTO bookings (user_id, court_id, start_time, end_time, status)
VALUES ('22665ae3-6ed6-11f1-b688-0ade6101e0c7', '09607ce3-6f22-11f1-b688-0ade6101e0c7',
        CURDATE() + INTERVAL 14 HOUR, CURDATE() + INTERVAL 15 HOUR, 'PENDING');
COMMIT;

-- Quay lại CỬA SỔ A
SELECT COUNT(*) FROM bookings WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7' AND DATE(start_time) = CURDATE();
-- Lần 2: số lượng tăng lên (3) -> PHANTOM READ

COMMIT;  -- Kết thúc A

-- ================================================================
-- 4. LOST UPDATE (Mất cập nhật)
-- ================================================================

-- Reset giá trước khi thực hiện
UPDATE courts SET price_per_hour = 200000 WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';

-- CỬA SỔ A (thực hiện trước, sau đó không commit ngay)
SET autocommit = 0;
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;  -- Có thể dùng bất kỳ level nào thấp hơn SERIALIZABLE
START TRANSACTION;
SELECT price_per_hour INTO @p FROM courts WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
UPDATE courts SET price_per_hour = @p * 1.1 WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
-- A chưa commit. Chuyển sang cửa sổ B.

-- CỬA SỔ B (chạy đồng thời, ngay sau khi A vừa update nhưng chưa commit)
SET autocommit = 0;
START TRANSACTION;
SELECT price_per_hour INTO @p FROM courts WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
-- B đọc được giá cũ 200000 (vì A chưa commit, và isolation level READ COMMITTED nên không thấy 220000)
UPDATE courts SET price_per_hour = @p * 1.1 WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
COMMIT;   -- B commit trước

-- Quay lại A, commit
COMMIT;

-- Kiểm tra giá cuối cùng
SELECT price_per_hour FROM courts WHERE court_id = '09607ce3-6f22-11f1-b688-0ade6101e0c7';
-- Kết quả: 220000 (chỉ tăng 10% một lần) thay vì 242000 -> LOST UPDATE xảy ra.

-- ================================================================
-- KẾT THÚC
-- ================================================================