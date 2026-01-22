import os


def send_notification(msg):
    provider = os.environ.get("NOTIFY_PROVIDER", "stdout").lower()
    providers = {
        "stdout": _send_stdout,
    }
    if provider not in providers:
        raise ValueError(
            f"Unsupported NOTIFY_PROVIDER '{provider}'. "
            f"Available providers: {', '.join(sorted(providers))}"
        )
    providers[provider](msg)


def _send_stdout(msg):
    print(msg)
