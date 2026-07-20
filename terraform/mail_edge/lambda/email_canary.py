import email
import imaplib
import json
import os
import socket
import time
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import BotoCoreError, ClientError


ses = boto3.client("ses", region_name=os.environ.get("SES_REGION"))
sns = boto3.client("sns")
secretsmanager = boto3.client("secretsmanager")


def lambda_handler(event, context):
    probes = load_probes()
    sent = []
    failures = []

    open_relay_probe = load_open_relay_probe()
    if open_relay_probe:
        try:
            result = check_open_relay(open_relay_probe)
            print(json.dumps({"status": "open-relay-rejected", **result}))
        except Exception as exc:
            detail = (
                f"The external SMTP RCPT-only canary could not confirm relay rejection: {exc}. "
                "No DATA command was sent. Treat recipient acceptance as an active open relay; "
                "treat connectivity or protocol failures as an inconclusive probe."
            )
            failures.append({"probe": "open-relay", "phase": "smtp-rcpt", "error": str(exc)})
            alert("open-relay", "Mail edge open-relay canary failed", detail)

    for probe in probes:
        token = uuid.uuid4().hex[:16]
        subject = f"[mail-canary:{probe['name']}] {token}"
        sent_at = datetime.now(timezone.utc).isoformat()
        try:
            send_canary(probe, subject, token, sent_at)
            sent.append({
                "probe": probe,
                "subject": subject,
                "token": token,
                "sent_at": sent_at,
                "deadline": time.monotonic() + int(probe["timeout_seconds"]),
            })
        except (BotoCoreError, ClientError, ValueError) as exc:
            failures.append({"probe": probe["name"], "phase": "send", "error": str(exc)})
            alert(probe["name"], "Email canary send failed", f"SES did not accept the canary message: {exc}")

    delivered, delivery_failures = wait_for_deliveries(sent)
    failures.extend(delivery_failures)

    print(json.dumps({"status": "complete", "delivered": delivered, "failures": failures}))
    if failures:
        raise RuntimeError(f"{len(failures)} email canary probe(s) failed")

    return {"status": "ok", "delivered": delivered}


def load_open_relay_probe():
    probe_json = os.environ.get("OPEN_RELAY_PROBE_JSON")
    if not probe_json:
        return None

    probe = json.loads(probe_json)
    normalized = {
        "host": probe.get("host"),
        "port": int(probe.get("port", 25)),
        "timeout_seconds": int(probe.get("timeout_seconds", 10)),
        "mail_from": probe.get("mail_from", "open-relay-canary@example.com"),
        "rcpt_to": probe.get("rcpt_to", "open-relay-canary@example.net"),
    }
    for key in ("host", "mail_from", "rcpt_to"):
        if not normalized[key]:
            raise ValueError(f"Open-relay probe is missing required key: {key}")
    return normalized


def check_open_relay(probe):
    """Confirm an external recipient is rejected without ever sending DATA."""
    transcript = []
    with socket.create_connection(
        (probe["host"], probe["port"]),
        timeout=probe["timeout_seconds"],
    ) as smtp_socket:
        smtp_socket.settimeout(probe["timeout_seconds"])
        smtp_file = smtp_socket.makefile("rb")

        banner_code, banner = read_smtp_response(smtp_file)
        transcript.append({"command": "banner", "code": banner_code})
        if banner_code != 220:
            raise RuntimeError(f"SMTP banner returned {banner_code}: {banner}")

        ehlo_code, ehlo = smtp_command(smtp_socket, smtp_file, "EHLO open-relay-canary.invalid")
        transcript.append({"command": "EHLO", "code": ehlo_code})
        if ehlo_code != 250:
            raise RuntimeError(f"SMTP EHLO returned {ehlo_code}: {ehlo}")

        mail_code, mail_response = smtp_command(
            smtp_socket,
            smtp_file,
            f"MAIL FROM:<{probe['mail_from']}>",
        )
        transcript.append({"command": "MAIL FROM", "code": mail_code})
        if mail_code != 250:
            raise RuntimeError(f"SMTP MAIL FROM returned {mail_code}: {mail_response}")

        rcpt_code, rcpt_response = smtp_command(
            smtp_socket,
            smtp_file,
            f"RCPT TO:<{probe['rcpt_to']}>",
        )
        transcript.append({"command": "RCPT TO", "code": rcpt_code})

        # Always reset and quit. This probe must never enter DATA, even when the
        # server has incorrectly accepted the external recipient.
        try:
            smtp_command(smtp_socket, smtp_file, "RSET")
            smtp_command(smtp_socket, smtp_file, "QUIT")
        except (OSError, RuntimeError):
            pass

    if 200 <= rcpt_code < 400:
        raise RuntimeError(
            f"SMTP server accepted external recipient {probe['rcpt_to']} with "
            f"{rcpt_code}: {rcpt_response}"
        )
    if 400 <= rcpt_code < 500:
        raise RuntimeError(
            f"SMTP server temporarily deferred external recipient with {rcpt_code}: "
            f"{rcpt_response}"
        )
    if not 500 <= rcpt_code < 600:
        raise RuntimeError(f"SMTP RCPT TO returned unexpected code {rcpt_code}: {rcpt_response}")

    return {
        "probe": "open-relay",
        "host": probe["host"],
        "port": probe["port"],
        "rcpt_code": rcpt_code,
        "transcript": transcript,
    }


