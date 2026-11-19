import type { RouteObject } from 'react-router';

import { IsAliveScreen } from './screens/is-alive-screen';
import { NotFoundScreen } from './screens/not-found-screen';

export const routes: RouteObject[] = [
  { path: '/', element: <IsAliveScreen /> },
  { path: '*', element: <NotFoundScreen /> },
];
