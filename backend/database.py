import sqlite3
import os
import random
from datetime import datetime, timedelta
from typing import Optional, Dict, Any, List

DB_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "abhaya.db"))


def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def db_init():
    """Initializes the ABHAYA project SQLite database with users, trusted_contacts, otp_codes, and sos_dispatches tables."""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 1. Users Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            phone_number TEXT UNIQUE NOT NULL,
            full_name TEXT NOT NULL,
            dob TEXT,
            full_address TEXT,
            email TEXT,
            activation_code TEXT NOT NULL,
            deactivation_code TEXT NOT NULL,
            backup_activation_code TEXT,
            backup_deactivation_code TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
    """)

    # Check and add missing columns if upgrading existing table
    cursor.execute("PRAGMA table_info(users)")
    existing_cols = [row["name"] for row in cursor.fetchall()]
    if "dob" not in existing_cols:
        cursor.execute("ALTER TABLE users ADD COLUMN dob TEXT")
    if "full_address" not in existing_cols:
        cursor.execute("ALTER TABLE users ADD COLUMN full_address TEXT")
    if "email" not in existing_cols:
        cursor.execute("ALTER TABLE users ADD COLUMN email TEXT")
    if "backup_activation_code" not in existing_cols:
        cursor.execute("ALTER TABLE users ADD COLUMN backup_activation_code TEXT")
    if "backup_deactivation_code" not in existing_cols:
        cursor.execute("ALTER TABLE users ADD COLUMN backup_deactivation_code TEXT")

    # 2. Trusted Contacts Table (Min 1, Max 3 per user)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS trusted_contacts (
            contact_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            phone_number TEXT NOT NULL,
            email TEXT,
            is_verified INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            FOREIGN KEY(user_id) REFERENCES users(user_id)
        );
    """)

    # 3. OTP Codes Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS otp_codes (
            phone_number TEXT PRIMARY KEY,
            otp_code TEXT NOT NULL,
            created_at TEXT NOT NULL,
            expires_at TEXT NOT NULL
        );
    """)

    # 4. SOS Dispatches Table for Trusted Contact Terminal Monitor
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS sos_dispatches (
            dispatch_id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            recipient_name TEXT NOT NULL,
            recipient_phone TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            is_critical INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
        );
    """)
    
    # Seed default user if not present
    cursor.execute("SELECT user_id FROM users WHERE user_id = ?", ("usr_registered_01",))
    if not cursor.fetchone():
        now_str = datetime.utcnow().isoformat()
        cursor.execute("""
            INSERT INTO users (user_id, phone_number, full_name, dob, full_address, email, activation_code, deactivation_code, backup_activation_code, backup_deactivation_code, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            "usr_registered_01",
            "+15550192831",
            "Pravin Kumar",
            "1995-08-15",
            "123 Safety Ave, City, Country",
            "pravin@example.com",
            "99+99",
            "11+11",
            "9999",
            "1111",
            now_str,
            now_str,
        ))

        cursor.execute("""
            INSERT OR IGNORE INTO trusted_contacts (contact_id, user_id, name, phone_number, email, is_verified, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, ("cnt_01", "usr_registered_01", "Guardian Contact 1", "+15559998888", "guardian1@example.com", 1, now_str))
    
    conn.commit()
    conn.close()


def store_pending_otp(phone_number: str, otp_code: str, ttl_minutes: int = 10):
    """Stores generated OTP code in SQLite database with expiration timestamp."""
    conn = get_db_connection()
    cursor = conn.cursor()
    now = datetime.utcnow()
    expires_at = (now + timedelta(minutes=ttl_minutes)).isoformat()
    now_str = now.isoformat()

    cursor.execute("""
        INSERT INTO otp_codes (phone_number, otp_code, created_at, expires_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(phone_number) DO UPDATE SET
            otp_code = excluded.otp_code,
            created_at = excluded.created_at,
            expires_at = excluded.expires_at
    """, (phone_number, otp_code, now_str, expires_at))

    conn.commit()
    conn.close()


def verify_db_otp(phone_number: str, code: str) -> bool:
    """Validates user-entered OTP code against SQLite database record and checks expiration."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT otp_code, expires_at FROM otp_codes WHERE phone_number = ?", (phone_number,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return False

    stored_code = row["otp_code"]
    expires_at = datetime.fromisoformat(row["expires_at"])

    if datetime.utcnow() > expires_at:
        cursor.execute("DELETE FROM otp_codes WHERE phone_number = ?", (phone_number,))
        conn.commit()
        conn.close()
        return False

    if stored_code == code.strip():
        cursor.execute("DELETE FROM otp_codes WHERE phone_number = ?", (phone_number,))
        conn.commit()
        conn.close()
        return True

    conn.close()
    return False


def check_user_exists(phone_number: str) -> Optional[Dict[str, Any]]:
    """Checks if a user already exists by phone number in the SQLite users database."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE phone_number = ?", (phone_number,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return None

    user_dict = dict(row)
    cursor.execute("SELECT * FROM trusted_contacts WHERE user_id = ?", (user_dict["user_id"],))
    contacts = [dict(c) for c in cursor.fetchall()]
    user_dict["trusted_contacts"] = contacts
    user_dict["emergency_contacts"] = contacts

    conn.close()
    return user_dict


def upsert_user_profile(
    user_id: str,
    phone_number: str,
    full_name: str,
    dob: Optional[str] = None,
    full_address: Optional[str] = None,
    email: Optional[str] = None,
    activation_code: str = "99+99",
    deactivation_code: str = "11+11",
    backup_activation_code: Optional[str] = "9999",
    backup_deactivation_code: Optional[str] = "1111",
    trusted_contacts: Optional[List[Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    """Persists user profile, personal details, backup codes, and trusted contacts to database."""
    conn = get_db_connection()
    cursor = conn.cursor()
    now_str = datetime.utcnow().isoformat()

    cursor.execute("SELECT created_at FROM users WHERE user_id = ?", (user_id,))
    existing = cursor.fetchone()

    if existing:
        created_at = existing["created_at"]
        cursor.execute("""
            UPDATE users SET
                phone_number = ?,
                full_name = ?,
                dob = ?,
                full_address = ?,
                email = ?,
                activation_code = ?,
                deactivation_code = ?,
                backup_activation_code = ?,
                backup_deactivation_code = ?,
                updated_at = ?
            WHERE user_id = ?
        """, (
            phone_number, full_name, dob, full_address, email,
            activation_code, deactivation_code, backup_activation_code, backup_deactivation_code,
            now_str, user_id
        ))
    else:
        created_at = now_str
        cursor.execute("""
            INSERT INTO users (user_id, phone_number, full_name, dob, full_address, email, activation_code, deactivation_code, backup_activation_code, backup_deactivation_code, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            user_id, phone_number, full_name, dob, full_address, email,
            activation_code, deactivation_code, backup_activation_code, backup_deactivation_code,
            created_at, now_str
        ))

    if trusted_contacts is not None:
        cursor.execute("DELETE FROM trusted_contacts WHERE user_id = ?", (user_id,))
        for idx, contact in enumerate(trusted_contacts):
            contact_id = f"cnt_{user_id}_{idx+1}"
            c_name = contact.get("full_name") or contact.get("name") or "Trusted Contact"
            c_phone = contact.get("phone_number") or contact.get("phone") or "+15559998888"
            c_email = contact.get("email") or ""
            cursor.execute("""
                INSERT INTO trusted_contacts (contact_id, user_id, name, phone_number, email, is_verified, created_at)
                VALUES (?, ?, ?, ?, ?, 1, ?)
            """, (contact_id, user_id, c_name, c_phone, c_email, now_str))

    conn.commit()
    conn.close()
    return get_user_profile(user_id) or {}


def store_sos_dispatch(session_id: str, recipient_name: str, recipient_phone: str, title: str, body: str, is_critical: bool = False):
    """Stores dispatched SOS SMS record for real-time trusted contact terminal monitoring."""
    conn = get_db_connection()
    cursor = conn.cursor()
    now_str = datetime.utcnow().isoformat()
    dispatch_id = f"disp_{int(datetime.utcnow().timestamp()*1000)}_{random.randint(100, 999)}"
    cursor.execute("""
        INSERT INTO sos_dispatches (dispatch_id, session_id, recipient_name, recipient_phone, title, body, is_critical, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (dispatch_id, session_id, recipient_name, recipient_phone, title, body, 1 if is_critical else 0, now_str))
    conn.commit()
    conn.close()


def get_recent_sos_dispatches(limit: int = 10) -> List[Dict[str, Any]]:
    """Retrieves recent SOS SMS dispatches."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM sos_dispatches ORDER BY created_at DESC LIMIT ?", (limit,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_user_profile(user_id: str) -> Optional[Dict[str, Any]]:
    """Retrieves user record and trusted contacts from users table."""
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE user_id = ?", (user_id,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return None

    user_dict = dict(row)
    cursor.execute("SELECT * FROM trusted_contacts WHERE user_id = ?", (user_id,))
    contacts = [dict(c) for c in cursor.fetchall()]
    user_dict["trusted_contacts"] = contacts
    user_dict["emergency_contacts"] = contacts
    conn.close()

    return user_dict


def get_user_triggers(user_id: str) -> Dict[str, str]:
    """Retrieves authenticated user's activation, deactivation, and backup codes from database."""
    user = get_user_profile(user_id)
    if user:
        return {
            "activation_code": user.get("activation_code", "99+99"),
            "deactivation_code": user.get("deactivation_code", "11+11"),
            "backup_activation_code": user.get("backup_activation_code", "9999"),
            "backup_deactivation_code": user.get("backup_deactivation_code", "1111"),
        }
    return {
        "activation_code": "99+99",
        "deactivation_code": "11+11",
        "backup_activation_code": "9999",
        "backup_deactivation_code": "1111",
    }


db_init()
