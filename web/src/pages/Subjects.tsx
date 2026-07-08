import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import apiClient from '../api/client';
import type { Subject } from '../types';
import CreateSubjectDialog from '../components/CreateSubjectDialog';

export default function Subjects() {
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [loading, setLoading] = useState(true);
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false);
  const navigate = useNavigate();

  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchSubjects();
  }, []);

  const fetchSubjects = async () => {
    try {
      setError(null);
      const response = await apiClient.get('/subjects');
      setSubjects(response.data.data);
    } catch (error: any) {
      setError(error.message || 'Failed to load subjects');
      console.error('Failed to fetch subjects:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateSubject = async (subjectData: any) => {
    try {
      // We need a projectId to create a subject. Fetch projects first.
      const projectsRes = await apiClient.get('/projects');
      const projects = projectsRes.data.data;
      
      let projectId = '';
      if (projects.length === 0) {
        // Create a default project if the user has none
        const newProjectRes = await apiClient.post('/projects', {
          name: 'My Project',
          colorValue: 0x006874, // Deep Teal
        });
        projectId = newProjectRes.data.data.id;
      } else {
        projectId = projects[0].id;
      }

      subjectData.projectId = projectId;
      
      const response = await apiClient.post('/subjects', subjectData);
      const newSubject = response.data.data;
      setSubjects((prev) => [newSubject, ...prev]);
    } catch (error) {
      console.error('Failed to create subject:', error);
      throw error;
    }
  };

  const formatColor = (colorValue: number) => {
    return `#${colorValue.toString(16).padStart(6, '0')}`;
  };

  const getLevel = (xp: number): number => {
    if (xp < 500) return 1;
    if (xp < 1500) return 2;
    if (xp < 3500) return 3;
    if (xp < 7000) return 4;
    if (xp < 10500) return 5;
    let level = 5;
    let threshold = 7000;
    while (xp >= Math.round((threshold * 1.5) / 100) * 100) {
      threshold = Math.round((threshold * 1.5) / 100) * 100;
      level++;
    }
    return level;
  };

  const getSubjectIcon = (index: number) => {
    const icons = ['science', 'architecture', 'account_balance', 'psychology', 'code', 'school'];
    return icons[index % icons.length];
  };

  return (
    <div className="min-h-screen bg-background">
      <main className="p-6">
        <div className="max-w-7xl mx-auto">
          {/* Header */}
          <div className="flex justify-between items-center mb-8">
            <div>
              <h1 className="text-3xl font-bold text-onSurface font-heading mb-2">My Subjects</h1>
              <p className="text-sm text-gray-400 font-body">
                Manage your academic curriculum and track progress across all subjects.
              </p>
            </div>
            <button
              onClick={() => setIsCreateDialogOpen(true)}
              className="flex items-center space-x-2 px-6 py-3 bg-primary hover:bg-primary-container text-background hover:text-primary-onContainer rounded-full font-heading font-bold transition-all duration-300 hover:scale-105 active:scale-95 shadow-lg shadow-primary/20"
            >
              <span className="material-symbols-rounded text-xl">add_circle</span>
              <span>New Subject</span>
            </button>
          </div>

          {error && (
            <div className="bg-red-500/20 border border-red-500/30 rounded-2xl p-6 mb-6 text-center">
              <p className="text-red-400 font-body mb-4">{error}</p>
              <button
                onClick={fetchSubjects}
                className="px-6 py-2 bg-primary hover:bg-primary-container text-background font-bold rounded-lg transition-colors"
              >
                Retry
              </button>
            </div>
          )}

          {/* Loading State */}
          {loading && !error && (
            <div className="flex justify-center items-center py-20">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
            </div>
          )}

          {/* Empty State */}
          {!loading && !error && subjects.length === 0 && (
            <div className="text-center py-12">
              <p className="text-gray-400">No subjects yet. Create your first subject to get started!</p>
            </div>
          )}
          
          {!loading && !error && subjects.length > 0 && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
              {subjects.map((subject, index) => (
                <div
                  key={subject.id}
                  onClick={() => navigate(`/subjects/${subject.id}`)}
                  className="bg-surfaceContainerHigh rounded-3xl p-6 hover:bg-surfaceContainerHighest hover:-translate-y-1 transition-all duration-300 cursor-pointer shadow-md hover:shadow-xl border border-transparent hover:border-outlineVariant"
                >
                  {/* Subject Icon */}
                  <div className="flex items-center justify-between mb-4">
                    <div
                      className="w-14 h-14 rounded-full flex items-center justify-center text-3xl text-white"
                      style={{ backgroundColor: formatColor(subject.colorValue) }}
                    >
                      <span className="material-symbols-rounded">{getSubjectIcon(index)}</span>
                    </div>
                    <span className="px-3 py-1 bg-primary/20 text-primary text-sm font-medium rounded-full">
                      Lvl {getLevel(subject.xpTotal)}
                    </span>
                  </div>

                  {/* Subject Name */}
                  <h3 className="text-xl font-bold text-onSurface font-heading mb-2">
                    {subject.name}
                  </h3>

                  {/* Description */}
                  {subject.description && (
                    <p className="text-sm text-gray-400 font-body mb-4 line-clamp-2">
                      {subject.description}
                    </p>
                  )}

                  {/* Stats */}
                  <div className="space-y-3 pt-4 border-t border-surfaceContainerHighest">
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-400 font-body">Time Invested</span>
                      <span className="text-sm font-medium text-onSurface font-data">
                        {Math.floor((subject.totalStudyMinutes || 0) / 60)}h {(subject.totalStudyMinutes || 0) % 60}m
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-400 font-body">Total Experience</span>
                      <span className="text-sm font-medium text-onSurface font-data">
                        {subject.xpTotal.toLocaleString()} XP
                      </span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </main>
      <CreateSubjectDialog
        isOpen={isCreateDialogOpen}
        onClose={() => setIsCreateDialogOpen(false)}
        onSubmit={handleCreateSubject}
      />
    </div>
  );
}
