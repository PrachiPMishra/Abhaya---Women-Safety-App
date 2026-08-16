import sys
import os
import unittest
from fastapi.testclient import TestClient

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import app
from session_service import backend_store


class TestPhase8EvidenceSubsystem(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        self.auth_headers = {"Authorization": "Bearer token_usr_01"}
        backend_store._sessions.clear()

    def test_evidence_metadata_ingestion_flow(self):
        # 1. Activate session
        res_create = self.client.post("/sessions", json={"user_id": "usr_registered_01"}, headers=self.auth_headers)
        self.assertEqual(res_create.status_code, 201)
        session_id = res_create.json()["session_id"]

        # 2. Ingest metadata for silent camera snapshot
        photo_payload = {
            "file_name": "evidence_cam_01.jpg",
            "media_type": "image/jpeg",
            "storage_url": "https://storage.googleapis.com/abhaya-evidence/evidence_cam_01.jpg",
            "file_size_bytes": 245000,
            "sha256_checksum": "a8f5f167f44f4964e6c998dee827110c"
        }
        res_photo = self.client.post(f"/sessions/{session_id}/evidence", json=photo_payload, headers=self.auth_headers)
        self.assertEqual(res_photo.status_code, 200)
        items_1 = res_photo.json()["session"]["evidence_items"]
        self.assertEqual(len(items_1), 1)
        self.assertEqual(items_1[0]["file_name"], "evidence_cam_01.jpg")

        # 3. Ingest metadata for ambient audio clip
        audio_payload = {
            "file_name": "evidence_mic_02.aac",
            "media_type": "audio/aac",
            "storage_url": "https://storage.googleapis.com/abhaya-evidence/evidence_mic_02.aac",
            "file_size_bytes": 1048576,
            "sha256_checksum": "7c9e6679f3977d4daee0358a7d93ac3a"
        }
        res_audio = self.client.post(f"/sessions/{session_id}/evidence", json=audio_payload, headers=self.auth_headers)
        self.assertEqual(res_audio.status_code, 200)
        items_2 = res_audio.json()["session"]["evidence_items"]
        self.assertEqual(len(items_2), 2)
        self.assertEqual(items_2[1]["media_type"], "audio/aac")

        # 4. Verify session owner authorization (User 2 rejected)
        res_user2 = self.client.post(f"/sessions/{session_id}/evidence", json=photo_payload, headers={"Authorization": "Bearer token_usr_02"})
        self.assertEqual(res_user2.status_code, 403)

        # 5. Terminate session
        res_term = self.client.post(f"/sessions/{session_id}/terminate", json={"reason": "11+11 deactivation"}, headers=self.auth_headers)
        self.assertEqual(res_term.status_code, 200)

        # 6. Verify evidence metadata ingestion rejected once session is INACTIVE
        res_post_term = self.client.post(f"/sessions/{session_id}/evidence", json=photo_payload, headers=self.auth_headers)
        self.assertEqual(res_post_term.status_code, 400)


if __name__ == "__main__":
    unittest.main()
