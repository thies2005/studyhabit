import { useState } from 'react';


const presetSeeds = [
  '#006874', // Deep Teal
  '#6750A4', // Purple
  '#0061A4', // Blue
  '#006E1C', // Green
  '#B3261E', // Red
  '#984061', // Pink
  '#AC3306', // Orange
  '#7B5800', // Brown
  '#386667', // Cyan
  '#343DFF', // Indigo
  '#1B6B46', // Forest
  '#4A4458', // Slate
];

interface CreateSubjectDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (subjectData: {
    name: string;
    description: string | null;
    colorValue: number;
    hierarchyMode: 'flat' | 'twoLevel' | 'threeLevel';
    defaultDurationMinutes: number;
    defaultBreakMinutes: number;
  }) => Promise<void>;
}

export default function CreateSubjectDialog({ isOpen, onClose, onSubmit }: CreateSubjectDialogProps) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [selectedColor, setSelectedColor] = useState(presetSeeds[0]);
  const [hierarchyMode, setHierarchyMode] = useState<'flat' | 'twoLevel' | 'threeLevel'>('flat');
  const [defaultDurationMinutes, setDefaultDurationMinutes] = useState(25);
  const [defaultBreakMinutes, setDefaultBreakMinutes] = useState(5);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError('Subject name is required');
      return;
    }

    // Convert hex color to integer
    const colorInt = parseInt(selectedColor.replace('#', ''), 16);

    setIsSubmitting(true);
    setError(null);
    try {
      await onSubmit({
        name: name.trim(),
        description: description.trim() || null,
        colorValue: colorInt,
        hierarchyMode,
        defaultDurationMinutes,
        defaultBreakMinutes,
      });
      // Reset form
      setName('');
      setDescription('');
      setSelectedColor(presetSeeds[0]);
      setHierarchyMode('flat');
      setDefaultDurationMinutes(25);
      setDefaultBreakMinutes(5);
      onClose();
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to create subject');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-surfaceHigh border border-gray-800 rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl animate-scaleUp">
        {/* Header */}
        <div className="px-6 py-5 border-b border-gray-800 flex justify-between items-center">
          <h2 className="text-xl font-bold text-onSurface font-heading flex items-center gap-2">
            <span className="material-icons text-primary">book</span>
            Create New Subject
          </h2>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-gray-400 hover:bg-surface hover:text-white transition-colors"
          >
            <span className="material-icons text-lg">close</span>
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-6 max-h-[80vh] overflow-y-auto">
          {error && (
            <div className="p-3 bg-red-500/10 border border-red-500/30 rounded-xl text-sm text-red-400 font-body">
              {error}
            </div>
          )}

          {/* Name */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
              Subject Name <span className="text-red-500">*</span>
            </label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Organic Chemistry, Algorithms & Data Structures"
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-gray-600"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-2 font-body">
              Description (Optional)
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              placeholder="Provide a brief description of what this subject covers..."
              rows={3}
              className="w-full px-4 py-3 bg-surface border border-gray-800 focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-gray-600 resize-none"
            />
          </div>

          {/* Seed Color Selector */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-3 font-body">
              Theme Color
            </label>
            <div className="grid grid-cols-6 gap-3">
              {presetSeeds.map((color) => (
                <button
                  key={color}
                  type="button"
                  onClick={() => setSelectedColor(color)}
                  className={`aspect-square rounded-full transition-all hover:scale-110 flex items-center justify-center ${
                    selectedColor === color ? 'ring-2 ring-white ring-offset-2 ring-offset-surfaceHigh' : ''
                  }`}
                  style={{ backgroundColor: color }}
                  title={color}
                >
                  {selectedColor === color && (
                    <span className="material-icons text-white text-base">check</span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Hierarchy Mode Selection */}
          <div>
            <label className="block text-sm font-medium text-gray-400 mb-3 font-body">
              Curriculum Organization
            </label>
            <div className="grid grid-cols-3 gap-3">
              {[
                { id: 'flat', label: 'Flat', desc: 'Subject → Sessions' },
                { id: 'twoLevel', label: '2-Level', desc: 'Subject → Topics' },
                { id: 'threeLevel', label: '3-Level', desc: 'Subject → Topics → Chapters' },
              ].map((mode) => (
                <button
                  key={mode.id}
                  type="button"
                  onClick={() => setHierarchyMode(mode.id as any)}
                  className={`p-3 border rounded-xl flex flex-col text-left transition-all ${
                    hierarchyMode === mode.id
                      ? 'bg-primary/10 border-primary text-primary'
                      : 'bg-surface border-gray-800 hover:border-gray-700 text-gray-400'
                  }`}
                >
                  <span className="font-bold text-sm font-heading">{mode.label}</span>
                  <span className="text-[10px] mt-1 font-body leading-tight">{mode.desc}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Study Durations */}
          <div className="grid grid-cols-2 gap-4">
            {/* Work Duration */}
            <div>
              <div className="flex justify-between items-center mb-2">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Focus Block
                </label>
                <span className="text-sm text-primary font-bold">{defaultDurationMinutes}m</span>
              </div>
              <input
                type="range"
                min="5"
                max="90"
                step="5"
                value={defaultDurationMinutes}
                onChange={(e) => setDefaultDurationMinutes(Number(e.target.value))}
                className="w-full h-1.5 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
              />
            </div>

            {/* Break Duration */}
            <div>
              <div className="flex justify-between items-center mb-2">
                <label className="text-sm font-medium text-gray-400 font-body">
                  Break Block
                </label>
                <span className="text-sm text-primary font-bold">{defaultBreakMinutes}m</span>
              </div>
              <input
                type="range"
                min="1"
                max="30"
                value={defaultBreakMinutes}
                onChange={(e) => setDefaultBreakMinutes(Number(e.target.value))}
                className="w-full h-1.5 bg-surface rounded-lg appearance-none cursor-pointer accent-primary"
              />
            </div>
          </div>

          {/* Footer Actions */}
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
              disabled={isSubmitting}
              className="flex-1 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm flex items-center justify-center gap-2"
            >
              {isSubmitting ? (
                <>
                  <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                  <span>Creating...</span>
                </>
              ) : (
                <span>Create Subject</span>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
