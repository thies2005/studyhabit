import { useState } from 'react';
import type { SubjectMilestone } from '../types';
import apiClient from '../api/client';

interface ManageMilestonesDialogProps {
  isOpen: boolean;
  onClose: () => void;
  subjectId: string;
  milestones: SubjectMilestone[];
  onUpdate: () => void;
}

export default function ManageMilestonesDialog({ isOpen, onClose, subjectId, milestones, onUpdate }: ManageMilestonesDialogProps) {
  const [title, setTitle] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    try {
      setIsSubmitting(true);
      await apiClient.post('/milestones', {
        subjectId,
        title: title.trim(),
        sortOrder: milestones.length,
      });
      setTitle('');
      onUpdate();
    } catch (error) {
      console.error('Failed to create milestone:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const toggleMilestone = async (m: SubjectMilestone) => {
    try {
      await apiClient.patch(`/milestones/${m.id}`, {
        isCompleted: !m.isCompleted,
      });
      onUpdate();
    } catch (error) {
      console.error('Failed to update milestone:', error);
    }
  };

  const deleteMilestone = async (id: string) => {
    try {
      await apiClient.delete(`/milestones/${id}`);
      onUpdate();
    } catch (error) {
      console.error('Failed to delete milestone:', error);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-surfaceContainerHighest border border-outlineVariant rounded-3xl w-full max-w-md overflow-hidden shadow-2xl animate-scaleUp">
        <div className="px-6 py-5 border-b border-outlineVariant flex justify-between items-center">
          <h2 className="text-xl font-bold text-onSurface font-heading">Manage Milestones</h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-gray-400 hover:bg-surface hover:text-white transition-colors"
          >
            <span className="material-symbols-rounded text-lg">close</span>
          </button>
        </div>

        <div className="p-6 space-y-5">
          <form onSubmit={handleAdd} className="flex gap-2">
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="flex-1 px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
              placeholder="New milestone..."
            />
            <button
              type="submit"
              disabled={isSubmitting || !title.trim()}
              className="px-6 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm disabled:opacity-50"
            >
              Add
            </button>
          </form>

          <div className="max-h-60 overflow-y-auto space-y-2 pr-2">
            {milestones.length === 0 ? (
              <p className="text-sm text-gray-400 font-body text-center py-4">No milestones yet.</p>
            ) : milestones.sort((a,b) => a.sortOrder - b.sortOrder).map(m => (
              <div key={m.id} className="flex items-center justify-between p-3 bg-surface rounded-xl border border-outlineVariant">
                <div className="flex items-center gap-3">
                  <button 
                    onClick={() => toggleMilestone(m)}
                    className={`w-6 h-6 rounded-md flex items-center justify-center border transition-colors ${m.isCompleted ? 'bg-primary border-primary' : 'border-gray-500'}`}
                  >
                    {m.isCompleted && <span className="material-symbols-rounded text-white text-[16px]">check</span>}
                  </button>
                  <span className={`text-sm font-body ${m.isCompleted ? 'text-gray-500 line-through' : 'text-onSurface'}`}>
                    {m.title}
                  </span>
                </div>
                <button onClick={() => deleteMilestone(m.id)} className="w-8 h-8 rounded-full flex items-center justify-center text-gray-500 hover:text-red-400 hover:bg-surfaceContainerHighest transition-colors">
                  <span className="material-symbols-rounded text-sm">delete</span>
                </button>
              </div>
            ))}
          </div>
        </div>

        <div className="px-6 py-5 border-t border-outlineVariant flex justify-end">
          <button
            type="button"
            onClick={onClose}
            className="px-8 py-3 bg-surface hover:bg-gray-800 text-gray-300 font-bold rounded-xl transition-colors font-body text-sm"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
}
