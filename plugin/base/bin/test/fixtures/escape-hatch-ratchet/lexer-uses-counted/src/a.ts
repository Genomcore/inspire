const x = y as any;
const t = `id: ${(v as any).id}`;
// @ts-expect-error the upstream type is wrong
call(z);
/** @ts-expect-error a block directive */
const w = { k: (q as any) } /* trailing as any mention */;
