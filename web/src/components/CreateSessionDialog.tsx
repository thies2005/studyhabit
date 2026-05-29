import { useState, useEffect } from 'react';
import apiClient from '../api/client';
import type { Subject, Topic, Chapter } from '../types';

interface CreateSessionDialogProps {
  isOpen: boolean;
  onClose: () => void;
  subjects: Subject[];
  onSubmit: (sessionData: {
    subjectId: string;
    topicId: string | null;
    chapterId: string | null;
    startedAt: string;
    endedAt: string | null;
    plannedDurationMinutes: number;
    actualDurationMinutes: number;
    pomodorosCompleted: number;
    confidenceRating: number | null;
    notes: string | null;
  }) => Promise<void>;
}

interface TopicWithChapters extends Topic {
  chapters: Chapter[];
}

export default function CreateSessionDialog({ isOpen, onClose, subjects, onSubmit }: CreateSessionDialogProps) {
  const [selectedSubjectId, setSelectedSubjectId] = useState('');
  const [topics, setTopics] = useState<TopicWithChapters[]>([]);
  const [selectedTopicId, setSelectedTopicId] = useState('');
  const [selectedChapterId, setSelectedChapterId] = useState('');

  const [date, setDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [startTime, setStartTime] = useState(() => {
    const now = new Date();
    return `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
  });
  const [actualDuration, setActualDuration] = useState(25);
  const [plannedDuration, setPlannedDuration] = useState(25);
  const [confidence, setConfidence] = useState<number | null>(null);
  const [notes, setNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Set default subject on open
  useEffect(() => {
    if (isOpen && subjects.length > 0 && !selectedSubjectId) {
      setSelectedSubjectId(subjects[0].id);
    }
  }, [isOpen, subjects, selectedSubjectId]);

  // Fetch topics and chapters when subject changes
  useEffect(() => {
    if (!selectedSubjectId) {
      setTopics([]);
      setSelectedTopicId('');
      setSelectedChapterId('');
      return;
    }

    const fetchTopics = async () => {
      try {
        const response = await apiClient.get('/topics', {
          params: { subjectId: selectedSubjectId },
        });
        setTopics(response.data.data);
        setSelectedTopicId('');
        setSelectedChapterId('');
      } catch (err) {
        console.error('Failed to fetch topics:', err);
      }
    };

    fetchTopics();
  }, [selectedSubjectId]);

  if (!isOpen) return null;

  const currentSubject = subjects.find((s) => s.id === selectedSubjectId);
  const hasTopics = currentSubject && currentSubject.hierarchyMode !== 'flat';
  const hasChapters = currentSubject && currentSubject.hierarchyMode === 'threeLevel';

  const selectedTopic = topics.find((t) => t.id === selectedTopicId);
  const availableChapters = selectedTopic?.chapters || [];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedSubjectId) {
      setError('Subject is required');
      return;
    }

    // Combine date and time
    const startDateTime = new Date(`${date}T${startTime}:00`);
    const endDateTime = new Date(startDateTime.getTime() + actualDuration * 60 * 1000);

    setIsSubmitting(true);
    setError(null);
    try {
      await onSubmit({
        subjectId: selectedSubjectId,
        topicId: selectedTopicId || null,
        chapterId: selectedChapterId || null,
        startedAt: startDateTime.toISOString(),
        endedAt: endDateTime.toISOString(),
        plannedDurationMinutes: plannedDuration,
        actualDurationMinutes: actualDuration,
        pomodorosCompleted: Math.floor(actualDuration / 25),
        confidenceRating: confidence,
        notes: notes.trim() || null,
      });

      // Reset form
      setSelectedTopicId('');
      setSelectedChapterId('');
      setActualDuration(25);
      setPlannedDuration(25);
      setConfidence(null);
      setNotes('');
      onClose();
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to log study session');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-surfaceHigh border border-gray-800 rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl animate-scaleUp">
        {/* Header */}
        <div className="px-6 py-5 border-b border-gray-800 flex justify-between items-center">
          <h2 className="text-xl font-bold text-onSurface font-heading flex items-center gap-2">
            <span className="material-icons text-primary">history_edu</span>
            Log Study Session Manually
          </h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-gray-400 hover:bg-surface hover:text-white transition-colors"
          >
            <span className="material-icons text-lg">close</span>
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-5 max-h-[80vh] overflow-y-auto">
          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-xl text-sm text-red-400 font-body">
              {error}
            </div>
          )}

          {/* Subject Picker */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
              Select Subject <span className="text-red-500">*</span>
            </label>
            <select
              required
              value={selectedSubjectId}
              onChange={(e) => setSelectedSubjectId(e.target.value)}
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
            >
              <option value="" disabled>Select a subject...</option>
              {subjects.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </select>
          </div>

          {/* Hierarchy Inputs (Topics/Chapters) */}
          {hasTopics && topics.length > 0 && (
            <div className="grid grid-cols-2 gap-4">
              {/* Topic Select */}
              <div>
                <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
                  Select Topic
                </label>
                <select
                  value={selectedTopicId}
                  onChange={(e) => setSelectedTopicId(e.target.value)}
                  className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
                >
                  <option value="">None</option>
                  {topics.map((t) => (
                    <option key={t.id} value={t.id}>
                      {t.name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Chapter Select */}
              {hasChapters && (
                <div>
                  <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
                    Select Chapter
                  </label>
                  <select
                    value={selectedChapterId}
                    onChange={(e) => setSelectedChapterId(e.target.value)}
                    disabled={!selectedTopicId || availableChapters.length === 0}
                    className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors disabled:opacity-50"
                  >
                    <option value="">None</option>
                    {availableChapters.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}
            </div>
          )}

          {/* Date and Time Pickers */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
                Date
              </label>
              <input
                type="date"
                required
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
                Start Time
              </label>
              <input
                type="time"
                required
                value={startTime}
                onChange={(e) => setStartTime(e.target.value)}
                className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
              />
            </div>
          </div>

          {/* Durations */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
                Planned Duration (min)
              </label>
              <input
                type="number"
                min="0"
                max="480"
                value={plannedDuration}
                onChange={(e) => setPlannedDuration(Number(e.target.value))}
                className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
                Actual Study Duration (min)
              </label>
              <input
                type="number"
                min="1"
                max="480"
                value={actualDuration}
                onChange={(e) => setActualDuration(Number(e.target.value))}
                className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
              />
            </div>
          </div>

          {/* Confidence Rating (1-5 Stars) */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
              How confident do you feel about this material?
            </label>
            <div className="flex items-center space-x-2">
              {[1, 2, 3, 4, 5].map((star) => (
                <button
                  key={star}
                  type="button"
                  onClick={() => setConfidence(star === confidence ? null : star)}
                  className="focus:outline-none transition-transform hover:scale-125"
                >
                  <span className={`material-icons text-2xl ${
                    confidence && star <= confidence ? 'text-yellow-500' : 'text-gray-600'
                  }`}>
                    star
                  </span>
                </button>
              ))}
              <span className="text-xs text-gray-500 ml-2 font-body">
                {confidence ? `${confidence} / 5` : 'Not rated'}
              </span>
            </div>
          </div>

          {/* Session Notes */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
              Study Notes (Optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="What did you study? Write any takeaways, concepts, or reminders..."
              rows={3}
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-gray-600 resize-none"
            />
          </div>

          {/* Footer Actions */}
          <div className="flex gap-3 pt-4 border-t border-gray-800">
            <button
              type="button"
              onClick={onClose}
              disabled={isSubmitting}
              className="flex-1 py-3 bg-surface hover:bg-gray-800 text-gray-300 font-bold rounded-xl transition-colors font-body text-sm"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting}
              className="flex-1 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm flex items-center justify-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  <span>Saving...</span>
                </>
              ) : (
                <span>Save Session</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
