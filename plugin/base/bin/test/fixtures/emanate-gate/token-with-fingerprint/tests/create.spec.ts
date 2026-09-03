// One citation carrying the claim's fingerprint, one carrying a STALE
// fingerprint. Coverage is an id question, so both cover: gate reads the id half
// of the token and nothing else. Whether the fingerprint matches is what
// `/inspire-emanate plan` asks, and only for realization.
// @claim auth.user.create/pre/P1 sha256:8e746ffcf64b9207c235eec51c1166d77b6a1bb590f1e013663b7d30ef4e9963
it('reads the id half of a fingerprinted token', () => { /* declaration-only in the golden */ })
// @claim auth.user.create/pre/P1 sha256:0000000000000000000000000000000000000000000000000000000000000000
it('covers the claim on a stale fingerprint too', () => { /* declaration-only in the golden */ })