def smtp_command(smtp_socket, smtp_file, command):
    smtp_socket.sendall(command.encode("ascii") + b"\r\n")
    return read_smtp_response(smtp_file)


def read_smtp_response(smtp_file):
    lines = []
    expected_code = None
    while True:
        raw_line = smtp_file.readline(4096)
        if not raw_line:
            raise RuntimeError("SMTP connection closed before a complete response")
        line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
        lines.append(line)
        if len(line) < 3 or not line[:3].isdigit():
            raise RuntimeError(f"Malformed SMTP response: {line}")
        code = int(line[:3])
        if expected_code is None:
            expected_code = code
        elif code != expected_code:
            raise RuntimeError(f"Inconsistent multiline SMTP response: {' | '.join(lines)}")
        if len(line) == 3 or line[3:4] != "-":
            return code, " | ".join(lines)


def load_probes():
    probes_json = os.environ.get("PROBES_JSON")
    if probes_json:
        probes = json.loads(probes_json)
    else:
        probes = [{
            "name": "external",
            "from_address": os.environ["CANARY_FROM_ADDRESS"],
            "to_address": os.environ["CANARY_TO_ADDRESS"],
            "imap_secret_arn": os.environ["IMAP_SECRET_ARN"],
            "timeout_seconds": int(os.environ["DELIVERY_TIMEOUT_SECONDS"]),
        }]

    normalized = []
    for probe in probes:
        normalized_probe = {
            "name": probe.get("name", "default"),
            "from_address": probe.get("from_address"),
            "to_address": probe.get("to_address"),
            "imap_secret_arn": probe.get("imap_secret_arn"),
            "timeout_seconds": int(probe.get("timeout_seconds", os.environ["DELIVERY_TIMEOUT_SECONDS"])),
        }
        for key in ("from_address", "to_address", "imap_secret_arn"):
            if not normalized_probe[key]:
                raise ValueError(f"Probe {normalized_probe['name']} is missing required key: {key}")
        normalized.append(normalized_probe)
    return normalized


def send_canary(probe, subject, token, sent_at):
    response = ses.send_email(
        Source=probe["from_address"],
        Destination={"ToAddresses": [probe["to_address"]]},
        Message={
            "Subject": {"Data": subject, "Charset": "UTF-8"},
            "Body": {
                "Text": {
                    "Data": (
                        "Mail canary probe.\n"
                        f"Token: {token}\n"
                        f"Sent-At: {sent_at}\n"
                        f"Domain: {os.environ.get('MAIL_DOMAIN', 'unknown')}\n"
                    ),
                    "Charset": "UTF-8",
                }
            },
        },
    )
    print(json.dumps({
        "status": "sent",
        "probe": probe["name"],
        "message_id": response.get("MessageId"),
        "subject": subject,
    }))


