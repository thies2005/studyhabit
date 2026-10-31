package de.schuelken.studyhabit.core.service

object BlockerPresets {
    private val socialPackages = setOf("com.facebook.katana", "com.facebook.lite", "com.instagram.android", "com.instagram.lite", "com.zhiliaoapp.musically", "com.ss.android.ugc.trill", "com.snapchat.android", "com.twitter.android", "com.reddit.frontpage", "com.discord", "org.telegram.messenger", "com.whatsapp", "com.pinterest", "com.linkedin.android", "com.google.android.youtube", "com.facebook.orca", "com.bsky.app", "com.instagram.barcelona")
    fun isSocial(packageName: String, categorySocial: Boolean): Boolean = categorySocial || packageName in socialPackages
    fun select(current: Set<String>, matches: Set<String>): Set<String> = current + matches
}
