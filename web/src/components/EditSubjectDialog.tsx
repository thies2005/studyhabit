import { useState, useEffect } from 'react';
import Modal from './Modal';
import { PRESET_SEEDS } from '../hooks/useThemeSettings';
import apiClient from '../api/client';
import type { Subject } from '../types';

const presetSeeds = PRESET_SEEDS.map((s) => s.seed);

interface EditSubjectDialogProps {
  isOpen: boolean;
  onClose: () => void;
  subject: Subject;
  onUpdated: () => void;
}

export default function EditSubjectDialog({ isOpen, onClose, subject, onUpdated }: EditSubjectDialogProps) {
  const [name, setName] = useState(subject.name || '');
  const [description, setDescription] = useState(subject.description || '');
  const [selectedColor, setSelectedColor] = useState(() => {
    const hex = `#${subject.colorValue.toString(16).padStart(6, '0')}`;
    return presetSeeds.find((c) => c.toLowerCase() === hex.toLowerCase()) || presetSeeds[0];
  });
  const [hierarchyMode, setHierarchyMode] = useState<'flat' | 'twoLevel' | 'threeLevel'>(subject.hierarchyMode || 'flat');
  const [defaultDurationMinutes, setDefaultDurationMinutes] = useState(subject.defaultDurationMinutes || 25);
  const [defaultBreakMinutes, setDefaultBreakMinutes] = useState(subject.defaultBreakMinutes || 5);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen && subject) {
      setName(subject.name || '');
      setDescription(subject.description || '');
      const hex = `#${subject.colorValue.toString(16).padStart(6, '0')}`;
      setSelectedColor(presetSeeds.find((c) => c.toLowerCase() === hex.toLowerCase()) || presetSeeds[0]);
      setHierarchyMode(subject.hierarchyMode || 'flat');
      setDefaultDurationMinutes(subject.defaultDurationMinutes || 25);
      setDefaultBreakMinutes(subject.defaultBreakMinutes || 5);
      setError(null);
    }
  }, [isOpen, subject]);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) {
      setError('Subject name is required');
      return;
    }

    const colorInt = parseInt(selectedColor.replace('#', ''), 16);

    setIsSubmitting(true);
    setError(null);
    try {
      await apiClient.patch(`/subjects/${subject.id}`, {
        name: name.trim(),
        description: description.trim() || null,
        colorValue: colorInt,
        hierarchyMode,
        defaultDurationMinutes,
        defaultBreakMinutes,
      });
      onUpdated();
      onClose();
    } catch (err: any) {
      console.error('Failed to update subject:', err);
      setError(err.response?.data?.error || err.message || 'Failed to update subject');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Edit Subject">
      {/* Header */}
      <div className="px-6 py-5 border-b border-outlineVariant flex justify-between items-center">
        <h2 className="text-xl font-bold text-onSurface font-heading flex items-center gap-2">
          <span className="material-symbols-rounded text-primary" aria-hidden="true">edit</span>
          Edit Subject
        </h2>
        <button
          onClick={onClose}
          aria-label="Close dialog"
          className="w-11 h-11 rounded-full flex items-center justify-center text-onSurfaceVariant hover:bg-surface hover:text-onSurface transition-colors"
        >
          <span className="material-symbols-rounded text-xl" aria-hidden="true">close</span>
        </button>
      </div>

      {/* Form */}
      <form onSubmit={handleSubmit} className="p-6 space-y-6 max-h-[80vh] overflow-y-auto">
        {error && (
          <div role="alert" className="p-3 bg-red-500/10 border border-red-500/30 rounded-xl text-sm text-red-400 font-body">
            {error}
          </div>
        )}

        {/* Name */}
        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant mb-2 font-body">
            Subject Name <span className="text-red-500">*</span>
          </label>
          <input
            type="text"
            required
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline"
          />
        </div>

        {/* Description */}
        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant mb-2 font-body">
            Description (Optional)
          </label>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={3}
            className="w-full px-4 py-3 bg-surface border border-outlineVariant focus:border-primary rounded-xl text-onSurface font-body focus:outline-none transition-colors placeholder:text-outline resize-none"
          />
        </div>

        {/* Theme Color Selector */}
        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant mb-3 font-body">
            Theme Color
          </label>
          <div className="grid grid-cols-6 gap-3">
            {presetSeeds.map((color) => (
              <button
                key={color}
                type="button"
                onClick={() => setSelectedColor(color)}
                aria-label={`Select theme color ${color}`}
                aria-pressed={selectedColor === color}
                className={`aspect-square rounded-full transition-all hover:scale-110 flex items-center justify-center ${
                  selectedColor === color ? 'ring-2 ring-white ring-offset-2 ring-offset-surfaceHigh' : ''
                }`}
                style={{ backgroundColor: color }}
                title={color}
              >
                {selectedColor === color && (
                  <span className="material-symbols-rounded text-white text-base">check</span>
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Hierarchy Mode Selection */}
        <div>
          <label className="block text-sm font-medium text-onSurfaceVariant mb-3 font-body">
            Curriculum Organization
          </label>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              { id: 'flat', label: 'Flat', desc: 'Subject → Sessions' },
              { id: 'twoLevel', label: '2-Level', desc: 'Subject → Topics' },
              { id: 'threeLevel', label: '3-Level', desc: 'Subject → Topics → Chapters' },
            ].map((mode) => (
              <button
                key={mode.id}
                type="button"
                onClick={() => setHierarchyMode(mode.id as any)}
                aria-pressed={hierarchyMode === mode.id}
                className={`p-3 border rounded-xl flex flex-col text-left transition-all ${
                  hierarchyMode === mode.id
                    ? 'bg-primary/10 border-primary text-primary'
                    : 'bg-surface border-outlineVariant hover:border-outline text-onSurfaceVariant'
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
          <div>
            <div className="flex justify-between items-center mb-2">
              <label className="text-sm font-medium text-onSurfaceVariant font-body">
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

          <div>
            <div className="flex justify-between items-center mb-2">
              <label className="text-sm font-medium text-onSurfaceVariant font-body">
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
            disabled={isSubmitting}
            className="flex-1 py-3 bg-primary hover:bg-primary-container text-white font-bold rounded-xl transition-colors font-body text-sm flex items-center justify-center gap-2"
          >
            {isSubmitting ? (
              <>
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                <span>Saving...</span>
              </>
            ) : (
              <span>Save Changes</span>
            )}
          </button>
        </div>
      </form>
    </Modal>
  );
}
