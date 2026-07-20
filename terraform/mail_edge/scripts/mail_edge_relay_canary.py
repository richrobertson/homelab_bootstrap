#!/usr/bin/env python3
"""Run a bodyless SMTP relay-policy probe against the Mailu WireGuard backend."""

import json
import os
import socket
import sys
import time
from datetime import datetime, timezone


EVENT_NAME = "relay_canary"
EXPECTED_RELAY_DENIAL_ENHANCED_CODE = "5.7.1"
EXPECTED_RELAY_DENIAL_TEXT = "relay access denied"


class ProbeError(RuntimeError):
    def __init__(self, phase, detail, code=None):
        super().__init__(detail)
        self.phase = phase
        self.code = code


def load_config():
    config = {
        "host": os.environ["MAIL_EDGE_RELAY_CANARY_HOST"],
        "port": int(os.environ.get("MAIL_EDGE_RELAY_CANARY_PORT", "25")),
        "timeout_seconds": float(os.environ.get("MAIL_EDGE_RELAY_CANARY_TIMEOUT_SECONDS", "10")),
        "mail_from": os.environ.get("MAIL_EDGE_RELAY_CANARY_MAIL_FROM", "open-relay-canary@example.com"),
        "rcpt_to": os.environ.get("MAIL_EDGE_RELAY_CANARY_RCPT_TO", "open-relay-canary@example.net"),
    }
    if config["port"] != 25:
        raise ValueError("MAIL_EDGE_RELAY_CANARY_PORT must be 25")
    if not 1 <= config["timeout_seconds"] <= 30:
        raise ValueError("MAIL_EDGE_RELAY_CANARY_TIMEOUT_SECONDS must be between 1 and 30")
    for key in ("host", "mail_from", "rcpt_to"):
        if not config[key] or "\r" in config[key] or "\n" in config[key]:
            raise ValueError(f"Invalid relay-canary value for {key}")
    return config


def read_smtp_response(smtp_file, phase):
    lines = []
    expected_code = None
    for _ in range(100):
        raw_line = smtp_file.readline(4096)
        if not raw_line:
            raise ProbeError(phase, "SMTP connection closed before a complete response")
        line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
        lines.append(line)
        if len(line) < 3 or not line[:3].isdigit():
            raise ProbeError(phase, f"Malformed SMTP response: {line[:256]}")
        code = int(line[:3])
        if expected_code is None:
            expected_code = code
        elif code != expected_code:
            raise ProbeError(phase, "Inconsistent SMTP multiline response codes")
        if len(line) == 3 or line[3:4] != "-":
            return code, " | ".join(lines)[:512]
    raise ProbeError(phase, "SMTP response exceeded 100 lines")


def smtp_command(smtp_socket, smtp_file, command, phase):
    smtp_socket.sendall(command.encode("ascii") + b"\r\n")
    return read_smtp_response(smtp_file, phase)


def cleanup_transaction(smtp_socket, smtp_file):
    """Reset and close the SMTP transaction. DATA is intentionally impossible here."""
    for command in ("RSET", "QUIT"):
        try:
            smtp_command(smtp_socket, smtp_file, command, "cleanup")
        except (OSError, ProbeError):
            return


def run_probe(config):
    started = time.monotonic()
    transcript = []
    rcpt_code = None
    phase = "connect"
    detail = ""
    status = "indeterminate"

    try:
        with socket.create_connection(
            (config["host"], config["port"]),
            timeout=config["timeout_seconds"],
        ) as smtp_socket:
            smtp_socket.settimeout(config["timeout_seconds"])
            with smtp_socket.makefile("rb") as smtp_file:
                phase = "banner"
                banner_code, banner = read_smtp_response(smtp_file, phase)
                transcript.append({"command": "banner", "code": banner_code})
                if banner_code != 220:
                    raise ProbeError(phase, f"Expected 220 banner, received {banner_code}: {banner}", banner_code)

                phase = "ehlo"
                ehlo_code, ehlo = smtp_command(
                    smtp_socket,
                    smtp_file,
                    "EHLO open-relay-canary.invalid",
                    phase,
                )
                transcript.append({"command": "EHLO", "code": ehlo_code})
                if ehlo_code != 250:
                    raise ProbeError(phase, f"Expected 250 EHLO, received {ehlo_code}: {ehlo}", ehlo_code)

                phase = "mail_from"
                mail_code, mail_response = smtp_command(
                    smtp_socket,
                    smtp_file,
                    f"MAIL FROM:<{config['mail_from']}>",
                    phase,
                )
                transcript.append({"command": "MAIL FROM", "code": mail_code})
                if mail_code != 250:
                    raise ProbeError(
                        phase,
                        f"Expected 250 MAIL FROM, received {mail_code}: {mail_response}",
                        mail_code,
                    )

                phase = "rcpt_to"
                rcpt_code, rcpt_response = smtp_command(
                    smtp_socket,
                    smtp_file,
                    f"RCPT TO:<{config['rcpt_to']}>",
                    phase,
                )
                transcript.append({"command": "RCPT TO", "code": rcpt_code})
                cleanup_transaction(smtp_socket, smtp_file)

        if 200 <= rcpt_code < 300:
            status = "critical"
            detail = f"External recipient accepted with {rcpt_code}: {rcpt_response}"
        elif (
            500 <= rcpt_code < 600
            and EXPECTED_RELAY_DENIAL_ENHANCED_CODE in rcpt_response
            and EXPECTED_RELAY_DENIAL_TEXT in rcpt_response.lower()
        ):
            status = "pass"
            detail = f"Expected relay denial received with {rcpt_code}: {rcpt_response}"
        else:
            status = "indeterminate"
            detail = f"RCPT response did not prove the expected relay restriction: {rcpt_code}: {rcpt_response}"
    except (OSError, ProbeError, ValueError) as exc:
        if isinstance(exc, ProbeError):
            phase = exc.phase
            if exc.code is not None and rcpt_code is None and phase == "rcpt_to":
                rcpt_code = exc.code
        detail = str(exc)[:512]

    return {
        "event": EVENT_NAME,
        "status": status,
        "heartbeat": 1,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "target": config["host"],
        "port": config["port"],
        "phase": phase,
        "rcpt_code": rcpt_code,
        "duration_ms": round((time.monotonic() - started) * 1000),
        "detail": detail,
        "transcript": transcript,
    }


def main():
    try:
        config = load_config()
        result = run_probe(config)
    except (KeyError, TypeError, ValueError) as exc:
        result = {
            "event": EVENT_NAME,
            "status": "indeterminate",
            "heartbeat": 1,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "phase": "configuration",
            "rcpt_code": None,
            "detail": str(exc)[:512],
            "transcript": [],
        }

    print(json.dumps(result, separators=(",", ":"), sort_keys=True), flush=True)
    if result["status"] == "pass":
        return 0
    if result["status"] == "critical":
        return 2
    return 1


if __name__ == "__main__":
    sys.exit(main())
