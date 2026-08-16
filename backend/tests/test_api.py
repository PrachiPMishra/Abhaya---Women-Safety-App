import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store
from router import user_profiles


class TestAbhayaBackendAPI(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        backend_store._sessions.clear()
        user_profiles.clear()

    def test_health_check(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "online")

    def test_unauthorized_access_rejected(self):
        response = self.client.post("/sessions", json={})
        self.assertEqual(response.status_code, 401)

    def test_user_profile_and_contacts_flow(self):
        # 1. Create User Profile
        profile_payload = {
            "full_name": "Pravin Kumar",
            "phone_number": "+15550192831",
            "emergency_contacts": [
                {
                    "name": "Guardian Contact",
                    "phone": "+15559998888",
                    "relationship": "Family",
                    "is_primary": True
                }
            ]
        }
        res_create = self.client.post("/users/profile", json=profile_payload, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        data = res_create.json()
        self.assertEqual(data["full_name"], "Pravin Kumar")
        self.assertEqual(len(data["emergency_contacts"]), 1)

        # 2. Get Profile
        res_get = self.client.get("/users/profile", headers=self.auth_headers)
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(res_get.json()["phone_number"], "+15550192831")

        # 3. Update Contacts
        update_payload = {
            "emergency_contacts": [
                {
                    "name": "Guardian 1",
                    "phone": "+15551112222",
                    "relationship": "Parent",
                    "is_primary": True
                },
                {
                    "name": "Guardian 2",
                    "phone": "+15553334444",
                    "relationship": "Sibling",
                    "is_primary": False
                }
            ]
        }
        res_update = self.client.put("/users/profile/contacts", json=update_payload, headers=self.auth_headers)
        self.assertEqual(res_update.status_code, 200)
        self.assertEqual(len(res_update.json()["emergency_contacts"]), 2)

    def test_full_session_lifecycle(self):
        # 1. Create session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        data = res_create.json()
        session_id = data["session_id"]
        self.assertEqual(data["state"], "active")
        self.assertEqual(data["escalation_level"], 0)

        # 2. Get session status
        res_get = self.client.get(f"/sessions/{session_id}", headers=self.auth_headers)
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(res_get.json()["session_id"], session_id)

        # 3. Post live location update
        loc_payload = {
            "location": {
                "latitude": 28.6139,
                "longitude": 77.2090,
                "accuracy": 4.5
            }
        }
        res_loc = self.client.post(f"/sessions/{session_id}/location", json=loc_payload, headers=self.auth_headers)
        self.assertEqual(res_loc.status_code, 200)
        self.assertEqual(res_loc.json()["session"]["latest_location"]["latitude"], 28.6139)

        # 4. Post evidence metadata
        ev_payload = {
            "file_name": "evidence_cam_01.mp4",
            "media_type": "video/mp4",
            "storage_url": "https://storage.firebase.google.com/abhaya-evidence/evidence_cam_01.mp4",
            "file_size_bytes": 10485760,
            "sha256_checksum": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        }
        res_ev = self.client.post(f"/sessions/{session_id}/evidence", json=ev_payload, headers=self.auth_headers)
        self.assertEqual(res_ev.status_code, 200)
        self.assertEqual(len(res_ev.json()["session"]["evidence_items"]), 1)

        # 5. Post Tamper Event -> Expect ACTIVE -> ESCALATED transition on SAME session ID
        tamper_payload = {
            "sensor_type": "accelerometer",
            "reason": "Sudden violent impact / device drop detected",
            "severity": "HIGH"
        }
        res_tamper = self.client.post(f"/sessions/{session_id}/tamper", json=tamper_payload, headers=self.auth_headers)
        self.assertEqual(res_tamper.status_code, 200)
        tamper_data = res_tamper.json()["session"]
        self.assertEqual(tamper_data["session_id"], session_id)
        self.assertEqual(tamper_data["state"], "escalated")
        self.assertEqual(tamper_data["escalation_level"], 1)

        # 6. Manual Escalation Increment -> Expect level 2
        res_esc = self.client.post(f"/sessions/{session_id}/escalate", json={"reason": "SOS timer expired"}, headers=self.auth_headers)
        self.assertEqual(res_esc.status_code, 200)
        self.assertEqual(res_esc.json()["session"]["escalation_level"], 2)

        # 7. Terminate Session -> Expect state INACTIVE
        term_payload = {
            "deactivation_code_verified": True,
            "reason": "11+11 covert deactivation code entered"
        }
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json=term_payload, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)
        self.assertEqual(res_term.json()["session"]["state"], "inactive")
        self.assertIsNotNone(res_term.json()["session"]["ended_at"])

    def test_unauthorized_user_cannot_access_other_user_session(self):
        res = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers={"Authorization": "Bearer token_usr_01"})
        session_id = res.json()["session_id"]
        res_user2 = self.client.get(f"/sessions/{session_id}", headers={"Authorization": "Bearer token_usr_02"})
        self.assertEqual(res_user2.status_code, 403)


if __name__ == "__main__":
    unittest.main()
