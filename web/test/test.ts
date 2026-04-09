import { strict as assert } from 'node:assert'
import { after, before, describe, it } from 'node:test'
import { build } from 'vite'

describe('build', () => {
  it('works', async () => {
    const result = await build({ configFile: false, root: 'test/fixtures' })
    assert.equal(result.output.length, 1)
  })
})
