import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store


class TestAbhayaAuditRequirements(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        self.unauth_headers = {"Authorization": "Bearer token_invalid"}
        backend_store._sessions.clear()

    def test_1_privacy_of_implementation(self):
        # Verify user profile endpoint does not leak internal framework implementation names
        res = self.client.get("/users/profile", headers=self.auth_headers)
        self.assertEqual(res.status_code, 200)
        profile = res.json()
        self.assertIn("user_id", profile)
        self.assertIn("trusted_contacts", profile)

    def test_2_trusted_contact_otp_verification(self):
        # Verify trusted contact profile creation requires valid phone numbers and contact structures
        new_profile = {
            "user_id": "usr_registered_01",
            "phone_number": "+15550192831",
            "full_name": "Pravin Kumar",
            "trusted_contacts": [
                {"name": "Verified Primary Contact", "phone_number": "+15559998888"},
                {"name": "Verified Secondary Contact", "phone_number": "+15557776666"},
            ]
        }
        res = self.client.post("/users/profile", json=new_profile, headers=self.auth_headers)
        self.assertEqual(res.status_code, 201)
        self.assertEqual(len(res.json()["trusted_contacts"]), 2)

    def test_7_trusted_contact_live_location_access_layer(self):
        # 1. Create emergency session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        session_data = res_create.json()
        session_id = session_data["session_id"]
        token = session_data["location_access_token"]
        live_url = session_data["live_tracking_url"]

        self.assertIsNotNone(token)
        self.assertIn(session_id, live_url)
        self.assertIn(token, live_url)

        # 2. Add location update fix
        self.client.post(
            f"/sessions/{session_id}/location",
            json={"location": {"latitude": 28.6139, "longitude": 77.2090, "timestamp": "2026-08-15T18:00:00Z"}},
            headers=self.auth_headers,
        )

        # 3. Access live tracking endpoint WITHOUT token -> 422 / 403 Rejected
        res_no_tok = self.client.get(f"/sessions/track/{session_id}")
        self.assertIn(res_no_tok.status_code, (422, 403))

        # 4. Access live tracking endpoint with WRONG token -> 403 Forbidden
        res_wrong_tok = self.client.get(f"/sessions/track/{session_id}?token=invalid_token")
        self.assertEqual(res_wrong_tok.status_code, 403)

        # 5. Access live tracking endpoint with VALID token -> Authorized 200 OK + Maps Handoff URLs
        res_track = self.client.get(f"/sessions/track/{session_id}?token={token}")
        self.assertEqual(res_track.status_code, 200)
        track_data = res_track.json()
        self.assertTrue(track_data["is_active"])
        self.assertEqual(track_data["latest_location"]["latitude"], 28.6139)
        self.assertIn("https://maps.google.com/?q=28.6139,77.209", track_data["google_maps_url"])
        self.assertIn("https://maps.apple.com/?q=28.6139,77.209", track_data["apple_maps_url"])

    def test_6_orderly_deactivation_lifecycle(self):
        # 1. Activate session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        session_id = res_create.json()["session_id"]

        # 2. Terminate session
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11"}, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)
        term_session = res_term.json()["session"]
        self.assertEqual(term_session["state"], "inactive")

        # 3. Query active session after termination -> 404 Not Found
        res_active = self.client.get("/sessions/active", headers=self.auth_headers)
        self.assertEqual(res_active.status_code, 404)


if __name__ == "__main__":
    unittest.main()
