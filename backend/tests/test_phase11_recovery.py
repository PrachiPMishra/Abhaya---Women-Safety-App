import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store


class TestPhase11StatePersistenceAndRecovery(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        backend_store._sessions.clear()

    def test_active_session_query_and_recovery(self):
        # 1. Activate session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        original_session_id = res_create.json()["session_id"]
        self.assertEqual(res_create.json()["state"], "active")

        # 2. Simulate startup state reconciliation via GET /sessions/active
        res_active = self.client.get("/sessions/active", headers=self.auth_headers)
        self.assertEqual(res_active.status_code, 200)
        recovered_data = res_active.json()

        # Verify same session ID, timestamps, and active state recovered without creating duplicate session ID
        self.assertEqual(recovered_data["session_id"], original_session_id)
        self.assertEqual(recovered_data["state"], "active")
        self.assertEqual(recovered_data["user_id"], "usr_registered_01")

    def test_escalated_session_recovery_preserves_escalation_state(self):
        # 1. Activate session & trigger tamper event (ACTIVE -> ESCALATED)
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        session_id = res_create.json()["session_id"]
        self.client.post(f"/sessions/{session_id}/tamper", json={"sensor_type": "accelerometer", "reason": "Impact"}, headers=self.auth_headers)

        # 2. Query active session on startup reconciliation
        res_active = self.client.get("/sessions/active", headers=self.auth_headers)
        self.assertEqual(res_active.status_code, 200)
        recovered_data = res_active.json()

        # Must recover as ESCALATED, NEVER downgraded to ACTIVE!
        self.assertEqual(recovered_data["session_id"], session_id)
        self.assertEqual(recovered_data["state"], "escalated")
        self.assertEqual(recovered_data["escalation_level"], 1)

    def test_no_active_session_returns_404(self):
        # Query when no session is active -> 404 Not Found
        res_active = self.client.get("/sessions/active", headers=self.auth_headers)
        self.assertEqual(res_active.status_code, 404)

    def test_terminated_session_does_not_return_as_active(self):
        # Activate and terminate
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        session_id = res_create.json()["session_id"]
        self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11"}, headers=self.auth_headers)

        # Query active session -> 404 Not Found (Terminated session ignored)
        res_active = self.client.get("/sessions/active", headers=self.auth_headers)
        self.assertEqual(res_active.status_code, 404)


if __name__ == "__main__":
    unittest.main()
