import { useEffect, useState } from 'preact/hooks';

export type NetworkTab = 'internet' | 'lan';
export type SettingsTab = 'diagnostics' | 'time' | 'management';

// The parent sidebar still owns #network / #settings. The hashes below select
// a panel without introducing new sidebar routes, and preserve old WAN/LAN URLs.
export function networkTabFromHash(hash: string): NetworkTab {
  return hash === '#lan' || hash === '#network/lan' ? 'lan' : 'internet';
}

export function settingsTabFromHash(hash: string): SettingsTab {
  if (hash === '#settings/time') return 'time';
  if (hash === '#settings/management') return 'management';
  return 'diagnostics';
}

function readTabs() {
  const hash = window.location.hash;
  return {
    network: networkTabFromHash(hash),
    settings: settingsTabFromHash(hash),
  };
}

export function usePageTabs() {
  const [tabs, setTabs] = useState(readTabs);

  useEffect(() => {
    const onHashChange = () => setTabs(readTabs());
    window.addEventListener('hashchange', onHashChange);
    return () => window.removeEventListener('hashchange', onHashChange);
  }, []);

  return tabs;
}
