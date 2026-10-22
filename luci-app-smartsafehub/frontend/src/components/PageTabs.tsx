interface PageTab {
  id: string;
  label: string;
  href: `#${string}`;
}

interface PageTabsProps {
  active: string;
  label: string;
  tabs: readonly PageTab[];
}

/** Hash links support bookmarks, back/forward and keyboard navigation. */
export function PageTabs({ active, label, tabs }: PageTabsProps) {
  return (
    <nav aria-label={label} class="mb-5 min-w-0" role="tablist">
      <div class={`grid w-full min-w-0 gap-2 ${tabs.length === 3
        ? 'grid-cols-3 sm:max-w-[592px]'
        : 'grid-cols-2 sm:max-w-[392px]'
      }`}>
        {tabs.map((tab) => {
          const selected = tab.id === active;
          return (
            <a
              aria-controls={`${tab.id}-panel`}
              aria-selected={selected}
              class={`flex min-h-11 min-w-0 items-center justify-center rounded-xl border px-2 py-2.5 text-center text-[11px] font-extrabold leading-5 transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-teal-500 sm:px-4 sm:text-sm ${
                selected
                  ? 'border-teal-200 bg-teal-50 text-teal-800'
                  : 'border-slate-200 bg-white text-slate-600 hover:border-teal-200 hover:text-teal-700'
              }`}
              href={tab.href}
              id={`${tab.id}-tab`}
              key={tab.id}
              role="tab"
              tabIndex={selected ? 0 : -1}
              onKeyDown={(event) => {
                if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
                event.preventDefault();
                const currentIndex = tabs.findIndex((item) => item.id === tab.id);
                const nextIndex = event.key === 'Home' ? 0
                  : event.key === 'End' ? tabs.length - 1
                    : (currentIndex + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
                const target = event.currentTarget.parentElement?.children[nextIndex] as HTMLAnchorElement | undefined;
                target?.focus();
                target?.click();
              }}
            >
              {tab.label}
            </a>
          );
        })}
      </div>
    </nav>
  );
}
