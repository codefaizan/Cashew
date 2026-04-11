# Keep rules generated to suppress R8 warnings about missing mediapipe proto classes
# These were suggested by the R8 missing_rules.txt
-dontwarn com.google.mediapipe.proto.CalculatorProfileProto$CalculatorProfile
-dontwarn com.google.mediapipe.proto.GraphTemplateProto$CalculatorGraphTemplate

# Conservative keep to avoid stripping potential entry points in mediapipe frameworks
-keep class com.google.mediapipe.** { *; }
