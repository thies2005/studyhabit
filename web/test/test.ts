import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';
import { existsSync } from 'node:fs';
import path from 'node:path';

// Smoke test: the previous test pointed at a non-existent 'test/fixtures'
// directory and only verified Vite could build nothing. This checks that the
// key production entry points actually exist so accidental removals fail CI.
describe('app entry points', () => {
  it('has the expected source entry points', () => {
    const root = path.resolve(import.meta.dirname, '..', 'src');
    const entries = ['main.tsx', 'App.tsx', 'api/client.ts', 'hooks/useAuth.tsx'];
    for (const entry of entries) {
      const full = path.join(root, entry);
      assert.ok(existsSync(full), `expected entry not found: ${entry}`);
    }
  });
});
