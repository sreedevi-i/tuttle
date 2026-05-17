import { useEffect, useState, useMemo } from "react";
import {
  FileText, FileSignature, FolderKanban, Flag,
  ListFilter, Search, CalendarDays,
} from "lucide-react";
import { rpc } from "../../api/rpc";
import type { Entity } from "../../api/types";
import { str, bool } from "../../api/entity";

type Category = "all" | "invoice" | "contract" | "project" | "goal";

const CATEGORIES: { id: Category; label: string; icon: typeof FileText }[] = [
  { id: "all",      label: "All",       icon: ListFilter },
  { id: "invoice",  label: "Invoices",  icon: FileText },
  { id: "contract", label: "Contracts", icon: FileSignature },
  { id: "project",  label: "Projects",  icon: FolderKanban },
  { id: "goal",     label: "Goals",     icon: Flag },
];

const CATEGORY_COLORS: Record<string, string> = {
  invoice:  "#0A84FF",
  contract: "#30D158",
  project:  "#FFD60A",
  goal:     "#BF5AF2",
};

function dotColor(event: Entity): string {
  const title = str(event, "title").toLowerCase();
  if (title.includes("reminder") && title.includes("sent")) return "#F59E0B";
  if (title.includes("paid") || title.includes("completed") || title.includes("reached")) return "#30D158";
  if (title.includes("overdue") || title.includes("cancelled")) return "#FF453A";
  if (title.includes("reminder")) return "#F59E0B";
  if (title.includes("due")) return CATEGORY_COLORS[str(event, "category")] || "#0A84FF";
  return CATEGORY_COLORS[str(event, "category")] || "#0A84FF";
}

function formatDate(iso: string): string {
  if (!iso) return "";
  try {
    return new Date(iso).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  } catch { return iso; }
}

function monthKey(iso: string): string {
  return iso?.slice(0, 7) || "";
}

function monthLabel(iso: string): string {
  if (!iso) return "";
  try {
    return new Date(iso + "-01").toLocaleDateString("en-US", { month: "long", year: "numeric" });
  } catch { return iso; }
}

type EventGroup = { key: string; label: string; events: Entity[] };

