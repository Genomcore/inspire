// The first run toward `until auth.user.list` promoted `auth.user` onto the
// goal branch, tests included. This file is those tests: every claim of
// auth.user's current contract, cited with a matching fingerprint.
//
// The second run toward the same goal reads realization from the tests in the
// GOAL WORKTREE (run.md § t=0 step 2, § The branch scheme), so it finds this
// file and drops auth.user from the frontier. The same graph with this file
// absent answers goal.floor 3 over three waves; with it present the answer is
// 1 over one. That is what makes a second run toward one goal a smaller problem
// than the first rather than a repeat of it.
describe('auth.user', () => {
  // @claim auth.user/field/id/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.user/field/id/unique sha256:c2720445a45267813688ff73fa188aa060c1b661aefaf1650d42f690697b5ab3
  // @claim auth.user/field/id/immutable sha256:3e58bada6a180c0d7f817bdae51fba96a461575b309bfbc17a6918d20c6617c7
  // @claim auth.user/field/org_id/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.user/field/org_id/immutable sha256:3e58bada6a180c0d7f817bdae51fba96a461575b309bfbc17a6918d20c6617c7
  // @claim auth.user/field/org_id/references sha256:6ddcb66483f838cd11a6aa4a3e5b7cd475b48474a43102664bc08a5d8ecbe299
  // @claim auth.user/field/email/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.user/field/email/pattern sha256:a5c79eafb8e59c8c78c5bece27fad8f93ec352bf86762c0da908f1ea8be71d44
  // @claim auth.user/field/status/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.user/field/status/default sha256:cf096fb38557a71ec5ef1a920acaacf0e7599e37aec1d43923798900582d5a54
  // @claim auth.user/field/created_at/nonnull sha256:1832c9ebcb6dd8369ff511b30ceb7c02a7a0560f5ddce41e7ca19e1a86b2e109
  // @claim auth.user/field/created_at/immutable sha256:3e58bada6a180c0d7f817bdae51fba96a461575b309bfbc17a6918d20c6617c7
  // @claim auth.user/field/created_at/default sha256:ed6baa0c5da273d87f29c5f46135fa2c98f6032e24294da3dd866067b8b9abb2
  // @claim auth.user/inv/I1 sha256:96f54602f847be60f03bc88b8d508870dee0a9330ce603076a4f0b396ceee434
  // @claim auth.user/inv/I2 sha256:f9cdb06c22b18ba50406fd38503aeb742d6f3699225beaf5c4a2fd6cf68bc1ac
  it('was delivered by the first run toward this goal', () => {})
})
