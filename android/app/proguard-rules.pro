# Intentionally empty.
#
# R8 is not enabled for the release build (no `isMinifyEnabled = true` in
# app/build.gradle.kts), so nothing here runs today. The file is kept because
# `proguardFiles` names it, and because the rules that used to live here — a set
# of -dontwarn lines for ML Kit text recognition — outlived the dependency they
# were written for: the translation feature they belonged to was removed, and
# stale keep rules are worse than none, since they read as evidence that a
# library is still in the build.
#
# If shrinking is ever turned on, the libraries that will need rules are
# sherpa_onnx (JNI entry points reached only by name) and onnxruntime.
