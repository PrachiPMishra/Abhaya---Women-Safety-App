from typing import List, Dict, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from models import (
    UserProfileCreate,
    UserProfileResponse,
    UserTriggersResponse,
    CheckPhoneRequest,
    CheckPhoneResponse,
    RequestOtpPayload,
    VerifyOtpPayload,
    CreateSessionRequest,
    EmergencySessionResponse,
    UpdateLocationRequest,
    EvidencePayload,
    EvidenceRecord,
    TamperPayload,
    EscalateSessionRequest,
    TerminateSessionRequest,
    AckNotificationDeliveryRequest,
    EmergencyNotificationRecord,
    LiveTrackingResponse,
    StandardMessageResponse,
    SafetyState,
)
from auth import get_current_user
from database import (
    upsert_user_profile,
    get_user_profile as db_get_user_profile,
    get_user_triggers as db_get_user_triggers,
    check_user_exists as db_check_user_exists,
)
from otp_service import sms_otp_service
from session_service import backend_store
from notification_service import notification_store

router = APIRouter(prefix="/sessions", tags=["Emergency Sessions"])
user_router = APIRouter(prefix="/users", tags=["Users & Profiles"])

# In-memory database cache of registered user profiles
user_profiles: Dict[str, UserProfileResponse] = {
    "usr_registered_01": UserProfileResponse(
        user_id="usr_registered_01",
        phone_number="+15550192831",
        full_name="Pravin Kumar",
        dob="1995-08-15",
        full_address="123 Safety Ave, City, Country",
        email="pravin@example.com",
        activation_code="99+99",
        deactivation_code="11+11",
        backup_activation_code="9999",
        backup_deactivation_code="1111",
        trusted_contacts=[
            {"name": "Guardian Contact 1", "phone_number": "+15559998888", "email": "guardian1@example.com"},
        ],
        emergency_contacts=[
            {"name": "Guardian Contact 1", "phone_number": "+15559998888", "email": "guardian1@example.com"},
        ],
        created_at=datetime.utcnow(),
    )
}


# ============================================================================
# USER PHONE EXISTENCE CHECK & REAL SMS OTP ENDPOINTS
# ============================================================================

@user_router.post("/check-phone", response_model=CheckPhoneResponse, status_code=status.HTTP_200_OK)
def check_phone_existence(payload: CheckPhoneRequest):
    """Checks if target phone number already exists in SQLite users database."""
    user = db_check_user_exists(payload.phone_number)
    if user:
        return CheckPhoneResponse(exists=True, user=user)
    return CheckPhoneResponse(exists=False, user=None)


@user_router.post("/otp/request", status_code=status.HTTP_200_OK)
def request_real_sms_otp(payload: RequestOtpPayload):
    """Generates a random 6-digit OTP, stores in SQLite database, and dispatches real SMS to recipient phone number."""
    result = sms_otp_service.request_otp(payload.phone_number)
    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.get("message", "Failed to dispatch SMS OTP"),
        )
    return result


@user_router.post("/otp/verify", status_code=status.HTTP_200_OK)
def verify_real_sms_otp(payload: VerifyOtpPayload):
    """Validates entered OTP code against SQLite database for target phone number."""
    result = sms_otp_service.verify_otp(payload.phone_number, payload.code)
    if not result.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.get("message", "Invalid OTP code"),
        )
    return result


# ============================================================================
# USER PROFILE & TRIGGER CODE ENDPOINTS (PERSISTED TO SQLITE DB)
# ============================================================================

@user_router.post("/profile", response_model=UserProfileResponse, status_code=status.HTTP_201_CREATED)
def create_profile(
    profile_data: UserProfileCreate,
    current_user: str = Depends(get_current_user),
):
    """Creates/updates an authenticated ABHAYA user profile with personal details, 1-3 trusted contacts with email, and primary/backup safety codes."""
    contacts = profile_data.trusted_contacts or profile_data.emergency_contacts
    act_code = profile_data.activation_code or "99+99"
    deact_code = profile_data.deactivation_code or "11+11"
    b_act_code = profile_data.backup_activation_code or "9999"
    b_deact_code = profile_data.backup_deactivation_code or "1111"

    db_rec = upsert_user_profile(
        user_id=current_user,
        phone_number=profile_data.phone_number or "+15550192831",
        full_name=profile_data.full_name or "Pravin Kumar",
        dob=profile_data.dob,
        full_address=profile_data.full_address,
        email=profile_data.email,
        activation_code=act_code,
        deactivation_code=deact_code,
        backup_activation_code=b_act_code,
        backup_deactivation_code=b_deact_code,
        trusted_contacts=contacts,
    )

    profile = UserProfileResponse(
        user_id=current_user,
        phone_number=db_rec["phone_number"],
        full_name=db_rec["full_name"],
        dob=db_rec.get("dob"),
        full_address=db_rec.get("full_address"),
        email=db_rec.get("email"),
        activation_code=db_rec["activation_code"],
        deactivation_code=db_rec["deactivation_code"],
        backup_activation_code=db_rec.get("backup_activation_code", "9999"),
        backup_deactivation_code=db_rec.get("backup_deactivation_code", "1111"),
        trusted_contacts=contacts,
        emergency_contacts=contacts,
        created_at=datetime.utcnow(),
    )
    user_profiles[current_user] = profile
    return profile


