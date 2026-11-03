import { routeOf } from './route-table';

import type { RouteObject } from 'react-router';

import { IsAliveScreen } from './screens/is-alive-screen';
import { NotFoundScreen } from './screens/not-found-screen';

export const routes: RouteObject[] = [
  { path: routeOf('home'), element: <IsAliveScreen /> },
  { path: routeOf('notFound'), element: <NotFoundScreen /> },
];
