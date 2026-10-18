// Compile-only check (`npm run typecheck:tests`): the public surface is typed
// from the generated OpenAPI types, and misuse fails to compile.

import { Halo, HaloConversionFailedError, verifyWebhook, type Conversion, type ConversionCreate, type ErrorCode, type HaloSchema } from '../src/index.js';

async function example(): Promise<void> {
  const halo = new Halo({ apiKey: 'halo_sk_example', baseUrl: 'http://127.0.0.1:8787' });
  const file = await halo.files.upload('photo.heic');
  const params: ConversionCreate = { input: { fileId: file.id }, target: 'webp', options: { quality: 80, lossless: false } };
  const c: Conversion = await halo.conversions.create(params, { idempotencyKey: 'order-1' });
  try {
    const done = await halo.conversions.wait(c, { timeoutMs: 60_000 });
    if (done.output) await halo.files.download(done.output.id, 'photo.webp');
    const minutes: number = done.usage.mediaMinutes;
    void minutes;
  } catch (e) {
    if (e instanceof HaloConversionFailedError) {
      const code: string | undefined = e.conversion.error?.code;
      void code;
    }
  }
  const schema: HaloSchema = await halo.schema.get();
  const kinds = schema.optionSchemas.flatMap((s) => s.options.map((o) => o.kind));
  void kinds;
  const code: ErrorCode = 'idempotency_conflict';
  void code;
  const ev = verifyWebhook('{}', 't=1,v1=00', 'whsec_x');
  if (ev.type === 'conversion.succeeded') void ev.data.conversion.output;

  // @ts-expect-error status is a closed enum
  const bad: Conversion['status'] = 'done';
  void bad;
  // @ts-expect-error input needs fileId or url
  await halo.conversions.create({ input: {}, target: 'png' });
}
void example;
