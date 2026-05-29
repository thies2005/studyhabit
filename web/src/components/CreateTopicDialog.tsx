import { useState } from 'react';

interface CreateTopicDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: { name: string; order: number }) => Promise<void>;
  currentTopicCount: number;
}

export default function CreateTopicDialog({ isOpen, onClose, onSubmit, currentTopicCount }: CreateTopicDialogProps) {
  const [name, setName] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    try {
      setIsSubmitting(true);
      await onSubmit({ name: name.trim(), order: currentTopicCount });
      setName('');
      onClose();
    } catch (error) {
      console.error('Failed to create topic:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-surfaceContainerHighest border border-outlineVariant rounded-3xl w-full max-w-md overflow-hidden shadow-2xl animate-scaleUp">
        <div className="px-6 py-5 border-b border-outlineVariant flex justify-between items-center">
          <h2 className="text-xl font-bold text-onSurface font-heading">Create Topic</h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-gray-400 hover:bg-surface hover:text-white transition-colors"
          >
            <span className="material-symbols-rounded text-lg">close</span>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-2">
              Topic Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
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
              className="flex-1 py-3 bg-surface hover:bg-gray-800 text-gray-300 font-bold rounded-xl transition-colors font-body text-sm"
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
      </div>
    </div>
  );
}
