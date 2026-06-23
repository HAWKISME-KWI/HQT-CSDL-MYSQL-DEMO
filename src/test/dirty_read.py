import pymysql
import sys
import os
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
if parent_dir not in sys.path:
    sys.path.append(parent_dir)
from config.db import get_mysql_connection
COURT_ID = "09607ce3-6f22-11f1-b688-0ade6101e0c7"    
NEW_PRICE = 100000

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
        cur_a.execute("SELECT price_per_hour FROM courts WHERE court_id = %s", (COURT_ID,))
        price_after_rollback = cur_a.fetchone()['price_per_hour']
        print(f"[A] Sau rollback, giá trong DB (theo connection A) là: {price_after_rollback}")
        print(f"[B] Vẫn dùng giá {price_b} để tính toán -> gây sai lệch")
    finally:
        cur_a.close()
        conn_a.close()
        cur_b.close()
        conn_b.close()

if __name__ == "__main__":
    dirty_read_demo()