import React, { useState, useRef, useEffect } from 'react';
import { useProject } from '../contexts/ProjectContext';

export default function ProjectSwitcher() {
  const { projects, currentProjectId, setCurrentProjectId, loading, createProject, updateProject } = useProject();
  const [isOpen, setIsOpen] = useState(false);
  const [isCreating, setIsCreating] = useState(false);
  const [newProjectName, setNewProjectName] = useState('');
  const [editingProjectId, setEditingProjectId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const containerRef = useRef<HTMLDivElement>(null);

  const currentProject = projects.find(p => p.id === currentProjectId);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setIsOpen(false);
        setIsCreating(false);
        setEditingProjectId(null);
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

  const handleRenameProject = async (projectId: string, e: React.FormEvent) => {
    e.preventDefault();
    if (!editName.trim()) return;

    try {
      await updateProject(projectId, { name: editName.trim() });
      setEditingProjectId(null);
    } catch (err) {
      console.error('Failed to rename project', err);
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
        <div className="absolute top-full left-0 mt-3 w-72 bg-surfaceContainerHigh border border-outlineVariant rounded-3xl shadow-xl overflow-hidden glass">
          <div className="p-2 max-h-60 overflow-y-auto space-y-1">
            {projects.map(project => (
              <div key={project.id} className="relative">
                {editingProjectId === project.id ? (
                  <form
                    onSubmit={(e) => handleRenameProject(project.id, e)}
                    onClick={(e) => e.stopPropagation()}
                    className="flex items-center gap-2 p-1.5 bg-surface rounded-xl border border-primary/40"
                  >
                    <input
                      type="text"
                      autoFocus
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      className="flex-1 bg-transparent px-2 py-1 text-sm font-body text-onSurface focus:outline-none"
                    />
                    <button
                      type="submit"
                      disabled={!editName.trim()}
                      className="text-primary disabled:opacity-50 hover:bg-primary/10 p-1 rounded-lg"
                      title="Save"
                    >
                      <span className="material-symbols-rounded text-lg">check</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setEditingProjectId(null)}
                      className="text-gray-400 hover:text-gray-200 hover:bg-surfaceContainer p-1 rounded-lg"
                      title="Cancel"
                    >
                      <span className="material-symbols-rounded text-lg">close</span>
                    </button>
                  </form>
                ) : (
                  <div className="flex items-center group rounded-lg hover:bg-surface/60 transition-colors">
                    <button
                      onClick={() => {
                        setCurrentProjectId(project.id);
                        setIsOpen(false);
                      }}
                      className={`flex-1 flex items-center gap-3 px-3 py-2 rounded-lg transition-colors text-left ${
                        project.id === currentProjectId
                          ? 'bg-primary/10 text-primary'
                          : 'text-gray-300'
                      }`}
                    >
                      <div
                        className="w-4 h-4 rounded-full flex-shrink-0"
                        style={{ backgroundColor: `#${project.colorValue.toString(16).padStart(6, '0')}` }}
                      />
                      <span className="font-body text-sm font-medium truncate flex-1">
                        {project.name}
                      </span>
                      {project.id === currentProjectId && (
                        <span className="material-symbols-rounded text-xl">check</span>
                      )}
                    </button>
                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        setEditingProjectId(project.id);
                        setEditName(project.name);
                      }}
                      className="opacity-0 group-hover:opacity-100 p-2 text-gray-400 hover:text-primary transition-all rounded-lg mr-1"
                      title={`Rename ${project.name}`}
                    >
                      <span className="material-symbols-rounded text-lg">edit</span>
                    </button>
                  </div>
                )}
              </div>
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
                  className="flex-1 bg-background border border-outlineVariant rounded-xl px-3 py-1.5 text-sm font-body focus:border-primary outline-none"
                />
                <button
                  type="submit"
                  disabled={!newProjectName.trim()}
                  className="text-primary disabled:opacity-50 hover:bg-primary/10 p-1.5 rounded-xl"
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
