import { useEffect, useState } from 'preact/hooks';

import { formatRecentTimestamp, formatTimestamp } from '../app/format';

interface RelativeTimestampProps {
  timestamp: number | null | undefined;
  fallback?: string;
}

/** Consistent relative timestamps with an accessible, tappable absolute-time disclosure. */
export function RelativeTimestamp({ timestamp, fallback = '기록 없음' }: RelativeTimestampProps) {
  const [nowTimestamp, setNowTimestamp] = useState(() => Date.now() / 1000);
  const validTimestamp = typeof timestamp === 'number' && Number.isFinite(timestamp) && timestamp > 0 && timestamp <= 8.64e12;

  useEffect(() => {
    if (!validTimestamp) {
      return;
    }

    setNowTimestamp(Date.now() / 1000);
    const timer = window.setInterval(() => setNowTimestamp(Date.now() / 1000), 60_000);
    return () => window.clearInterval(timer);
  }, [timestamp, validTimestamp]);

  if (!validTimestamp || timestamp === null || timestamp === undefined) {
    return <span>{fallback}</span>;
  }

  const exactTime = formatTimestamp(timestamp);
  return (
    <span class="inline-flex max-w-full flex-wrap items-center gap-1">
      <time
        class="min-w-0"
        dateTime={new Date(timestamp * 1000).toISOString()}
        title={exactTime}
      >
        {formatRecentTimestamp(timestamp, nowTimestamp)}
      </time>
      <details class="group inline-flex max-w-full flex-wrap items-center gap-1 align-middle">
        <summary
          aria-label="정확한 날짜 및 시간 확인"
          class="inline-flex size-6 cursor-pointer list-none items-center justify-center rounded-full text-slate-400 transition hover:text-teal-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-500 [&::-webkit-details-marker]:hidden"
          title="정확한 날짜 및 시간 확인"
        >
          <svg aria-hidden="true" class="size-3.5" fill="none" stroke="currentColor" strokeWidth="1.8" viewBox="0 0 24 24">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 11v5m0-8h.01" strokeLinecap="round" />
          </svg>
        </summary>
        <span class="hidden max-w-full break-words rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700 group-open:inline-block">
          {exactTime}
        </span>
      </details>
    </span>
  );
}