@user_router.put("/profile", response_model=UserProfileResponse)
def update_profile(
    profile_data: UserProfileCreate,
    current_user: str = Depends(get_current_user),
):
    """Updates an authenticated ABHAYA user profile and trigger codes in database."""
    return create_profile(profile_data, current_user)


@user_router.put("/profile/contacts", response_model=UserProfileResponse)
def update_profile_contacts(
    profile_data: UserProfileCreate,
    current_user: str = Depends(get_current_user),
):
    """Updates contacts for an authenticated ABHAYA user profile."""
    return create_profile(profile_data, current_user)


@user_router.get("/profile", response_model=UserProfileResponse)
def get_user_profile(current_user: str = Depends(get_current_user)):
    """Fetches the authenticated user profile from SQLite users table."""
    db_rec = db_get_user_profile(current_user)
    if not db_rec:
        db_rec = upsert_user_profile(
            user_id=current_user,
            phone_number="+15550192831",
            full_name="Pravin Kumar",
            activation_code="99+99",
            deactivation_code="11+11",
            backup_activation_code="9999",
            backup_deactivation_code="1111",
        )

    contacts = db_rec.get("trusted_contacts") or [
        {"name": "Guardian Contact 1", "phone_number": "+15559998888", "email": "guardian1@example.com"},
    ]

    return UserProfileResponse(
        user_id=current_user,
        phone_number=db_rec["phone_number"],
        full_name=db_rec["full_name"],
        dob=db_rec.get("dob"),
        full_address=db_rec.get("full_address"),
        email=db_rec.get("email"),
        activation_code=db_rec["activation_code"],
        deactivation_code=db_rec["deactivation_code"],
        backup_activation_code=db_rec.get("backup_activation_code", "9999"),
        backup_deactivation_code=db_rec.get("backup_deactivation_code", "1111"),
        trusted_contacts=contacts,
        emergency_contacts=contacts,
        created_at=datetime.utcnow(),
    )


@user_router.get("/triggers", response_model=UserTriggersResponse)
def get_user_safety_triggers(current_user: str = Depends(get_current_user)):
    """Retrieves authenticated user's primary and backup safety codes from database."""
    triggers = db_get_user_triggers(current_user)
    return UserTriggersResponse(
        user_id=current_user,
        activation_code=triggers["activation_code"],
        deactivation_code=triggers["deactivation_code"],
        backup_activation_code=triggers.get("backup_activation_code", "9999"),
        backup_deactivation_code=triggers.get("backup_deactivation_code", "1111"),
    )


# ============================================================================
# TRUSTED CONTACT SECURE LIVE TRACKING ENDPOINT
# ============================================================================

@router.get("/track/{session_id}", response_model=LiveTrackingResponse)
def get_live_tracking_for_contact(
    session_id: str,
    token: str = Query(..., description="Access token for secure trusted contact location viewing"),
):
    """Secure, session-bound live location access endpoint for verified emergency contacts."""
    session = backend_store._sessions.get(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Emergency session '{session_id}' not found",
        )

    if not session.location_access_token or session.location_access_token != token:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: Invalid location access token for this emergency session",
        )

    lat = session.latest_location.latitude if session.latest_location else 28.6139
    lng = session.latest_location.longitude if session.latest_location else 77.2090

    g_maps_url = f"https://maps.google.com/?q={lat},{lng}"
    a_maps_url = f"https://maps.apple.com/?q={lat},{lng}"

    return LiveTrackingResponse(
        session_id=session_id,
        user_id=session.user_id,
        state=session.state,
        is_active=session.state in (SafetyState.ACTIVE, SafetyState.ESCALATED),
        latest_location=session.latest_location,
        google_maps_url=g_maps_url,
        apple_maps_url=a_maps_url,
        last_updated=datetime.utcnow(),
    )


# ============================================================================
# EMERGENCY SESSION LIFECYCLE ENDPOINTS
# ============================================================================

@router.post("", response_model=EmergencySessionResponse, status_code=status.HTTP_201_CREATED)
def create_emergency_session(
    request: CreateSessionRequest,
    current_user: str = Depends(get_current_user),
):
    """Creates a new Emergency Session."""
    return backend_store.create_session(
        user_id=current_user,
        latitude=request.latitude,
        longitude=request.longitude,
    )


@router.get("/active", response_model=EmergencySessionResponse)
def get_active_emergency_session(current_user: str = Depends(get_current_user)):
    """Startup state reconciliation endpoint querying current active emergency session."""
    active = backend_store.get_active_session_for_user(current_user)
    if not active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active emergency session found for authenticated user",
        )
    active.notifications = notification_store.get_session_notifications(active.session_id)
    return active


