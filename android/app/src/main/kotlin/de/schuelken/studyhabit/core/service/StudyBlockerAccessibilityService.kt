package de.schuelken.studyhabit.core.service

import android.accessibilityservice.AccessibilityService
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.provider.Settings
import android.text.TextUtils
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager
import de.schuelken.studyhabit.StudyHabitApplication
import de.schuelken.studyhabit.core.model.TimerPhase
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
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return

        if (SystemClock.elapsedRealtime() < bypassUntilElapsedMs) return

        val app = applicationContext as? StudyHabitApplication ?: return
        val preferences = app.container.preferences
        if (!preferences.appBlockerEnabled) return

        val blockedSet = preferences.blockedAppPackages
        if (pkg !in blockedSet) return

        val state = TimerForegroundService.timerState.value
        val shouldBlockTimer = state.isRunning && (!preferences.blockOnlyDuringFocusPhase || (!state.isPaused && state.phase == TimerPhase.WORK))
        if (!shouldBlockTimer) return

        // Ignore own package, System UI, and Settings
        if (pkg == packageName || pkg == "com.android.systemui" || pkg == "com.android.settings") return

        // Ignore input methods (keyboards)
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager
        val enabledImes = imm?.enabledInputMethodList?.map { it.packageName } ?: emptyList()
        if (pkg in enabledImes) return

        // Ignore default home launcher
        val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val defaultLauncher = packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
        if (pkg == defaultLauncher) return

        val intent = Intent(this, BlockedAppActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(BlockedAppActivity.EXTRA_BLOCKED_PACKAGE, pkg)
        }
        startActivity(intent)
    }

    override fun onInterrupt() {
        // No-op
    }
}
