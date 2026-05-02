import { useParams, Link } from 'react-router-dom';
import { useState } from 'react';
import { useApi } from '../api/hooks';
import type { Subject } from '../types';

type Tab = 'timeline' | 'sources' | 'topics';

// Mock data for demo purposes
const mockSubject = {
  id: '1',
  name: 'Neuroscience & Synaptic Plasticity',
  description: 'Study of brain function, neural networks, and synaptic strength changes',
  colorValue: 85,
  totalStudyHours: 42,
  hierarchyMode: 'twoLevel' as const,
};

const mockSessions = [
  {
    id: '1',
    date: 'TODAY · 09:15 AM',
    title: 'Synaptic Transmission Mechanics',
    description: 'Completed deep dive into neurotransmitter release mechanisms and receptor binding dynamics',
    tags: ['Synapse', 'Molecular'],
    isLab: false,
    score: undefined,
    duration: '45 min',
    xp: 50,
    confidence: 4,
  },
  {
    id: '2',
    date: 'YESTERDAY · 03:30 PM',
    title: 'Lab Session: Neural Pathway Mapping',
    description: 'Hands-on session mapping neural pathways in mouse brain tissue samples',
    tags: ['Lab', 'Mapping'],
    isLab: true,
    score: 92,
    duration: '90 min',
    xp: 120,
    confidence: 5,
  },
  {
    id: '3',
    date: 'OCT 8 · 10:00 AM',
    title: 'Dendritic Spine Structure',
    description: 'Analyzing morphological changes in dendritic spines during learning',
    tags: ['Structure', 'Learning'],
    isLab: false,
    score: undefined,
    duration: '30 min',
    xp: 50,
    confidence: 3,
  },
];

const mockSources = [
  {
    id: '1',
    type: 'pdf' as const,
    title: 'Principles of Neural Science',
    subtitle: 'PDF · 1,600 Pages · Chapter 3 Read',
    pagesRead: 124,
    totalPages: 1600,
  },
  {
    id: '2',
    type: 'url' as const,
    title: 'Current Research on Neuroplasticity',
    subtitle: 'WEB · Nature Neuroscience',
  },
  {
    id: '3',
    type: 'video' as const,
    title: 'Synaptic Plasticity Explained',
    subtitle: 'VIDEO · 45:12 / 58:00',
    progress: 78,
    totalDuration: 58,
  },
];

const mockTopics = [
  {
    id: '1',
    name: 'Synaptic Transmission',
    taskCount: 8,
    subtopics: ['Neurotransmitters', 'Receptors', 'Ion Channels'],
  },
  {
    id: '2',
    name: 'Plasticity Mechanisms',
    taskCount: 12,
    subtopics: ['LTP', 'LTD', 'STDP'],
  },
  {
    id: '3',
    name: 'Neural Networks',
    taskCount: 6,
    subtopics: ['Feedforward', 'Feedback', 'Recurrent'],
  },
];

export default function SubjectDetail() {
  const { subjectId } = useParams<{ subjectId: string }>();
  const { data: subject, loading } = useApi<Subject>(`/subjects/${subjectId}`);
  const [activeTab, setActiveTab] = useState<Tab>('timeline');
  const [expandedTopics, setExpandedTopics] = useState<Set<string>>(new Set());

  if (loading) return <div className="p-8 text-center text-gray-400">Loading...</div>;

  const displaySubject = subject || mockSubject;
  const displaySessions = mockSessions;
  const displaySources = mockSources;
  const displayTopics = mockTopics;

  const toggleTopic = (topicId: string) => {
    const newExpanded = new Set(expandedTopics);
    if (newExpanded.has(topicId)) {
      newExpanded.delete(topicId);
    } else {
      newExpanded.add(topicId);
    }
    setExpandedTopics(newExpanded);
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
              <span className="text-sm text-gray-400 font-body">{displaySessions.length} sessions</span>
            </div>
            {displaySessions.map((session) => (
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
              <a href="#" className="text-sm text-primary hover:underline font-body">
                View All
              </a>
            </div>
            {displaySources.map((source) => (
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
              <span className="text-sm text-gray-400 font-body">{displayTopics.length} topics</span>
            </div>
            {displayTopics.map((topic) => (
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
                    {topic.subtopics.map((subtopic, idx) => (
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
            {(['timeline', 'sources', 'topics'] as Tab[]).map((tab) => (
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
                <h4 className="text-sm text-gray-400 font-body mb-2">Next Milestone</h4>
                <h3 className="text-lg font-semibold text-onSurface font-heading mb-2">
                  Motor Cortex Mapping
                </h3>
                <p className="text-xs text-gray-400 font-body mb-3">
                  Due Oct 28 • Complete neural pathway exercises
                </p>
                <button className="w-full bg-primary/20 text-primary py-2 rounded-lg text-sm font-medium hover:bg-primary/30 transition-colors font-body">
                  Plan Study Block
                </button>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
