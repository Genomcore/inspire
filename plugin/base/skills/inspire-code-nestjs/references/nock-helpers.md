# Nock Helpers (E2E)

Static helper class per external API. Each method returns `nock.Scope`; tests call `mockScope.done()` to verify the request was made.

## Template

```typescript
import * as nock from 'nock';
import { HttpStatus } from '@nestjs/common';

export class ExternalApiHttpMock {
  static readonly host = 'http://external-api.test';

  private static getScope({ accessToken }: { accessToken: string }): nock.Scope {
    return nock(this.host, {
      reqheaders: { Authorization: `Bearer ${accessToken}` },
    });
  }

  static findByIdWithOkResponse(args: {
    id: string;
    accessToken: string;
    response: unknown;
  }): nock.Scope {
    return this.getScope({ accessToken: args.accessToken })
      .get(`/api/v1/resources/${args.id}`)
      .reply(HttpStatus.OK, args.response);
  }

  static findByIdWithErrorResponse(args: {
    id: string;
    accessToken: string;
    statusCode: HttpStatus;
    error: unknown;
  }): nock.Scope {
    return this.getScope({ accessToken: args.accessToken })
      .get(`/api/v1/resources/${args.id}`)
      .reply(args.statusCode, args.error);
  }
}
```

## Conventions

- One helper class per external API. File: `test/mocks/<api-name>.http-mock.ts`.
- Static `host` constant — shared across methods.
- Private `getScope` — applies common headers (auth, content-type) once.
- Public methods named `<action>With<Outcome>Response`:
  - `findByIdWithOkResponse`, `findByIdWithErrorResponse`
  - `createWithCreatedResponse`, `createWithValidationErrorResponse`
  - `deleteWithNoContentResponse`, `deleteWithNotFoundResponse`
- Each method takes a single `args` object — never positional parameters.
- Return type is always `nock.Scope` so tests can call `.done()`.

## Test usage

```typescript
// GIVEN
const accessToken = 'token-123';
const id = 'res-1';
const expected = new ResourceMother().make({ id });
const mockScope = ExternalApiHttpMock.findByIdWithOkResponse({
  id,
  accessToken,
  response: expected,
});

// WHEN
const result = await externalApiClient.findById({ id, accessToken });

// THEN
expect(result).toEqual(expected);
mockScope.done(); // verifies the request was made
```

## Cleanup

Always reset nock between tests:

```typescript
afterEach(() => {
  nock.cleanAll();
});
```
