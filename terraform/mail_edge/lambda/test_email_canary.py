import importlib.util
import json
import pathlib
import sys
import types
import unittest
from unittest import mock


class BotoCoreError(Exception):
    pass


class ClientError(Exception):
    pass


BOTO3 = types.ModuleType("boto3")
BOTO3.client = mock.Mock(side_effect=lambda *_args, **_kwargs: mock.Mock())
BOTOCORE = types.ModuleType("botocore")
BOTOCORE_EXCEPTIONS = types.ModuleType("botocore.exceptions")
BOTOCORE_EXCEPTIONS.BotoCoreError = BotoCoreError
BOTOCORE_EXCEPTIONS.ClientError = ClientError
BOTOCORE.exceptions = BOTOCORE_EXCEPTIONS
sys.modules.setdefault("boto3", BOTO3)
sys.modules.setdefault("botocore", BOTOCORE)
sys.modules.setdefault("botocore.exceptions", BOTOCORE_EXCEPTIONS)

MODULE_PATH = pathlib.Path(__file__).with_name("email_canary.py")
SPEC = importlib.util.spec_from_file_location("email_canary", MODULE_PATH)
email_canary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(email_canary)


def probe(name="mailu-dovecot"):
    return {
        "name": name,
        "from_address": "canary@example.com",
        "to_address": "inbox@example.net",
        "imap_secret_arn": "arn:aws:secretsmanager:us-west-2:123456789012:secret:canary",
        "timeout_seconds": 240,
    }


def metrics_by_name(call):
    return {metric["MetricName"]: metric for metric in call.kwargs["MetricData"]}