def wait_for_deliveries(sent_messages):
    pending = []
    delivered = []
    failures = []

    for message in sent_messages:
        try:
            secret = load_imap_secret(message["probe"]["imap_secret_arn"])
            pending.append({**message, "secret": secret, "folder": secret.get("folder", "INBOX")})
        except Exception as exc:
            probe_name = message["probe"]["name"]
            failures.append({"probe": probe_name, "phase": "imap-secret", "error": str(exc)})
            alert(probe_name, "Email canary IMAP setup failed", str(exc))

    while pending:
        now = time.monotonic()
        next_pending = []

        for message in pending:
            probe = message["probe"]
            if now >= message["deadline"]:
                detail = (
                    f"Probe {probe['name']} email was not visible in {message['folder']} within "
                    f"{probe['timeout_seconds']} seconds. This can indicate delayed delivery, rejection, "
                    "filtering, DNS/reputation trouble, or IMAP access failure."
                )
                failures.append({"probe": probe["name"], "phase": "delivery", "error": detail})
                alert(probe["name"], "Email canary delivery check failed", detail)
                continue

            try:
                delivered_at = find_message(message["secret"], message["folder"], message["subject"], message["token"])
            except Exception as exc:
                failures.append({"probe": probe["name"], "phase": "imap-search", "error": str(exc)})
                alert(probe["name"], "Email canary IMAP search failed", str(exc))
                continue

            if delivered_at:
                delivered.append({"probe": probe["name"], "delivered_at": delivered_at})
            else:
                next_pending.append(message)

        pending = next_pending
        if pending:
            sleep_seconds = min(
                min(int(message["secret"].get("poll_seconds", 15)) for message in pending),
                max(1, min(message["deadline"] for message in pending) - time.monotonic()),
            )
            time.sleep(sleep_seconds)

    return delivered, failures


def load_imap_secret(secret_arn):
    response = secretsmanager.get_secret_value(SecretId=secret_arn)
    payload = response.get("SecretString")
    if not payload:
        raise ValueError("IMAP secret must contain SecretString JSON")

    secret = json.loads(payload)
    for key in ("host", "username", "password"):
        if not secret.get(key):
            raise ValueError(f"IMAP secret is missing required key: {key}")
    return secret


def find_message(secret, folder, subject, token):
    host = secret["host"]
    use_ssl = parse_bool(secret.get("use_ssl", True))
    port = int(secret.get("port", 993 if use_ssl else 143))
    socket.setdefaulttimeout(int(secret.get("socket_timeout_seconds", 20)))

    imap = imaplib.IMAP4_SSL(host, port) if use_ssl else imaplib.IMAP4(host, port)
    try:
        imap.login(secret["username"], secret["password"])
        select_status, _ = imap.select(folder, readonly=True)
        if select_status != "OK":
            raise RuntimeError(f"Could not select IMAP folder {folder}")

        search_status, search_data = imap.search(None, "SUBJECT", quote_imap(subject))
        if search_status != "OK":
            raise RuntimeError("IMAP search failed")

        for message_id in reversed(search_data[0].split()):
            fetch_status, fetch_data = imap.fetch(message_id, "(RFC822)")
            if fetch_status != "OK":
                continue
            raw = fetch_data[0][1]
            message = email.message_from_bytes(raw)
            if message_contains_token(message, token):
                return datetime.now(timezone.utc).isoformat()
        return None
    finally:
        try:
            imap.close()
        except imaplib.IMAP4.error:
            pass
        try:
            imap.logout()
        except imaplib.IMAP4.error:
            pass


def parse_bool(value):
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() not in ("0", "false", "no", "off")
    return bool(value)


def quote_imap(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def message_contains_token(message, token):
    if token in str(message.get("Subject", "")):
        return True

    if message.is_multipart():
        for part in message.walk():
            if part.get_content_maintype() == "multipart":
                continue
            if payload_contains_token(part, token):
                return True
        return False

    return payload_contains_token(message, token)


def payload_contains_token(part, token):
    payload = part.get_payload(decode=True)
    if payload is None:
        return token in str(part.get_payload())

    charset = part.get_content_charset() or "utf-8"
    try:
        body = payload.decode(charset, errors="replace")
    except LookupError:
        body = payload.decode("utf-8", errors="replace")
    return token in body


def alert(probe_name, title, detail):
    message = f"{title}\nProbe: {probe_name}\n{detail}"
    print(json.dumps({"status": "alert", "probe": probe_name, "title": title, "detail": detail}))
    sns.publish(
        TopicArn=os.environ["ALERT_TOPIC_ARN"],
        Subject=title[:100],
        Message=message,
    )
