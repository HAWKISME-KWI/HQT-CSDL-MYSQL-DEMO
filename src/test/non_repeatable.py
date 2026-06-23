# attack_non_repeatable_read.py
import pymysql
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from config.db import get_mysql_connection
BOOKING_ID = "some_booking_id"    
ADMIN_ID = "some_admin_id"        

def non_repeatable_read_demo():
    conn_a = get_mysql_connection()
    conn_a.autocommit(False)
    cur_a = conn_a.cursor()
    conn_b = get_mysql_connection()
    conn_b.autocommit(False)
    cur_b = conn_b.cursor()
    try:
        cur_a.execute("SELECT status FROM bookings WHERE booking_id = %s", (BOOKING_ID,))
        status1 = cur_a.fetchone()['status']
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
            print("Không xảy ra non‑repeatable read (có thể do isolation level cao hơn).")
    finally:
        conn_a.rollback()  # không commit để không ảnh hưởng
        cur_a.close()
        conn_a.close()
        cur_b.close()
        conn_b.close()
if __name__ == "__main__":
    non_repeatable_read_demo()