class EmailCanaryMetricTest(unittest.TestCase):
    def setUp(self):
        email_canary.cloudwatch = mock.Mock()

    def test_success_publishes_send_accepted_success_failure_and_latency_per_probe(self):
        configured_probe = probe()
        sent = [{"probe": configured_probe}]
        delivered = [{
            "probe": configured_probe["name"],
            "delivered_at": "2026-07-20T00:00:12+00:00",
            "delivery_latency_seconds": 12.5,
        }]

        email_canary.publish_probe_metrics([configured_probe], sent, delivered, [])

        call = email_canary.cloudwatch.put_metric_data.call_args
        self.assertEqual(call.kwargs["Namespace"], "Mailu/EmailCanary")
        metrics = metrics_by_name(call)
        self.assertEqual(metrics["SendAccepted"]["Value"], 1)
        self.assertEqual(metrics["Success"]["Value"], 1)
        self.assertEqual(metrics["Failure"]["Value"], 0)
        self.assertEqual(metrics["DeliveryLatencySeconds"]["Value"], 12.5)
        for metric in metrics.values():
            self.assertEqual(metric["Dimensions"], [{"Name": "Probe", "Value": "mailu-dovecot"}])

    def test_failure_publishes_zero_send_accepted_and_success_without_latency(self):
        configured_probe = probe("external")
        failures = [{"probe": "external", "phase": "send", "error": "SES rejected"}]

        email_canary.publish_probe_metrics([configured_probe], [], [], failures)

        metrics = metrics_by_name(email_canary.cloudwatch.put_metric_data.call_args)
        self.assertEqual(metrics["SendAccepted"]["Value"], 0)
        self.assertEqual(metrics["Success"]["Value"], 0)
        self.assertEqual(metrics["Failure"]["Value"], 1)
        self.assertNotIn("DeliveryLatencySeconds", metrics)

    def test_delivery_latency_is_end_to_end_from_before_ses_send(self):
        configured_probe = probe()
        sent = [{
            "probe": configured_probe,
            "subject": "canary subject",
            "token": "token",
            "started_at_monotonic": 100.0,
            "deadline": 200.0,
        }]

        with (
            mock.patch.object(email_canary, "load_imap_secret", return_value={"folder": "INBOX"}),
            mock.patch.object(email_canary, "find_message", return_value="2026-07-20T00:00:12+00:00"),
            mock.patch.object(email_canary.time, "monotonic", side_effect=[110.0, 112.5]),
        ):
            delivered, failures = email_canary.wait_for_deliveries(sent)

        self.assertEqual(failures, [])
        self.assertEqual(delivered[0]["delivery_latency_seconds"], 12.5)

    def test_metric_publish_failure_is_logged_without_changing_probe_result(self):
        configured_probe = probe()
        email_canary.cloudwatch.put_metric_data.side_effect = ClientError("access denied")

        with mock.patch("builtins.print") as print_mock:
            email_canary.publish_probe_metrics([configured_probe], [], [], [])

        event = json.loads(print_mock.call_args.args[0])
        self.assertEqual(event["status"], "metric-publish-failed")
        self.assertIn("access denied", event["error"])

    def test_handler_starts_latency_clock_before_ses_api_call(self):
        configured_probe = probe()
        events = []
        monotonic_values = iter([100.0, 102.0])
        captured_sent = []

        def monotonic():
            events.append("clock")
            return next(monotonic_values)

        def send_canary(*_args):
            events.append("send")

        def wait_for_deliveries(sent):
            captured_sent.extend(sent)
            return ([{
                "probe": configured_probe["name"],
                "delivered_at": "2026-07-20T00:00:12+00:00",
                "delivery_latency_seconds": 12.5,
            }], [])

        with (
            mock.patch.object(email_canary, "load_probes", return_value=[configured_probe]),
            mock.patch.object(email_canary, "send_canary", side_effect=send_canary),
            mock.patch.object(email_canary.time, "monotonic", side_effect=monotonic),
            mock.patch.object(email_canary, "wait_for_deliveries", side_effect=wait_for_deliveries),
        ):
            email_canary.lambda_handler({}, None)

        self.assertEqual(events[:3], ["clock", "send", "clock"])
        self.assertEqual(captured_sent[0]["started_at_monotonic"], 100.0)
        self.assertEqual(captured_sent[0]["deadline"], 342.0)

    def test_send_failure_publishes_failure_before_preserving_failed_outcome(self):
        configured_probe = probe("external")
        with (
            mock.patch.object(email_canary, "load_probes", return_value=[configured_probe]),
            mock.patch.object(email_canary, "send_canary", side_effect=ClientError("SES rejected")),
            mock.patch.object(email_canary, "alert"),
            self.assertRaisesRegex(RuntimeError, "1 email canary probe"),
        ):
            email_canary.lambda_handler({}, None)

        metrics = metrics_by_name(email_canary.cloudwatch.put_metric_data.call_args)
        self.assertEqual(metrics["SendAccepted"]["Value"], 0)
        self.assertEqual(metrics["Success"]["Value"], 0)
        self.assertEqual(metrics["Failure"]["Value"], 1)

    def test_delivery_failure_publishes_send_accepted_and_failure_before_raising(self):
        configured_probe = probe()
        delivery_failures = [{"probe": configured_probe["name"], "phase": "delivery", "error": "timeout"}]
        with (
            mock.patch.object(email_canary, "load_probes", return_value=[configured_probe]),
            mock.patch.object(email_canary, "send_canary"),
            mock.patch.object(email_canary.time, "monotonic", side_effect=[100.0, 100.0]),
            mock.patch.object(email_canary, "wait_for_deliveries", return_value=([], delivery_failures)),
            self.assertRaisesRegex(RuntimeError, "1 email canary probe"),
        ):
            email_canary.lambda_handler({}, None)

        metrics = metrics_by_name(email_canary.cloudwatch.put_metric_data.call_args)
        self.assertEqual(metrics["SendAccepted"]["Value"], 1)
        self.assertEqual(metrics["Success"]["Value"], 0)
        self.assertEqual(metrics["Failure"]["Value"], 1)

    def test_metric_api_failure_does_not_change_successful_handler_result(self):
        configured_probe = probe()
        delivered = [{
            "probe": configured_probe["name"],
            "delivered_at": "2026-07-20T00:00:12+00:00",
            "delivery_latency_seconds": 12.5,
        }]
        email_canary.cloudwatch.put_metric_data.side_effect = ClientError("metrics unavailable")

        with (
            mock.patch.object(email_canary, "load_probes", return_value=[configured_probe]),
            mock.patch.object(email_canary, "send_canary"),
            mock.patch.object(email_canary.time, "monotonic", side_effect=[100.0, 100.0]),
            mock.patch.object(email_canary, "wait_for_deliveries", return_value=(delivered, [])),
        ):
            result = email_canary.lambda_handler({}, None)

        self.assertEqual(result["status"], "ok")

    def test_configuration_failure_emits_named_failure_without_masking_original(self):
        configured = json.dumps([{"name": "mailu-dovecot"}])
        with (
            mock.patch.dict(email_canary.os.environ, {"PROBES_JSON": configured}),
            mock.patch.object(email_canary, "load_probes", side_effect=ValueError("missing address")),
            self.assertRaisesRegex(ValueError, "missing address"),
        ):
            email_canary.lambda_handler({}, None)

        metrics = metrics_by_name(email_canary.cloudwatch.put_metric_data.call_args)
        self.assertEqual(metrics["Failure"]["Value"], 1)
        self.assertEqual(metrics["Failure"]["Dimensions"], [{"Name": "Probe", "Value": "mailu-dovecot"}])

    def test_lambda_has_no_open_relay_tcp_probe(self):
        self.assertFalse(hasattr(email_canary, "check_open_relay"))
        self.assertFalse(hasattr(email_canary, "load_open_relay_probe"))


if __name__ == "__main__":
    unittest.main()
