import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle } from './ui/dialog';

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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;

    try {
      setIsSubmitting(true);
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
    } catch (error) {
      console.error('Failed to create source:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="sm:max-w-[425px] bg-surfaceHigh border-gray-800">
        <DialogHeader>
          <DialogTitle className="text-xl font-heading text-onSurface">Add Source</DialogTitle>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="space-y-4 mt-4">
          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-1">
              Source Title
            </label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
              placeholder="e.g., Chapter 4: Neural Networks"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-1">
              Source Type
            </label>
            <select
              value={type}
              onChange={(e) => setType(e.target.value as any)}
              className="w-full bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
            >
              <option value="url">Website / Article</option>
              <option value="videoUrl">Video</option>
              <option value="pdf">Document / Book (Pages)</option>
            </select>
          </div>

          {type !== 'pdf' && (
            <div>
              <label className="block text-sm font-medium text-gray-400 font-body mb-1">
                URL
              </label>
              <input
                type="url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                className="w-full bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
                placeholder="https://..."
              />
            </div>
          )}

          {type === 'pdf' && (
            <div>
              <label className="block text-sm font-medium text-gray-400 font-body mb-1">
                Total Pages
              </label>
              <input
                type="number"
                min="1"
                value={totalPages}
                onChange={(e) => setTotalPages(e.target.value)}
                className="w-full bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
                placeholder="e.g., 345"
              />
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-1">
              Topic (Optional)
            </label>
            <select
              value={topicId}
              onChange={(e) => setTopicId(e.target.value)}
              className="w-full bg-surface border border-gray-700 rounded-lg px-4 py-2 text-onSurface font-body focus:outline-none focus:border-primary"
            >
              <option value="">No specific topic</option>
              {topics.map(t => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </select>
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
              disabled={isSubmitting || !title.trim()}
              className="px-4 py-2 bg-primary text-white text-sm font-medium rounded-lg font-body hover:bg-primary-container disabled:opacity-50 transition-colors"
            >
              {isSubmitting ? 'Adding...' : 'Add Source'}
            </button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}
