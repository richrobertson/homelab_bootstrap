import importlib.util
import pathlib
import socket
import sys
import threading
import types
import unittest


class FakeBoto3(types.ModuleType):
    def client(self, *_args, **_kwargs):
        return object()


botocore = types.ModuleType("botocore")
botocore_exceptions = types.ModuleType("botocore.exceptions")
botocore_exceptions.BotoCoreError = type("BotoCoreError", (Exception,), {})
botocore_exceptions.ClientError = type("ClientError", (Exception,), {})
sys.modules.setdefault("boto3", FakeBoto3("boto3"))
sys.modules.setdefault("botocore", botocore)
sys.modules.setdefault("botocore.exceptions", botocore_exceptions)

MODULE_PATH = pathlib.Path(__file__).with_name("email_canary.py")
SPEC = importlib.util.spec_from_file_location("email_canary", MODULE_PATH)
email_canary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(email_canary)


class SmtpFixture:
    def __init__(self, rcpt_response):
        self.rcpt_response = rcpt_response
        self.commands = []
        self.listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen(1)
        self.port = self.listener.getsockname()[1]
        self.thread = threading.Thread(target=self.serve, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *_args):
        self.thread.join(timeout=2)
        self.listener.close()

    def serve(self):
        connection, _ = self.listener.accept()
        with connection, connection.makefile("rb") as smtp_file:
            connection.sendall(b"220 mx.example ESMTP\r\n")
            while True:
                raw_command = smtp_file.readline(4096)
                if not raw_command:
                    return
                command = raw_command.decode("ascii").rstrip("\r\n")
                self.commands.append(command)
                if command.startswith("EHLO "):
                    connection.sendall(b"250-mx.example\r\n250 SIZE 10240000\r\n")
                elif command.startswith("MAIL FROM:"):
                    connection.sendall(b"250 2.1.0 Sender OK\r\n")
                elif command.startswith("RCPT TO:"):
                    connection.sendall(self.rcpt_response)
                elif command == "RSET":
                    connection.sendall(b"250 2.0.0 Reset\r\n")
                elif command == "QUIT":
                    connection.sendall(b"221 2.0.0 Bye\r\n")
                    return
                else:
                    connection.sendall(b"500 5.5.1 Unknown command\r\n")


def probe(port):
    return {
        "host": "127.0.0.1",
        "port": port,
        "timeout_seconds": 2,
        "mail_from": "open-relay-canary@example.com",
        "rcpt_to": "open-relay-canary@example.net",
    }


class OpenRelayCanaryTest(unittest.TestCase):
    def test_rejected_external_recipient_is_healthy(self):
        with SmtpFixture(b"550 5.7.1 Relay access denied\r\n") as smtp:
            result = email_canary.check_open_relay(probe(smtp.port))

        self.assertEqual(result["rcpt_code"], 550)
        self.assertFalse(any(command == "DATA" for command in smtp.commands))
        self.assertEqual(smtp.commands[-2:], ["RSET", "QUIT"])

    def test_accepted_external_recipient_is_open_relay_failure(self):
        with SmtpFixture(b"250 2.1.5 Recipient OK\r\n") as smtp:
            with self.assertRaisesRegex(RuntimeError, "accepted external recipient"):
                email_canary.check_open_relay(probe(smtp.port))

        self.assertFalse(any(command == "DATA" for command in smtp.commands))
        self.assertEqual(smtp.commands[-2:], ["RSET", "QUIT"])

    def test_temporary_rcpt_failure_is_inconclusive(self):
        with SmtpFixture(b"450 4.7.1 Try again later\r\n") as smtp:
            with self.assertRaisesRegex(RuntimeError, "temporarily deferred"):
                email_canary.check_open_relay(probe(smtp.port))

        self.assertFalse(any(command == "DATA" for command in smtp.commands))


if __name__ == "__main__":
    unittest.main()
