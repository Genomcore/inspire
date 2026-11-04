// The guard narrows it: as any would hide the field, @ts-expect-error would outlive the fix.
/* A block mention: as any.
 * @ts-expect-error inside a block, not at its start.
 */
const a = "she said \"as any\" twice // not a comment";
const b = 'it\'s as any, and // @ts-expect-error';
const c = `multi
line as any ${"as any"} text
@ts-expect-error`;
const d = /'/g; const e = n as number;
const f = "//" + "as any";
