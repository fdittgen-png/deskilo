// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2393 — tool arguments checked against the contract's own input schema
// (MCP_INPUT_SCHEMAS) before the database is asked. Each problem names its
// field with the same codes as the app's validateMcpInput
// (lib/core/mcp/mcp_spec.dart): forbidden, unknown_field, required,
// invalid_uuid, invalid_datetime, invalid_month, invalid_integer,
// too_small, too_large, invalid_boolean, invalid_text, too_long,
// invalid_value. SQL keeps its own checks as the last line.

interface FieldSchema {
  type?: string;
  format?: string;
  pattern?: string;
  minimum?: number;
  maximum?: number;
  maxLength?: number;
  enum?: string[];
}

interface InputSchema {
  properties: Record<string, FieldSchema>;
  required?: string[];
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MONTH = /^\d{4}-(0[1-9]|1[0-2])$/;
const OFFSET = /(Z|[+-]\d{2}:\d{2})$/;

function check(f: FieldSchema, v: unknown): string | null {
  switch (f.type) {
    case "string":
      if (typeof v !== "string") {
        return f.format === "uuid" ? "invalid_uuid" : f.format === "date-time" ? "invalid_datetime"
          : f.pattern === MONTH.source ? "invalid_month" : f.enum ? "invalid_value" : "invalid_text";
      }
      if (f.format === "uuid") return UUID.test(v) ? null : "invalid_uuid";
      if (f.format === "date-time") return OFFSET.test(v) && !Number.isNaN(Date.parse(v)) ? null : "invalid_datetime";
      if (f.pattern === MONTH.source) return MONTH.test(v) ? null : "invalid_month";
      if (f.enum) return f.enum.includes(v) ? null : "invalid_value";
      if (f.pattern && !new RegExp(f.pattern).test(v)) return "invalid_text";
      return v.length > (f.maxLength ?? 500) ? "too_long" : null;
    case "integer":
      if (typeof v !== "number" || !Number.isInteger(v)) return "invalid_integer";
      if (f.minimum !== undefined && v < f.minimum) return "too_small";
      if (f.maximum !== undefined && v > f.maximum) return "too_large";
      return null;
    case "boolean":
      return typeof v === "boolean" ? null : "invalid_boolean";
    default:
      return null;
  }
}

/** Field errors for [args] against [schema], by field name; empty = valid. */
export function validateInput(
  schema: unknown,
  args: Record<string, unknown>,
  forbidden: readonly string[],
): Record<string, string> {
  const s = schema as InputSchema;
  const errors: Record<string, string> = {};
  for (const key of Object.keys(args)) {
    if (forbidden.includes(key)) errors[key] = "forbidden";
    else if (!(key in s.properties)) errors[key] = "unknown_field";
  }
  for (const [name, field] of Object.entries(s.properties)) {
    if (name in errors) continue;
    const v = args[name];
    if (v === undefined || v === null) {
      if ((s.required ?? []).includes(name)) errors[name] = "required";
      continue;
    }
    const problem = check(field, v);
    if (problem) errors[name] = problem;
  }
  return errors;
}
