# attack_dirty_read.py
import pymysql
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from config.db import get_mysql_connection
COURT_ID = "some_court_id"    
NEW_PRICE = 150.00

def dirty_read_demo():
    conn_a = get_mysql_connection()
    conn_a.autocommit(False)
    cur_a = conn_a.cursor()
    conn_b = get_mysql_connection()
    conn_b.autocommit(False)
    cur_b = conn_b.cursor()
    cur_b.execute("SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED")
    try:
        cur_a.execute("UPDATE courts SET price_per_hour = %s WHERE court_id = %s", (NEW_PRICE, COURT_ID))
        print(f"[A] Đã cập nhật giá lên {NEW_PRICE} (chưa commit)")
        cur_b.execute("SELECT price_per_hour FROM courts WHERE court_id = %s", (COURT_ID,))
        price_b = cur_b.fetchone()['price_per_hour']
        print(f"[B] Đọc được giá: {price_b} (dirty read)")
        conn_a.rollback()
        print("[A] Rollback, giá trở lại ban đầu")
        print(f"[B] Vẫn dùng giá {price_b} để tính toán -> gây sai lệch")
    finally:
        cur_a.close()
        conn_a.close()
        cur_b.close()
        conn_b.close()

if __name__ == "__main__":
    dirty_read_demo()