it('rejects a duplicate address', () => {
  expect(body.errors[0].extensions).toEqual({ code: 'email_exists' });
});
