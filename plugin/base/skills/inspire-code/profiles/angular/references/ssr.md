# Server-side rendering

Applies when the project uses `@angular/ssr`; skip otherwise. SSR setup,
render modes, hydration (including incremental hydration), browser-only code,
prerendering, TransferState, SEO, caching, and SSR tests. Detect the Angular
version in use from `@angular/core` in `package.json` before recommending
version-gated APIs.

## Setup

### Add SSR to an existing project

```bash
ng add @angular/ssr
```

This adds:
- `@angular/ssr` package
- `server.ts` — Express server
- `src/main.server.ts` — server bootstrap
- `src/app/app.config.server.ts` — server providers
- Updates `angular.json` with SSR configuration

### Project structure

```
src/
├── app/
│   ├── app.config.ts          # Browser config
│   ├── app.config.server.ts   # Server config
│   └── app.routes.ts
├── main.ts                     # Browser bootstrap
├── main.server.ts              # Server bootstrap
server.ts                       # Express server
```

## Configuration

### app.config.server.ts

```typescript
import { ApplicationConfig, mergeApplicationConfig } from '@angular/core';
import { provideServerRendering } from '@angular/platform-server';
import { provideServerRoutesConfig } from '@angular/ssr';
import { appConfig } from './app.config';
import { serverRoutes } from './app.routes.server';

const serverConfig: ApplicationConfig = {
  providers: [
    provideServerRendering(),
    provideServerRoutesConfig(serverRoutes),
  ],
};

export const config = mergeApplicationConfig(appConfig, serverConfig);
```

### Server routes configuration

```typescript
// app.routes.server.ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  {
    path: '',
    renderMode: RenderMode.Prerender, // Static at build time
  },
  {
    path: 'products',
    renderMode: RenderMode.Prerender,
  },
  {
    path: 'products/:id',
    renderMode: RenderMode.Server, // Dynamic SSR
  },
  {
    path: 'dashboard',
    renderMode: RenderMode.Client, // Client-only (SPA)
  },
  {
    path: '**',
    renderMode: RenderMode.Server,
  },
];
```

### Render modes

| Mode | Description | Use case |
|------|-------------|----------|
| `RenderMode.Prerender` | Static HTML at build time | Marketing pages, blogs |
| `RenderMode.Server` | Dynamic SSR per request | User-specific content |
| `RenderMode.Client` | Client-side only (SPA) | Authenticated dashboards |

## Hydration

### Default hydration

Hydration is enabled with `provideClientHydration()`:

```typescript
// app.config.ts
import { provideClientHydration } from '@angular/platform-browser';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(),
    // ...
  ],
};
```

### Incremental hydration

Incremental hydration (`@defer (hydrate ...)`) was introduced in Angular 19
(developer preview) and is stable since Angular 20.

Defer hydration of specific components:

```typescript
@Component({
  template: `
    <!-- Hydrate when visible -->
    @defer (hydrate on viewport) {
      <app-comments [postId]="postId" />
    } @placeholder {
      <div class="comments-placeholder">Loading comments...</div>
    }

    <!-- Hydrate on interaction -->
    @defer (hydrate on interaction) {
      <app-interactive-chart [data]="chartData" />
    }

    <!-- Hydrate on idle -->
    @defer (hydrate on idle) {
      <app-recommendations />
    }

    <!-- Never hydrate (static only) -->
    @defer (hydrate never) {
      <app-static-footer />
    }
  `,
})
export class Post {
  postId = input.required<string>();
  chartData = input.required<ChartData>();
}
```

### Hydration triggers

| Trigger | Description |
|---------|-------------|
| `hydrate on viewport` | When element enters viewport |
| `hydrate on interaction` | On click, focus, or input |
| `hydrate on idle` | When browser is idle |
| `hydrate on immediate` | Immediately after load |
| `hydrate on timer(ms)` | After specified delay |
| `hydrate when condition` | When expression is true |
| `hydrate never` | Never hydrate (static) |

### Event replay

Capture user events before hydration completes:

```typescript
import { provideClientHydration, withEventReplay } from '@angular/platform-browser';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(withEventReplay()),
  ],
};
```

## Browser-only code

### Platform detection

