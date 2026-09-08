# Release preparation checklist

## Current configuration

- App name: BillBuddy
- Android minimum SDK: 26
- Android compile SDK: 37
- Android camera permission: declared
- iOS camera permission: declared
- iOS photo-library permission: declared
- Android and iOS launcher icon assets: present
- iOS launch-screen assets: present

## Required before store submission

### Identity and signing

- Replace the template Android application ID
  `com.example.billbuddy` with the production package name.
- Set the production iOS bundle identifier and Apple signing team.
- Register both production identifiers in Firebase and regenerate platform
  configuration files.
- Configure a CI-managed Android release keystore. Never commit the keystore
  or its password.
- Confirm the iOS distribution certificate and provisioning profile in Xcode.

### Store and privacy materials

- Prepare the store listing name, description, screenshots, support URL, and
  privacy-policy URL for both stores.
- Explain that receipt photos are processed for OCR and stored locally on the
  device unless a future cloud feature is enabled.
- Explain camera and photo-library use, local receipt data, optional Firebase
  services, and the JSON export feature.
- Confirm the privacy policy and data-safety declarations match the final
  Firebase, OCR, analytics, and crash-reporting configuration.

### Release validation

On a real Android device and iPhone:

1. Install release builds.
2. Verify camera scanning, gallery selection, OCR, manual bills, splitting,
   settlement, export, and deletion.
3. Verify App Check uses Play Integrity on Android and DeviceCheck on iOS.
4. Verify permissions are requested with the store-facing explanations.
5. Test an upgrade from the previous production build without clearing data.
6. Confirm the final version/build number and icons on both stores.
7. Confirm the Android release build completes with R8 enabled and inspect the
   generated APK/AAB on a physical device.

Windows can validate Dart code and Android configuration, but iOS release
building and Apple signing require macOS/Xcode.
