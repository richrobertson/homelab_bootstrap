import importlib.util
import pathlib
import socket
import threading
import unittest
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).with_name("mail_edge_relay_canary.py")
SPEC = importlib.util.spec_from_file_location("mail_edge_relay_canary", MODULE_PATH)
relay_canary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(relay_canary)


class SmtpFixture:
    def __init__(self, rcpt_response=b"554 5.7.1 Relay access denied\r\n", banner=b"220 mx.example ESMTP\r\n"):
        self.banner = banner
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
            connection.sendall(self.banner)
            if not self.banner.startswith(b"220"):
                return
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


def config(port):
    return {
        "host": "127.0.0.1",
        "port": port,
        "timeout_seconds": 2,
        "mail_from": "open-relay-canary@example.com",
        "rcpt_to": "open-relay-canary@example.net",
    }


class RelayCanaryTest(unittest.TestCase):
    def test_expected_relay_denial_passes_and_emits_heartbeat(self):
        with SmtpFixture() as smtp:
            result = relay_canary.run_probe(config(smtp.port))

        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["heartbeat"], 1)
        self.assertEqual(result["rcpt_code"], 554)
        self.assertNotIn("DATA", smtp.commands)
        self.assertEqual(smtp.commands[-2:], ["RSET", "QUIT"])

    def test_all_success_class_recipient_codes_are_critical(self):
        for code in (250, 251, 252):
            with self.subTest(code=code), SmtpFixture(f"{code} Recipient accepted\r\n".encode()) as smtp:
                result = relay_canary.run_probe(config(smtp.port))

            self.assertEqual(result["status"], "critical")
            self.assertEqual(result["rcpt_code"], code)
            self.assertNotIn("DATA", smtp.commands)
            self.assertEqual(smtp.commands[-2:], ["RSET", "QUIT"])

    def test_temporary_rejection_is_indeterminate(self):
        with SmtpFixture(b"450 4.7.1 Try again later\r\n") as smtp:
            result = relay_canary.run_probe(config(smtp.port))

        self.assertEqual(result["status"], "indeterminate")
        self.assertEqual(result["rcpt_code"], 450)
        self.assertNotIn("DATA", smtp.commands)

    def test_unrelated_permanent_rejection_is_indeterminate(self):
        with SmtpFixture(b"550 5.1.1 User unknown\r\n") as smtp:
            result = relay_canary.run_probe(config(smtp.port))

        self.assertEqual(result["status"], "indeterminate")
        self.assertEqual(result["rcpt_code"], 550)
        self.assertNotIn("DATA", smtp.commands)

    def test_protocol_failure_is_indeterminate(self):
        with SmtpFixture(banner=b"554 Service unavailable\r\n") as smtp:
            result = relay_canary.run_probe(config(smtp.port))

        self.assertEqual(result["status"], "indeterminate")
        self.assertEqual(result["phase"], "banner")
        self.assertNotIn("DATA", smtp.commands)

    def test_transport_failure_is_indeterminate(self):
        with mock.patch.object(relay_canary.socket, "create_connection", side_effect=OSError("unreachable")):
            result = relay_canary.run_probe(config(25))

        self.assertEqual(result["status"], "indeterminate")
        self.assertEqual(result["phase"], "connect")
        self.assertEqual(result["heartbeat"], 1)


if __name__ == "__main__":
    unittest.main()