@router.get("/{session_id}", response_model=EmergencySessionResponse)
def get_emergency_session(
    session_id: str,
    current_user: str = Depends(get_current_user),
):
    """Fetch status and telemetry data for a specific emergency session."""
    return backend_store.get_session(session_id=session_id, requesting_user_id=current_user)


@router.get("/{session_id}/notifications", response_model=List[EmergencyNotificationRecord])
def get_session_notifications(
    session_id: str,
    current_user: str = Depends(get_current_user),
):
    """Fetch notification logs and FCM recipient delivery states for an emergency session."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    return notification_store.get_session_notifications(session_id)


@router.post("/{session_id}/notifications/ack", response_model=StandardMessageResponse)
def acknowledge_notification_delivery(
    session_id: str,
    payload: AckNotificationDeliveryRequest,
    current_user: str = Depends(get_current_user),
):
    """FCM callback endpoint recording push delivery status updates (DELIVERED/FAILED)."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    updated_record = notification_store.acknowledge_delivery(
        session_id=session_id,
        notification_id=payload.notification_id,
        contact_id=payload.contact_id,
        recipient_phone=payload.recipient_phone,
        status=payload.status,
        error_detail=payload.error_detail or payload.error_message,
    )

    updated_session = backend_store.get_session(session_id, current_user)
    return StandardMessageResponse(
        status="success",
        message=f"Recipient delivery status updated to '{payload.status}'",
        session=updated_session,
    )


@router.post("/{session_id}/location", response_model=StandardMessageResponse)
def update_session_location(
    session_id: str,
    payload: UpdateLocationRequest,
    current_user: str = Depends(get_current_user),
):
    """Streams live GPS coordinates for an active emergency session."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    loc = payload.location
    if isinstance(loc, dict):
        lat = float(loc.get("latitude", 28.6139))
        lng = float(loc.get("longitude", 77.2090))
        ts_val = loc.get("timestamp", datetime.utcnow())
        acc = loc.get("accuracy_meters")
    else:
        lat = float(getattr(loc, "latitude", 28.6139))
        lng = float(getattr(loc, "longitude", 77.2090))
        ts_val = getattr(loc, "timestamp", datetime.utcnow())
        acc = getattr(loc, "accuracy_meters", None)

    ts = datetime.utcnow() if isinstance(ts_val, str) else ts_val

    updated_session = backend_store.add_location_update(
        session_id=session_id,
        latitude=lat,
        longitude=lng,
        timestamp=ts,
        accuracy_meters=acc,
    )

    return StandardMessageResponse(
        status="success",
        message="Location fix appended to active emergency session",
        session=updated_session,
    )


@router.post("/{session_id}/evidence", response_model=StandardMessageResponse)
def record_evidence_metadata(
    session_id: str,
    payload: EvidencePayload,
    current_user: str = Depends(get_current_user),
):
    """Registers evidence metadata (photo/audio upload reference) for an emergency session."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    backend_store.register_evidence_metadata(
        session_id=session_id,
        file_name=payload.file_name,
        media_type=payload.media_type,
        storage_url=payload.storage_url,
        file_size_bytes=payload.file_size_bytes,
        sha256_checksum=payload.sha256_checksum,
    )
    updated_session = backend_store.get_session(session_id, current_user)
    return StandardMessageResponse(
        status="success",
        message="Evidence metadata registered",
        session=updated_session,
    )


@router.post("/{session_id}/tamper", response_model=StandardMessageResponse)
def record_tamper_event(
    session_id: str,
    payload: TamperPayload,
    current_user: str = Depends(get_current_user),
):
    """Registers a tamper anomaly event and mutates session state to ESCALATED."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    updated_session = backend_store.record_tamper_event(
        session_id=session_id,
        sensor_type=payload.sensor_type or "accelerometer",
        reason=payload.reason or "Device tamper anomaly detected",
    )

    return StandardMessageResponse(
        status="escalated",
        message=f"Tamper anomaly recorded. Session '{session_id}' escalated to level {updated_session.escalation_level}",
        session=updated_session,
    )


@router.post("/{session_id}/escalate", response_model=StandardMessageResponse)
def escalate_session(
    session_id: str,
    payload: EscalateSessionRequest,
    current_user: str = Depends(get_current_user),
):
    """Explicitly escalates emergency severity level for an active session."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    updated_session = backend_store.record_tamper_event(
        session_id=session_id,
        sensor_type="manual_trigger",
        reason=payload.reason,
    )

    return StandardMessageResponse(
        status="escalated",
        message=f"Session '{session_id}' escalated",
        session=updated_session,
    )


@router.post("/{session_id}/terminate", response_model=StandardMessageResponse)
def terminate_emergency_session(
    session_id: str,
    payload: TerminateSessionRequest,
    current_user: str = Depends(get_current_user),
):
    """Orderly deactivation of an emergency session."""
    backend_store.get_session(session_id=session_id, requesting_user_id=current_user)
    terminated_session = backend_store.terminate_session(
        session_id=session_id,
        reason=payload.reason,
    )

    return StandardMessageResponse(
        status="terminated",
        message=f"Emergency session '{session_id}' successfully terminated",
        session=terminated_session,
    )
