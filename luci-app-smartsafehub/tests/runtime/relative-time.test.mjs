import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  formatRecentTimestamp,
  formatTimestamp,
  parseArtifactVersionTimestamp,
} from '../../frontend/src/app/format.ts';

const NOW = 1_800_000_000;

test('시간 표시: 분·시간·일 경계와 방금 전을 구분한다', () => {
  assert.equal(formatRecentTimestamp(NOW, NOW), '방금 전');
  assert.equal(formatRecentTimestamp(NOW - 59, NOW), '방금 전');
  assert.equal(formatRecentTimestamp(NOW - 60, NOW), '1분 전');
  assert.equal(formatRecentTimestamp(NOW - 3599, NOW), '59분 전');
  assert.equal(formatRecentTimestamp(NOW - 3600, NOW), '1시간 전');
  assert.equal(formatRecentTimestamp(NOW - 86399, NOW), '23시간 전');
  assert.equal(formatRecentTimestamp(NOW - 86400, NOW), '1일 전');
  assert.equal(formatRecentTimestamp(NOW - 6 * 86400, NOW), '6일 전');
});

test('시간 표시: 7일 이상은 날짜로 바꾸고 잘못된 값은 무시한다', () => {
  assert.equal(formatRecentTimestamp(NOW - 7 * 86400, NOW), formatTimestamp(NOW - 7 * 86400));
  assert.equal(formatRecentTimestamp(NOW - 30 * 86400, NOW), formatTimestamp(NOW - 30 * 86400));
  assert.equal(formatRecentTimestamp(NOW + 300, NOW), '방금 전');
  assert.equal(formatRecentTimestamp(NOW + 301, NOW), formatTimestamp(NOW + 301));
  assert.equal(formatRecentTimestamp(NOW, NaN), formatTimestamp(NOW));
  for (const timestamp of [0, -1, NaN, Infinity, 8.64e12 + 1]) {
    assert.equal(formatRecentTimestamp(timestamp, NOW), '기록 없음');
  }
});

test('보호 데이터 버전: 정확한 UTC 시각을 변환한다', () => {
  assert.equal(parseArtifactVersionTimestamp('20261016T020000Z'), Date.UTC(2026, 9, 16, 2) / 1000);
  assert.equal(parseArtifactVersionTimestamp('20240229T235959Z'), Date.UTC(2024, 1, 29, 23, 59, 59) / 1000);
});

test('보호 데이터 버전: 누락·형식 오류·존재하지 않는 날짜를 거부한다', () => {
  for (const value of [null, '', '20261016T020000', '20261016T020000+0900', '20230229T120000Z', '20261316T120000Z', '20261016T250000Z', '20261016T026000Z', '20261016T020060Z']) {
    assert.equal(parseArtifactVersionTimestamp(value), null);
  }
});
