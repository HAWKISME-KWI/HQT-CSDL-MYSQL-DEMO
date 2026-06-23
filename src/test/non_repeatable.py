import pymysql
import sys
import os
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
if parent_dir not in sys.path:
    sys.path.append(parent_dir)
from config.db import get_mysql_connection
BOOKING_ID = "bc5728e7-6f25-11f1-b688-0ade6101e0c7"    
ADMIN_ID = "22665ae3-6ed6-11f1-b688-0ade6101e0c7"        
import pymysql
import sys
import os
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
if parent_dir not in sys.path:
    sys.path.append(parent_dir)
from config.db import get_mysql_connection
BOOKING_ID = "b87b5fcc-6f21-11f1-b688-0ade6101e0c7"
ADMIN_ID = "22665ae3-6ed6-11f1-b688-0ade6101e0c7"

def non_repeatable_read_demo():
    try:
        conn_a = get_mysql_connection()
        conn_a.autocommit(False)
        cur_a = conn_a.cursor()
        cur_a.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED")
        conn_b = get_mysql_connection()
        conn_b.autocommit(False)
        cur_b = conn_b.cursor()
        cur_a.execute("SELECT status FROM bookings WHERE booking_id = %s", (BOOKING_ID,))
        row = cur_a.fetchone()
        if not row:
            print(f"Không tìm thấy booking có ID: {BOOKING_ID}")
            return
        status1 = row['status']
        print(f"[A] Lần 1: status = {status1}")
        cur_b.execute("UPDATE bookings SET status = 'BOOKED' WHERE booking_id = %s", (BOOKING_ID,))
        conn_b.commit()
        print(f"[B] Đã cập nhật status thành BOOKED và commit")
        cur_a.execute("SELECT status FROM bookings WHERE booking_id = %s", (BOOKING_ID,))
        status2 = cur_a.fetchone()['status']
        print(f"[A] Lần 2: status = {status2}")
        if status1 != status2:
            print("Non‑repeatable read xảy ra: cùng một dòng, giá trị thay đổi.")
        else:
            print("Không xảy ra non‑repeatable read (vẫn còn REPEATABLE READ?)")
    except Exception as e:
        print(f"❗ Lỗi: {e}")
        import traceback
        traceback.print_exc()
    finally:
        try:
            conn_a.rollback()
            cur_a.close()
            conn_a.close()
            cur_b.close()
            conn_b.close()
        except:
            pass

if __name__ == "__main__":
    non_repeatable_read_demo()