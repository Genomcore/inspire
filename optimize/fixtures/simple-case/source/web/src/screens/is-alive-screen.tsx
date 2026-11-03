import type { ReactNode } from 'react';

import { DEFAULT_ENDPOINT, type IsAliveResult } from '../api/is-alive';
import { actionClassName } from '../components/action';
import { CheckCircleIcon, CirclePulseIcon, NoPulseIcon, RefreshIcon } from '../components/icons';
import { PulseTrace } from '../components/pulse-trace';
import { useIsAlive, type IsAliveStatus } from '../hooks/use-is-alive';
import { text } from '../i18n';

const timeFormat = new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' });

function describe(status: IsAliveStatus, result: IsAliveResult | undefined): { title: string; detail: string } {
  if (status === 'loading' || result === undefined) return text.isAlive.loading;
  const time = timeFormat.format(result.checkedAt);
  if (status === 'alive') return { title: text.isAlive.alive.title, detail: text.isAlive.alive.detail(result.latencyMs, time) };
  const detail = result.httpStatus === undefined
    ? text.isAlive.unavailable.noAnswer(time)
    : text.isAlive.unavailable.wrongAnswer(result.httpStatus, time);
  return { title: text.isAlive.unavailable.title, detail };
}

function responseText(result: IsAliveResult | undefined): string {
  if (result === undefined) return text.isAlive.pending;
  if (result.body === undefined) return text.isAlive.noResponse;
  return result.body === '' ? text.isAlive.emptyBody : result.body;
}

function StatusIcon({ status }: { status: IsAliveStatus }) {
  const className = 'size-7 shrink-0';
  if (status === 'loading') return <CirclePulseIcon className={`${className} text-blue-500`} />;
  if (status === 'alive') return <CheckCircleIcon className={`${className} text-healthy`} />;
  return <NoPulseIcon className={`${className} text-down`} />;
}

function Row({ label, mono = false, children }: { label: string; mono?: boolean; children: ReactNode }) {
  return (
    <>
      <dt className="text-slate-500">{label}</dt>
      <dd className={mono ? 'font-mono break-all text-slate-900' : 'text-slate-900'}>{children}</dd>
    </>
  );
}

export function IsAliveScreen() {
  const { status, result, check } = useIsAlive();
  const copy = describe(status, result);
  const pending = text.isAlive.pending;
  return (
    <main className="mx-auto w-full max-w-2xl px-6 py-16 sm:py-24">
      <PulseTrace status={status} />
      <div role="status" aria-live="polite" className="mt-10">
        <h1 className="flex items-center gap-3 text-2xl font-semibold tracking-tight text-slate-900">
          <StatusIcon status={status} />
          {copy.title}
        </h1>
        <p className="mt-2 max-w-prose text-sm text-slate-600">{copy.detail}</p>
      </div>
      <dl className="mt-10 grid grid-cols-[max-content_1fr] gap-x-8 gap-y-3 text-sm">
        <Row label={text.isAlive.endpoint} mono>GET {result?.endpoint ?? DEFAULT_ENDPOINT}</Row>
        <Row label={text.isAlive.response} mono>{responseText(result)}</Row>
        {result?.failure !== undefined && <Row label={text.isAlive.failure}>{result.failure}</Row>}
        <Row label={text.isAlive.latency}>{result === undefined ? pending : `${String(result.latencyMs)} ms`}</Row>
        <Row label={text.isAlive.checked}>{result === undefined ? pending : timeFormat.format(result.checkedAt)}</Row>
      </dl>
      <button type="button" onClick={check} disabled={status === 'loading'} className={`mt-10 ${actionClassName}`}>
        <RefreshIcon className="size-4" />
        {text.isAlive.checkAgain}
      </button>
    </main>
  );
}
