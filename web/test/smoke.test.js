// Lightweight smoke test runnable with `node --test`.
// Verifies the production source entry points exist so accidental removals
// are caught. (There is no component-test runner configured; this replaces the
// previous test/test.ts that pointed at a non-existent fixture directory.)
import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

describe('app entry points', () => {
  it('has the expected source entry points', () => {
    const root = path.resolve(__dirname, '..', 'src');
    const entries = ['main.tsx', 'App.tsx', 'api/client.ts', 'hooks/useAuth.tsx'];
    for (const entry of entries) {
      assert.ok(existsSync(path.join(root, entry)), `expected entry not found: ${entry}`);
    }
  });
});
