"""Opaque session tokens."""
import hmac
import secrets
from hashlib import sha256

TOKEN_BYTES = 32


def issue_token(secret: bytes) -> tuple[str, str]:
    """Return (token, digest). Store the digest; give the token to the client."""
    token = secrets.token_urlsafe(TOKEN_BYTES)
    return token, _digest(secret, token)


def verify_token(secret: bytes, token: str, expected_digest: str) -> bool:
    """Constant-time comparison so a mismatch leaks no timing signal."""
    return hmac.compare_digest(_digest(secret, token), expected_digest)


def _digest(secret: bytes, token: str) -> str:
    return hmac.new(secret, token.encode("utf-8"), sha256).hexdigest()
