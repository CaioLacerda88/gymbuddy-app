# GymBuddy R8 keep rules. Narrow by design — do NOT add -keep class ** wildcards.
# Every block documents WHY it exists and which library triggers it.
#
# Order: attributes -> JNI -> Flutter engine -> per-library blocks.

# ---------------------------------------------------------------------------
# Reflection-friendly attributes (must appear before any -keep rules)
# ---------------------------------------------------------------------------
# Signature + InnerClasses: Sentry generic type deobfuscation, readable stacks.
# *Annotation*: any JSON path that inspects annotations at runtime (Sentry's
#   JsonSerializable, AndroidX @Keep, retrofit-style reflection if a plugin
#   adds it). Cheap insurance.
# EnclosingMethod: keep lambda + anonymous class names legible in crash reports.
# SourceFile + LineNumberTable: needed for readable stack traces. We rename
#   SourceFile to "SourceFile" to strip original .kt paths while still giving
#   R8 enough metadata to produce line numbers.
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# JNI native methods
# ---------------------------------------------------------------------------
# Any class with a `native` method must be kept; stripping breaks JNI lookup
# with UnsatisfiedLinkError. Affects Flutter engine, Sentry NDK, SQLite,
# CanvasKit native glue.
-keepclasseswithmembernames class * { native <methods>; }

# Enums used across JNI / reflection need values() and valueOf() preserved.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable CREATOR fields — some plugins hand Parcelables across isolate
# boundaries. Without this, the static CREATOR field gets stripped.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# ---------------------------------------------------------------------------
# Flutter embedding
# ---------------------------------------------------------------------------
# Flutter engine reflectively instantiates plugin registrants and embedding
# entry points. The Flutter team's canonical guidance is to keep these
# packages whole; stripping causes opaque MissingPluginException at runtime.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---------------------------------------------------------------------------
# Play Core (deferred components) — not used, suppress R8 missing-class errors
# ---------------------------------------------------------------------------
# Flutter's embedding references com.google.android.play.core.splitinstall.*
# from PlayStoreDeferredComponentManager even though we do NOT use deferred
# components. Without -dontwarn R8 hard-fails with "Missing class ...".
# We suppress rather than add play:core (which would inflate ~1.5MB for a
# feature we don't ship).
-dontwarn com.google.android.play.core.**

# ---------------------------------------------------------------------------
# Sentry (sentry_flutter -> sentry-android + NDK)
# ---------------------------------------------------------------------------
# sentry-android ships consumer ProGuard rules via its AAR, but we lock
# intent here in case a future minor version regresses them. Sentry uses
# reflection for: breadcrumb serialization (JsonSerializer), integration
# auto-discovery (AndroidManifest meta-data), and the NDK crash bridge.
-keep class io.sentry.** { *; }
-keep interface io.sentry.** { *; }
-dontwarn io.sentry.**

# ---------------------------------------------------------------------------
# Supabase (supabase_flutter — Dart side) + OkHttp (transitive Android)
# ---------------------------------------------------------------------------
# The supabase_flutter plugin is pure Dart over platform channels — no
# supabase-kt on the Android classpath. All Supabase domain models live in
# Dart (Freezed/json_serializable), so R8 never sees them. BUT the
# `supabase_flutter` plugin depends on `app_links` and transitively on
# OkHttp via some HTTP clients that bundle it. If Realtime phoenix channels
# start failing in release builds, the culprit is usually OkHttp's internal
# reflection for Conscrypt / BouncyCastle TLS providers.
#
# Guard against those transitively-pulled HTTP clients:
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# If a future Supabase version introduces a Kotlin/Java domain layer that
# reflects on POJOs for JSON, add a targeted -keep here. DO NOT preemptively
# keep io.supabase.** today — there is no io.supabase package on the
# classpath at this Flutter version.

# ---------------------------------------------------------------------------
# Hive (hive / hive_flutter)
# ---------------------------------------------------------------------------
# Hive is pure Dart; its Android side is just path_provider + file I/O. No
# TypeAdapter reflection lives on the JVM. `lib/core/local_storage/hive_service.dart`
# only opens Box<dynamic> (active_workout, offline_queue, user_prefs) — zero
# registered adapters as of Phase 13. NO KEEP RULES REQUIRED.
#
# REVISIT when Phase 14 offline support lands: if it adds
# `Hive.registerAdapter(SomethingAdapter())` with a @HiveType-generated
# adapter, no JVM rules are needed either (adapters are Dart-side). This
# comment exists only to prevent a future agent from adding cargo-cult
# -keep rules for Hive.

# ---------------------------------------------------------------------------
# Freezed / json_serializable / Riverpod / GoRouter
# ---------------------------------------------------------------------------
# All code-gen outputs live in Dart (*.g.dart / *.freezed.dart) compiled
# AOT into libapp.so. R8 never sees them. NO KEEP RULES REQUIRED.

# ---------------------------------------------------------------------------
# flutter_dotenv, package_info_plus, wakelock_plus, flutter_svg,
# cached_network_image, fl_chart, flutter_markdown_plus
# ---------------------------------------------------------------------------
# All pure-Dart / standard platform-channel plugins with no reflection
# surfaces on the JVM side. The Flutter embedding -keep block above already
# covers the generated GeneratedPluginRegistrant. NO KEEP RULES REQUIRED.

# ---------------------------------------------------------------------------
# Kotlin coroutines (transitive via some plugins)
# ---------------------------------------------------------------------------
# Kotlinx-coroutines uses reflection on DebugProbesKt in debug builds only;
# the kotlinx.coroutines consumer rules already handle this. Suppress the
# noisy R8 warning if a transitive dep pulls a slightly-old coroutines jar.
-dontwarn kotlinx.coroutines.**
