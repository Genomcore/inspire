import { routeOf } from '../route-table';
import { Link, useLocation } from 'react-router';

import { actionClassName } from '../components/action';
import { ArrowLeftIcon, SignpostIcon } from '../components/icons';
import { text } from '../i18n';

export function NotFoundScreen() {
  const { pathname } = useLocation();
  return (
    <main className="mx-auto w-full max-w-2xl px-6 py-16 sm:py-24">
      <SignpostIcon className="size-10 text-slate-400" />
      <p className="mt-8 text-xs text-slate-500">{text.notFound.label}</p>
      <h1 className="mt-1 text-2xl font-semibold tracking-tight text-slate-900">{text.notFound.title}</h1>
      <p className="mt-2 max-w-prose text-sm text-slate-600">
        {text.notFound.nothingAt} <code className="rounded bg-slate-100 px-1.5 py-0.5 font-mono text-[0.8125rem] text-slate-900">{pathname}</code>. {text.notFound.hint}
      </p>
      <Link to={routeOf('home')} className={`mt-10 ${actionClassName}`}>
        <ArrowLeftIcon className="size-4" />
        {text.notFound.home}
      </Link>
    </main>
  );
}
