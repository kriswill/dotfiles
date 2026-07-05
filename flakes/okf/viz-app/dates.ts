// Human-friendly rendering of ISO dates in the detail panel, controlled by
// okf-viz.toml's display.date-format. Browser-safe and framework-free.

export const DATE_FORMATS = ["iso", "us", "international"] as const;
export type DateFormat = (typeof DATE_FORMATS)[number];

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Full-match only — a bare ISO date or an RFC3339-ish timestamp. Prose that
// merely contains a date is left alone.
const ISO_RE = /^(\d{4})-(\d{2})-(\d{2})(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:?\d{2})?)?$/;

/**
 * Format an ISO-date-shaped frontmatter value per `format`; null when the
 * value is not one (callers fall through to their default rendering) or the
 * format is "iso" (pass-through). The literal Y-M-D written in the value is
 * what gets formatted — no Date() timezone conversion, which would show
 * '2026-07-04T00:00:00-07:00' as a different calendar day to viewers east of
 * the author. Time-of-day is dropped: bundle timestamps carry placeholder
 * times, and the panel rows answer "when", not "at what second".
 */
export function formatDate(value: unknown, format: DateFormat): string | null {
  if (format === "iso" || typeof value !== "string") return null;
  const m = value.match(ISO_RE);
  if (!m) return null;
  const [, y, mo, d] = m;
  const month = MONTHS[Number(mo) - 1];
  const day = Number(d);
  if (!month || day < 1 || day > 31) return null;
  return format === "us" ? `${month} ${day}, ${y}` : `${day} ${month} ${y}`;
}
