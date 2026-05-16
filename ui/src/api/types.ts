/**
 * Minimal type layer -- no model redefinition.
 *
 * Python SQLModel objects arrive as plain JSON dicts via model_dump().
 * We access fields dynamically via the Entity interface.
 */

export interface Entity {
  id: number;
  [key: string]: unknown;
}

export interface RPCResult<T = unknown> {
  ok: boolean;
  data: T;
  error: string | null;
}
