// Regenerates reflection-filter.data.ts from contracts/safety/reflection_filter.v1.json.
//   node server/aura-api/src/reflections/filter/gen-data.js      (from the repo root or anywhere)
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..', '..', '..', '..', '..');
const json = JSON.parse(fs.readFileSync(path.join(root, 'contracts', 'safety', 'reflection_filter.v1.json'), 'utf8'));
const out =
  '/**\n * GENERATED copy of contracts/safety/reflection_filter.v1.json (the dist build has no access to contracts/).\n' +
  ' * test/unit/reflections.filter.spec.ts fails when it drifts. Regenerate: node server/aura-api/src/reflections/filter/gen-data.js\n */\n' +
  '/* eslint-disable */\n' +
  `export const REFLECTION_FILTER_DATA = ${JSON.stringify(json, null, 2)} as const;\n`;
fs.writeFileSync(path.join(__dirname, 'reflection-filter.data.ts'), out);
