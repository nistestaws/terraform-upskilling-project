import json
import os


def handler(event, context):
    environment = os.environ.get("ENVIRONMENT", "unknown")
    body = {
        "message": "Hello World from Terraform! Updated as practice scenario.",
        "environment": environment,
    }
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
