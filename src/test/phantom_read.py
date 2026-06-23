import pymysql
import datetime
import sys
import os
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
if parent_dir not in sys.path:
    sys.path.append(parent_dir)
from config.db import get_mysql_connection
COURT_ID = "09607ce3-6f22-11f1-b688-0ade6101e0c7"
USER_ID = "22665ae3-6ed6-11f1-b688-0ade6101e0c7"   
TODAY = datetime.date.today()
START_TIME = datetime.datetime(TODAY.year, TODAY.month, TODAY.day, 15, 0, 0)
END_TIME = datetime.datetime(TODAY.year, TODAY.month, TODAY.day, 16, 0, 0)
def phantom_read_demo():
    conn_a = get_mysql_connection()
    conn_a.autocommit(False)
    cur_a = conn_a.cursor()
    cur_a.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED")
    conn_b = get_mysql_connection()
    conn_b.autocommit(False)
    cur_b = conn_b.cursor()
    try:
        cur_a.execute("""
            SELECT COUNT(*) AS cnt FROM bookings
            WHERE court_id = %s AND DATE(start_time) = %s
        """, (COURT_ID, TODAY))
        count1 = cur_a.fetchone()['cnt']
        print(f"[A] Lần 1: số booking = {count1}")
        cur_b.callproc('sp_book_court', (USER_ID, COURT_ID, START_TIME, END_TIME))
        conn_b.commit()
        print(f"[B] Đã thêm booking mới cho sân {COURT_ID} vào ngày {TODAY}")
        cur_a.execute("""
            SELECT COUNT(*) AS cnt FROM bookings
            WHERE court_id = %s AND DATE(start_time) = %s
        """, (COURT_ID, TODAY))
        count2 = cur_a.fetchone()['cnt']
        print(f"[A] Lần 2: số booking = {count2}")

        if count1 != count2:
            print("Phantom read xảy ra: số dòng thay đổi (ảo).")
        else:
            print("Không xảy ra phantom read (có thể do isolation level SERIALIZABLE).")
    finally:
        conn_a.rollback()
        cur_a.close()
        conn_a.close()
        cur_b.close()
        conn_b.close()
if __name__ == "__main__":
    phantom_read_demo()