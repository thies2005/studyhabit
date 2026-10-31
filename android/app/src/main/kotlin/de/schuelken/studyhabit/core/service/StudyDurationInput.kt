package de.schuelken.studyhabit.core.service

object StudyDurationInput {
    fun minutes(text: String): Int? = text.toIntOrNull()?.takeIf { it in 1..720 }
    fun reduction(text: String, baseline: Int): Int? =
        if (text.isEmpty()) 0 else text.toIntOrNull()?.takeIf { it in 0 until baseline }
}
