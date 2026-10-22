// SPDX-License-Identifier: GPL-3.0-or-later

export type BundledVersionComparison = 'same' | 'newer' | 'older' | 'different' | 'unknown';

/** Compare SmartSafeHub numeric package versions, including the -rN revision. */
export function compareBundledVersion(
  bundled: string | null | undefined,
  installed: string | null | undefined,
): BundledVersionComparison {
  if (!bundled || !installed) {
    return 'unknown';
  }
  if (bundled === installed) {
    return 'same';
  }
  const pattern = /^(\d+)\.(\d+)\.(\d+)(?:-r(\d+))?$/;
  const target = pattern.exec(bundled);
  const current = pattern.exec(installed);
  if (!target || !current) {
    return 'different';
  }
  for (let index = 1; index <= 4; index += 1) {
    const targetPart = BigInt(target[index] || '0');
    const currentPart = BigInt(current[index] || '0');
    if (targetPart > currentPart) return 'newer';
    if (targetPart < currentPart) return 'older';
  }
  return 'same';
}
