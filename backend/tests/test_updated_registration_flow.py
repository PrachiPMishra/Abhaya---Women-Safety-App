import unittest
from fastapi.testclient import TestClient
from main import app
from database import db_init, get_db_connection


class TestUpdatedRegistrationFlow(unittest.TestCase):
    """Automated Integration Test Suite for Updated Registration & Authentication Flow."""

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        db_init()

    def test_check_phone_existence_flow(self):
        """Verifies phone existence check endpoint returning exists=True for existing phone and exists=False for new phone."""
        # 1. Test existing phone (+15550192831)
        res_existing = self.client.post("/users/check-phone", json={"phone_number": "+15550192831"})
        self.assertEqual(res_existing.status_code, 200)
        data_exist = res_existing.json()
        self.assertTrue(data_exist["exists"])
        self.assertIsNotNone(data_exist["user"])

        # 2. Test new phone (+15559990000)
        res_new = self.client.post("/users/check-phone", json={"phone_number": "+15559990000"})
        self.assertEqual(res_new.status_code, 200)
        data_new = res_new.json()
        self.assertFalse(data_new["exists"])
        self.assertIsNone(data_new["user"])

    def test_profile_creation_with_dob_email_and_backup_codes(self):
        """Verifies user profile registration persisting personal details, 1-3 trusted contacts with email, and primary/backup safety codes."""
        headers = {"Authorization": "Bearer token_usr_new_01"}
        payload = {
            "phone_number": "+15558887777",
            "full_name": "New Safety User",
            "dob": "1998-05-20",
            "full_address": "456 Guard Street, Suite 10",
            "email": "newuser@example.com",
            "activation_code": "88+88",
            "deactivation_code": "22+22",
            "backup_activation_code": "8888",
            "backup_deactivation_code": "2222",
            "trusted_contacts": [
                {"name": "Guardian 1", "phone_number": "+15551112222", "email": "g1@example.com"},
                {"name": "Guardian 2", "phone_number": "+15553334444", "email": "g2@example.com"},
            ],
        }

        res = self.client.post("/users/profile", json=payload, headers=headers)
        self.assertEqual(res.status_code, 201)
        data = res.json()
        self.assertEqual(data["full_name"], "New Safety User")
        self.assertEqual(data["dob"], "1998-05-20")
        self.assertEqual(data["activation_code"], "88+88")
        self.assertEqual(data["backup_activation_code"], "8888")

        # Check triggers endpoint
        res_trig = self.client.get("/users/triggers", headers=headers)
        self.assertEqual(res_trig.status_code, 200)
        trig_data = res_trig.json()
        self.assertEqual(trig_data["activation_code"], "88+88")
        self.assertEqual(trig_data["backup_activation_code"], "8888")


if __name__ == "__main__":
    unittest.main()
