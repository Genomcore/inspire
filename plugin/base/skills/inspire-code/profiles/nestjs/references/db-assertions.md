# E2E DB assertions — full examples

Reference for the **DB state**, **expected-from-the-domain-entity**, and **read
fixture** rules in [`testing.md`](testing.md). The building blocks: read fixtures,
domain→model / domain→HTTP-response mappers, matcher helpers, and `expectXInDb`
wrappers.

The examples are written against MongoDB/Mongoose because that is the store they were
measured on; the discipline — read fixtures, mappers taking the domain interface,
full-document assertions — translates to any store, with the driver-specific notes
(`toObject()`, `ObjectId`) swapped for the equivalent.

## 1. Read fixtures (`test/fixtures/`)

Reading a collection back is a fixture, exactly like inserting. Extract the model
accessor once, and split the query from the `.map()`:

```typescript
// message-fixtures.ts
const getMessageModel = (app: INestApplication): Model<MessageModel> =>
  app.get<Model<MessageModel>>(getModelToken(MessageModel.name));

export const insertMessages = async (app: INestApplication, messages: Message[]): Promise<Message[]> => {
  const model = getMessageModel(app); // reused
  // ...
};

export const getMessagesInDb = async (app: INestApplication): Promise<MessageModel[]> => {
  const documents = await getMessageModel(app).find().exec();

  return documents.map((document) => document.toObject());
};
```

- `find().exec()` then `.map(toObject())` in **two statements** — never
  `(await model.find().exec()).map(...)` on one line.
- `toObject()` (not `lean()`) so documents are hydrated by the app's mongoose (see
  the `anyObjectId` note below).

## 2. Domain → model mapper

One mapper per entity, named `map<Entity>DomainToModel`, taking the **domain
interface** and returning the persisted shape. `_id` from the domain `id`, defaults
for non-domain columns (`deletedAt: null`):

```typescript
const mapMessageDomainToModel = (message: Message): MessageModel => ({
  _id: new Types.ObjectId(message.id),
  conversationId: message.conversationId,
  senderContactId: message.senderContactId,
  content: message.content,
  ...(message.replyToMessageId !== undefined && { replyToMessageId: message.replyToMessageId }),
  createdAt: message.createdAt,
  updatedAt: message.updatedAt,
});
```

## 3. Domain → HTTP-response mapper

Delegate to `convertToHttpResponse` — written once into the shared test support the
first time a spec needs it: it serializes `Date` → ISO string, recurses into nested
objects/arrays, turns an `anyDate()` matcher into `anyString()`, and preserves other
matchers. Keep a named wrapper that takes the domain interface:

```typescript
const mapConversationDomainToHttpResponse = (conversation: Conversation): HttpResponse<Conversation> =>
  convertToHttpResponse(conversation);
```

For a list, `convertArrayToHttpResponse(entities)`.

## 4. Matcher helpers (only for server-generated values)

```typescript
import { mongo, Types } from 'mongoose';

const anyString = (): string => expect.any(String) as unknown as string;
const anyDate = (): Date => expect.any(Date) as unknown as Date;
// lean()/toObject() ids are mongo.ObjectId, a different bson build than mongoose's Types.ObjectId,
// so expect.any(Types.ObjectId) never matches — check the driver's class.
const anyObjectId = (): Types.ObjectId => expect.any(mongo.ObjectId) as unknown as Types.ObjectId;
```

`anyDate()` is typed `Date` so it can be passed inside a domain object;
`convertToHttpResponse` rewrites it to `anyString()` for the serialized body, while
`mapXDomainToModel` keeps it as a `Date` matcher for the DB document.

## 5. `expectXInDb` wrappers

```typescript
const expectConversationsInDb = async (expected: ConversationModel[]): Promise<void> => {
  const conversationsInDb = await getConversationsInDb(app);

  Expect.arrayIsEqualIndistinctOrder(expected, conversationsInDb);
};
```

`arrayIsEqualIndistinctOrder(expected, actual)` is the written-once helper for
comparing two arrays when order is irrelevant: it runs
`expect(actual).toEqual(expect.arrayContaining(expected))` + a length check — so the
**expected** (with matchers) must be the **first** argument. Two lines, authored into
the shared test support at first need.

## 6. Putting it together

```typescript
it('should add the new tags and persist them, bumping updatedAt', async () => {
  // GIVEN
  const { conversation } = await insertConversationWithCaller({
    conversation: { status: ConversationStatus.OPEN, tags: ['onboarding'] },
  });

  // WHEN
  const response = await request(app.getHttpServer())
    .patch(`${ENDPOINT}/${conversation.id}/tags`)
    .set('Authorization', AUTH)
    .send({ addTags: ['priority'] });

  // THEN
  expect(response.status).toEqual(HttpStatus.OK);
  expect(response.body).toEqual(
    mapConversationDomainToHttpResponse({ ...conversation, tags: ['onboarding', 'priority'], updatedAt: anyDate() }),
  );

  const responseBody = response.body as { updatedAt: string };
  expect(new Date(responseBody.updatedAt).getTime()).toBeGreaterThan(conversation.updatedAt.getTime());

  await expectConversationsInDb([
    mapConversationDomainToModel({ ...conversation, tags: ['onboarding', 'priority'], updatedAt: new Date(responseBody.updatedAt) }),
  ]);
});
```

Note the same domain object (`conversation`) feeds both the HTTP-response and the DB
assertions, with per-test overrides applied inline — nothing is read out of
`response.body` to build either expected (except `responseBody.updatedAt`, used only
because the bumped timestamp is genuinely server-generated and is asserted
independently with `toBeGreaterThan`).

## 7. Create / no domain entity

When the resource is created server-side there is no inserted domain entity, so ids
and timestamps are matchers. Still go through the mapper:

```typescript
expect(response.body).toEqual(
  mapConversationDomainToHttpResponse({
    id: anyString(),
    channel: ConversationChannel.EMAIL,
    subject: body.subject,
    status: ConversationStatus.OPEN,
    tags: [],
    participants: [
      { contactId: anyString(), type: ContactType.INTERNAL, role: ParticipantRole.OWNER, joinedAt: anyDate(), userId: CALLER_USER_ID },
    ],
    lastMessageAt: anyDate(),
    lastMessagePreview: body.message.content,
    createdAt: anyDate(),
    updatedAt: anyDate(),
  }),
);
```

Assert every other collection the create touched too, with
`anyObjectId()`/`anyDate()` where the store generated the value.

## 8. Unchanged / empty collections

A request that fails (403/404/400) or is a no-op must leave state intact — assert it:

```typescript
// 404 — nothing created
await expectConversationsInDb([]);

// 403 — conversation unchanged
await expectConversationsInDb([mapConversationDomainToModel(conversation)]);
```