```typescript
import { PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser, isPlatformServer } from '@angular/common';

@Component({...})
export class My {
  private platformId = inject(PLATFORM_ID);

  ngOnInit() {
    if (isPlatformBrowser(this.platformId)) {
      // Browser-only code
      window.addEventListener('scroll', this.onScroll);
    }
  }
}
```

### afterNextRender / afterRender

Run code only in the browser after rendering:

```typescript
import { afterNextRender, afterRender } from '@angular/core';

@Component({...})
export class Chart {
  constructor() {
    // Runs once after first render (browser only)
    afterNextRender(() => {
      this.initChart();
    });

    // Runs after every render (browser only)
    afterRender(() => {
      this.updateChart();
    });
  }

  private initChart() {
    // Safe to use DOM APIs here
    const canvas = document.getElementById('chart');
    new Chart(canvas, this.config);
  }
}
```

### Inject browser APIs safely

```typescript
// tokens.ts
import { InjectionToken, PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';

export const WINDOW = new InjectionToken<Window | null>('Window', {
  providedIn: 'root',
  factory: () => {
    const platformId = inject(PLATFORM_ID);
    return isPlatformBrowser(platformId) ? window : null;
  },
});

export const LOCAL_STORAGE = new InjectionToken<Storage | null>('LocalStorage', {
  providedIn: 'root',
  factory: () => {
    const platformId = inject(PLATFORM_ID);
    return isPlatformBrowser(platformId) ? localStorage : null;
  },
});

// Usage
@Injectable({ providedIn: 'root' })
export class Storage {
  private storage = inject(LOCAL_STORAGE);

  get(key: string): string | null {
    return this.storage?.getItem(key) ?? null;
  }

  set(key: string, value: string): void {
    this.storage?.setItem(key, value);
  }
}
```

## Prerendering

### Static routes

```typescript
// app.routes.server.ts
export const serverRoutes: ServerRoute[] = [
  { path: '', renderMode: RenderMode.Prerender },
  { path: 'about', renderMode: RenderMode.Prerender },
  { path: 'contact', renderMode: RenderMode.Prerender },
  { path: 'blog', renderMode: RenderMode.Prerender },
];
```

### Dynamic routes with getPrerenderParams

```typescript
// app.routes.server.ts
import { RenderMode, ServerRoute, PrerenderFallback } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  {
    path: 'products/:id',
    renderMode: RenderMode.Prerender,
    async getPrerenderParams() {
      // Fetch product IDs to prerender
      const response = await fetch('https://api.example.com/products');
      const products = await response.json();
      return products.map((p: Product) => ({ id: p.id }));
    },
    fallback: PrerenderFallback.Server, // SSR for non-prerendered
  },
  {
    path: 'blog/:slug',
    renderMode: RenderMode.Prerender,
    async getPrerenderParams() {
      const posts = await fetchBlogPosts();
      return posts.map(post => ({ slug: post.slug }));
    },
    fallback: PrerenderFallback.Client, // SPA for non-prerendered
  },
];
```

### Prerender fallback options

| Fallback | Description |
|----------|-------------|
| `PrerenderFallback.Server` | SSR for non-prerendered routes |
| `PrerenderFallback.Client` | Client-side rendering |
| `PrerenderFallback.None` | 404 for non-prerendered routes |

## HTTP caching

### TransferState

Automatically transfer HTTP responses from server to client:

```typescript
import { provideClientHydration, withHttpTransferCacheOptions } from '@angular/platform-browser';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(
      withHttpTransferCacheOptions({
        includePostRequests: true,
        includeRequestsWithAuthHeaders: false,
        filter: (req) => !req.url.includes('/api/realtime'),
      })
    ),
  ],
};
```

### Manual TransferState

```typescript
import { TransferState, makeStateKey } from '@angular/core';

const PRODUCTS_KEY = makeStateKey<Product[]>('products');

@Injectable({ providedIn: 'root' })
export class Product {
  private http = inject(HttpClient);
  private transferState = inject(TransferState);
  private platformId = inject(PLATFORM_ID);

  getProducts(): Observable<Product[]> {
    // Check if data was transferred from server
    if (this.transferState.hasKey(PRODUCTS_KEY)) {
      const products = this.transferState.get(PRODUCTS_KEY, []);
      this.transferState.remove(PRODUCTS_KEY);
      return of(products);
    }

    return this.http.get<Product[]>('/api/products').pipe(
      tap(products => {
        // Store for transfer on server
        if (isPlatformServer(this.platformId)) {
          this.transferState.set(PRODUCTS_KEY, products);
        }
      })
    );
  }
}
```

