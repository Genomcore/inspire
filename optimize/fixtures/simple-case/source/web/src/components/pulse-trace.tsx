import type { IsAliveStatus } from '../hooks/use-is-alive';

const BEAT = 'l8-8 8 8 12-30 14 60 12-30 10-10 10 10';
const HEARTBEAT = `M0 40H110${BEAT}H370${BEAT}H600`;
const FLATLINE = 'M0 40H600';

const tone: Record<IsAliveStatus, string> = {
  loading: 'text-blue-500',
  alive: 'text-healthy',
  unavailable: 'text-down',
};

const sweep: Record<IsAliveStatus, string> = {
  loading: 'trace-sweep trace-sweep--fast',
  alive: 'trace-sweep',
  unavailable: '',
};

export function PulseTrace({ status }: { status: IsAliveStatus }) {
  const path = status === 'unavailable' ? FLATLINE : HEARTBEAT;
  return (
    <svg viewBox="0 0 600 80" preserveAspectRatio="none" aria-hidden="true" className={`h-20 w-full ${tone[status]}`}>
      <path d={path} fill="none" stroke="currentColor" strokeWidth={2} vectorEffect="non-scaling-stroke" className="text-slate-200" />
      <path d={path} pathLength={1000} fill="none" stroke="currentColor" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" className={sweep[status]} />
    </svg>
  );
}
