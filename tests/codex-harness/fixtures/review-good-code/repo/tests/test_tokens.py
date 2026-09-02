import pytest
from svc.tokens import issue_token, verify_token

SECRET = b"unit-test-secret"


def test_issued_token_verifies_against_its_digest():
    token, digest = issue_token(SECRET)
    assert verify_token(SECRET, token, digest)


def test_a_different_token_does_not_verify():
    _, digest = issue_token(SECRET)
    other, _ = issue_token(SECRET)
    assert not verify_token(SECRET, other, digest)


def test_a_different_secret_does_not_verify():
    token, digest = issue_token(SECRET)
    assert not verify_token(b"other-secret", token, digest)


def test_tokens_are_unique_across_issues():
    assert issue_token(SECRET)[0] != issue_token(SECRET)[0]


def test_empty_token_does_not_verify():
    _, digest = issue_token(SECRET)
    assert not verify_token(SECRET, "", digest)
