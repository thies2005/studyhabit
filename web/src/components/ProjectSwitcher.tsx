import React, { useState, useRef, useEffect } from 'react';
import { useProject } from '../contexts/ProjectContext';

export default function ProjectSwitcher() {
  const { projects, currentProjectId, setCurrentProjectId, loading, createProject } = useProject();
  const [isOpen, setIsOpen] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [newProjectName, setNewProjectName] = useState('');
  const containerRef = useRef<HTMLDivElement>(null);

  const currentProject = projects.find(p => p.id === currentProjectId);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setIsCreating(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleCreateProject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newProjectName.trim()) return;
    
    try {
      await createProject(newProjectName.trim(), 0x006874); // Default to Teal
      setNewProjectName('');
      setIsCreating(false);
      setIsOpen(false);
    } catch (err) {
      console.error('Failed to create project', err);
    }
  };

  if (loading) {
    return <div className="animate-pulse bg-surface h-10 w-32 rounded-lg"></div>;
  }

  return (
    <div className="relative z-50" ref={containerRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="flex items-center gap-3 px-4 py-2.5 bg-surfaceContainer hover:bg-surfaceContainerHigh rounded-full transition-all duration-300 border border-outlineVariant shadow-sm"
      >
        <span className="material-symbols-rounded text-primary text-xl">
          {currentProject ? 'work' : 'error_outline'}
        </span>
        <span className="font-heading font-medium text-sm truncate max-w-[120px]">
          {currentProject ? currentProject.name : 'No Project'}
        </span>
        <span className="material-symbols-rounded text-onSurfaceVariant text-xl">
          expand_more
        </span>
      </button>

      {isOpen && (
        <div className="absolute top-full left-0 mt-3 w-64 bg-surfaceContainerHigh border border-outlineVariant rounded-3xl shadow-xl overflow-hidden glass">
          <div className="p-2 max-h-60 overflow-y-auto space-y-1">
            {projects.map(project => (
              <button
                key={project.id}
                onClick={() => {
                  setCurrentProjectId(project.id);
                  setIsOpen(false);
                }}
                className={`w-full flex items-center gap-3 px-3 py-2 rounded-lg transition-colors ${
                  project.id === currentProjectId
                    ? 'bg-primary/10 text-primary'
                    : 'hover:bg-surface text-gray-300'
                }`}
              >
                <div
                  className="w-4 h-4 rounded-full"
                  style={{ backgroundColor: `#${project.colorValue.toString(16).padStart(6, '0')}` }}
                />
                <span className="font-body text-sm font-medium truncate flex-1 text-left">
                  {project.name}
                </span>
                {project.id === currentProjectId && (
                  <span className="material-symbols-rounded text-xl">check</span>
                )}
              </button>
            ))}
          </div>
          
          <div className="p-3 border-t border-outlineVariant bg-surfaceContainerLowest">
            {isCreating ? (
              <form onSubmit={handleCreateProject} className="flex gap-2">
                <input
                  type="text"
                  autoFocus
                  value={newProjectName}
                  onChange={e => setNewProjectName(e.target.value)}
                  placeholder="Project name..."
                  className="flex-1 bg-background border border-outlineVariant rounded px-2 py-1 text-sm font-body focus:border-primary outline-none"
                />
                <button
                  type="submit"
                  disabled={!newProjectName.trim()}
                  className="text-primary disabled:opacity-50 hover:bg-primary/10 p-1 rounded"
                >
                  <span className="material-symbols-rounded text-xl">check</span>
                </button>
              </form>
            ) : (
              <button
                onClick={() => setIsCreating(true)}
                className="w-full flex items-center gap-3 px-3 py-2.5 text-sm text-onSurfaceVariant hover:text-onSurface hover:bg-surfaceContainer rounded-xl transition-colors"
              >
                <span className="material-symbols-rounded text-xl">add</span>
                <span className="font-heading font-medium">New Project</span>
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
