# Routing

Router configuration with lazy loading, functional guards, resolvers,
signal-based route parameters, nested routes, auxiliary outlets, preloading
strategies, and route animations.

## Basic setup

```typescript
// app.routes.ts
import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', redirectTo: '/home', pathMatch: 'full' },
  { path: 'home', component: Home },
  { path: 'about', component: About },
  { path: '**', component: NotFound },
];

// app.config.ts
import { ApplicationConfig } from '@angular/core';
import { provideRouter } from '@angular/router';
import { routes } from './app.routes';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
  ],
};

// app.component.ts
import { Component } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
    <nav>
      <a routerLink="/home" routerLinkActive="active">Home</a>
      <a routerLink="/about" routerLinkActive="active">About</a>
    </nav>
    <router-outlet />
  `,
})
export class App {}
```

## Lazy loading

Load feature modules on demand:

```typescript
// app.routes.ts
export const routes: Routes = [
  { path: '', redirectTo: '/home', pathMatch: 'full' },
  { path: 'home', component: Home },

  // Lazy load entire feature
  {
    path: 'admin',
    loadChildren: () => import('./admin/admin.routes').then(m => m.adminRoutes),
  },

  // Lazy load single component
  {
    path: 'settings',
    loadComponent: () => import('./settings/settings.component').then(m => m.Settings),
  },
];

// admin/admin.routes.ts
export const adminRoutes: Routes = [
  { path: '', component: AdminDashboard },
  { path: 'users', component: AdminUsers },
  { path: 'settings', component: AdminSettings },
];
```

## Route parameters

### With signal inputs (recommended)

```typescript
// Route config
{ path: 'users/:id', component: UserDetail }

// Component - use input() for route params
import { Component, input, computed } from '@angular/core';

@Component({
  selector: 'app-user-detail',
  template: `
    <h1>User {{ id() }}</h1>
  `,
})
export class UserDetail {
  // Route param as signal input
  id = input.required<string>();

  // Computed based on route param
  userId = computed(() => parseInt(this.id(), 10));
}
```

Enable with `withComponentInputBinding()`:

```typescript
// app.config.ts
import { provideRouter, withComponentInputBinding } from '@angular/router';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withComponentInputBinding()),
  ],
};
```

### Query parameters

```typescript
// Route: /search?q=angular&page=1

@Component({...})
export class Search {
  // Query params as inputs
  q = input<string>('');
  page = input<string>('1');

  currentPage = computed(() => parseInt(this.page(), 10));
}
```

### With ActivatedRoute (alternative)

```typescript
import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs';

@Component({...})
export class UserDetail {
  private route = inject(ActivatedRoute);

  // Convert route params to signal
  id = toSignal(
    this.route.paramMap.pipe(map(params => params.get('id'))),
    { initialValue: null }
  );

  // Query params
  query = toSignal(
    this.route.queryParamMap.pipe(map(params => params.get('q'))),
    { initialValue: '' }
  );
}
```

## Functional guards

### Auth guard

```typescript
// guards/auth.guard.ts
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';

export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(Auth);
  const router = inject(Router);

  if (authService.isAuthenticated()) {
    return true;
  }

  // Redirect to login with return URL
  return router.createUrlTree(['/login'], {
    queryParams: { returnUrl: state.url },
  });
};

// Usage in routes
{
  path: 'dashboard',
  component: Dashboard,
  canActivate: [authGuard],
}
```

### Role guard

```typescript
export const roleGuard = (allowedRoles: string[]): CanActivateFn => {
  return (route, state) => {
    const authService = inject(Auth);
    const router = inject(Router);

    const userRole = authService.currentUser()?.role;

    if (userRole && allowedRoles.includes(userRole)) {
      return true;
    }

    return router.createUrlTree(['/unauthorized']);
  };
};

// Usage
{
  path: 'admin',
  component: Admin,
  canActivate: [authGuard, roleGuard(['admin', 'superadmin'])],
}
```

### Can deactivate guard

```typescript
export interface CanDeactivate {
  canDeactivate: () => boolean | Promise<boolean>;
}

export const unsavedChangesGuard: CanDeactivateFn<CanDeactivate> = (component) => {
  if (component.canDeactivate()) {
    return true;
  }

  return confirm('You have unsaved changes. Leave anyway?');
};

// Component implementation
@Component({...})
export class Edit implements CanDeactivate {
  form = inject(FormBuilder).group({...});

