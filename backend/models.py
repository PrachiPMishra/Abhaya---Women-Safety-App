from typing import List, Optional, Any, Dict
from datetime import datetime
from enum import Enum
from pydantic import BaseModel, Field


class SafetyState(str, Enum):
    INACTIVE = "INACTIVE"
    STARTING = "STARTING"
    ACTIVE = "ACTIVE"
    ESCALATED = "ESCALATED"
    TERMINATING = "TERMINATING"


class ServiceModuleStatus(str, Enum):
    IDLE = "IDLE"
    STARTING = "STARTING"
    ACTIVE = "ACTIVE"
    DEGRADED = "DEGRADED"
    FAILED = "FAILED"


class NotificationDeliveryStatus(str, Enum):
    QUEUED = "QUEUED"
    SENT = "SENT"
    DELIVERED = "DELIVERED"
    FAILED = "FAILED"


NotificationStatusEnum = NotificationDeliveryStatus


class NotificationRecipientRecord(BaseModel):
    contact_id: Optional[str] = "cnt_01"
    name: Optional[str] = "Trusted Contact"
    recipient_name: Optional[str] = "Trusted Contact"
    phone: Optional[str] = "+91 98765 00001"
    recipient_phone: Optional[str] = "+91 98765 00001"
    status: Optional[NotificationDeliveryStatus] = NotificationDeliveryStatus.SENT
    dispatched_at: Optional[datetime] = None


class UserProfileResponse(BaseModel):
    user_id: str
    phone_number: str
    full_name: str
    dob: Optional[str] = None
    full_address: Optional[str] = None
    email: Optional[str] = None
    activation_code: str
    deactivation_code: str
    backup_activation_code: Optional[str] = "9999"
    backup_deactivation_code: Optional[str] = "1111"
    trusted_contacts: List[Dict[str, Any]] = []
    emergency_contacts: List[Dict[str, Any]] = []
    created_at: datetime


class UserTriggersResponse(BaseModel):
    user_id: str
    activation_code: str
    deactivation_code: str
    backup_activation_code: Optional[str] = "9999"
    backup_deactivation_code: Optional[str] = "1111"


class CheckPhoneRequest(BaseModel):
    phone_number: str = Field(..., description="Target mobile phone number to check")


class CheckPhoneResponse(BaseModel):
    exists: bool
    phone_number: str
    user: Optional[Dict[str, Any]] = None


class RequestOtpPayload(BaseModel):
    phone_number: str = Field(..., description="Target mobile phone number")


class VerifyOtpPayload(BaseModel):
    phone_number: str = Field(..., description="Target mobile phone number")
    code: str = Field(..., description="6-digit verification code received via SMS")


class EmergencyContactModel(BaseModel):
    contact_id: Optional[str] = None
    name: Optional[str] = "Trusted Contact"
    phone: Optional[str] = None
    phone_number: Optional[str] = None
    email: Optional[str] = None
    relationship: Optional[str] = "Trusted Contact"
    is_primary: Optional[bool] = False
    fcm_token: Optional[str] = None

    def get_phone(self) -> str:
        return self.phone or self.phone_number or "+15559998888"


class UserProfileCreate(BaseModel):
    phone_number: str
    full_name: str
    dob: Optional[str] = None
    full_address: Optional[str] = None
    email: Optional[str] = None
    activation_code: str
    deactivation_code: str
    backup_activation_code: Optional[str] = "9999"
    backup_deactivation_code: Optional[str] = "1111"
    trusted_contacts: List[Dict[str, Any]] = []


class CreateSessionRequest(BaseModel):
    user_id: Optional[str] = Field(default="usr_registered_01")
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    accuracy_meters: Optional[float] = 5.0


class TerminateSessionRequest(BaseModel):
    reason: Optional[str] = "User covert deactivation sequence entered"


class LocationPayload(BaseModel):
    latitude: Optional[float] = 28.6139
    longitude: Optional[float] = 77.2090
    timestamp: Optional[Any] = None
    accuracy_meters: Optional[float] = None


class UpdateLocationRequest(BaseModel):
    location: Any


class EvidencePayload(BaseModel):
    file_name: str
    media_type: str
    storage_url: str
    file_size_bytes: int
    sha256_checksum: Optional[str] = None


class TamperPayload(BaseModel):
    sensor_type: Optional[str] = "accelerometer"
    reason: Optional[str] = "Device tamper anomaly detected"
    confidence_score: Optional[float] = 0.95


class EscalateSessionRequest(BaseModel):
    reason: Optional[str] = "Manual tamper escalation"


class LocationRecord(BaseModel):
    latitude: float
    longitude: float
    timestamp: datetime
    accuracy_meters: float = 5.0
    session_id: str


class EvidenceRecord(BaseModel):
    evidence_id: str
    session_id: str
    file_name: str
    media_type: str
    storage_url: str
    file_size_bytes: int
    created_at: datetime
    sha256_checksum: Optional[str] = None


class EmergencyNotificationRecord(BaseModel):
    notification_id: Optional[str] = None
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    title: Optional[str] = None
    body: Optional[str] = None
    message_body: Optional[str] = None
    recipient_name: Optional[str] = None
    recipient_phone: Optional[str] = None
    recipients: List[Any] = []
    status: Optional[NotificationDeliveryStatus] = NotificationDeliveryStatus.DELIVERED
    dispatched_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    error_message: Optional[str] = None
    google_maps_link: Optional[str] = None


class EmergencySessionResponse(BaseModel):
    session_id: str
    user_id: str
    state: SafetyState
    started_at: datetime
    ended_at: Optional[datetime] = None
    escalation_level: int = 0
    tamper_events_count: int = 0
    live_tracking_url: str
    location_status: ServiceModuleStatus = ServiceModuleStatus.ACTIVE
    notification_status: ServiceModuleStatus = ServiceModuleStatus.ACTIVE
    evidence_status: ServiceModuleStatus = ServiceModuleStatus.ACTIVE
    tamper_status: ServiceModuleStatus = ServiceModuleStatus.ACTIVE
    latest_location: Optional[LocationRecord] = None
    locations: List[LocationRecord] = []
    evidence_items: List[EvidenceRecord] = []
    notifications: List[EmergencyNotificationRecord] = []
    metadata: Dict[str, Any] = {}


class LiveTrackingResponse(BaseModel):
    session_id: str
    user_id: str
    state: SafetyState
    is_active: bool
    latest_location: Optional[LocationRecord] = None
    google_maps_url: Optional[str] = None
    apple_maps_url: Optional[str] = None
    last_updated: datetime


class AckNotificationDeliveryRequest(BaseModel):
    notification_id: str
    contact_id: Optional[str] = "contact_01"
    recipient_phone: Optional[str] = "+15559998888"
    status: NotificationDeliveryStatus = NotificationDeliveryStatus.DELIVERED
    error_detail: Optional[str] = None
    error_message: Optional[str] = None


class StandardMessageResponse(BaseModel):
    success: Optional[bool] = True
    status: Optional[str] = "success"
    message: str
    data: Optional[Dict[str, Any]] = None
    session: Optional[Any] = None
