import type { z } from 'zod';
import { ApiError } from './api-error';

/** First zod issue as `path: message` — never echoes input values. */
export function describeZodError(err: z.ZodError): string {
  const issue = err.issues[0];
  if (!issue) return 'Invalid request.';
  const path = issue.path.length ? issue.path.join('.') : 'body';
  return `${path}: ${issue.message}`;
}

/** Parse or throw `400 { code }`. */
export function parseOrThrow<S extends z.ZodType>(schema: S, input: unknown, code = 'invalid_request'): z.output<S> {
  const r = schema.safeParse(input);
  if (!r.success) throw ApiError.badRequest(code, describeZodError(r.error));
  return r.data;
}