## Build and deploy

### Build commands

```bash
# Build with SSR
ng build

# Output structure
dist/
├── my-app/
│   ├── browser/      # Client assets
│   └── server/       # Server bundle
```

### Run SSR server

```bash
# Development
npm run serve:ssr:my-app

# Production
node dist/my-app/server/server.mjs
```

### Deploy to a Node.js host

```javascript
// server.ts (generated)
import { APP_BASE_HREF } from '@angular/common';
import { CommonEngine } from '@angular/ssr/node';
import express from 'express';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import bootstrap from './src/main.server';

const serverDistFolder = dirname(fileURLToPath(import.meta.url));
const browserDistFolder = resolve(serverDistFolder, '../browser');
const indexHtml = join(serverDistFolder, 'index.server.html');

const app = express();
const commonEngine = new CommonEngine();

app.get('*', express.static(browserDistFolder, { maxAge: '1y', index: false }));

app.get('*', (req, res, next) => {
  commonEngine
    .render({
      bootstrap,
      documentFilePath: indexHtml,
      url: req.originalUrl,
      publicPath: browserDistFolder,
      providers: [{ provide: APP_BASE_HREF, useValue: req.baseUrl }],
    })
    .then((html) => res.send(html))
    .catch((err) => next(err));
});

app.listen(4000, () => {
  console.log('Server listening on http://localhost:4000');
});
```

## Hydration debugging

### Common hydration mismatches

```typescript
// Problem: Different content on server vs client
@Component({
  template: `<p>Current time: {{ currentTime }}</p>`,
})
export class Time {
  // BAD: Different value on server and client
  currentTime = new Date().toLocaleTimeString();
}

// Solution: Use afterNextRender or skip SSR
@Component({
  template: `<p>Current time: {{ currentTime() }}</p>`,
})
export class Time {
  currentTime = signal('');

  constructor() {
    afterNextRender(() => {
      this.currentTime.set(new Date().toLocaleTimeString());
    });
  }
}
```

### Skip hydration for dynamic content

```typescript
@Component({
  template: `
    <!-- Skip hydration for this subtree -->
    <div ngSkipHydration>
      <app-dynamic-widget />
    </div>
  `,
})
export class Page {}
```

### Debug hydration issues

```typescript
// Enable hydration debugging in development
import { provideClientHydration, withNoDomReuse } from '@angular/platform-browser';

export const appConfig: ApplicationConfig = {
  providers: [
    provideClientHydration(
      // Disable DOM reuse to see hydration errors clearly
      ...(isDevMode() ? [withNoDomReuse()] : [])
    ),
  ],
};
```

## SEO optimization

### Meta tags service

