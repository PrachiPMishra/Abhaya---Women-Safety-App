import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store


class TestPhase6LocationStreaming(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        backend_store._sessions.clear()

    def test_location_streaming_lifecycle(self):
        # 1. Activate session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        session_id = res_create.json()["session_id"]

        # 2. Stream sequence of GPS location updates
        coordinates = [
            (28.6139, 77.2090, 4.0),
            (28.6140, 77.2091, 3.8),
            (28.6142, 77.2093, 3.5),
            (28.6145, 77.2095, 3.2),
        ]

        for lat, lng, acc in coordinates:
            payload = {
                "location": {
                    "latitude": lat,
                    "longitude": lng,
                    "accuracy": acc
                }
            }
            res_stream = self.client.post(f"/sessions/{session_id}/location", json=payload, headers=self.auth_headers)
            self.assertEqual(res_stream.status_code, 200)
            loc_data = res_stream.json()["session"]["latest_location"]
            self.assertEqual(loc_data["latitude"], lat)
            self.assertEqual(loc_data["longitude"], lng)

        # 3. Verify latest session location via GET /sessions/{session_id}
        res_get = self.client.get(f"/sessions/{session_id}", headers=self.auth_headers)
        self.assertEqual(res_get.status_code, 200)
        self.assertEqual(res_get.json()["latest_location"]["latitude"], 28.6145)

        # 4. Terminate session
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11 deactivation"}, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)
        self.assertEqual(res_term.json()["session"]["state"], "inactive")

        # 5. Verify location updates rejected after session termination
        res_post_term = self.client.post(f"/sessions/{session_id}/location", json={"location": {"latitude": 28.6150, "longitude": 77.2099, "accuracy": 3.0}}, headers=self.auth_headers)
        self.assertEqual(res_post_term.status_code, 400)


if __name__ == "__main__":
    unittest.main()
