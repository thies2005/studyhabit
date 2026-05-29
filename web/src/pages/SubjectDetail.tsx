import { useParams, Link } from 'react-router-dom';
import { useState } from 'react';
import { useApi } from '../api/hooks';
import type { Subject } from '../types';
import CreateSessionDialog from '../components/CreateSessionDialog';
import CreateTopicDialog from '../components/CreateTopicDialog';
import CreateSourceDialog from '../components/CreateSourceDialog';
import ManageMilestonesDialog from '../components/ManageMilestonesDialog';
import apiClient from '../api/client';
import type { SubjectMilestone } from '../types';

type Tab = 'timeline' | 'sources' | 'topics';

// No mock data

export default function SubjectDetail() {
  const { subjectId } = useParams<{ subjectId: string }>();
  const { data: subject, loading: subjectLoading, refetch: refetchSubject } = useApi<Subject & { topics: any[] }>(`/subjects/${subjectId}`);
  const { data: sessions, loading: sessionsLoading, refetch: refetchSessions } = useApi<any[]>(`/sessions?subjectId=${subjectId}`);
  const { data: sources, loading: sourcesLoading, refetch: refetchSources } = useApi<any[]>(`/sources?subjectId=${subjectId}`);
  const { data: milestones, loading: milestonesLoading, refetch: refetchMilestones } = useApi<SubjectMilestone[]>(`/milestones?subjectId=${subjectId}`);
  const { data: stats } = useApi<any>('/stats/overview');
  
  const [activeTab, setActiveTab] = useState<Tab>('timeline');
  const [expandedTopics, setExpandedTopics] = useState<Set<string>>(new Set());
  const [isSessionDialogOpen, setIsSessionDialogOpen] = useState(false);
  const [isTopicDialogOpen, setIsTopicDialogOpen] = useState(false);
  const [isSourceDialogOpen, setIsSourceDialogOpen] = useState(false);
  const [isMilestonesDialogOpen, setIsMilestonesDialogOpen] = useState(false);

  const loading = subjectLoading || sessionsLoading || sourcesLoading || milestonesLoading;

  if (loading) return <div className="p-8 text-center text-gray-400">Loading...</div>;
  if (!subject) return <div className="p-8 text-center text-gray-400">Subject not found</div>;

  const displaySubject = subject;

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

  const handleCreateSource = async (sourceData: any) => {
    await apiClient.post('/sources', { ...sourceData, subjectId });
    refetchSources();
  };

  const renderTabContent = () => {
    switch (activeTab) {
      case 'timeline':
        return (
          <div className="space-y-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-medium text-onSurface font-heading flex items-center gap-2">
                <span className="material-icons">filter_list</span>
                Study Sessions
              </h3>
              <button
                onClick={() => setIsSessionDialogOpen(true)}
                className="text-xs flex items-center gap-1 bg-primary hover:bg-primary-container px-3 py-1.5 rounded-lg text-white font-medium transition-colors font-body"
              >
                <span className="material-icons text-sm">add</span>
                Log Session
              </button>
            </div>
            {displaySessions.length === 0 ? (
              <div className="text-center py-8 text-gray-400 font-body">No study sessions logged yet.</div>
            ) : displaySessions.map((session) => (
              <div key={session.id} className="bg-[#323536] rounded-xl p-4">
                <div className="text-xs text-primary font-body font-medium mb-2">
                  {session.date}
                </div>
                <h4 className="text-base font-semibold text-onSurface font-heading mb-2">
                  {session.title}
                </h4>
                <p className="text-sm text-gray-400 font-body mb-3 line-clamp-2">
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
                <div className="flex items-center gap-4 text-sm text-gray-400 font-body">
                  <span className="flex items-center gap-1">
                    <span className="material-icons text-base">schedule</span>
                    {session.duration}
                  </span>
                  <span className="flex items-center gap-1">
                    <span className="material-icons text-base">star</span>
                    {session.confidence}/5
                  </span>
                  <span className="flex items-center gap-1 text-primary">
                    <span className="material-icons text-base">bolt</span>
                    +{session.xp} XP
                  </span>
                  {session.isLab && (
                    <span className="flex items-center gap-1 text-tertiary">
                      <span className="material-icons text-base">biotech</span>
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
                <span className="material-icons">folder_open</span>
                Primary Sources
              </h3>
              <div className="flex items-center gap-4">
                <button
                  onClick={() => setIsSourceDialogOpen(true)}
                  className="text-xs flex items-center gap-1 text-primary hover:text-primary/80 font-medium transition-colors font-body"
                >
                  <span className="material-icons text-sm">add</span>
                  Add Source
                </button>
              </div>
            </div>
            {displaySources.length === 0 ? (
              <div className="text-center py-8 text-gray-400 font-body">No sources added yet.</div>
            ) : displaySources.map((source) => (
              <div key={source.id} className="bg-[#323536] rounded-xl p-4 flex items-start gap-4">
                <div className={`flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center ${
                  source.type === 'pdf' ? 'bg-red-500/20' :
                  source.type === 'video' ? 'bg-purple-500/20' :
                  'bg-blue-500/20'
                }`}>
                  <span className={`material-icons text-2xl ${
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
                  <h4 className="text-base font-semibold text-onSurface font-heading mb-1">
                    {source.title}
                  </h4>
                  <p className="text-sm text-gray-400 font-body mb-2">
                    {source.subtitle}
                  </p>
                  {source.type === 'pdf' && (
                    <div className="w-full bg-gray-700 rounded-full h-1.5">
                      <div
                        className="bg-primary h-1.5 rounded-full"
                        style={{ width: `${(source.pagesRead / source.totalPages) * 100}%` }}
                      />
                    </div>
                  )}
                  {source.type === 'video' && (
                    <div className="w-full bg-gray-700 rounded-full h-1.5">
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
                <span className="material-icons">schema</span>
                Topics
              </h3>
              <div className="flex items-center gap-4">
                <span className="text-sm text-gray-400 font-body">{displayTopics.length} topics</span>
                <button
                  onClick={() => setIsTopicDialogOpen(true)}
                  className="text-xs flex items-center gap-1 text-primary hover:text-primary/80 font-medium transition-colors font-body"
                >
                  <span className="material-icons text-sm">add</span>
                  Add Topic
                </button>
              </div>
            </div>
            {displayTopics.length === 0 ? (
              <div className="text-center py-8 text-gray-400 font-body">No topics added yet.</div>
            ) : displayTopics.map((topic) => (
              <div key={topic.id} className="bg-[#323536] rounded-xl overflow-hidden">
                <div
                  className="p-4 cursor-pointer hover:bg-[#3A3E40] transition-colors"
                  onClick={() => toggleTopic(topic.id)}
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-base font-semibold text-onSurface font-heading mb-1">
                        {topic.name}
                      </h4>
                      <p className="text-sm text-gray-400 font-body">
                        {topic.taskCount} tasks
                      </p>
                    </div>
                    <span className="material-icons text-gray-400">
                      {expandedTopics.has(topic.id) ? 'expand_less' : 'expand_more'}
                    </span>
                  </div>
                </div>
                {expandedTopics.has(topic.id) && topic.subtopics && (
                  <div className="px-4 pb-4 border-t border-gray-700/50">
                    {topic.subtopics.map((subtopic: string, idx: number) => (
                      <div
                        key={idx}
                        className="py-2 px-3 text-sm text-gray-300 font-body hover:bg-gray-700/50 rounded-lg"
                      >
                        {subtopic}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        );
    }
  };

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-7xl mx-auto">
          {/* Back Link */}
          <Link
            to="/subjects"
            className="text-primary hover:underline mb-4 inline-block font-body flex items-center gap-2"
          >
            <span className="material-icons text-xl">arrow_back</span>
            Back to Subjects
          </Link>

          {/* Header Section */}
          <div className="mb-6">
            <div className="flex items-center gap-2 mb-3">
              <span className="px-3 py-1 bg-primary/20 text-primary text-xs font-medium rounded-full flex items-center gap-1 font-body">
                <span className="material-icons text-sm">event</span>
                In Progress
              </span>
              <span className="text-sm text-gray-400 font-body">
                {displaySubject.totalStudyHours || '42h'} total study
              </span>
            </div>
            <h1 className="text-3xl font-bold text-onSurface font-heading mb-2">
              {displaySubject.name}
            </h1>
            {displaySubject.description && (
              <p className="text-gray-400 font-body">{displaySubject.description}</p>
            )}
          </div>

          {/* Tab Buttons */}
          <div className="flex gap-6 mb-6 border-b border-gray-700">
            {(['timeline', 'sources', ...(displaySubject.hierarchyMode !== 'flat' ? ['topics'] : [])] as Tab[]).map((tab) => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`pb-3 text-sm font-medium font-body flex items-center gap-2 border-b-2 transition-colors ${
                  activeTab === tab
                    ? 'text-primary border-primary'
                    : 'text-gray-400 border-transparent hover:text-gray-300'
                }`}
              >
                <span className="material-icons text-lg">
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
              <div className="bg-[#323536] rounded-xl p-4">
                <div className="flex items-center gap-4 mb-4">
                  <div className="flex-1">
                    <div className="text-sm text-gray-400 font-body mb-1">Retention</div>
                    <div className="text-2xl font-bold text-onSurface font-data">82%</div>
                  </div>
                  <div className="w-12 h-12 rounded-full border-4 border-primary flex items-center justify-center">
                    <span className="material-icons text-primary">trending_up</span>
                  </div>
                </div>
                <div className="w-full bg-gray-700 rounded-full h-2">
                  <div className="bg-primary h-2 rounded-full" style={{ width: '82%' }} />
                </div>
              </div>

              <div className="bg-[#323536] rounded-xl p-4 flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-tertiary/20 flex items-center justify-center">
                  <span className="material-icons text-tertiary text-2xl">local_fire_department</span>
                </div>
                <div>
                  <div className="text-sm text-gray-400 font-body mb-1">Streak</div>
                  <div className="text-2xl font-bold text-onSurface font-data">12d</div>
                </div>
              </div>

              {/* Next Milestone Card */}
              <div className="bg-[#323536] rounded-xl p-4">
                <div className="flex items-center justify-between mb-2">
                  <h4 className="text-sm text-gray-400 font-body">Next Milestone</h4>
                  <button onClick={() => setIsMilestonesDialogOpen(true)} className="text-xs text-primary hover:underline">Manage</button>
                </div>
                
                {milestones && milestones.filter(m => !m.isCompleted).length > 0 ? (
                  <>
                    <h3 className="text-lg font-semibold text-onSurface font-heading mb-2">
                      {milestones.filter(m => !m.isCompleted).sort((a,b) => a.sortOrder - b.sortOrder)[0].title}
                    </h3>
                    <p className="text-xs text-gray-400 font-body mb-3">
                      Keep going to unlock this!
                    </p>
                  </>
                ) : (
                  <div className="text-sm text-gray-400 my-4">No upcoming milestones</div>
                )}
                
                <button onClick={() => setIsSessionDialogOpen(true)} className="w-full bg-primary/20 text-primary py-2 rounded-lg text-sm font-medium hover:bg-primary/30 transition-colors font-body">
                  Plan Study Block
                </button>
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
    </div>
  );
}