  canDeactivate(): boolean {
    return !this.form.dirty;
  }
}

// Route
{
  path: 'edit/:id',
  component: Edit,
  canDeactivate: [unsavedChangesGuard],
}
```

## Resolvers

Pre-fetch data before route activation:

```typescript
// resolvers/user.resolver.ts
import { inject } from '@angular/core';
import { ResolveFn } from '@angular/router';

export const userResolver: ResolveFn<User> = (route) => {
  const userService = inject(User);
  const id = route.paramMap.get('id')!;
  return userService.getById(id);
};

// Route config
{
  path: 'users/:id',
  component: UserDetail,
  resolve: { user: userResolver },
}

// Component - access resolved data via input
@Component({...})
export class UserDetail {
  user = input.required<User>();
}
```

## Nested routes

```typescript
// Parent route with children
export const routes: Routes = [
  {
    path: 'products',
    component: ProductsLayout,
    children: [
      { path: '', component: ProductList },
      { path: ':id', component: ProductDetail },
      { path: ':id/edit', component: ProductEdit },
    ],
  },
];

// ProductsLayout
@Component({
  imports: [RouterOutlet],
  template: `
    <h1>Products</h1>
    <router-outlet /> <!-- Child routes render here -->
  `,
})
export class ProductsLayout {}
```

## Programmatic navigation

```typescript
import { Component, inject } from '@angular/core';
import { Router } from '@angular/router';

@Component({...})
export class Product {
  private router = inject(Router);

  // Navigate to route
  goToProducts() {
    this.router.navigate(['/products']);
  }

  // Navigate with params
  goToProduct(id: string) {
    this.router.navigate(['/products', id]);
  }

  // Navigate with query params
  search(query: string) {
    this.router.navigate(['/search'], {
      queryParams: { q: query, page: 1 },
    });
  }

  // Navigate relative to current route
  goToEdit() {
    this.router.navigate(['edit'], { relativeTo: this.route });
  }

  // Replace current history entry
  replaceUrl() {
    this.router.navigate(['/new-page'], { replaceUrl: true });
  }
}
```

## Route data

```typescript
// Static route data
{
  path: 'admin',
  component: Admin,
  data: {
    title: 'Admin Dashboard',
    roles: ['admin'],
  },
}

// Access in component
@Component({...})
export class AdminCmpt {
  title = input<string>(); // From route data
  roles = input<string[]>(); // From route data
}

// Or via ActivatedRoute
private route = inject(ActivatedRoute);
data = toSignal(this.route.data);
```

## Router events

```typescript
import { Router, NavigationStart, NavigationEnd } from '@angular/router';
import { filter } from 'rxjs';

@Component({...})
export class AppMain {
  private router = inject(Router);

  isNavigating = signal(false);

  constructor() {
    this.router.events.pipe(
      filter(e => e instanceof NavigationStart || e instanceof NavigationEnd)
    ).subscribe(event => {
      this.isNavigating.set(event instanceof NavigationStart);
    });
  }
}
```

## Route configuration options

### Full route options

```typescript
{
  path: 'users/:id',
  component: UserCmpt,

  // Lazy loading alternatives
  loadComponent: () => import('./user.component').then(m => m.UserCmpt),
  loadChildren: () => import('./user.routes').then(m => m.userRoutes),

  // Guards
  canActivate: [authGuard],
  canActivateChild: [authGuard],
  canDeactivate: [unsavedChangesGuard],
  canMatch: [featureFlagGuard],

  // Data
  resolve: { user: userResolver },
  data: { title: 'User Profile', animation: 'userPage' },

  // Children
  children: [...],

  // Outlet
  outlet: 'sidebar',

  // Path matching
  pathMatch: 'full', // or 'prefix'

  // Title
  title: 'User Profile',
  // Or dynamic title
  title: userTitleResolver,
}
```

### Dynamic title resolver

```typescript
export const userTitleResolver: ResolveFn<string> = (route) => {
  const userService = inject(User);
  const id = route.paramMap.get('id')!;
  return userService.getById(id).pipe(
    map(user => `${user.name} - Profile`)
  );
};
```

## Authentication flow

### Complete auth setup

```typescript
// auth.service.ts
@Injectable({ providedIn: 'root' })
export class Auth {
  private _user = signal<User | null>(null);
  private _token = signal<string | null>(null);

