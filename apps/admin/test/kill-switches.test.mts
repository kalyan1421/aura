/** Kill switches page: PRD 19 coverage from the flags that exist, and per-region pause states. */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { PRD_KILL_SWITCHES, isRegionFlag, isRegionName, prdCoverage, regionState } from '../src/lib/kill-switches.ts';

test('every PRD 19 kill switch maps to a flag; coverage follows the table', () => {
  const all = [
    'reflections_composer',
    'rooms_pool_hi',
    'ripples_enabled',
    'ripples_echoes',
    'gifts_enabled',
    'reduced_mode',
    'room_lanterns_enabled',
    'room_intention_enabled',
    'quiet_enabled',
    'lantern_wind_down_enabled',
  ];
  assert.equal(PRD_KILL_SWITCHES.length, 11);
  assert.ok(prdCoverage(all).every((c) => c.exists));
  const partial = prdCoverage(all.filter((k) => k !== 'gifts_enabled'));
  assert.deepEqual(
    partial.filter((c) => !c.exists).map((c) => c.what),
    ['Gifts'],
  );
});

test('region state: the flag off wins over the list', () => {
  const flag = { key: 'quiet_enabled', enabled: true, pausedRegions: ['south_asia'], updatedAt: null };
  assert.equal(regionState(flag, 'south_asia'), 'paused');
  assert.equal(regionState(flag, 'americas'), 'open');
  assert.equal(regionState({ ...flag, enabled: false }, 'americas'), 'off');
});

test('only the two regional flags and region-shaped names pass', () => {
  assert.ok(isRegionFlag('quiet_enabled'));
  assert.ok(isRegionFlag('lantern_wind_down_enabled'));
  assert.ok(!isRegionFlag('rooms_enabled'));
  assert.ok(isRegionName('east_asia_pacific'));
  assert.ok(!isRegionName('../config'));
  assert.ok(!isRegionName(''));
});
