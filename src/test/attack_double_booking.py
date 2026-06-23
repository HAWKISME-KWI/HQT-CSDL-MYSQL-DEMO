import threading
import time
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from service import db_service

BOOKING_ID = "2e6063e2-6f22-11f1-b688-0ade6101e0c7"   # Booking đang ở trạng thái PENDING
ADMIN_APPROVE = "22665ae3-6ed6-11f1-b688-0ade6101e0c7"              # Admin có quyền approve
ADMIN_REJECT = "f8535db9-6f13-11f1-b688-0ade6101e0c7"               # Admin có quyền reject (có thể khác hoặc cùng)


def approve():
    print(f"[{time.strftime('%H:%M:%S')}] Approve: Bắt đầu approve...")
    res = db_service.approve_booking(BOOKING_ID, ADMIN_APPROVE)
    print(f"[{time.strftime('%H:%M:%S')}] Approve: Kết quả = {res}")

def reject():
    print(f"[{time.strftime('%H:%M:%S')}] Reject: Bắt đầu reject...")
    res = db_service.reject_booking(BOOKING_ID, ADMIN_REJECT)
    print(f"[{time.strftime('%H:%M:%S')}] Reject: Kết quả = {res}")

t1 = threading.Thread(target=approve)
t2 = threading.Thread(target=reject)
t1.start()
t2.start()
t1.join()
t2.join()

print("\n=== KẾT THÚC ===")
print(f"Kiểm tra trạng thái booking {BOOKING_ID} trong DB.")
print(f"Nếu cả hai đều thành công và trạng thái cuối cùng là của thằng chạy sau => Lost Update xảy ra.")