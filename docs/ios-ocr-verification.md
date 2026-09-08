# iOS OCR verification

BillBuddy uses Apple Vision OCR on iOS and Google ML Kit OCR on Android and
other platforms. Both implementations return normalized text: line endings
are converted to `\n`, blank lines are removed, and trailing whitespace is
trimmed. The receipt validator and parser therefore receive the same basic
text shape on both platforms.

## Required macOS environment

- macOS with Xcode installed
- CocoaPods installed and available on `PATH`
- An iOS simulator or physical iPhone
- Apple signing configured for the Runner target

From the project root on macOS:

```bash
flutter pub get
cd ios
pod install
cd ..
flutter doctor -v
flutter devices
flutter test
flutter build ios --debug --no-codesign
```

Run the app on an iOS device or simulator and scan the same receipt fixtures
used for Android verification. Compare:

1. OCR success versus empty-text and OCR-failure states.
2. Line ordering and line-ending normalization.
3. Merchant, item, tax, subtotal, and total extraction in the review screen.
4. Rotated, perspective-corrected, low-light, and handwritten/noisy images.

Apple Vision and ML Kit can differ in recognition confidence, punctuation,
language correction, and reading order. The app does not assume identical
recognized text; both outputs go through the same receipt validation and AI
parsing stages, and failures remain typed `Result` failures with a retake
message instead of being treated as valid receipt data.

The Windows development environment cannot perform the Xcode build or
device-level Vision verification. Record the iOS build and fixture results
before App Store submission.

## Multi-page receipts

The document scanner accepts up to 10 pages. Each page is OCR'd in capture
order, then the page text is joined before validation and parsing. Every page
is now stored in the `receipt_images` table and in local receipt storage. The
first page remains the receipt cover image for backward compatibility, while
the detail viewer lets users swipe through all stored pages. Gallery uploads
continue to use the existing single-image flow.
