import 'reflect-metadata';

import { createApp } from './create-app';

async function scaffold(): Promise<void> {
  const app = await createApp();
  await app.listen(process.env.PORT ?? 3000);
}

void scaffold();
