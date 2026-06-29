from supabase import create_client
from dotenv import load_dotenv
import os
import bcrypt
import datetime
import io
import time
import uuid
from PIL import Image
import pymysql
import sys
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(os.path.dirname(current_dir))
if parent_dir not in sys.path:
    sys.path.append(parent_dir)

from config.db import get_mysql_connection, supabase_storage
load_dotenv()

def register(username, password, phone_number, role='CUSTOMER'):
    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            sql = """INSERT INTO users (username, password_hash, phone_number, role, is_active)
                     VALUES (%s, %s, %s, %s, %s)"""
            cur.execute(sql, (username, hashed, phone_number, role, True))
            conn.commit()
            return {"success": True, "data": {"username": username}}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def login(username, password):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM users WHERE username = %s", (username,))
            user = cur.fetchone()
            if not user:
                return {"error": "User not found"}
            if not user.get("is_active"):
                return {"error": "Account is deactivated"}
            if not bcrypt.checkpw(password.encode(), user['password_hash'].encode()):
                return {"error": "Invalid password"}
            cur.execute("UPDATE users SET last_login = %s WHERE user_id = %s",
                        (datetime.datetime.now(datetime.timezone.utc).isoformat(), user['user_id']))
            conn.commit()
            user.pop("password_hash", None)
            return {"success": True, "user": user}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def book_court(user_id, court_id, start_time, end_time):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_book_court', (user_id, court_id, start_time, end_time))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def cancel_booking_customer(booking_id, user_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_cancel_booking_customer', (booking_id, user_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def cancel_booking_admin(booking_id, admin_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_cancel_booking_powerfull', (booking_id, admin_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def complete_booking_admin(booking_id, admin_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_complete_booking', (booking_id, admin_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def approve_booking(booking_id, admin_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_approve_booking', (booking_id, admin_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def reject_booking(booking_id, admin_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_reject_booking', (booking_id, admin_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def upload_court_image(file_path, court_id):
    try:
        img = Image.open(file_path)
        if img.mode == 'RGBA':
            img = img.convert('RGB')
        img.thumbnail((800, 800))
        buffer = io.BytesIO()
        img.save(buffer, format='JPEG', quality=85)
        buffer.seek(0)
        unique_id = uuid.uuid4().hex[:8]
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        file_name = f"court_{court_id}_{timestamp}_{unique_id}.jpg"
        res = supabase_storage.storage.from_("court_images").upload(
            file_name,
            buffer.getvalue(),
            {"content-type": "image/jpeg"}
        )
        if hasattr(res, 'error') and res.error:
            return {"error": str(res.error)}
        public_url = supabase_storage.storage.from_("court_images").get_public_url(file_name)
        return {"success": True, "url": public_url}
    except Exception as e:
        return {"error": str(e)}
def add_court(court_name, address, surface, size, price_hour, price_3h, image_path, admin_id):
    try:
        if price_3h <= price_hour:
            return {"error": "3-hour price must be greater than 1-hour price"}
        conn = get_mysql_connection()
        try:
            with conn.cursor() as cur:
                cur.callproc(
                    'sp_add_court',
                    (court_name, address, surface, size, price_hour, price_3h, admin_id, None, None)
                )
                conn.commit()
                cur.execute("SELECT @_sp_add_court_8 AS court_id")
                row = cur.fetchone()
                if not row or not row.get('court_id'):
                    return {"error": "Không thể lấy court_id từ stored procedure"}
                court_id = row['court_id']

                if image_path:
                    upload_result = upload_court_image(image_path, court_id)
                    if upload_result.get("error"):
                        cur.execute("DELETE FROM courts WHERE court_id = %s", (court_id,))
                        conn.commit()
                        return {"error": f"Upload ảnh thất bại: {upload_result['error']}"}
                    image_url = upload_result["url"]
                    cur.execute("UPDATE courts SET image_url = %s WHERE court_id = %s", (image_url, court_id))
                    conn.commit()

                return {"success": True, "court_id": court_id}
        except pymysql.MySQLError as e:
            return {"error": str(e)}
        finally:
            conn.close()
    except Exception as e:
        return {"error": str(e)}
def update_court(court_id, court_name, address, surface, size, price_hour, price_3h, is_active, image_url, admin_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_update_court', (court_id, court_name, address, surface, size, price_hour, price_3h, is_active, image_url, admin_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def delete_court(court_id, admin_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_delete_court', (court_id, admin_id))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_available_courts():
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM view_available_courts")
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_booking_history(user_id):
    return search_bookings(user_id=user_id)

def get_admin_dashboard_stats():
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM view_admin_dashboard")
            data = cur.fetchone()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_all_bookings(owner_id=None):
    return search_bookings(owner_id=owner_id)

def calculate_cost(court_id, start_time, end_time):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT fn_calculate_booking_cost(%s, %s, %s) AS cost", (court_id, start_time, end_time))
            result = cur.fetchone()
            return {"success": True, "data": result['cost']}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def search_bookings(user_id=None, from_date=None, to_date=None, status=None, court_id=None, owner_id=None):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_search_bookings', (user_id, from_date, to_date, status, court_id, owner_id))
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def filter_courts(surface=None, size=None, min_price=None, max_price=None, is_free=None):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_filter_courts', (surface, size, min_price, max_price, is_free))
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_court_by_id(court_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM courts WHERE court_id = %s", (court_id,))
            court = cur.fetchone()
            if not court:
                return {"error": "Court not found"}
            if court.get('owner_id'):
                cur.execute("SELECT phone_number FROM users WHERE user_id = %s", (court['owner_id'],))
                owner = cur.fetchone()
                court['owner_phone'] = owner['phone_number'] if owner else None
            else:
                court['owner_phone'] = None
            return {"success": True, "data": court}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_court_schedule(court_id, date):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_get_court_schedule', (court_id, date))
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_daily_revenue(from_date=None, to_date=None, owner_id=None):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_daily_revenue', (from_date, to_date, owner_id))
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_top_courts(limit=10, owner_id=None):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.callproc('sp_top_courts', (limit, owner_id))
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def get_notifications(user_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM notifications WHERE user_id = %s ORDER BY created_at DESC", (user_id,))
            data = cur.fetchall()
            return {"success": True, "data": data}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()

def mark_notification_read(notification_id):
    conn = get_mysql_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE notifications SET is_read = TRUE WHERE notification_id = %s", (notification_id,))
            conn.commit()
            return {"success": True}
    except pymysql.MySQLError as e:
        return {"error": str(e)}
    finally:
        conn.close()