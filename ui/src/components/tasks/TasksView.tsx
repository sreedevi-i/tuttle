import { useEffect, useState } from "react";
import { CheckSquare, Circle, CheckCircle2, X } from "lucide-react";
import { rpc } from "../../api/rpc";
import { EmptyStateIntro } from "../shared/EmptyStateIntro";
import type { Entity } from "../../api/types";

export function TasksView() {
  const [tasks, setTasks] = useState<Entity[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { load(); }, []);

  async function load() {
    setLoading(true);
    const res = await rpc<Entity[]>("tasks.get_all");
    if (res.ok && Array.isArray(res.data)) setTasks(res.data);
    setLoading(false);
  }

  async function markDone(id: number) {
    setTasks((prev) => prev.filter((t) => t.id !== id));
    await rpc("tasks.mark_done", { id });
  }

  async function dismiss(id: number) {
    setTasks((prev) => prev.filter((t) => t.id !== id));
    await rpc("tasks.dismiss", { id });
  }

  if (loading) {
    return <div className="flex items-center justify-center h-full text-secondary">Loading tasks…</div>;
  }

  if (tasks.length === 0) {
    return <EmptyStateIntro icon={CheckSquare} description="You're all caught up — no pending tasks." />;
  }

  return (
    <div className="p-6 max-w-2xl">
      <h1 className="text-lg font-semibold mb-4">Tasks</h1>
      <div className="space-y-1">
        {tasks.map((task) => (
          <TaskRow
            key={task.id as number}
            task={task}
            onDone={() => markDone(task.id as number)}
            onDismiss={() => dismiss(task.id as number)}
          />
        ))}
      </div>
    </div>
  );
}

function TaskRow({ task, onDone, onDismiss }: {
  task: Entity;
  onDone: () => void;
  onDismiss: () => void;
}) {
  const [hovered, setHovered] = useState(false);
  const key = (task.key as string) ?? "";
  const isTutorial = key.startsWith("tutorial:");

  return (
    <div
      className="flex items-start gap-3 px-3 py-2.5 rounded-lg transition-colors hover:bg-bg-hover group"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      <button
        onClick={onDone}
        className="mt-0.5 shrink-0 text-secondary hover:text-green-500 transition-colors"
        title="Mark done"
      >
        {hovered ? <CheckCircle2 size={18} /> : <Circle size={18} />}
      </button>

      <div className="flex-1 min-w-0">
        <div className="text-sm font-medium">{String(task.title ?? "")}</div>
        {task.description ? (
          <div className="text-xs text-tertiary mt-0.5">{String(task.description)}</div>
        ) : null}
        {isTutorial && (
          <span className="inline-block mt-1 text-[10px] uppercase tracking-wide text-tertiary bg-bg-hover px-1.5 py-0.5 rounded">
            Getting started
          </span>
        )}
      </div>

      <button
        onClick={onDismiss}
        className="shrink-0 opacity-0 group-hover:opacity-100 text-muted hover:text-secondary transition-all"
        title="Dismiss"
      >
        <X size={14} />
      </button>
    </div>
  );
}
