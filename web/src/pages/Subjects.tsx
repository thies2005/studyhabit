import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import apiClient from '../api/client';
import type { Subject } from '../types';

export default function Subjects() {
  const [subjects, setSubjects] = useState<Subject[]>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    fetchSubjects();
  }, []);

  const fetchSubjects = async () => {
    try {
      const response = await apiClient.get('/subjects');
      setSubjects(response.data.data);
    } catch (error) {
      console.error('Failed to fetch subjects', error);
    } finally {
      setLoading(false);
    }
  };

  const formatColor = (colorValue: number) => {
    return `#${colorValue.toString(16).padStart(6, '0')}`;
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
              onClick={() => {/* TODO: Implement new subject dialog */}}
              className="flex items-center space-x-2 px-4 py-2 bg-primary hover:bg-primary-container text-white rounded-lg font-medium transition-colors"
            >
              <span className="text-xl">add_circle</span>
              <span>New Subject</span>
            </button>
          </div>

          {/* Subjects Grid */}
          {loading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : subjects.length === 0 ? (
            <div className="text-center py-12">
              <p className="text-gray-400">No subjects yet. Create your first subject to get started!</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
              {subjects.map((subject, index) => (
                <div
                  key={subject.id}
                  onClick={() => navigate(`/subjects/${subject.id}`)}
                  className="bg-surfaceHigh rounded-2xl p-6 hover:brightness-110 transition-all cursor-pointer shadow-lg"
                >
                  {/* Subject Icon */}
                  <div className="flex items-center justify-between mb-4">
                    <div
                      className="w-14 h-14 rounded-full flex items-center justify-center text-3xl text-white"
                      style={{ backgroundColor: formatColor(subject.colorValue) }}
                    >
                      <span className="material-icons">{getSubjectIcon(index)}</span>
                    </div>
                    <span className="px-3 py-1 bg-primary/20 text-primary text-sm font-medium rounded-full">
                      Lvl {Math.floor(subject.xpTotal / 500) + 1}
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
                  <div className="space-y-2 pt-4 border-t border-gray-700">
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-400 font-body">Time Invested</span>
                      <span className="text-sm font-medium text-onSurface font-data">
                        {Math.floor(subject.xpTotal / 50)}h {(subject.xpTotal % 50) * 0.6}m
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

          {/* Upcoming Milestone Card */}
          <div className="bg-surfaceHigh rounded-2xl p-6 shadow-lg border-l-4 border-tertiary">
            <div className="flex items-center space-x-2 mb-4">
              <span className="text-tertiary text-2xl">emoji_events</span>
              <span className="px-2 py-1 text-xs font-medium bg-tertiary/20 text-tertiary rounded">
                UPCOMING MILESTONE
              </span>
            </div>
            <h3 className="text-xl font-bold text-onSurface font-heading mb-2">Master of Logic</h3>
            <p className="text-sm text-gray-400 font-body mb-4">
              Complete advanced exercises in Logic and Reasoning to earn this prestigious badge.
            </p>
            <div className="w-full bg-gray-700 rounded-full h-2 mb-2">
              <div className="bg-tertiary h-2 rounded-full transition-all" style={{ width: '95%' }}></div>
            </div>
            <p className="text-xs text-gray-400 font-body">
              Finish today's module to earn the 'Precisionist' badge
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
