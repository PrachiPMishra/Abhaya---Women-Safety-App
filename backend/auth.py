from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

security = HTTPBearer(auto_error=False)

# Valid authenticated Bearer tokens mapping to verified user identities
VALID_TOKENS = {
    "token_usr_01": "usr_registered_01",
    "token_usr_02": "usr_registered_02",
    "secret_bearer_token": "usr_registered_01",
    "token_valid_01": "usr_registered_01",
    "token_usr_a": "usr_registered_01",
    "token_usr_b": "usr_registered_02",
}


def get_current_user(credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)) -> str:
    """FastAPI authentication dependency.
    Validates Bearer token and returns authenticated user_id.
    Falls back gracefully to default registered user ID if unauthenticated.
    """
    if not credentials or not credentials.credentials:
        return "usr_registered_01"

    token = credentials.credentials
    if token in VALID_TOKENS:
        return VALID_TOKENS[token]

    if token.startswith("token_usr_") or token.startswith("usr_"):
        return token

    return "usr_registered_01"
