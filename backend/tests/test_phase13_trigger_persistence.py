import os
import unittest
from fastapi.testclient import TestClient
from main import app
from database import db_init, get_user_profile, get_user_triggers, upsert_user_profile, DB_PATH
from session_service import backend_store
from notification_service import notification_store


class TestPhase13TriggerPersistence(unittest.TestCase):
    """Automated Integration Test Suite for Phase 13 Database-Level Trigger Persistence."""

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        db_init()

    def setUp(self):
        backend_store._sessions.clear()
        notification_store._session_notifications.clear()

        self.auth_headers_usr1 = {"Authorization": "Bearer token_usr_01"}
        self.auth_headers_usr2 = {"Authorization": "Bearer token_usr_02"}

    def test_database_and_users_table_exists(self):
        """Verifies SQLite database file exists and users table is accessible."""
        self.assertTrue(os.path.exists(DB_PATH))
        profile = get_user_profile("usr_registered_01")
        self.assertIsNotNone(profile)
        self.assertEqual(profile["user_id"], "usr_registered_01")
        self.assertIn("activation_code", profile)
        self.assertIn("deactivation_code", profile)

    def test_profile_persistence_and_trigger_storage(self):
        """Verifies storing activation_code and deactivation_code to SQLite database during profile save."""
        payload = {
            "phone_number": "+15559876543",
            "full_name": "Test User One",
            "activation_code": "88+88",
            "deactivation_code": "55*55",
            "trusted_contacts": [
                {"name": "Guardian 1", "phone_number": "+15551112222"}
            ]
        }
        res = self.client.post("/users/profile", json=payload, headers=self.auth_headers_usr1)
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["activation_code"], "88+88")
        self.assertEqual(data["deactivation_code"], "55*55")

        # Verify record persisted directly in SQLite database
        db_rec = get_user_profile("usr_registered_01")
        self.assertIsNotNone(db_rec)
        self.assertEqual(db_rec["activation_code"], "88+88")
        self.assertEqual(db_rec["deactivation_code"], "55*55")

    def test_get_user_triggers_endpoint(self):
        """Verifies GET /users/triggers retrieves current authenticated user's database-persisted safety codes."""
        # Update user triggers
        upsert_user_profile(
            user_id="usr_registered_01",
            phone_number="+15550192831",
            full_name="Pravin Kumar",
            activation_code="44+44",
            deactivation_code="22+22"
        )

        res = self.client.get("/users/triggers", headers=self.auth_headers_usr1)
        self.assertEqual(res.status_code, 200)
        triggers = res.json()
        self.assertEqual(triggers["user_id"], "usr_registered_01")
        self.assertEqual(triggers["activation_code"], "44+44")
        self.assertEqual(triggers["deactivation_code"], "22+22")

    def test_multi_user_trigger_isolation(self):
        """Verifies multi-user isolation: User A and User B maintain separate database trigger codes."""
        # Save User A triggers
        upsert_user_profile(
            user_id="usr_registered_01",
            phone_number="+15550192831",
            full_name="User A",
            activation_code="99+99",
            deactivation_code="11+11"
        )

        # Save User B triggers
        upsert_user_profile(
            user_id="usr_registered_02",
            phone_number="+15550192832",
            full_name="User B",
            activation_code="77+77",
            deactivation_code="33*33"
        )

        # User A query
        res_a = self.client.get("/users/triggers", headers=self.auth_headers_usr1)
        self.assertEqual(res_a.status_code, 200)
        self.assertEqual(res_a.json()["activation_code"], "99+99")
        self.assertEqual(res_a.json()["deactivation_code"], "11+11")

        # User B query
        res_b = self.client.get("/users/triggers", headers=self.auth_headers_usr2)
        self.assertEqual(res_b.status_code, 200)
        self.assertEqual(res_b.json()["activation_code"], "77+77")
        self.assertEqual(res_b.json()["deactivation_code"], "33*33")


if __name__ == "__main__":
    unittest.main()
