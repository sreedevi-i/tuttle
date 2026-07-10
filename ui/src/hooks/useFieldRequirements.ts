import { useEffect, useState } from "react";
import { rpc } from "../api/rpc";

interface FieldMeta {
  required: boolean;
  label: string;
}

type FieldMap = Record<string, FieldMeta>;

/**
 * Fetch field requirements from the backend model schema.
 * The model class is the single source of truth; this hook
 * exposes that to the form layer.
 */
export function useFieldRequirements(domain: string) {
  const [fields, setFields] = useState<FieldMap>({});

  useEffect(() => {
    rpc<FieldMap>(`${domain}.get_field_requirements`).then((res) => {
      if (res.ok && res.data) setFields(res.data);
    });
  }, [domain]);

  const isRequired = (name: string) => fields[name]?.required ?? false;
  const label = (name: string) => fields[name]?.label ?? name.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());

  return { fields, isRequired, label };
}
