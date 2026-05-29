import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import apiClient from '../api/client';
import { Project } from '../types';

interface ProjectContextType {
  projects: Project[];
  currentProjectId: string | null;
  setCurrentProjectId: (id: string | null) => void;
  loading: boolean;
  refreshProjects: () => Promise<void>;
  createProject: (name: string, colorValue: number) => Promise<Project>;
}

const ProjectContext = createContext<ProjectContextType | undefined>(undefined);

export function ProjectProvider({ children }: { children: ReactNode }) {
  const [projects, setProjects] = useState<Project[]>([]);
  const [currentProjectId, setCurrentProjectId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchProjects = async () => {
    try {
      const response = await apiClient.get('/projects');
      const fetchedProjects = response.data.data;
      setProjects(fetchedProjects);
      
      // If we don't have a selected project, or it's not in the list, select the first one
      if (fetchedProjects.length > 0 && (!currentProjectId || !fetchedProjects.find((p: Project) => p.id === currentProjectId))) {
        setCurrentProjectId(fetchedProjects[0].id);
      } else if (fetchedProjects.length === 0) {
        setCurrentProjectId(null);
      }
    } catch (error) {
      console.error('Failed to fetch projects', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Basic check if user is logged in (has token) before fetching
    if (localStorage.getItem('access_token')) {
      fetchProjects();
    } else {
      setLoading(false);
    }
  }, []);

  const createProject = async (name: string, colorValue: number) => {
    const response = await apiClient.post('/projects', { name, colorValue });
    const newProject = response.data.data;
    setProjects(prev => [newProject, ...prev]);
    setCurrentProjectId(newProject.id);
    return newProject;
  };

  return (
    <ProjectContext.Provider value={{
      projects,
      currentProjectId,
      setCurrentProjectId,
      loading,
      refreshProjects: fetchProjects,
      createProject
    }}>
      {children}
    </ProjectContext.Provider>
  );
}

export function useProject() {
  const context = useContext(ProjectContext);
  if (context === undefined) {
    throw new Error('useProject must be used within a ProjectProvider');
  }
  return context;
}
