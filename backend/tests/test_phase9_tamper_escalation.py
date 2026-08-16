import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store
from router import user_profiles
from notification_service import notification_store


class TestPhase9TamperEscalation(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        backend_store._sessions.clear()
        user_profiles.clear()
        notification_store._session_notifications.clear()

    def test_tamper_escalation_flow(self):
        # 1. Setup User Profile
        profile_payload = {
            "full_name": "Pravin Kumar",
            "phone_number": "+15550192831",
            "emergency_contacts": [
                {"name": "Guardian Contact 1", "phone": "+15559998888"}
            ]
        }
        self.client.post("/users/profile", json=profile_payload, headers=self.auth_headers)

        # 2. Activate Emergency Session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        session_id = res_create.json()["session_id"]
        self.assertEqual(res_create.json()["state"], "active")

        # 3. Simulate Device Tamper Anomaly -> Mutates State to ESCALATED
        tamper_payload = {
            "sensor_type": "power_off_attempt",
            "reason": "Attempted Power-Off / Device Shutdown during active SOS Mode"
        }
        res_tamper = self.client.post(f"/sessions/{session_id}/tamper", json=tamper_payload, headers=self.auth_headers)
        self.assertEqual(res_tamper.status_code, 200)
        session_data = res_tamper.json()["session"]

        # Verify Session ID retained and State mutated to ESCALATED
        self.assertEqual(session_data["session_id"], session_id)
        self.assertEqual(session_data["state"], "escalated")
        self.assertEqual(session_data["escalation_level"], 1)

        # 4. Verify High-Priority Critical Escalation Alert Generated
        notifications = session_data["notifications"]
        self.assertGreaterEqual(len(notifications), 2)
        crit_notif = notifications[-1]
        self.assertEqual(crit_notif["title"], "ABHAYA CRITICAL ESCALATION ALERT")
        self.assertIn("ABHAYA CRITICAL ESCALATION ALERT", crit_notif["body"])
        self.assertIn("SITUATION ESCALATED: Tampering or power-off attempt detected for Pravin Kumar", crit_notif["body"])
        self.assertIn("Immediate help must reach quickly. Police informed.", crit_notif["body"])

        # 5. Verify Location & Evidence streaming CONTINUE normally during ESCALATED state
        res_loc = self.client.post(f"/sessions/{session_id}/location", json={"location": {"latitude": 28.6145, "longitude": 77.2095, "accuracy": 3.0}}, headers=self.auth_headers)
        self.assertEqual(res_loc.status_code, 200)
        self.assertEqual(res_loc.json()["session"]["state"], "escalated")

        # 6. Deactivation (`11+11=`) terminates ESCALATED session cleanly to INACTIVE
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11 deactivation"}, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)
        self.assertEqual(res_term.json()["session"]["state"], "inactive")


if __name__ == "__main__":
    unittest.main()
