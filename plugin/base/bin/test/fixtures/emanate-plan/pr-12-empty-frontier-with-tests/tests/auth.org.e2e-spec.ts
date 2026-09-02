// Every claim of auth.org's contract, cited with a matching fingerprint — and
// it changes nothing: auth.org is `draft`, so the frontier is empty before any
// derivation and PR-12 refuses in tier 1. A populated tests root never rescues
// an empty frontier; realization is only reachable once there is one.
describe('auth.org', () => {
  // @claim auth.org/field/id/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.org/field/id/unique sha256:c2720445a45267813688ff73fa188aa060c1b661aefaf1650d42f690697b5ab3
  // @claim auth.org/field/id/immutable sha256:3e58bada6a180c0d7f817bdae51fba96a461575b309bfbc17a6918d20c6617c7
  // @claim auth.org/field/slug/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.org/field/slug/len sha256:e6086ede46d1030e2a8c23109a8d1bb32a1e2a4b130657f5d7f9a56719e1899f
  it('is delivered', () => {})
})
