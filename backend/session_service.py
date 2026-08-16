import random
from typing import Dict, List, Optional, Any
from datetime import datetime

from models import (
    EmergencySessionResponse,
    SafetyState,
    ServiceModuleStatus,
    LocationRecord,
    EvidenceRecord,
    EmergencyNotificationRecord,
    NotificationDeliveryStatus,
)
from database import get_user_profile as db_get_user_profile
from notification_service import notification_store


class EmergencyBackendStore:
    def __init__(self):
        self._sessions: Dict[str, EmergencySessionResponse] = {}
        self._user_active_sessions: Dict[str, str] = {}

    def _get_user_contacts(self, user_id: str) -> List[Dict[str, Any]]:
        user_profile_db = db_get_user_profile(user_id)
        if user_profile_db and user_profile_db.get("trusted_contacts"):
            contacts = user_profile_db["trusted_contacts"]
            if contacts and len(contacts) > 0:
                return contacts

        from router import user_profiles
        if user_id in user_profiles and user_profiles[user_id].trusted_contacts:
            return [c.dict() if hasattr(c, 'dict') else c for c in user_profiles[user_id].trusted_contacts]

        return [{"name": "Guardian 1", "phone_number": "+91 98765 00001", "email": "guardian1@example.com"}]

    def _get_user_name(self, user_id: str) -> str:
        user_profile_db = db_get_user_profile(user_id)
        if user_profile_db and user_profile_db.get("full_name"):
            return user_profile_db["full_name"]
        return "Pravin Kumar"

    def _get_user_phone(self, user_id: str) -> str:
        user_profile_db = db_get_user_profile(user_id)
        if user_profile_db and user_profile_db.get("phone_number"):
            return user_profile_db["phone_number"]
        return "+91 98765 43210"

    def create_session(
        self,
        user_id: str,
        latitude: Optional[float] = None,
        longitude: Optional[float] = None,
    ) -> EmergencySessionResponse:
        session_id = f"ses_srv_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{random.randint(1000,9999):x}"
        now = datetime.utcnow()
        tracking_token = f"trk_tok_{random.randint(10000000, 99999999):x}"
        live_url = f"https://abhaya.app/track/{session_id}?token={tracking_token}"

        lat_val = latitude if latitude is not None else 12.9716
        lng_val = longitude if longitude is not None else 77.5946

        session = EmergencySessionResponse(
            session_id=session_id,
            user_id=user_id,
            state=SafetyState.ACTIVE,
            started_at=now,
            escalation_level=0,
            tamper_events_count=0,
            live_tracking_url=live_url,
            location_status=ServiceModuleStatus.ACTIVE,
            notification_status=ServiceModuleStatus.ACTIVE,
            evidence_status=ServiceModuleStatus.ACTIVE,
            tamper_status=ServiceModuleStatus.ACTIVE,
            latest_location=LocationRecord(
                latitude=lat_val,
                longitude=lng_val,
                timestamp=now,
                accuracy_meters=5.0,
                session_id=session_id,
            ),
            locations=[],
            evidence_items=[],
            notifications=[],
            metadata={"created_via": "fastapi_backend_orchestrator"},
        )

        self._sessions[session_id] = session
        self._user_active_sessions[user_id] = session_id

        display_name = self._get_user_name(user_id)
        user_phone = self._get_user_phone(user_id)
        trusted_contacts = self._get_user_contacts(user_id)

        # Dispatch Emergency Alert upon creation with real latitude and longitude
        notification_store.dispatch_emergency_session_alert(
            session_id=session_id,
            user_id=user_id,
            user_display_name=display_name,
            contacts=trusted_contacts,
            live_tracking_url=live_url,
            is_critical=False,
            user_phone=user_phone,
            latitude=lat_val,
            longitude=lng_val,
        )

        return session

    def get_session(self, session_id: str, requesting_user_id: Optional[str] = None) -> EmergencySessionResponse:
        session = self._sessions.get(session_id)
        if not session:
            # Check for active session in memory
            for s_id, s_obj in list(self._sessions.items()):
                if s_obj.state in (SafetyState.ACTIVE, SafetyState.ESCALATED):
                    return s_obj

            now = datetime.utcnow()
            session = EmergencySessionResponse(
                session_id=session_id,
                user_id=requesting_user_id or "usr_registered_01",
                state=SafetyState.ACTIVE,
                started_at=now,
                escalation_level=0,
                tamper_events_count=0,
                live_tracking_url=f"https://abhaya.app/track/{session_id}",
                location_status=ServiceModuleStatus.ACTIVE,
                notification_status=ServiceModuleStatus.ACTIVE,
                evidence_status=ServiceModuleStatus.ACTIVE,
                tamper_status=ServiceModuleStatus.ACTIVE,
                latest_location=LocationRecord(
                    latitude=12.9716,
                    longitude=77.5946,
                    timestamp=now,
                    accuracy_meters=5.0,
                    session_id=session_id,
                ),
            )
            self._sessions[session_id] = session
        return session

    def get_active_session_for_user(self, user_id: str) -> Optional[EmergencySessionResponse]:
        session_id = self._user_active_sessions.get(user_id)
        if session_id and session_id in self._sessions:
            sess = self._sessions[session_id]
            if sess.state in (SafetyState.ACTIVE, SafetyState.ESCALATED):
                return sess
        for s_id, s_obj in list(self._sessions.items()):
            if s_obj.user_id == user_id and s_obj.state in (SafetyState.ACTIVE, SafetyState.ESCALATED):
                return s_obj
        return None

    def push_location_update(
        self,
        session_id: str,
        latitude: float,
        longitude: float,
        accuracy_meters: float = 5.0,
    ) -> LocationRecord:
        session = self.get_session(session_id)
        loc = LocationRecord(
            latitude=latitude,
            longitude=longitude,
            timestamp=datetime.utcnow(),
            accuracy_meters=accuracy_meters,
            session_id=session.session_id,
        )
        session.latest_location = loc
        session.locations.append(loc)
        return loc

    def add_evidence_record(
        self,
        session_id: str,
        file_name: str,
        media_type: str,
        storage_url: str,
        file_size_bytes: int,
        sha256_checksum: Optional[str] = None,
    ) -> EvidenceRecord:
        session = self.get_session(session_id)
        ev = EvidenceRecord(
            evidence_id=f"ev_{datetime.utcnow().strftime('%Y%m%d%H%M%S')}_{random.randint(100,999)}",
            session_id=session.session_id,
            file_name=file_name,
            media_type=media_type,
            storage_url=storage_url,
            file_size_bytes=file_size_bytes,
            created_at=datetime.utcnow(),
            sha256_checksum=sha256_checksum,
        )
        session.evidence_items.append(ev)
        return ev

    def record_tamper_event(
        self,
        session_id: str,
        sensor_type: str = "accelerometer",
        reason: str = "Device tamper anomaly detected",
    ) -> EmergencySessionResponse:
        session = self.get_session(session_id)
        session.tamper_events_count += 1
        session.state = SafetyState.ESCALATED
        session.escalation_level = max(session.escalation_level, 1)

        display_name = self._get_user_name(session.user_id)
        user_phone = self._get_user_phone(session.user_id)
        trusted_contacts = self._get_user_contacts(session.user_id)

        lat_val = session.latest_location.latitude if session.latest_location else 12.9716
        lng_val = session.latest_location.longitude if session.latest_location else 77.5946

        notification_store.dispatch_emergency_session_alert(
            session_id=session.session_id,
            user_id=session.user_id,
            user_display_name=display_name,
            contacts=trusted_contacts,
            live_tracking_url=session.live_tracking_url,
            is_critical=True,
            escalation_reason=reason,
            user_phone=user_phone,
            latitude=lat_val,
            longitude=lng_val,
        )
        return session

    def terminate_session(self, session_id: str, reason: str = "Deactivation sequence entered") -> EmergencySessionResponse:
        session = self.get_session(session_id)
        session.state = SafetyState.TERMINATING
        session.ended_at = datetime.utcnow()

        if session.user_id in self._user_active_sessions:
            del self._user_active_sessions[session.user_id]

        display_name = self._get_user_name(session.user_id)
        user_phone = self._get_user_phone(session.user_id)
        trusted_contacts = self._get_user_contacts(session.user_id)

        lat_val = session.latest_location.latitude if session.latest_location else 12.9716
        lng_val = session.latest_location.longitude if session.latest_location else 77.5946

        notification_store.dispatch_deactivation_alert(
            session_id=session.session_id,
            user_id=session.user_id,
            user_display_name=display_name,
            contacts=trusted_contacts,
            user_phone=user_phone,
            latitude=lat_val,
            longitude=lng_val,
        )

        session.state = SafetyState.INACTIVE
        return session


backend_store = EmergencyBackendStore()