export function TimelineView() {
  const [events, setEvents] = useState<Entity[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeFilter, setActiveFilter] = useState<Category>("all");
  const [searchQuery, setSearchQuery] = useState("");

  useEffect(() => { load(); }, []);

  async function load() {
    setLoading(true);
    const res = await rpc<Entity[]>("timeline.get_events", {});
    if (res.ok && res.data) setEvents(res.data);
    setLoading(false);
  }

  const filtered = useMemo(() => {
    let result = events;
    if (activeFilter !== "all") {
      result = result.filter((e) => str(e, "category") === activeFilter);
    }
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      result = result.filter(
        (e) => str(e, "title").toLowerCase().includes(q)
          || str(e, "description").toLowerCase().includes(q),
      );
    }
    return result;
  }, [events, activeFilter, searchQuery]);

  const groups = useMemo<EventGroup[]>(() => {
    const result: EventGroup[] = [];
    let currentKey = "";
    let current: Entity[] = [];
    for (const ev of filtered) {
      const k = monthKey(str(ev, "date"));
      if (k !== currentKey) {
        if (current.length) result.push({ key: currentKey, label: monthLabel(currentKey), events: current });
        currentKey = k;
        current = [ev];
      } else {
        current.push(ev);
      }
    }
    if (current.length) result.push({ key: currentKey, label: monthLabel(currentKey), events: current });
    return result;
  }, [filtered]);

  const todayISO = new Date().toISOString().slice(0, 10);

  const todayPosition = useMemo<{ group: number; event: number } | null>(() => {
    for (let gi = 0; gi < groups.length; gi++) {
      for (let ei = 0; ei < groups[gi].events.length; ei++) {
        const ev = groups[gi].events[ei];
        if (!bool(ev, "is_future") && str(ev, "date") <= todayISO) {
          return { group: gi, event: ei };
        }
      }
    }
    return null;
  }, [groups, todayISO]);

  if (loading) return <div className="flex items-center justify-center h-full text-secondary">Loading timeline…</div>;

  if (!events.length) {
    return (
      <div className="flex flex-col items-center justify-center h-full gap-3 text-secondary">
        <CalendarDays size={40} strokeWidth={1.2} />
        <span className="text-lg font-medium">No Events Yet</span>
        <span className="text-sm text-muted">Create invoices, contracts, or projects to see them here.</span>
      </div>
    );
  }

  return (
    <div className="p-6 max-w-3xl">
      {/* Search + Filter bar */}
      <div className="flex items-center gap-3 mb-5">
        <div className="relative flex-1 max-w-xs">
          <Search size={14} className="absolute left-2.5 top-1/2 -translate-y-1/2 text-muted" />
          <input
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search events…"
            className="w-full pl-8 pr-3 py-1.5 rounded-md border border-border-subtle bg-bg-content text-sm text-primary placeholder:text-muted focus:outline-none focus:ring-1 focus:ring-accent"
          />
        </div>
        <div className="flex gap-1.5">
          {CATEGORIES.map((cat) => {
            const active = activeFilter === cat.id;
            const color = cat.id === "all" ? "#0A84FF" : CATEGORY_COLORS[cat.id];
            return (
              <button
                key={cat.id}
                onClick={() => setActiveFilter(cat.id)}
                className="flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-semibold border transition-colors"
                style={{
                  borderColor: color,
                  backgroundColor: active ? color : "transparent",
                  color: active ? "#fff" : color,
                }}
              >
                <cat.icon size={12} />
                {cat.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Filtered-empty state */}
      {!filtered.length && (
        <div className="text-center py-12 text-muted text-sm">No events match your filter.</div>
      )}

      {/* Timeline */}
      <div className="relative">
        {groups.map((group, gi) => (
            <div key={group.key}>
              {/* Month header */}
              <div className="flex items-center h-9" style={{ paddingTop: gi > 0 ? 8 : 0 }}>
                <div className="w-9 flex justify-center">
                  <div className="w-0.5 h-full bg-border-subtle" />
                </div>
                <span className="text-xs font-semibold uppercase tracking-widest text-muted ml-2">
                  {group.label}
                </span>
              </div>

              {group.events.map((ev, ei) => {
                const isLast = gi === groups.length - 1 && ei === group.events.length - 1;
                const showToday = todayPosition?.group === gi && todayPosition?.event === ei;

                return (
                  <div key={`${str(ev, "category")}-${ei}-${str(ev, "date")}`}>
                    {showToday && <TodayMarker />}
                    <EventCard event={ev} isLast={isLast} />
                  </div>
                );
              })}

              {gi === groups.length - 1 && !todayPosition && <TodayMarker />}
            </div>
          ))}
      </div>
    </div>
  );
}

function TodayMarker() {
  return (
    <div className="flex items-center gap-2">
      <div className="w-9 flex justify-center relative">
        <div className="w-0.5 h-8 bg-border-subtle" />
        <div className="absolute top-1/2 -translate-y-1/2 w-2.5 h-2.5 rounded-full bg-red-500" />
      </div>
      <span className="text-[11px] font-bold text-white bg-red-500 px-2.5 py-0.5 rounded-full">
        Today
      </span>
      <div className="flex-1 border-t border-border-subtle" />
    </div>
  );
}

function EventCard({ event, isLast }: { event: Entity; isLast: boolean }) {
  const cat = str(event, "category");
  const color = dotColor(event);
  const catColor = CATEGORY_COLORS[cat] || "#0A84FF";
  const isFuture = bool(event, "is_future");
  const CatIcon = CATEGORIES.find((c) => c.id === cat)?.icon || FileText;
  const catLabel = CATEGORIES.find((c) => c.id === cat)?.label || cat;

  return (
    <div className="flex" style={{ opacity: isFuture ? 0.5 : 1 }}>
      {/* Spine */}
      <div className="w-9 flex flex-col items-center shrink-0">
        <div className="w-0.5 h-3.5 bg-border-subtle" />
        <div className="relative flex items-center justify-center">
          <div className="w-[18px] h-[18px] rounded-full" style={{ backgroundColor: color + "26" }} />
          <div className="absolute w-2.5 h-2.5 rounded-full" style={{ backgroundColor: color }} />
        </div>
        {!isLast && <div className="w-0.5 flex-1 min-h-[46px] bg-border-subtle" />}
      </div>

      {/* Card */}
      <div className="flex-1 ml-2 mb-1">
        <div className="rounded-lg bg-[#ffffff08] p-3">
          <div className="flex items-start justify-between gap-2">
            <div className="flex items-center gap-1.5">
              <CatIcon size={14} style={{ color }} />
              <span className="text-sm font-semibold">{str(event, "title")}</span>
            </div>
            <span className="text-[11px] text-muted whitespace-nowrap shrink-0">
              {formatDate(str(event, "date"))}
            </span>
          </div>
          {str(event, "description") && (
            <p className="text-xs text-secondary mt-1">{str(event, "description")}</p>
          )}
          <span
            className="inline-block mt-1.5 text-[10px] font-semibold px-2 py-0.5 rounded-full"
            style={{ color: catColor, backgroundColor: catColor + "1F" }}
          >
            {catLabel}
          </span>
        </div>
      </div>
    </div>
  );
}
