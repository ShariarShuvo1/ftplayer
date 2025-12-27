-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }

-dontwarn com.dexterous.**

-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep interface com.dexterous.flutterlocalnotifications.** { *; }

-keep public class * extends android.app.IntentService
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
