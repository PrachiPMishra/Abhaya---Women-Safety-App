import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store


class TestPhase10DeactivationProtocol(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        backend_store._sessions.clear()

    def test_deactivation_from_active_state(self):
        # 1. Activate Emergency Session (99+99= while INACTIVE)
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        session_id = res_create.json()["session_id"]
        self.assertEqual(res_create.json()["state"], "active")

        # 2. Deactivate Emergency Session (11+11= while ACTIVE)
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "covert_deactivation_triggered"}, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)
        session_data = res_term.json()["session"]
        self.assertEqual(session_data["session_id"], session_id)
        self.assertEqual(session_data["state"], "inactive")
        self.assertIsNotNone(session_data["ended_at"])
        self.assertEqual(session_data["location_status"], "standby")
        self.assertEqual(session_data["notification_status"], "standby")

    def test_deactivation_from_escalated_state(self):
        # 1. Activate Session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        session_id = res_create.json()["session_id"]

        # 2. Tamper Event -> ACTIVE -> ESCALATED
        self.client.post(f"/sessions/{session_id}/tamper", json={"sensor_type": "accelerometer", "reason": "Impact"}, headers=self.auth_headers)
        res_get_esc = self.client.get(f"/sessions/{session_id}", headers=self.auth_headers)
        self.assertEqual(res_get_esc.json()["state"], "escalated")

        # 3. Deactivate (11+11= while ESCALATED) -> ESCALATED -> INACTIVE
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "covert_deactivation_triggered"}, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)
        self.assertEqual(res_term.json()["session"]["state"], "inactive")

    def test_duplicate_deactivation_rejected(self):
        # Activate and terminate session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        session_id = res_create.json()["session_id"]
        self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11"}, headers=self.auth_headers)

        # Second termination on already INACTIVE session -> 400 Bad Request
        res_term_again = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11"}, headers=self.auth_headers)
        self.assertEqual(res_term_again.status_code, 400)


if __name__ == "__main__":
    unittest.main()
