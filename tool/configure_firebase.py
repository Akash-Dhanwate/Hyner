#!/usr/bin/env python3
"""Extract configuration from an actual Firebase Android registration, without printing keys."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def configure(source: Path, environment: str, application_id: str | None) -> Path:
    data = json.loads(source.read_text())
    clients = data.get('client', [])
    if application_id:
        clients = [client for client in clients if client.get('client_info', {}).get('android_client_info', {}).get('package_name') == application_id]
    if len(clients) != 1:
        raise ValueError('Select one registered Android client with --application-id. No configuration was written.')
    client = clients[0]
    info = client['client_info']
    package = info['android_client_info']['package_name']
    web_clients = [item['client_id'] for item in client.get('oauth_client', []) if item.get('client_type') == 3]
    if not web_clients:
        raise ValueError('No web OAuth client was found. Enable Google in Firebase Authentication, add SHA fingerprints, and download a fresh google-services.json.')
    api_keys = client.get('api_key', [])
    if not api_keys:
        raise ValueError('The Firebase registration has no API key. Download google-services.json again.')
    project = data['project_info']
    values = {
        'HYNER_ENV': environment,
        'FIREBASE_API_KEY': api_keys[0]['current_key'],
        'FIREBASE_APP_ID': info['mobilesdk_app_id'],
        'FIREBASE_MESSAGING_SENDER_ID': project['project_number'],
        'FIREBASE_PROJECT_ID': project['project_id'],
        'GOOGLE_SERVER_CLIENT_ID': web_clients[0],
        'HYNER_ANDROID_APPLICATION_ID': package,
    }
    if any(not isinstance(value, str) or not value.strip() for value in values.values()):
        raise ValueError('The downloaded configuration is incomplete. No configuration was written.')
    if environment == 'production' and package.startswith('com.example.'):
        raise ValueError('Register your final Android application ID before configuring production.')
    destination = ROOT / 'config' / f'firebase.{environment}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(values, indent=2) + '\n')
    destination.chmod(0o600)
    print(f'Configuration written: {destination.relative_to(ROOT)}')
    print(f'Android application ID: {package}')
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--google-services', required=True, type=Path)
    parser.add_argument('--environment', choices=['development', 'production'], default='development')
    parser.add_argument('--application-id')
    arguments = parser.parse_args()
    try:
        configure(arguments.google_services, arguments.environment, arguments.application_id)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f'Configuration failed: {error}\n')


if __name__ == '__main__':
    main()
