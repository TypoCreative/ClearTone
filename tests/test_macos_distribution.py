"""Exercise release gates without submitting software or using signing secrets."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cleartone-notary-tests-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.calls = self.directory / "calls"
        self.package = self.directory / "ClearTone.pkg"
        self.package.touch()
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith("CLEARTONE_")}
        self.env.update(PATH=f"{self.directory}:/usr/bin:/bin:/usr/sbin:/sbin",
                        TEST_CALLS=str(self.calls), CLEARTONE_NOTARY_PROFILE="test-profile")
        self.stub("pkgutil", 'exit 0\n')
        self.stub("xcrun", '''printf '%s\\n' "$*" >> "$TEST_CALLS"
if [ "$1 $2" = "stapler staple" ] && [ "${TEST_STAPLE_FAILURE:-0}" = 1 ]; then exit 1; fi
if [ "$1 $2" = "notarytool submit" ]; then
  if [ "${TEST_TIMEOUT:-0}" = 1 ]; then exit 1; fi
  printf '{"status":"%s"}\\n' "${TEST_STATUS:-Accepted}"
fi
''')

    def stub(self, name, body):
        script = self.directory / name
        script.write_text("#!/bin/sh\n" + body)
        script.chmod(0o700)

    def run_script(self, path, *args):
        return subprocess.run(["/bin/zsh", str(ROOT / path), *map(str, args)],
                              env=self.env, capture_output=True, text=True)

    def test_accepted_submission_staples_and_validates(self):
        result = self.run_script("scripts/notarize-mac.sh", self.package)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.calls.read_text()
        self.assertIn("stapler staple", calls)
        self.assertIn("stapler validate", calls)

    def test_rejection_does_not_staple(self):
        self.env["TEST_STATUS"] = "Invalid"
        result = self.run_script("scripts/notarize-mac.sh", self.package)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("stapler", self.calls.read_text())

    def test_timeout_does_not_staple(self):
        self.env["TEST_TIMEOUT"] = "1"
        result = self.run_script("scripts/notarize-mac.sh", self.package)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("stapler", self.calls.read_text())

    def test_stapling_failure_stops_validation(self):
        self.env["TEST_STAPLE_FAILURE"] = "1"
        result = self.run_script("scripts/notarize-mac.sh", self.package)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("stapler staple", self.calls.read_text())
        self.assertNotIn("stapler validate", self.calls.read_text())

    def test_missing_credentials_fail(self):
        del self.env["CLEARTONE_NOTARY_PROFILE"]
        result = self.run_script("scripts/notarize-mac.sh", "--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.calls.exists())

    def test_public_build_rejects_development_identity(self):
        self.env.update(CLEARTONE_REQUIRE_DEVELOPER_ID="1",
                        CLEARTONE_APP_SIGN_IDENTITY="Apple Development: test")
        result = self.run_script("scripts/package-mac.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Developer ID Application identity is required", result.stderr)

    def test_public_build_requires_installer_identity(self):
        self.env.update(CLEARTONE_REQUIRE_DEVELOPER_ID="1",
                        CLEARTONE_APP_SIGN_IDENTITY="Developer ID Application: test")
        result = self.run_script("scripts/package-mac.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Developer ID Installer identity is required", result.stderr)

    def test_public_build_rejects_adhoc_driver(self):
        self.env.update(CLEARTONE_REQUIRE_DEVELOPER_ID="1",
                        CLEARTONE_APP_SIGN_IDENTITY="Developer ID Application: test",
                        CLEARTONE_INSTALLER_SIGN_IDENTITY="Developer ID Installer: test",
                        CLEARTONE_DRIVER_SIGN_IDENTITY="-")
        result = self.run_script("scripts/package-mac.sh")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HAL driver also requires", result.stderr)


if __name__ == "__main__":
    unittest.main()
