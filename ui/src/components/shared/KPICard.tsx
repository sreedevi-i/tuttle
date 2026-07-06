import type { LucideIcon } from "lucide-react";
import { Info } from "lucide-react";
type Props = {
  title: string;
  value: string;
  icon: LucideIcon;
  valueColor?: string;
  tooltip?: string;
};

export function KPICard({ title, value, icon: Icon, valueColor, tooltip }: Props) {
  return (
    <div className="flex flex-col gap-1.5 rounded-lg bg-bg-card border border-border-subtle p-3.5">
      <div className="flex items-center justify-between text-tertiary">
        <div className="flex items-center gap-1.5">
          <Icon size={14} strokeWidth={1.8} />
          <span className="text-xs font-semibold uppercase tracking-wider">{title}</span>
        </div>
        {tooltip && (
          <div className="relative group">
                  <button
                  type="button"
                  aria-label={`More information about ${title}`}
                  aria-describedby={`tooltip-${title}`}
                  className="cursor-help text-tertiary rounded focus:outline-none focus:ring-2 focus:ring-primary"
                  >
                  <Info
                    size={14}
                    strokeWidth={1.8}
                  />
                  </button>

          <div
            id={`tooltip-${title}`}
            role="tooltip"
            className="
              absolute
              bottom-full
              right-0
              mb-2
              z-50
              w-56
              rounded-md
              border
              border-border-subtle
              bg-bg-card
              p-3
              text-xs
              text-primary
              shadow-lg
              whitespace-normal
              opacity-0
              invisible
              transition-all
              duration-150
              group-hover:opacity-100
              group-hover:visible
              group-focus-within:opacity-100
              group-focus-within:visible
            "
          >
            {tooltip}
          </div>
          </div>
        )}
      </div>
      <span className="text-xl font-bold leading-tight truncate"
        style={valueColor ? { color: valueColor } : undefined}>
        {value || "—"}
      </span>
    </div>
  );
}
