import os


def send_notification(msg):
    provider = os.environ.get("NOTIFY_PROVIDER", "stdout").lower()
    providers = {
        "stdout": _send_stdout,
        "twilio": _send_twilio,
    }
    if provider not in providers:
        raise ValueError(
            f"Unsupported NOTIFY_PROVIDER '{provider}'. "
            f"Available providers: {', '.join(sorted(providers))}"
        )
    providers[provider](msg)


def _send_stdout(msg):
    print(msg)


def _send_twilio(msg):
    from twilio.rest import Client

    account_sid = os.environ.get("TWILIO_ACCOUNT_SID")
    auth_token = os.environ.get("TWILIO_TOKEN")
    destination = os.environ.get("TWILIO_DESTINATION_PHONE_NUMBER")
    messaging_service_sid = os.environ.get("TWILIO_MESSAGING_SERVICE_SID")
    missing = [
        name
        for name, value in {
            "TWILIO_ACCOUNT_SID": account_sid,
            "TWILIO_TOKEN": auth_token,
            "TWILIO_DESTINATION_PHONE_NUMBER": destination,
            "TWILIO_MESSAGING_SERVICE_SID": messaging_service_sid,
        }.items()
        if not value
    ]
    if missing:
        raise ValueError(
            "Missing required Twilio env vars: " + ", ".join(sorted(missing))
        )
    client = Client(account_sid, auth_token)
    message = client.messages.create(
        messaging_service_sid=messaging_service_sid,
        body=msg,
        to=destination,
    )
    print(message.sid)