  readonly user = this._user.asReadonly();
  readonly isAuthenticated = computed(() => this._user() !== null);

  private router = inject(Router);
  private http = inject(HttpClient);

  async login(credentials: Credentials): Promise<boolean> {
    try {
      const response = await firstValueFrom(
        this.http.post<AuthResponse>('/api/login', credentials)
      );

      this._token.set(response.token);
      this._user.set(response.user);
      localStorage.setItem('token', response.token);

      return true;
    } catch {
      return false;
    }
  }

  logout(): void {
    this._user.set(null);
    this._token.set(null);
    localStorage.removeItem('token');
    this.router.navigate(['/login']);
  }

  async checkAuth(): Promise<boolean> {
    const token = localStorage.getItem('token');
    if (!token) return false;

    try {
      const user = await firstValueFrom(
        this.http.get<User>('/api/me')
      );
      this._user.set(user);
      this._token.set(token);
      return true;
    } catch {
      localStorage.removeItem('token');
      return false;
    }
  }
}

// auth.guard.ts
export const authGuard: CanActivateFn = async (route, state) => {
  const authService = inject(Auth);
  const router = inject(Router);

  // Check if already authenticated
  if (authService.isAuthenticated()) {
    return true;
  }

  // Try to restore session
  const isValid = await authService.checkAuth();
  if (isValid) {
    return true;
  }

  // Redirect to login
  return router.createUrlTree(['/login'], {
    queryParams: { returnUrl: state.url },
  });
};

// login.component.ts
@Component({
  template: `
    <form (ngSubmit)="login()">
      <input [(ngModel)]="email" name="email" />
      <input [(ngModel)]="password" name="password" type="password" />
      <button type="submit">Login</button>
    </form>
  `,
})
export class Login {
  private authService = inject(Auth);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  email = '';
  password = '';

  async login() {
    const success = await this.authService.login({
      email: this.email,
      password: this.password,
    });

    if (success) {
      const returnUrl = this.route.snapshot.queryParams['returnUrl'] || '/';
      this.router.navigateByUrl(returnUrl);
    }
  }
}
```

## Breadcrumbs

```typescript
// breadcrumb.service.ts
@Injectable({ providedIn: 'root' })
export class Breadcrumb {
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  breadcrumbs = toSignal(
    this.router.events.pipe(
      filter(event => event instanceof NavigationEnd),
      map(() => this.buildBreadcrumbs(this.route.root))
    ),
    { initialValue: [] }
  );

  private buildBreadcrumbs(
    route: ActivatedRoute,
    url: string = '',
    breadcrumbs: Breadcrumb[] = []
  ): Breadcrumb[] {
    const children = route.children;

    if (children.length === 0) {
      return breadcrumbs;
    }

    for (const child of children) {
      const routeUrl = child.snapshot.url
        .map(segment => segment.path)
        .join('/');

      if (routeUrl) {
        url += `/${routeUrl}`;
      }

      const label = child.snapshot.data['breadcrumb'];
      if (label) {
        breadcrumbs.push({ label, url });
      }

      return this.buildBreadcrumbs(child, url, breadcrumbs);
    }

    return breadcrumbs;
  }
}

// Route config with breadcrumb data
export const routes: Routes = [
  {
    path: 'products',
    data: { breadcrumb: 'Products' },
    children: [
      { path: '', component: ProductList },
      {
        path: ':id',
        data: { breadcrumb: 'Product Details' },
        component: ProductDetail,
      },
    ],
  },
];

// breadcrumb.component.ts
@Component({
  selector: 'app-breadcrumb',
  template: `
    <nav aria-label="Breadcrumb">
      <ol>
        <li><a routerLink="/">Home</a></li>
        @for (crumb of breadcrumbService.breadcrumbs(); track crumb.url) {
          <li>
            <a [routerLink]="crumb.url">{{ crumb.label }}</a>
          </li>
        }
      </ol>
    </nav>
  `,
})
export class BreadcrumbCmpt {
  breadcrumbService = inject(Breadcrumb);
}
```

## Tab navigation

```typescript
// tabs-layout.component.ts
@Component({
  imports: [RouterOutlet, RouterLink, RouterLinkActive],
  template: `
    <div class="tabs">
      @for (tab of tabs; track tab.path) {
        <a
          [routerLink]="tab.path"
          routerLinkActive="active"
          [routerLinkActiveOptions]="{ exact: tab.exact }"
        >
          {{ tab.label }}
        </a>
      }
    </div>
    <div class="tab-content">
      <router-outlet />
    </div>
  `,
})
export class TabsLayout {
  tabs = [
    { path: './', label: 'Overview', exact: true },
    { path: 'details', label: 'Details', exact: false },
    { path: 'settings', label: 'Settings', exact: false },
  ];
}

