import type { ComponentChildren } from 'preact';

interface SectionHeadingProps {
  action?: ComponentChildren;
  description: string;
  eyebrow: string;
  id?: string;
  title: string;
}

/** Section context is outside the content card; controls stay with their functional card. */
export function SectionHeading({ action, description, eyebrow, id, title }: SectionHeadingProps) {
  return (
    <div class="ssh-section-heading mb-4 min-w-0">
      <p class="m-0 text-[0.68rem] font-black uppercase tracking-[0.18em] text-teal-700">{eyebrow}</p>
      <div class="mt-2 flex min-w-0 flex-wrap items-center justify-between gap-3">
        <h2 class="m-0 min-w-0 text-xl font-black tracking-tight text-slate-950" id={id}>{title}</h2>
        {action ? <div class="shrink-0">{action}</div> : null}
      </div>
      <p class="mt-2 mb-0 text-sm leading-6 text-slate-500">{description}</p>
    </div>
  );
}
