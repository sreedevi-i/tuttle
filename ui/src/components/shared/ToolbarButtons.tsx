import type { ReactNode } from "react";

export function ToolbarButtonPrimary({ icon, label, onClick }: {
  icon: ReactNode; label: string; onClick: () => void;
}) {
  return (
    <button onClick={onClick}
      className="flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-medium bg-accent text-white hover:bg-accent/90 transition-colors">
      {icon}
      <span>{label}</span>
    </button>
  );
}

export function ToolbarButtonSecondary({ icon, label, onClick }: {
  icon: ReactNode; label: string; onClick: () => void;
}) {
  return (
    <button onClick={onClick}
      className="flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-medium text-secondary hover:text-primary border border-border-subtle hover:bg-bg-hover transition-colors">
      {icon}
      <span>{label}</span>
    </button>
  );
}
