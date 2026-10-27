import { useState } from 'react';
import Modal from './Modal';

interface CreateSourceDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: { title: string; type: 'pdf' | 'url' | 'videoUrl'; url?: string; totalPages?: number; topicId?: string }) => Promise<void>;
  topics: { id: string; name: string }[];
}

export default function CreateSourceDialog({ isOpen, onClose, onSubmit, topics }: CreateSourceDialogProps) {
  const [title, setTitle] = useState('');
  const [type, setType] = useState<'pdf' | 'url' | 'videoUrl'>('url');
  const [url, setUrl] = useState('');
  const [totalPages, setTotalPages] = useState('');
  const [topicId, setTopicId] = useState<string>('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    try {
      setIsSubmitting(true);
      setError(null);
      await onSubmit({ 
        title: title.trim(), 
        type, 
        url: url.trim() || undefined, 
        totalPages: totalPages ? parseInt(totalPages, 10) : undefined,
        topicId: topicId || undefined,
      });
      setTitle('');
      setUrl('');
      setTotalPages('');
      setTopicId('');
      onClose();
    } catch (err: any) {
      console.error('Failed to create source:', err);
      setError(err.response?.data?.error || err.message || 'Failed to create source. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Add Source" maxWidthClass="max-w-md">
      <div className="px-6 py-5 border-b border-outlineVariant flex justify-between items-center">
        <h2 className="text-xl font-bold text-onSurface font-heading">Add Source</h2>
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
            Source Title
          </label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline"
            placeholder="e.g., Chapter 4: Neural Networks"
            required
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant font-body mb-2">
            Source Type
          </label>
          <select
            value={type}
            onChange={(e) => setType(e.target.value as any)}
            className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
          >
            <option value="url">Website / Article</option>
            <option value="videoUrl">Video</option>
            <option value="pdf">Document / Book (Pages)</option>
          </select>
        </div>

        {type !== 'pdf' && (
          <div>
            <label className="block text-sm font-medium text-onSurfaceVariant font-body mb-2">
              URL
            </label>
            <input
              type="url"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline"
              placeholder="https://..."
            />
          </div>
        )}

        {type === 'pdf' && (
          <div>
            <label className="block text-sm font-medium text-onSurfaceVariant font-body mb-2">
              Total Pages
            </label>
            <input
              type="number"
              min="1"
              value={totalPages}
              onChange={(e) => setTotalPages(e.target.value)}
              className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline"
              placeholder="e.g., 345"
            />
          </div>
        )}

        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant font-body mb-2">
            Topic (Optional)
          </label>
          <select
            value={topicId}
            onChange={(e) => setTopicId(e.target.value)}
            className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
          >
            <option value="">No specific topic</option>
            {topics.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </select>
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
            disabled={isSubmitting || !title.trim()}
            className="flex-1 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm disabled:opacity-50"
          >
            {isSubmitting ? 'Adding...' : 'Add Source'}
          </button>
        </div>
      </form>
    </Modal>
  );
}
