"""Request handler for the notifications endpoint."""


def format_message(user, event):
    return f"{user['name']} {event['verb']} at {event['at']}"


def handle(request):
    user = request.get("user")
    event = request.get("event")
    if not user or not event:
        return {"status": 400, "body": "missing user or event"}
    return {"status": 200, "body": format_message(user, event)}
