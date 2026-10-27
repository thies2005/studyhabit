import { useState } from 'react';
import Modal from './Modal';

interface CreateTopicDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: { name: string; order: number }) => Promise<void>;
  currentTopicCount: number;
}

export default function CreateTopicDialog({ isOpen, onClose, onSubmit, currentTopicCount }: CreateTopicDialogProps) {
  const [name, setName] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    try {
      setIsSubmitting(true);
      setError(null);
      await onSubmit({ name: name.trim(), order: currentTopicCount });
      setName('');
      onClose();
    } catch (err: any) {
      console.error('Failed to create topic:', err);
      setError(err.response?.data?.error || err.message || 'Failed to create topic. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create Topic" maxWidthClass="max-w-md">
      <div className="px-6 py-5 border-b border-outlineVariant flex justify-between items-center">
        <h2 className="text-xl font-bold text-onSurface font-heading">Create Topic</h2>
        <button
          onClick={onClose}
          aria-label="Close dialog"
          className="w-11 h-11 rounded-full flex items-center justify-center text-onSurfaceVariant hover:bg-surface hover:text-onSurface transition-colors"
        >
          <span className="material-symbols-rounded text-xl" aria-hidden="true">close</span>
        </button>
      </div>

      <form onSubmit={handleSubmit} className="p-6 space-y-5">
        {error && (
          <div role="alert" className="p-3 bg-red-500/10 border border-red-500/30 rounded-xl text-sm text-red-400 font-body">
            {error}
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant font-body mb-2">
            Topic Name
          </label>
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline"
            placeholder="e.g., Data Structures"
            autoFocus
            required
          />
        </div>

        <div className="flex gap-3 pt-4 border-t border-outlineVariant">
          <button
            type="button"
            onClick={onClose}
            disabled={isSubmitting}
            className="flex-1 py-3 bg-surface hover:bg-surfaceContainerHighest text-onSurfaceVariant hover:text-onSurface font-bold rounded-xl transition-colors font-body text-sm"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={isSubmitting || !name.trim()}
            className="flex-1 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm disabled:opacity-50"
          >
            {isSubmitting ? 'Creating...' : 'Create Topic'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
