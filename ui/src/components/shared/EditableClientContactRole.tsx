import { useEffect, useState } from "react";
import { Tag, Pencil } from "lucide-react";
import { rpc } from "../../api/rpc";

type UpdateRoleMethod =
  | "contacts.update_client_contact_role"
  | "clients.update_client_contact_role";

export function EditableClientContactRole({ associationId, role, onUpdated, updateMethod }: {
  associationId: number;
  role: string;
  onUpdated: () => void;
  updateMethod: UpdateRoleMethod;
}) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(role);
  const [saving, setSaving] = useState(false);

  useEffect(() => { setValue(role); }, [role]);

  async function save() {
    const newRole = value.trim() || null;
    const currentRole = role.trim() || null;
    if (newRole === currentRole) {
      setEditing(false);
      return;
    }
    setSaving(true);
    const res = await rpc(updateMethod, {
      association_id: associationId,
      role: newRole,
    });
    setSaving(false);
    if (res.ok) {
      setEditing(false);
      await onUpdated();
    }
  }

  function cancel() {
    setValue(role);
    setEditing(false);
  }

  if (editing) {
    return (
      <div className="flex items-center gap-2 mt-0.5">
        <input type="text" value={value} autoFocus disabled={saving}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => { if (e.key === "Escape") cancel(); }}
          placeholder="Role (optional), e.g. project lead, accountant"
          className="flex-1 min-w-0 px-2 py-1 rounded text-xs bg-bg-sidebar text-primary border border-accent outline-none transition-colors placeholder:text-muted disabled:opacity-50" />
        <button type="button" onClick={cancel} disabled={saving}
          className="px-2 py-1 rounded text-xs text-secondary hover:text-primary transition-colors disabled:opacity-50">
          Cancel
        </button>
        <button type="button" onClick={save} disabled={saving}
          className="px-2 py-1 rounded text-xs font-medium text-primary bg-accent/20 hover:bg-accent/30 border border-accent/30 transition-colors disabled:opacity-40">
          {saving ? "Saving…" : "Save"}
        </button>
      </div>
    );
  }

  return (
    <button type="button" onClick={() => setEditing(true)}
      className="flex items-center gap-1 text-xs text-tertiary hover:text-primary transition-colors group/role"
      title="Edit role">
      <Tag size={10} />
      {role || <span className="italic text-muted">Add role…</span>}
      <Pencil size={10} className="opacity-0 group-hover/role:opacity-100 transition-opacity" />
    </button>
  );
}
