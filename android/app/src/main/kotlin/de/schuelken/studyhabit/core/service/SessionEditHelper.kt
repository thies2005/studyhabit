package de.schuelken.studyhabit.core.service

import androidx.room.withTransaction
import de.schuelken.studyhabit.core.database.StudySessionEntity
import de.schuelken.studyhabit.core.database.UserStatsEntity
import de.schuelken.studyhabit.core.di.AppContainer
import de.schuelken.studyhabit.ui.widget.StudyHabitWidgetProvider

object SessionEditHelper {

    fun calculateEffectivePomodoros(isFreeTimer: Boolean, plannedDurationMinutes: Int, actualMinutes: Int): Int {
        val clampedMinutes = actualMinutes.coerceIn(1, 720)
        return if (!isFreeTimer && plannedDurationMinutes > 0) {
            (clampedMinutes / plannedDurationMinutes).coerceAtLeast(
                if (clampedMinutes * 60 >= plannedDurationMinutes * 60 * 0.8) 1 else 0
            )
        } else {
            0
        }
    }

    fun calculateSessionXp(session: StudySessionEntity, newMinutes: Int, newConfidence: Int?): Int {
        val clampedMinutes = newMinutes.coerceIn(1, 720)
        val effectivePomodoros = calculateEffectivePomodoros(
            isFreeTimer = session.isFreeTimer,
            plannedDurationMinutes = session.plannedDurationMinutes,
            actualMinutes = clampedMinutes
        )
        return XpCalculator.calculateSessionXp(
            actualMinutes = clampedMinutes,
            confidence = newConfidence,
            isPomodoro = !session.isFreeTimer,
            pomodorosCompleted = effectivePomodoros,
            plannedSeconds = session.plannedDurationMinutes * 60,
            studiedSeconds = clampedMinutes * 60
        )
    }

    suspend fun updateSession(
        context: android.content.Context,
        container: AppContainer,
        session: StudySessionEntity,
        newMinutes: Int,
        newConfidence: Int?,
        newNotes: String?
    ) {
        val clampedMinutes = newMinutes.coerceIn(1, 720)
        val effectivePomodoros = calculateEffectivePomodoros(
            isFreeTimer = session.isFreeTimer,
            plannedDurationMinutes = session.plannedDurationMinutes,
            actualMinutes = clampedMinutes
        )

        val newXp = calculateSessionXp(session, clampedMinutes, newConfidence)

        container.database.withTransaction {
            val xpDelta = newXp - session.xpEarned
            val minutesDelta = clampedMinutes - session.actualDurationMinutes

            val updatedSession = session.copy(
                actualDurationMinutes = clampedMinutes,
                endedAt = session.startedAt + clampedMinutes * 60_000L,
                pomodorosCompleted = effectivePomodoros,
                confidenceRating = newConfidence,
                notes = newNotes?.trim()?.ifEmpty { null },
                xpEarned = newXp,
                updatedAt = System.currentTimeMillis()
            )
            container.database.sessionDao().upsert(updatedSession)

            container.database.subjectDao().updateXp(session.subjectId, xpDelta)

            val currentStats = container.database.userStatsDao().getUserStats() ?: UserStatsEntity()
            val newTotalXp = (currentStats.totalXp + xpDelta).coerceAtLeast(0)
            val newLevel = XpCalculator.calculateLevel(newTotalXp)
            val newTotalMinutes = (currentStats.totalStudyMinutes + minutesDelta).coerceAtLeast(0)
            container.database.userStatsDao().upsert(
                currentStats.copy(
                    totalXp = newTotalXp,
                    currentLevel = newLevel,
                    totalStudyMinutes = newTotalMinutes,
                    updatedAt = System.currentTimeMillis()
                )
            )
        }

        container.achievementEvaluator.checkAndUnlock()
        StudyHabitWidgetProvider.updateAllWidgets(context)
        container.triggerDataChangedSync()
    }

    suspend fun updateSession(
        container: AppContainer,
        session: StudySessionEntity,
        newMinutes: Int,
        newConfidence: Int?,
        newNotes: String?
    ) = updateSession(container.context, container, session, newMinutes, newConfidence, newNotes)
}
