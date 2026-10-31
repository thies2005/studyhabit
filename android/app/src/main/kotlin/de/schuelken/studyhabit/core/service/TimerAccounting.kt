package de.schuelken.studyhabit.core.service

import de.schuelken.studyhabit.core.model.TimerPhase
import de.schuelken.studyhabit.core.model.TimerType

/** Keeps measured work separate from phase targets and break time. */
object TimerAccounting {
    fun priorWorkSeconds(state: TimerState): Int =
        if (state.phase == TimerPhase.WORK) {
            (state.totalWorkSeconds - state.elapsedSeconds).coerceAtLeast(0)
        } else state.totalWorkSeconds

    fun snapshot(state: TimerState, elapsedSeconds: Int, priorWorkSeconds: Int): TimerState {
        val elapsed = elapsedSeconds.coerceAtLeast(0)
        val work = if (state.phase == TimerPhase.WORK) priorWorkSeconds + elapsed else priorWorkSeconds
        return state.copy(
            elapsedSeconds = elapsed,
            totalWorkSeconds = work,
            remainingSeconds = (state.totalSeconds - elapsed).coerceAtLeast(0),
            isOvertime = state.timerType == TimerType.POMODORO && state.phase == TimerPhase.WORK && elapsed >= state.totalSeconds,
            overtimeSeconds = if (state.phase == TimerPhase.WORK) (elapsed - state.totalSeconds).coerceAtLeast(0) else 0
        )
    }

    fun advance(
        state: TimerState,
        longBreakSeconds: Int,
        longBreakEvery: Int,
        autoStartBreaks: Boolean,
        autoStartWork: Boolean
    ): TimerState {
        val leavingWork = state.phase == TimerPhase.WORK
        val earnedCompletion = leavingWork && state.elapsedSeconds >= state.totalSeconds
        val completed = state.pomodorosCompleted + if (earnedCompletion) 1 else 0
        val nextPhase = if (!leavingWork) TimerPhase.WORK else if (
            earnedCompletion && completed % longBreakEvery.coerceAtLeast(1) == 0
        ) TimerPhase.LONG_BREAK else TimerPhase.SHORT_BREAK
        val duration = when (nextPhase) {
            TimerPhase.WORK -> state.plannedWorkSeconds
            TimerPhase.LONG_BREAK -> longBreakSeconds
            else -> state.shortBreakSeconds.takeIf { it > 0 } ?: 5 * 60
        }
        return state.copy(
            phase = nextPhase, totalSeconds = duration, remainingSeconds = duration,
            elapsedSeconds = 0, overtimeSeconds = 0, isOvertime = false,
            pomodorosCompleted = completed,
            isPaused = if (leavingWork) !autoStartBreaks else !autoStartWork
        )
    }
}
