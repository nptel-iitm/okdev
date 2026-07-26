from svc.search import handle


def test_handle_runs():
    result = handle({"q": "shoe"})
    assert result is not None
