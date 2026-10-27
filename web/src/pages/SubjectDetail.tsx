import { useParams, Link, useNavigate } from 'react-router-dom';
import { useState } from 'react';
import { useApi } from '../api/hooks';
import type { Subject, SubjectMilestone } from '../types';
import CreateSessionDialog from '../components/CreateSessionDialog';
import CreateTopicDialog from '../components/CreateTopicDialog';
import CreateSourceDialog from '../components/CreateSourceDialog';
import ManageMilestonesDialog from '../components/ManageMilestonesDialog';
import EditSubjectDialog from '../components/EditSubjectDialog';
import PomodoroTimerModal from '../components/PomodoroTimerModal';
import apiClient from '../api/client';
import { getLevelProgress } from '../utils/xp';

type Tab = 'timeline' | 'sources' | 'topics';

const SKILL_LEVELS = ['beginner', 'intermediate', 'advanced', 'expert'] as const;

const isValidHttpUrl = (urlString: string | null | undefined): boolean => {
  if (!urlString) return false;
  try {
    const u = new URL(urlString);
    return u.protocol === 'http:' || u.protocol === 'https:';
  } catch {
    return false;
  }
};

export default function SubjectDetail() {
  const navigate = useNavigate();
  const { subjectId } = useParams<{ subjectId: string }>();
  const { data: subject, loading: subjectLoading, refetch: refetchSubject } = useApi<Subject & { topics: any[] }>(`/subjects/${subjectId}`);
  const { data: sessions, loading: sessionsLoading, refetch: refetchSessions } = useApi<any[]>(`/sessions?subjectId=${subjectId}`);
  const { data: sources, loading: sourcesLoading, refetch: refetchSources } = useApi<any[]>(`/sources?subjectId=${subjectId}`);
  const { data: milestones, loading: milestonesLoading, refetch: refetchMilestones } = useApi<SubjectMilestone[]>(`/milestones?subjectId=${subjectId}`);
  const { data: stats } = useApi<any>('/stats/overview');
  const { data: skillLabels, refetch: refetchSkillLabels } = useApi<any[]>(`/skill-labels?subjectId=${subjectId}`);
  
  const [activeTab, setActiveTab] = useState<Tab>('timeline');
  const [expandedTopics, setExpandedTopics] = useState<Set<string>>(new Set());
  const [isSessionDialogOpen, setIsSessionDialogOpen] = useState(false);
  const [isTopicDialogOpen, setIsTopicDialogOpen] = useState(false);
  const [isSourceDialogOpen, setIsSourceDialogOpen] = useState(false);
  const [isMilestonesDialogOpen, setIsMilestonesDialogOpen] = useState(false);
  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false);
  const [isTimerModalOpen, setIsTimerModalOpen] = useState(false);

  // Chapter creation state per topic
  const [addingChapterTopicId, setAddingChapterTopicId] = useState<string | null>(null);
  const [newChapterName, setNewChapterName] = useState('');
  const [isSubmittingChapter, setIsSubmittingChapter] = useState(false);

  // Skill updating state
  const [isUpdatingSkill, setIsUpdatingSkill] = useState(false);

  const loading = subjectLoading || sessionsLoading || sourcesLoading || milestonesLoading;

  if (loading) return <div className="p-8 text-center text-onSurfaceVariant">Loading...</div>;
  if (!subject) return <div className="p-8 text-center text-onSurfaceVariant">Subject not found</div>;

  const displaySubject = subject;
  const currentSkill = skillLabels?.[0]?.label || 'beginner';
  const totalStudyHours = displaySubject.totalStudyHours ?? (displaySubject.totalStudyMinutes ? Number((displaySubject.totalStudyMinutes / 60).toFixed(1)) : 0);

  const displaySessions = (sessions && sessions.length > 0)
    ? sessions.map((s) => ({
        id: s.id,
        date: new Date(s.startedAt).toLocaleDateString() + ' · ' + new Date(s.startedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        title: s.notes ? s.notes.split('\n')[0] : 'Study Session',
        description: s.notes || 'No notes added for this study session.',
        tags: s.topicId ? ['Topic'] : [],
        isLab: false,
        score: undefined,
        duration: `${s.actualDurationMinutes} min`,
        xp: s.xpEarned,
        confidence: s.confidenceRating || 3,
      }))
    : [];

  const displaySources = (sources && sources.length > 0)
    ? sources.map((src) => ({
        id: src.id,
        type: src.type === 'videoUrl' ? ('video' as const) : (src.type as 'pdf' | 'url'),
        title: src.title,
        url: src.url,
        subtitle: src.type === 'pdf' ? `PDF · ${src.totalPages || 0} Pages · Current: ${src.currentPage || 0}` : src.type === 'videoUrl' ? `VIDEO · ${Math.round(src.progressPercent || 0)}% watched` : `WEB · ${src.url || ''}`,
        pagesRead: src.currentPage || 0,
        totalPages: src.totalPages || 100,
        progress: src.progressPercent || 0,
      }))
    : [];

  const displayTopics = (subject?.topics && subject.topics.length > 0)
    ? subject.topics.map((t: any) => ({
        id: t.id,
        name: t.name,
        taskCount: t.chapters?.length || 0,
        subtopics: t.chapters?.map((c: any) => c.name) || [],
      }))
    : [];

  const handleCreateSession = async (sessionData: any) => {
    await apiClient.post('/sessions', sessionData);
    refetchSessions();
    refetchSubject();
  };

  const toggleTopic = (topicId: string) => {
    const newExpanded = new Set(expandedTopics);
    if (newExpanded.has(topicId)) {
      newExpanded.delete(topicId);
    } else {
      newExpanded.add(topicId);
    }
    setExpandedTopics(newExpanded);
  };

  const handleCreateTopic = async (topicData: { name: string; order: number }) => {
    await apiClient.post('/topics', { ...topicData, subjectId });
    refetchSubject();
  };

  const handleDeleteSubject = async () => {
    if (!window.confirm(`Are you sure you want to delete "${displaySubject.name}"? This action cannot be undone.`)) {
      return;
    }
    try {
      await apiClient.delete(`/subjects/${subjectId}`);
      navigate('/subjects');
    } catch (err) {
      console.error('Failed to delete subject:', err);
    }
  };

  const handleCreateSource = async (sourceData: any) => {
    await apiClient.post('/sources', { ...sourceData, subjectId });
    refetchSources();
  };

  const handleAddChapter = async (topicId: string, currentChapterCount: number) => {
    if (!newChapterName.trim()) return;
    try {
      setIsSubmittingChapter(true);
      await apiClient.post('/chapters', {
        topicId,
        name: newChapterName.trim(),
        order: currentChapterCount,
      });
      setNewChapterName('');
      setAddingChapterTopicId(null);
      refetchSubject();
    } catch (err) {
      console.error('Failed to create chapter:', err);
    } finally {
      setIsSubmittingChapter(false);
    }
  };

  const handleSkillChange = async (newLabel: string) => {
    try {
      setIsUpdatingSkill(true);
      await apiClient.post('/skill-labels', {
        subjectId,
        label: newLabel,
      });
      refetchSkillLabels();
    } catch (err) {
      console.error('Failed to update skill label:', err);
    } finally {
      setIsUpdatingSkill(false);
    }
  };

  const renderTabContent = () => {
    switch (activeTab) {
      case 'timeline':
        return (
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-onSurface font-heading flex items-center gap-2">
                <span className="material-symbols-rounded">filter_list</span>
                Study Sessions
              </h3>
              <button
                onClick={() => setIsSessionDialogOpen(true)}
                className="text-xs flex items-center gap-1 bg-primary hover:bg-primary-container px-3 py-1.5 rounded-lg text-white font-medium transition-colors font-body"
              >
                <span className="material-symbols-rounded text-sm">add</span>
                Log Session
              </button>
            </div>
            {displaySessions.length === 0 ? (
              <div className="text-center py-8 text-onSurfaceVariant font-body">No study sessions logged yet.</div>
            ) : displaySessions.map((session) => (
              <div key={session.id} className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-sm hover:shadow-md transition-shadow border border-transparent hover:border-outlineVariant">
                <div className="text-xs text-primary font-body font-medium mb-2">
                  {session.date}
                </div>
                <h4 className="text-base font-semibold text-onSurface font-heading mb-2">
                  {session.title}
                </h4>
                <p className="text-sm text-onSurfaceVariant font-body mb-3 line-clamp-2">
                  {session.description}
                </p>
                <div className="flex flex-wrap gap-2 mb-3">
                  {session.tags.map((tag) => (
                    <span
                      key={tag}
                      className="text-xs px-2 py-1 bg-primary/20 text-primary rounded-full font-body"
                    >
                      #{tag}
                    </span>
                  ))}
                </div>
                <div className="flex items-center gap-4 text-sm text-onSurfaceVariant font-body">
                  <span className="flex items-center gap-1">
                    <span className="material-symbols-rounded text-base">schedule</span>
                    {session.duration}
                  </span>
                  <span className="flex items-center gap-1">
                    <span className="material-symbols-rounded text-base">star</span>
                    {session.confidence}/5
                  </span>
                  <span className="flex items-center gap-1 text-primary">
                    <span className="material-symbols-rounded text-base">bolt</span>
                    +{session.xp} XP
                  </span>
                  {session.isLab && (
                    <span className="flex items-center gap-1 text-tertiary">
                      <span className="material-symbols-rounded text-base">biotech</span>
                      Lab • Score: {session.score}
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        );

      case 'sources':
        return (
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-onSurface font-heading flex items-center gap-2">
                <span className="material-symbols-rounded">folder_open</span>
                Primary Sources
              </h3>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => setIsSourceDialogOpen(true)}
                  className="text-xs flex items-center gap-1 text-primary hover:text-primary/80 font-medium transition-colors font-body"
                >
                  <span className="material-symbols-rounded text-sm">add</span>
                  Add Source
                </button>
              </div>
            </div>
            {displaySources.length === 0 ? (
              <div className="text-center py-8 text-onSurfaceVariant font-body">No sources added yet.</div>
            ) : displaySources.map((source) => (
              <div key={source.id} className="bg-surfaceContainerHigh rounded-3xl p-6 flex items-start gap-4 shadow-sm hover:shadow-md transition-shadow border border-transparent hover:border-outlineVariant">
                <div className={`flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center ${
                  source.type === 'pdf' ? 'bg-red-500/20' :
                  source.type === 'video' ? 'bg-purple-500/20' :
                  'bg-blue-500/20'
                }`}>
                  <span className={`material-symbols-rounded text-2xl ${
                    source.type === 'pdf' ? 'text-red-400' :
                    source.type === 'video' ? 'text-purple-400' :
                    'text-blue-400'
                  }`}>
                    {source.type === 'pdf' ? 'picture_as_pdf' :
                     source.type === 'video' ? 'play_circle' :
                     'article'}
                  </span>
                </div>
                <div className="flex-1 min-w-0">
                  {isValidHttpUrl(source.url) ? (
                    <a
                      href={source.url!}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-base font-semibold text-primary hover:underline font-heading mb-1 inline-flex items-center gap-1.5"
                    >
                      <span>{source.title}</span>
                      <span className="material-symbols-rounded text-sm" aria-hidden="true">open_in_new</span>
                    </a>
                  ) : (
                    <h4 className="text-base font-semibold text-onSurface font-heading mb-1">
                      {source.title}
                    </h4>
                  )}
                  <p className="text-sm text-onSurfaceVariant font-body mb-2">
                    {source.subtitle}
                  </p>
                  {source.type === 'pdf' && (
                    <div className="w-full bg-surfaceContainerHighest rounded-full h-1.5">
                      <div
                        className="bg-primary h-1.5 rounded-full"
                        style={{ width: `${(source.pagesRead / source.totalPages) * 100}%` }}
                      />
                    </div>
                  )}
                  {source.type === 'video' && (
                    <div className="w-full bg-surfaceContainerHighest rounded-full h-1.5">
                      <div
                        className="bg-purple-400 h-1.5 rounded-full"
                        style={{ width: `${source.progress}%` }}
                      />
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        );

      case 'topics':
        return (
          <div className="space-y-3">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-onSurface font-heading flex items-center gap-2">
                <span className="material-symbols-rounded">schema</span>
                Topics
              </h3>
              <div className="flex items-center gap-4">
                <span className="text-sm text-onSurfaceVariant font-body">{displayTopics.length} topics</span>
                <button
                  onClick={() => setIsTopicDialogOpen(true)}
                  className="text-xs flex items-center gap-1 text-primary hover:text-primary/80 font-medium transition-colors font-body"
                >
                  <span className="material-symbols-rounded text-sm">add</span>
                  Add Topic
                </button>
              </div>
            </div>
            {displayTopics.length === 0 ? (
              <div className="text-center py-8 text-onSurfaceVariant font-body">No topics added yet.</div>
            ) : displayTopics.map((topic) => (
              <div key={topic.id} className="bg-surfaceContainerHigh rounded-3xl overflow-hidden shadow-sm hover:shadow-md transition-shadow border border-transparent hover:border-outlineVariant">
                <div
                  role="button"
                  tabIndex={0}
                  aria-expanded={expandedTopics.has(topic.id)}
                  aria-label={`Toggle topic ${topic.name}`}
                  className="p-6 flex items-center justify-between cursor-pointer hover:bg-surfaceContainerHighest transition-colors focus:outline-none focus:ring-2 focus:ring-primary rounded-3xl"
                  onClick={() => toggleTopic(topic.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      toggleTopic(topic.id);
                    }
                  }}
                >
                  <div className="flex items-center justify-between w-full">
                    <div>
                      <h4 className="text-base font-semibold text-onSurface font-heading mb-1">
                        {topic.name}
                      </h4>
                      <p className="text-sm text-onSurfaceVariant font-body">
                        {topic.taskCount} chapters
                      </p>
                    </div>
                    <span className="material-symbols-rounded text-onSurfaceVariant transition-transform duration-300">
                      {expandedTopics.has(topic.id) ? 'expand_less' : 'expand_more'}
                    </span>
                  </div>
                </div>
                {expandedTopics.has(topic.id) && (
                  <div className="bg-surfaceContainer border-t border-surfaceContainerHighest">
                    {topic.subtopics && topic.subtopics.map((sub: string, i: number) => (
                      <div
                        key={i}
                        className="px-6 py-4 flex items-center gap-3 text-sm text-onSurfaceVariant font-body border-b border-surfaceContainerHighest last:border-0 hover:bg-surfaceContainerHigh transition-colors"
                      >
                        <span className="w-1.5 h-1.5 rounded-full bg-primary/50"></span>
                        {sub}
                      </div>
                    ))}

                    {/* Chapter creation inline */}
                    <div className="p-4 border-t border-surfaceContainerHighest">
                      {addingChapterTopicId === topic.id ? (
                        <div className="flex gap-2">
                          <input
                            type="text"
                            value={newChapterName}
                            onChange={(e) => setNewChapterName(e.target.value)}
                            placeholder="Chapter name..."
                            autoFocus
                            className="flex-1 px-3 py-1.5 bg-surface border border-outlineVariant focus:border-primary rounded-lg text-sm text-onSurface font-body focus:outline-none"
                            onKeyDown={(e) => {
                              if (e.key === 'Enter') {
                                handleAddChapter(topic.id, topic.subtopics.length);
                              } else if (e.key === 'Escape') {
                                setAddingChapterTopicId(null);
                                setNewChapterName('');
                              }
                            }}
                          />
                          <button
                            type="button"
                            onClick={() => handleAddChapter(topic.id, topic.subtopics.length)}
                            disabled={isSubmittingChapter || !newChapterName.trim()}
                            className="px-3 py-1.5 bg-primary hover:bg-primary-container text-white font-bold rounded-lg text-xs transition-colors disabled:opacity-50"
                          >
                            Save
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setAddingChapterTopicId(null);
                              setNewChapterName('');
                            }}
                            className="px-3 py-1.5 bg-surface hover:bg-surfaceContainerHighest text-onSurfaceVariant rounded-lg text-xs transition-colors"
                          >
                            Cancel
                          </button>
                        </div>
                      ) : (
                        <button
                          type="button"
                          onClick={() => {
                            setAddingChapterTopicId(topic.id);
                            setNewChapterName('');
                          }}
                          className="inline-flex items-center gap-1.5 text-xs text-primary hover:text-primary/80 font-medium font-body transition-colors"
                        >
                          <span className="material-symbols-rounded text-sm">add</span>
                          Add Chapter
                        </button>
                      )}
                    </div>
                  </div>
                )}
              </div>
            ))}
          </div>
        );
    }
  };

  const levelProgress = getLevelProgress(stats?.totalXp || 0);
  const level = levelProgress.currentLevel;
  const progressPercent = levelProgress.progressPercent;

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-7xl mx-auto">
          {/* Back Link */}
          <Link
            to="/subjects"
            className="text-primary hover:underline mb-4 inline-flex items-center gap-2 font-body"
          >
            <span className="material-symbols-rounded text-xl">arrow_back</span>
            Back to Subjects
          </Link>

          {/* Header Section */}
          <div className="mb-6">
            <div className="flex items-center flex-wrap gap-3 mb-3">
              <span className="px-3 py-1 bg-primary/20 text-primary text-xs font-medium rounded-full flex items-center gap-1 font-body">
                <span className="material-symbols-rounded text-sm">event</span>
                In Progress
              </span>
              <span className="text-sm text-onSurfaceVariant font-body">
                {totalStudyHours}h total study
              </span>

              {/* Skill Level Selector */}
              <div className="flex items-center gap-1.5 ml-auto">
                <span className="text-xs text-onSurfaceVariant font-body">Skill:</span>
                <select
                  value={currentSkill}
                  disabled={isUpdatingSkill}
                  onChange={(e) => handleSkillChange(e.target.value)}
                  className="bg-surfaceContainerHighest text-onSurface border border-outlineVariant rounded-lg px-2.5 py-1 text-xs font-semibold focus:outline-none focus:border-primary cursor-pointer capitalize"
                >
                  {SKILL_LEVELS.map((lvl) => (
                    <option key={lvl} value={lvl}>
                      {lvl.charAt(0).toUpperCase() + lvl.slice(1)}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
              <div>
                <h1 className="text-3xl font-bold text-onSurface font-heading mb-2">
                  {displaySubject.name}
                </h1>
                {displaySubject.description && (
                  <p className="text-onSurfaceVariant font-body">{displaySubject.description}</p>
                )}
              </div>
              <div className="flex items-center gap-2 flex-wrap">
                <button
                  type="button"
                  onClick={() => setIsTimerModalOpen(true)}
                  className="inline-flex items-center gap-1.5 px-4 py-2 bg-primary hover:bg-primary-container text-white text-sm font-semibold rounded-xl shadow transition-colors font-body"
                >
                  <span className="material-symbols-rounded text-base">timer</span>
                  Start Timer
                </button>
                <button
                  type="button"
                  onClick={() => setIsEditDialogOpen(true)}
                  aria-label="Edit subject"
                  className="inline-flex items-center gap-1.5 px-3 py-2 bg-surfaceContainerHighest hover:bg-surfaceContainerHigh text-onSurface text-sm font-medium rounded-xl border border-outlineVariant transition-colors font-body"
                >
                  <span className="material-symbols-rounded text-base">edit</span>
                  Edit
                </button>
                <button
                  type="button"
                  onClick={handleDeleteSubject}
                  aria-label="Delete subject"
                  className="inline-flex items-center gap-1.5 px-3 py-2 bg-surfaceContainerHighest hover:bg-red-500/20 text-red-400 text-sm font-medium rounded-xl border border-outlineVariant transition-colors font-body"
                >
                  <span className="material-symbols-rounded text-base">delete</span>
                  Delete
                </button>
              </div>
            </div>
          </div>

          {/* Tab Buttons */}
          <div className="flex gap-6 mb-6 border-b border-outlineVariant">
            {(['timeline', 'sources', ...(displaySubject.hierarchyMode !== 'flat' ? ['topics'] : [])] as Tab[]).map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`pb-3 text-sm font-medium font-body flex items-center gap-2 border-b-2 transition-colors ${
                  activeTab === tab
                    ? 'text-primary border-primary'
                    : 'text-onSurfaceVariant border-transparent hover:text-onSurface'
                }`}
              >
                <span className="material-symbols-rounded text-lg">
                  {tab === 'timeline' ? 'event_note' :
                   tab === 'sources' ? 'folder_open' : 'schema'}
                </span>
                {tab === 'timeline' ? 'Timeline' :
                 tab === 'sources' ? 'Sources' : 'Topics'}
              </button>
            ))}
          </div>

          {/* Two-column Layout */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Main Content Area (2/3 width) */}
            <div className="lg:col-span-2">
              {renderTabContent()}
            </div>

            {/* Sidebar (1/3 width) */}
            <div className="space-y-4">
              {/* Stats Cards */}
              <div className="bg-surfaceContainerHigh rounded-3xl p-6">
                <div className="flex items-center gap-4 mb-4">
                  <div className="flex-1">
                    <div className="text-sm text-onSurfaceVariant font-body mb-1">XP Level</div>
                    <div className="text-2xl font-bold text-onSurface font-data">{level}</div>
                  </div>
                  <div className="w-12 h-12 rounded-full border-4 border-primary flex items-center justify-center">
                    <span className="material-symbols-rounded text-primary">emoji_events</span>
                  </div>
                </div>
                <div className="w-full bg-surfaceContainerHighest rounded-full h-2">
                  <div className="bg-primary h-2 rounded-full" style={{ width: `${Math.min(progressPercent, 100)}%` }} />
                </div>
              </div>

              <div className="bg-surfaceContainerHigh rounded-3xl p-6 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-tertiary/20 flex items-center justify-center">
                  <span className="material-symbols-rounded text-tertiary text-2xl">local_fire_department</span>
                </div>
                <div>
                  <div className="text-sm text-onSurfaceVariant font-body mb-1">Current Streak</div>
                  <div className="text-2xl font-bold text-onSurface font-data">{stats?.currentStreak || 0}d</div>
                </div>
              </div>

              {/* Next Milestone Card */}
              <div className="bg-surfaceContainerHigh rounded-3xl p-6 shadow-md border-l-4 border-tertiary relative overflow-hidden group">
                <div className="absolute top-0 right-0 p-6 opacity-5 group-hover:opacity-10 transition-opacity duration-500">
                  <span className="material-symbols-rounded text-6xl text-tertiary">local_fire_department</span>
                </div>
                <div className="relative z-10">
                  <div className="flex items-center justify-between mb-2">
                    <h4 className="text-sm text-onSurfaceVariant font-body">Next Milestone</h4>
                    <button onClick={() => setIsMilestonesDialogOpen(true)} className="text-xs text-primary hover:underline">Manage</button>
                  </div>
                  
                  {milestones && milestones.filter((m) => !m.isCompleted).length > 0 ? (
                    <>
                      <h3 className="text-lg font-semibold text-onSurface font-heading mb-2">
                        {milestones.filter((m) => !m.isCompleted).sort((a, b) => a.sortOrder - b.sortOrder)[0].title}
                      </h3>
                      <p className="text-xs text-onSurfaceVariant font-body mb-3">
                        Keep going to unlock this!
                      </p>
                    </>
                  ) : (
                    <div className="text-sm text-onSurfaceVariant my-4">No upcoming milestones</div>
                  )}
                  
                  <button onClick={() => setIsSessionDialogOpen(true)} className="w-full bg-primary/20 text-primary py-2 rounded-lg text-sm font-medium hover:bg-primary/30 transition-colors font-body">
                    Plan Study Block
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
      <CreateSessionDialog
        isOpen={isSessionDialogOpen}
        onClose={() => setIsSessionDialogOpen(false)}
        subjects={[displaySubject as Subject]}
        onSubmit={handleCreateSession}
      />
      <CreateTopicDialog
        isOpen={isTopicDialogOpen}
        onClose={() => setIsTopicDialogOpen(false)}
        onSubmit={handleCreateTopic}
        currentTopicCount={displayTopics.length}
      />
      <CreateSourceDialog
        isOpen={isSourceDialogOpen}
        onClose={() => setIsSourceDialogOpen(false)}
        onSubmit={handleCreateSource}
        topics={displayTopics.map((t: any) => ({ id: t.id, name: t.name }))}
      />
      <ManageMilestonesDialog
        isOpen={isMilestonesDialogOpen}
        onClose={() => setIsMilestonesDialogOpen(false)}
        subjectId={subjectId!}
        milestones={milestones || []}
        onUpdate={refetchMilestones}
      />
      <EditSubjectDialog
        isOpen={isEditDialogOpen}
        onClose={() => setIsEditDialogOpen(false)}
        subject={displaySubject as Subject}
        onUpdated={refetchSubject}
      />
      <PomodoroTimerModal
        isOpen={isTimerModalOpen}
        onClose={() => setIsTimerModalOpen(false)}
        initialSubjectId={subjectId}
        onSessionLogged={() => {
          refetchSubject();
          refetchSessions();
        }}
      />
    </div>
  );
}
