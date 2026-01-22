import os


def send_notification(msg):
    provider = os.environ.get("NOTIFY_PROVIDER", "stdout").lower()
    providers = {
        "stdout": _send_stdout,
        "sns": _send_sns,
    }
    if provider not in providers:
        raise ValueError(
            f"Unsupported NOTIFY_PROVIDER '{provider}'. "
            f"Available providers: {', '.join(sorted(providers))}"
        )
    providers[provider](msg)


def _send_stdout(msg):
    print(msg)


def _send_sns(msg):
    import boto3

    topic_arn = os.environ.get("SNS_TOPIC_ARN")
    region = os.environ.get("AWS_REGION") or os.environ.get("AWS_DEFAULT_REGION")
    missing = [
        name
        for name, value in {
            "SNS_TOPIC_ARN": topic_arn,
            "AWS_REGION": region,
        }.items()
        if not value
    ]
    if missing:
        raise ValueError("Missing required SNS env vars: " + ", ".join(sorted(missing)))

    client = boto3.client("sns", region_name=region)
    response = client.publish(TopicArn=topic_arn, Message=msg)
    print(response.get("MessageId", "sent"))
