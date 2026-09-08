# Security and secrets release checklist

## App Check

The app uses Firebase App Check debug providers for debug/profile builds and
production attestation providers for release builds:

- Android release: Play Integrity
- iOS release: DeviceCheck

Before shipping, register the Android package and iOS bundle ID in Firebase,
enable Play Integrity and DeviceCheck providers in the Firebase console, and
set enforcement for the Firebase products used by the app. Debug tokens must
be registered only for local development and must never be used in a store
build.

Release verification:

1. Build and install a release artifact on a real Android device and iPhone.
2. Confirm Firebase requests succeed with valid attestation.
3. Confirm an unregistered/debug token is rejected after enforcement is
   enabled.
4. Confirm debug builds still work with a locally registered debug token.

## Configuration and credentials

Firebase client identifiers in `firebase_options.dart` and
`google-services.json` are application identifiers, not server credentials.
They must still be restricted in the Firebase/Google Cloud console by
platform package/bundle ID and the APIs the app uses.

Never commit service-account JSON files, private keys, keystores, signing
certificates, or API secrets. Keep release signing material and passwords in
the platform CI secret store.

## Release signing blocker

Android currently uses the debug signing configuration for release builds and
still uses the template `com.example.billbuddy` application ID. Before store
submission, create a real production application ID, register it in Firebase,
configure a release keystore through CI secrets, and replace the debug
`signingConfig`. The iOS bundle identifier and signing team must likewise be
set to the production values in Xcode.
