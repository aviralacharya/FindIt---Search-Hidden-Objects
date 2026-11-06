# Flutter and the remaining local-storage/audio plugins ship consumer rules.
-keepattributes Signature,InnerClasses,EnclosingMethod
# No blanket SDK keeps. The demo-only WorkDatabase constructor rule now lives
# in ad_preview/android/app/proguard-rules.pro with the dependency that needs it.
