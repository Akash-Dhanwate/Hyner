"""Isolated registration-import tests; fixture identifiers are never app config."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('configure_firebase', Path(__file__).resolve().parents[1] / 'tool/configure_firebase.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ConfigurationImportTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.previous_root = MODULE.ROOT
        MODULE.ROOT = self.root
        self.addCleanup(setattr, MODULE, 'ROOT', self.previous_root)
        self.fixture = {
            'project_info': {'project_number': '123456', 'project_id': 'test-only-fixture'},
            'client': [{
                'client_info': {'mobilesdk_app_id': '1:123456:android:testfixture', 'android_client_info': {'package_name': 'test.fixture.hyner'}},
                'api_key': [{'current_key': 'test-only-not-a-real-api-key'}],
                'oauth_client': [{'client_type': 3, 'client_id': 'test-only.apps.googleusercontent.com'}],
            }],
        }

    def run_import(self, environment='development', application_id=None):
        source = self.root / 'registration.json'
        source.write_text(json.dumps(self.fixture))
        return MODULE.configure(source, environment, application_id)

    def test_actual_registration_values_are_preserved_without_printing_the_key(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            path = self.run_import()
        result = json.loads(path.read_text())
        self.assertEqual(result['FIREBASE_PROJECT_ID'], 'test-only-fixture')
        self.assertEqual(result['FIREBASE_API_KEY'], 'test-only-not-a-real-api-key')
        self.assertEqual(result['HYNER_ANDROID_APPLICATION_ID'], 'test.fixture.hyner')
        self.assertNotIn('test-only-not-a-real-api-key', output.getvalue())
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_missing_web_oauth_client_does_not_write_config(self):
        self.fixture['client'][0]['oauth_client'] = []
        with self.assertRaisesRegex(ValueError, 'web OAuth client'):
            self.run_import()
        self.assertFalse((self.root / 'config').exists())

    def test_missing_api_key_does_not_write_config(self):
        self.fixture['client'][0]['api_key'] = []
        with self.assertRaisesRegex(ValueError, 'no API key'):
            self.run_import()

    def test_ambiguous_android_registrations_require_explicit_selection(self):
        self.fixture['client'].append(json.loads(json.dumps(self.fixture['client'][0])))
        self.fixture['client'][1]['client_info']['android_client_info']['package_name'] = 'test.fixture.other'
        with self.assertRaisesRegex(ValueError, 'Select one'):
            self.run_import()
        with contextlib.redirect_stdout(io.StringIO()):
            path = self.run_import(application_id='test.fixture.hyner')
        self.assertEqual(json.loads(path.read_text())['HYNER_ANDROID_APPLICATION_ID'], 'test.fixture.hyner')

    def test_empty_registration_values_do_not_write_config(self):
        self.fixture['project_info']['project_id'] = ''
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            self.run_import()

    def test_production_rejects_the_flutter_template_package(self):
        self.fixture['client'][0]['client_info']['android_client_info']['package_name'] = 'com.example.hyner'
        with self.assertRaisesRegex(ValueError, 'final Android application ID'):
            self.run_import(environment='production')


if __name__ == '__main__':
    unittest.main()