```typescript
import { Injectable, inject } from '@angular/core';
import { Meta, Title } from '@angular/platform-browser';
import { DOCUMENT } from '@angular/common';

@Injectable({ providedIn: 'root' })
export class Seo {
  private meta = inject(Meta);
  private title = inject(Title);
  private document = inject(DOCUMENT);

  updateMetaTags(config: {
    title: string;
    description: string;
    image?: string;
    url?: string;
    type?: string;
  }) {
    // Basic meta
    this.title.setTitle(config.title);
    this.meta.updateTag({ name: 'description', content: config.description });

    // Open Graph
    this.meta.updateTag({ property: 'og:title', content: config.title });
    this.meta.updateTag({ property: 'og:description', content: config.description });
    this.meta.updateTag({ property: 'og:type', content: config.type || 'website' });

    if (config.image) {
      this.meta.updateTag({ property: 'og:image', content: config.image });
    }

    if (config.url) {
      this.meta.updateTag({ property: 'og:url', content: config.url });
      this.updateCanonicalUrl(config.url);
    }

    // Twitter Card
    this.meta.updateTag({ name: 'twitter:card', content: 'summary_large_image' });
    this.meta.updateTag({ name: 'twitter:title', content: config.title });
    this.meta.updateTag({ name: 'twitter:description', content: config.description });

    if (config.image) {
      this.meta.updateTag({ name: 'twitter:image', content: config.image });
    }
  }

  private updateCanonicalUrl(url: string) {
    let link: HTMLLinkElement | null = this.document.querySelector('link[rel="canonical"]');

    if (!link) {
      link = this.document.createElement('link');
      link.setAttribute('rel', 'canonical');
      this.document.head.appendChild(link);
    }

    link.setAttribute('href', url);
  }

  setJsonLd(data: object) {
    let script: HTMLScriptElement | null = this.document.querySelector('script[type="application/ld+json"]');

    if (!script) {
      script = this.document.createElement('script');
      script.type = 'application/ld+json';
      this.document.head.appendChild(script);
    }

    script.textContent = JSON.stringify(data);
  }
}

// Usage in component
@Component({...})
export class Product {
  private seo = inject(Seo);
  product = input.required<Product>();

  constructor() {
    effect(() => {
      const product = this.product();
      this.seo.updateMetaTags({
        title: `${product.name} | My Store`,
        description: product.description,
        image: product.imageUrl,
        url: `https://example.com/products/${product.id}`,
        type: 'product',
      });

      this.seo.setJsonLd({
        '@context': 'https://schema.org',
        '@type': 'Product',
        name: product.name,
        description: product.description,
        image: product.imageUrl,
        offers: {
          '@type': 'Offer',
          price: product.price,
          priceCurrency: 'USD',
        },
      });
    });
  }
}
```

### Route-based SEO with resolvers

```typescript
// seo.resolver.ts
export const seoResolver: ResolveFn<SeoData> = async (route) => {
  const productId = route.paramMap.get('id')!;
  const productService = inject(Product);
  const product = await productService.getById(productId);

  return {
    title: `${product.name} | My Store`,
    description: product.description,
    image: product.imageUrl,
  };
};

// Routes
{
  path: 'products/:id',
  component: Product,
  resolve: { seo: seoResolver },
}

// Component
@Component({...})
export class Product {
  private seo = inject(Seo);
  seoData = input.required<SeoData>(); // From resolver

  constructor() {
    effect(() => {
      this.seo.updateMetaTags(this.seoData());
    });
  }
}
```

## Authentication with SSR

### Cookie-based auth

```typescript
// Server-side cookie reading
import { REQUEST } from '@angular/ssr/tokens';

@Injectable({ providedIn: 'root' })
export class Auth {
  private request = inject(REQUEST, { optional: true });
  private platformId = inject(PLATFORM_ID);

  getToken(): string | null {
    if (isPlatformServer(this.platformId) && this.request) {
      // Read from request cookies on server
      const cookies = this.request.headers.cookie || '';
      const match = cookies.match(/auth_token=([^;]+)/);
      return match ? match[1] : null;
    }

    if (isPlatformBrowser(this.platformId)) {
      // Read from document cookies on client
      const match = document.cookie.match(/auth_token=([^;]+)/);
      return match ? match[1] : null;
    }

    return null;
  }
}
```

### Skip SSR for authenticated routes

```typescript
// app.routes.server.ts
export const serverRoutes: ServerRoute[] = [
  // Public routes - prerender
  { path: '', renderMode: RenderMode.Prerender },
  { path: 'products', renderMode: RenderMode.Prerender },

  // Authenticated routes - client only
  { path: 'dashboard', renderMode: RenderMode.Client },
  { path: 'profile', renderMode: RenderMode.Client },
  { path: 'settings', renderMode: RenderMode.Client },
];
```

## Caching strategies

### HTTP cache headers

```typescript
// server.ts
import { REQUEST, RESPONSE_INIT } from '@angular/ssr/tokens';

// In route configuration or component
@Component({...})
export class ProductList {
  private responseInit = inject(RESPONSE_INIT, { optional: true });

