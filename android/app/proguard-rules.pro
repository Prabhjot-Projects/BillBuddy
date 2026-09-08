# ML Kit references optional language recognizers from one shared entry point.
# BillBuddy bundles Latin text recognition only, so these optional classes are
# intentionally absent from the release APK.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
