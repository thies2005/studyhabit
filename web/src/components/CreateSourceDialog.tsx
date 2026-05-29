import { useState } from 'react';

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

  if (!isOpen) return null;

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
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-surfaceHigh border border-gray-800 rounded-3xl w-full max-w-md overflow-hidden shadow-2xl animate-scaleUp">
        <div className="px-6 py-5 border-b border-gray-800 flex justify-between items-center">
          <h2 className="text-xl font-bold text-onSurface font-heading">Add Source</h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-gray-400 hover:bg-surface hover:text-white transition-colors"
          >
            <span className="material-icons text-lg">close</span>
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-5">
          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-2">
              Source Title
            </label>
            <input
              type="text"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
              placeholder="e.g., Chapter 4: Neural Networks"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-2">
              Source Type
            </label>
            <select
              value={type}
              onChange={(e) => setType(e.target.value as any)}
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
            >
              <option value="url">Website / Article</option>
              <option value="videoUrl">Video</option>
              <option value="pdf">Document / Book (Pages)</option>
            </select>
          </div>

          {type !== 'pdf' && (
            <div>
              <label className="block text-sm font-medium text-gray-400 font-body mb-2">
                URL
              </label>
              <input
                type="url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
                placeholder="https://..."
              />
            </div>
          )}

          {type === 'pdf' && (
            <div>
              <label className="block text-sm font-medium text-gray-400 font-body mb-2">
                Total Pages
              </label>
              <input
                type="number"
                min="1"
                value={totalPages}
                onChange={(e) => setTotalPages(e.target.value)}
                className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
                placeholder="e.g., 345"
              />
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-400 font-body mb-2">
              Topic (Optional)
            </label>
            <select
              value={topicId}
              onChange={(e) => setTopicId(e.target.value)}
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors"
            >
              <option value="">No specific topic</option>
              {topics.map(t => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </select>
          </div>

          <div className="flex gap-3 pt-4 border-t border-gray-800">
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
              disabled={isSubmitting || !title.trim()}
              className="flex-1 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm disabled:opacity-50"
            >
              {isSubmitting ? 'Adding...' : 'Add Source'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
