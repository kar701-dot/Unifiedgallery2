# Suppress warnings from missing FirebaseInstanceId referenced by old ML Kit/transitive libraries
-dontwarn com.google.firebase.iid.FirebaseInstanceId

# Suppress missing class warnings for optional ML Kit Text Recognition languages (only Latin is used by default)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
