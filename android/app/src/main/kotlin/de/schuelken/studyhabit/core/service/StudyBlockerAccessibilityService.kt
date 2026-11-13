package de.schuelken.studyhabit.core.service

import android.Manifest
import android.accessibilityservice.AccessibilityService
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.text.TextUtils
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import de.schuelken.studyhabit.StudyHabitApplication
import de.schuelken.studyhabit.core.model.TimerPhase
import de.schuelken.studyhabit.core.preferences.AppPreferences
import de.schuelken.studyhabit.ui.blocker.BlockedAppActivity

class StudyBlockerAccessibilityService : AccessibilityService() {

    companion object {
        var bypassUntilElapsedMs: Long = 0L

        fun isAccessibilityServiceEnabled(context: Context): Boolean {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false
            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServices)
            val expected = ComponentName(context, StudyBlockerAccessibilityService::class.java)
            while (colonSplitter.hasNext()) {
                val enabledComponent = ComponentName.unflattenFromString(colonSplitter.next())
                if (enabledComponent == expected) {
                    return true
                }
            }
            return false
        }

        fun hasUsageStatsPermission(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            }
            if (mode == AppOpsManager.MODE_DEFAULT) {
                return context.checkCallingOrSelfPermission(Manifest.permission.PACKAGE_USAGE_STATS) == PackageManager.PERMISSION_GRANTED
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }

        fun getForegroundPackageFromUsageStats(context: Context): String? {
            val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager ?: return null
            val endTime = System.currentTimeMillis()
            val beginTime = endTime - 60_000L
            val events = usageStatsManager.queryEvents(beginTime, endTime) ?: return null
            val event = UsageEvents.Event()
            var latestPackage: String? = null
            var latestTimestamp = 0L
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val isForeground = event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND)
                if (isForeground && event.timeStamp >= latestTimestamp) {
                    latestTimestamp = event.timeStamp
                    latestPackage = event.packageName
                }
            }
            return latestPackage
        }

        fun blockIfNeeded(
            context: Context,
            pkg: String,
            preferences: AppPreferences,
            state: TimerState
        ) {
            if (SystemClock.elapsedRealtime() < bypassUntilElapsedMs) return
            if (!preferences.appBlockerEnabled) return
            if (pkg !in preferences.blockedAppPackages) return

            val shouldBlockTimer = state.isRunning &&
                (!preferences.blockOnlyDuringFocusPhase || (!state.isPaused && state.phase == TimerPhase.WORK))
            if (!shouldBlockTimer) return

            // Ignore own package, System UI, and Settings
            if (pkg == context.packageName || pkg == "com.android.systemui" || pkg == "com.android.settings") return

            // Ignore input methods (keyboards)
            val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
            val enabledImes = imm?.enabledInputMethodList?.map { it.packageName } ?: emptyList()
            if (pkg in enabledImes) return

            // Ignore default home launcher
            val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            val defaultLauncher = context.packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
            if (pkg == defaultLauncher) return

            // On Android 10+ (enforced strictly on 14-16), starting an Activity from a foreground service
            // hits Background Activity Launch (BAL) restrictions unless Accessibility or Display Over Other Apps is granted.
            val canLaunchFromBackground = isAccessibilityServiceEnabled(context) || Settings.canDrawOverlays(context)
            if (!canLaunchFromBackground) return

            val intent = Intent(context, BlockedAppActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(BlockedAppActivity.EXTRA_BLOCKED_PACKAGE, pkg)
            }
            runCatching { context.startActivity(intent) }
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        val app = applicationContext as? StudyHabitApplication ?: return
        blockIfNeeded(this, pkg, app.container.preferences, TimerForegroundService.timerState.value)
    }

    override fun onInterrupt() {
        // No-op
    }
}