  constructor() {
    // Set cache headers for SSR response
    if (this.responseInit) {
      this.responseInit.headers = {
        ...this.responseInit.headers,
        'Cache-Control': 'public, max-age=3600, s-maxage=86400',
      };
    }
  }
}
```

### CDN caching with Vary headers

```typescript
// server.ts - Express middleware
app.use((req, res, next) => {
  // Vary by cookie for authenticated content
  res.setHeader('Vary', 'Cookie');
  next();
});
```

### Stale-while-revalidate

```typescript
// Set SWR headers for dynamic content
this.responseInit.headers = {
  'Cache-Control': 'public, max-age=60, stale-while-revalidate=3600',
};
```

## Error handling

### SSR error boundaries

```typescript
// error-handler.ts
import { ErrorHandler, Injectable, inject } from '@angular/core';
import { PLATFORM_ID } from '@angular/core';
import { isPlatformServer } from '@angular/common';

@Injectable()
export class SsrError implements ErrorHandler {
  private platformId = inject(PLATFORM_ID);

  handleError(error: Error) {
    if (isPlatformServer(this.platformId)) {
      // Log server errors
      console.error('SSR Error:', error);
      // Could send to monitoring service
    } else {
      // Client-side error handling
      console.error('Client Error:', error);
    }
  }
}

// Provide in app.config.ts
{ provide: ErrorHandler, useClass: SsrError }
```

### Graceful degradation

```typescript
@Component({
  template: `
    @if (dataError()) {
      <!-- Fallback content that works without data -->
      <app-fallback-content />
    } @else {
      <app-data-content [data]="data()" />
    }
  `,
})
export class PageCmpt {
  private dataService = inject(Data);

  data = signal<Data | null>(null);
  dataError = signal(false);

  constructor() {
    this.loadData();
  }

  private async loadData() {
    try {
      const data = await this.dataService.getData();
      this.data.set(data);
    } catch {
      this.dataError.set(true);
    }
  }
}
```

## Performance optimization

### Lazy hydration strategy

```typescript
@Component({
  template: `
    <!-- Critical content - hydrate immediately -->
    <header>
      <app-navigation />
    </header>

    <!-- Main content - hydrate on viewport -->
    <main>
      @defer (hydrate on viewport) {
        <app-product-grid [products]="products()" />
      }
    </main>

    <!-- Below fold - hydrate on idle -->
    @defer (hydrate on idle) {
      <app-reviews [productId]="productId()" />
    }

    <!-- Interactive only - hydrate on interaction -->
    @defer (hydrate on interaction) {
      <app-chat-widget />
    }

    <!-- Static footer - never hydrate -->
    @defer (hydrate never) {
      <app-footer />
    }
  `,
})
export class ProductPage {}
```

### Preload critical data

```typescript
// app.routes.server.ts
export const serverRoutes: ServerRoute[] = [
  {
    path: 'products/:id',
    renderMode: RenderMode.Server,
    async getPrerenderParams() {
      // Prerender top 100 products
      const topProducts = await fetchTopProducts(100);
      return topProducts.map(p => ({ id: p.id }));
    },
  },
];
```

### Streaming SSR (experimental)

Streaming SSR was introduced as experimental in Angular 19 — verify its
current status for the Angular version in use.

```typescript
// Enable streaming for faster TTFB
import { provideServerRendering } from '@angular/platform-server';

const serverConfig: ApplicationConfig = {
  providers: [
    provideServerRendering(),
    // Streaming is automatic with @defer blocks
  ],
};
```

## Testing SSR

### Test server rendering

```typescript
import { renderApplication } from '@angular/platform-server';
import { App } from './app.component';
import { config } from './app.config.server';

describe('SSR', () => {
  it('should render home page', async () => {
    const html = await renderApplication(App, {
      appId: 'my-app',
      providers: config.providers,
      url: '/',
    });

    expect(html).toContain('<h1>Welcome</h1>');
    expect(html).toContain('</app-root>');
  });

  it('should render product page with data', async () => {
    const html = await renderApplication(App, {
      appId: 'my-app',
      providers: config.providers,
      url: '/products/123',
    });

    expect(html).toContain('Product Name');
    expect(html).not.toContain('Loading...');
  });
});
```

### Test hydration

```typescript
import { TestBed } from '@angular/core/testing';
import { provideClientHydration } from '@angular/platform-browser';

describe('Hydration', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideClientHydration()],
    });
  });

  it('should hydrate without errors', () => {
    const fixture = TestBed.createComponent(App);
    fixture.detectChanges();

    // No hydration mismatch errors should be thrown
    expect(fixture.componentInstance).toBeTruthy();
  });
});
```
