import unittest
from fastapi.testclient import TestClient
from main import app
from database import db_init, get_db_connection
from session_service import backend_store
from notification_service import notification_store


class TestPhase14RealSmsOtp(unittest.TestCase):
    """Automated Integration Test Suite for Real SMS Gateway OTP Delivery & Verification Engine."""

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        db_init()

    def setUp(self):
        backend_store._sessions.clear()
        notification_store._session_notifications.clear()

    def test_request_and_verify_real_sms_otp_flow(self):
        """Verifies OTP generation, SQLite DB persistence, and exact verification."""
        phone = "+15559876543"

        # 1. Request SMS OTP
        res_req = self.client.post("/users/otp/request", json={"phone_number": phone})
        self.assertEqual(res_req.status_code, 200)
        req_data = res_req.json()
        self.assertTrue(req_data["success"])
        self.assertIn("Verification code sent via SMS", req_data["message"])

        # 2. Check code stored in SQLite database
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT otp_code FROM otp_codes WHERE phone_number = ?", (phone,))
        row = cursor.fetchone()
        conn.close()

        self.assertIsNotNone(row)
        stored_code = row["otp_code"]
        self.assertEqual(len(stored_code), 6)

        # 3. Verify invalid OTP fails
        res_bad = self.client.post("/users/otp/verify", json={"phone_number": phone, "code": "000000"})
        self.assertEqual(res_bad.status_code, 400)

        # 4. Verify valid OTP succeeds
        res_good = self.client.post("/users/otp/verify", json={"phone_number": phone, "code": stored_code})
        self.assertEqual(res_good.status_code, 200)
        self.assertTrue(res_good.json()["success"])

        # 5. Verify single-use code is deleted after verification
        conn2 = get_db_connection()
        cursor2 = conn2.cursor()
        cursor2.execute("SELECT otp_code FROM otp_codes WHERE phone_number = ?", (phone,))
        row2 = cursor2.fetchone()
        conn2.close()
        self.assertIsNone(row2)


if __name__ == "__main__":
    unittest.main()
