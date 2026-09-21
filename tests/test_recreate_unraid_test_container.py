import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "recreate-unraid-test-container.py"
SPEC = importlib.util.spec_from_file_location("recreate_unraid_test_container", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def completed(stdout="", returncode=0):
    return subprocess.CompletedProcess([], returncode, stdout=stdout, stderr="")


class RecreateUnraidContainerTests(unittest.TestCase):
    def test_image_ownership_rejects_any_non_vibe_tag(self):
        self.assertTrue(
            MODULE.image_is_vibe_owned(
                {"RepoTags": ["sagetv-vibe-server-u26-gpu-j11:previous"]}
            )
        )
        self.assertTrue(MODULE.image_is_vibe_owned({"RepoTags": None}))
        self.assertFalse(
            MODULE.image_is_vibe_owned(
                {"RepoTags": ["sagetv-vibe-server-u26-gpu-j11:previous", "unrelated:latest"]}
            )
        )

    def test_zero_second_stability_gate_still_checks_health_and_ip(self):
        state = {
            "State": {"Running": True, "Health": {"Status": "healthy"}},
            "NetworkSettings": {"Networks": {"br0": {"IPAddress": "192.0.2.20"}}},
        }
        with mock.patch.object(MODULE, "inspect_container", return_value=state):
            self.assertIs(state, MODULE.wait_stably_healthy("vibe", "192.0.2.20", 0))

    def test_verified_cleanup_removes_only_exact_rollback_and_old_vibe_image(self):
        rollback = "sagetv-vibe-server-u26-gpu-j11-rollback-20260921-120000"
        inspections = {
            rollback: {"State": {"Running": False}},
            "sagetv-vibe-server-u26-gpu-j11": {"Image": "sha256:new"},
        }

        def fake_run(*args, **kwargs):
            if args[:4] == ("docker", "ps", "--all", "--filter"):
                return completed("")
            if args[:3] == ("docker", "image", "inspect"):
                return completed(json.dumps([{"RepoTags": ["sagetv-vibe-server-u26-gpu-j11:old"]}]))
            return completed()

        with mock.patch.object(MODULE, "inspect_container", side_effect=lambda name: inspections[name]), mock.patch.object(
            MODULE, "run", side_effect=fake_run
        ) as runner:
            MODULE.remove_verified_rollback(
                rollback, "sagetv-vibe-server-u26-gpu-j11", "sha256:old"
            )

        runner.assert_any_call("docker", "rm", rollback, capture=False)
        runner.assert_any_call("docker", "image", "rm", "sha256:old", capture=False)

    def test_cleanup_rejects_non_vibe_container_name(self):
        with self.assertRaisesRegex(RuntimeError, "non-Vibe rollback"):
            MODULE.remove_verified_rollback(
                "another-container-rollback-1",
                "sagetv-vibe-server-u26-gpu-j11",
                "sha256:old",
            )


if __name__ == "__main__":
    unittest.main()
