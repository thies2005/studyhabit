import { type ReactNode } from 'react';
import { useDialog } from '../hooks/useDialog';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  labelledById?: string;
  children: ReactNode;
  maxWidthClass?: string;
}

/**
 * Accessible modal wrapper: renders the overlay, sets dialog semantics
 * (role/aria-modal), and wires focus trap + Escape-to-close via useDialog.
 * Replace the bespoke overlay <div> in each dialog with this.
 */
export default function Modal({
  isOpen,
  onClose,
  title,
  labelledById,
  children,
  maxWidthClass = 'max-w-lg',
}: ModalProps) {
  const ref = useDialog({ isOpen, onClose });

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div
        ref={ref}
        role="dialog"
        aria-modal="true"
        aria-labelledby={labelledById}
        aria-label={title && !labelledById ? title : undefined}
        className={`bg-surfaceContainerHighest border border-outlineVariant rounded-3xl w-full ${maxWidthClass} overflow-hidden shadow-2xl animate-scaleUp`}
      >
        {children}
      </div>
    </div>
  );
}
