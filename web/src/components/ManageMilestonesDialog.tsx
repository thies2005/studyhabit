import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';
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
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[425px] bg-surfaceHigh border-gray-800">
        <DialogHeader>
          <DialogTitle className="text-xl font-heading text-onSurface">Manage Milestones</DialogTitle>
        </DialogHeader>

        <div className="space-y-4 mt-4">
          <form onSubmit={handleAdd} className="flex gap-2">
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="flex-1 bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
              placeholder="New milestone..."
            />
            <button
              type="submit"
              disabled={isSubmitting || !title.trim()}
              className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-lg font-body hover:bg-primary-container disabled:opacity-50 transition-colors"
            >
              Add
            </button>
          </form>

          <div className="max-h-60 overflow-y-auto space-y-2 mt-4 pr-2">
            {milestones.length === 0 ? (
              <p className="text-sm text-gray-400 font-body">No milestones yet.</p>
            ) : milestones.sort((a,b) => a.sortOrder - b.sortOrder).map(m => (
              <div key={m.id} className="flex items-center justify-between p-3 bg-surface rounded-lg">
                <div className="flex items-center gap-3">
                  <button 
                    onClick={() => toggleMilestone(m)}
                    className={`w-5 h-5 rounded-md flex items-center justify-center border transition-colors ${m.isCompleted ? 'bg-primary border-primary' : 'border-gray-500'}`}
                  >
                    {m.isCompleted && <span className="material-icons text-white text-[16px]">check</span>}
                  </button>
                  <span className={`text-sm font-body ${m.isCompleted ? 'text-gray-500 line-through' : 'text-onSurface'}`}>
                    {m.title}
                  </span>
                </div>
                <button onClick={() => deleteMilestone(m.id)} className="text-gray-500 hover:text-red-400 transition-colors">
                  <span className="material-icons text-sm">delete</span>
                </button>
              </div>
            ))}
          </div>
        </div>

        <div className="flex justify-end gap-3 mt-4">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 bg-surface text-onSurface text-sm font-medium rounded-lg font-body transition-colors"
          >
            Done
          </button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
