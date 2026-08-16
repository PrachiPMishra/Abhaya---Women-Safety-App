import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store


class TestPhase12SecurityAudit(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.user_a_headers = {"Authorization": "Bearer token_usr_01"}
        self.user_b_headers = {"Authorization": "Bearer token_usr_02"}
        self.invalid_headers = {"Authorization": "Bearer token_invalid_expired"}
        backend_store._sessions.clear()

    def test_unauthenticated_request_rejected(self):
        # 1. No Authorization header -> 401 Unauthorized
        res_no_auth = self.client.post("/sessions", json={"user_id": "usr_registered_01"})
        self.assertEqual(res_no_auth.status_code, 401)

        res_get_no_auth = self.client.get("/sessions/active")
        self.assertEqual(res_get_no_auth.status_code, 401)

    def test_invalid_bearer_token_rejected(self):
        # Invalid/Expired token -> 401 Unauthorized
        res_invalid = self.client.get("/sessions/active", headers=self.invalid_headers)
        self.assertEqual(res_invalid.status_code, 401)

    def test_session_owner_authorization_enforced(self):
        # User A creates emergency session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.user_a_headers)
        self.assertEqual(res_create.status_code, 201)
        session_id = res_create.json()["session_id"]

        # User B attempts to access User A's session -> 403 Forbidden
        res_user_b_get = self.client.get(f"/sessions/{session_id}", headers=self.user_b_headers)
        self.assertEqual(res_user_b_get.status_code, 403)

        # User B attempts to post location update to User A's session -> 403 Forbidden
        res_user_b_loc = self.client.post(f"/sessions/{session_id}/location", json={"location": {"latitude": 28.6, "longitude": 77.2}}, headers=self.user_b_headers)
        self.assertEqual(res_user_b_loc.status_code, 403)

        # User B attempts to record tamper on User A's session -> 403 Forbidden
        res_user_b_tamper = self.client.post(f"/sessions/{session_id}/tamper", json={"sensor_type": "acc", "reason": "Impact"}, headers=self.user_b_headers)
        self.assertEqual(res_user_b_tamper.status_code, 403)

        # User B attempts to terminate User A's session -> 403 Forbidden
        res_user_b_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11"}, headers=self.user_b_headers)
        self.assertEqual(res_user_b_term.status_code, 403)

    def test_authorized_owner_access_granted(self):
        # User A creates emergency session -> 201 Created
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.user_a_headers)
        session_id = res_create.json()["session_id"]

        # User A fetches own session -> 200 OK
        res_get = self.client.get(f"/sessions/{session_id}", headers=self.user_a_headers)
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(res_get.json()["user_id"], "usr_registered_01")


if __name__ == "__main__":
    unittest.main()