// Routes
{
  path: 'account',
  component: TabsLayout,
  children: [
    { path: '', component: AccountOverview },
    { path: 'details', component: AccountDetails },
    { path: 'settings', component: AccountSettings },
  ],
}
```

## Modal routes

Using auxiliary outlets for modals:

```typescript
// Routes
export const routes: Routes = [
  { path: 'products', component: ProductList },
  { path: 'product-modal/:id', component: ProductModal, outlet: 'modal' },
];

// App template
@Component({
  template: `
    <router-outlet />
    <router-outlet name="modal" />
  `,
})
export class App {}

// Open modal
this.router.navigate([{ outlets: { modal: ['product-modal', productId] } }]);

// Close modal
this.router.navigate([{ outlets: { modal: null } }]);

// Link to open modal
<a [routerLink]="[{ outlets: { modal: ['product-modal', product.id] } }]">
  View Details
</a>
```

## Preloading strategies

### Built-in strategies

```typescript
import {
  provideRouter,
  withPreloading,
  PreloadAllModules,
  NoPreloading
} from '@angular/router';

// Preload all lazy modules
provideRouter(routes, withPreloading(PreloadAllModules))

// No preloading (default)
provideRouter(routes, withPreloading(NoPreloading))
```

### Custom preloading strategy

```typescript
// selective-preload.strategy.ts
@Injectable({ providedIn: 'root' })
export class SelectivePreloadStrategy implements PreloadingStrategy {
  preload(route: Route, load: () => Observable<any>): Observable<any> {
    // Only preload routes marked with data.preload = true
    if (route.data?.['preload']) {
      return load();
    }
    return of(null);
  }
}

// Routes
{
  path: 'dashboard',
  loadComponent: () => import('./dashboard.component'),
  data: { preload: true }, // Will be preloaded
}

// Config
provideRouter(routes, withPreloading(SelectivePreloadStrategy))
```

### Network-aware preloading

```typescript
@Injectable({ providedIn: 'root' })
export class NetworkAwarePreloadStrategy implements PreloadingStrategy {
  preload(route: Route, load: () => Observable<any>): Observable<any> {
    // Check network conditions
    const connection = (navigator as any).connection;

    if (connection) {
      // Don't preload on slow connections
      if (connection.saveData || connection.effectiveType === '2g') {
        return of(null);
      }
    }

    // Preload if marked
    if (route.data?.['preload']) {
      return load();
    }

    return of(null);
  }
}
```

## Route animations

```typescript
// app.routes.ts
export const routes: Routes = [
  { path: 'home', component: Home, data: { animation: 'HomePage' } },
  { path: 'about', component: About, data: { animation: 'AboutPage' } },
];

// app.component.ts
@Component({
  imports: [RouterOutlet],
  template: `
    <div [@routeAnimations]="getRouteAnimationData()">
      <router-outlet />
    </div>
  `,
  animations: [
    trigger('routeAnimations', [
      transition('HomePage <=> AboutPage', [
        style({ position: 'relative' }),
        query(':enter, :leave', [
          style({
            position: 'absolute',
            top: 0,
            left: 0,
            width: '100%',
          }),
        ]),
        query(':enter', [style({ left: '-100%' })]),
        query(':leave', animateChild()),
        group([
          query(':leave', [animate('300ms ease-out', style({ left: '100%' }))]),
          query(':enter', [animate('300ms ease-out', style({ left: '0%' }))]),
        ]),
      ]),
    ]),
  ],
})
export class AppMain {
  getRouteAnimationData() {
    return this.route.firstChild?.snapshot.data['animation'];
  }
}
```

## Scroll position restoration

```typescript
// app.config.ts
import {
  provideRouter,
  withInMemoryScrolling,
  withRouterConfig
} from '@angular/router';

provideRouter(
  routes,
  withInMemoryScrolling({
    scrollPositionRestoration: 'enabled', // or 'top'
    anchorScrolling: 'enabled',
  }),
  withRouterConfig({
    onSameUrlNavigation: 'reload',
  })
)
```
