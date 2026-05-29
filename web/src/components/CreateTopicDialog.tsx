import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';

interface CreateTopicDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: { name: string; order: number }) => Promise<void>;
  currentTopicCount: number;
}

export default function CreateTopicDialog({ isOpen, onClose, onSubmit, currentTopicCount }: CreateTopicDialogProps) {
  const [name, setName] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

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
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[425px] bg-surfaceHigh border-gray-800">
        <DialogHeader>
          <DialogTitle className="text-xl font-heading text-onSurface">Create Topic</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-1">
              Topic Name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
              placeholder="e.g., Data Structures"
              autoFocus
              required
            />
          </div>

          <div className="flex justify-end gap-3 mt-6">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-400 hover:text-gray-300 font-body transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || !name.trim()}
              className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-lg font-body hover:bg-primary-container disabled:opacity-50 transition-colors"
            >
              {isSubmitting ? 'Creating...' : 'Create Topic'}
            </button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
