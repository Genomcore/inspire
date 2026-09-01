# Performance

Change detection optimization (OnPush, signals), lazy loading, rendering
performance (track, virtual scrolling, `@defer`), memory leak prevention, NgRx
selector memoization, bundle size, profiling, and the runtime checklist. The
NgRx, ag-Grid, and ECharts sections apply only when the project uses those
libraries.

## Change detection

### OnPush strategy

Prevent unnecessary re-renders by using `OnPush`:

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class OptimizedComponent {
  private cdr = inject(ChangeDetectorRef);

  // Only re-renders when:
  // 1. @Input reference changes
  // 2. Event handler fires in template
  // 3. Async pipe emits
  // 4. Manual markForCheck() / detectChanges()
}
```

**Rules for OnPush:**
- Never mutate objects/arrays — always create new references
- Use `markForCheck()` after subscription callbacks that update local state
- Use `async` pipe when possible (handles markForCheck automatically)
- Use `detach()` + manual `detectChanges()` for maximum control

### Detaching change detection

For components that update on a schedule (e.g., real-time data):

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RealtimeComponent implements OnInit, OnDestroy {
  private cdr = inject(ChangeDetectorRef);
  private intervalId: any;

  data: DataPoint[] = [];

  ngOnInit(): void {
    // Detach from change detection tree
    this.cdr.detach();

    // Update manually on interval
    this.intervalId = setInterval(() => {
      this.data = this.fetchLatestData();
      this.cdr.detectChanges();
    }, 5000);
  }

  ngOnDestroy(): void {
    clearInterval(this.intervalId);
  }
}
```

### Signals for automatic change detection

Signals provide fine-grained reactivity without `markForCheck()`:

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <div>{{ count() }}</div>
    <div>{{ doubled() }}</div>
  `,
})
export class SignalComponent {
  count = signal(0);
  doubled = computed(() => this.count() * 2);

  increment(): void {
    this.count.update(c => c + 1);
    // No markForCheck needed - signals auto-notify
  }
}
```

## Lazy loading

### Route-level lazy loading

```typescript
export const routes: Routes = [
  {
    path: 'reports',
    loadChildren: () =>
      import('./reports/reports.module').then(m => m.ReportsModule),
  },
  {
    path: 'records',
    loadChildren: () =>
      import('./records/records.module').then(m => m.RecordsModule),
  },
];
```

### Component-level lazy loading with @defer

```html
<!-- Load component when visible in viewport -->
@defer (on viewport) {
  <app-heavy-chart [data]="chartData" />
} @placeholder {
  <div class="chart-skeleton">
    <mat-spinner diameter="40" />
  </div>
} @loading (minimum 300ms) {
  <mat-progress-bar mode="indeterminate" />
}

<!-- Load on interaction -->
@defer (on interaction) {
  <app-item-detail [itemId]="selectedId" />
} @placeholder {
  <button mat-raised-button>{{ 'action.viewDetails' | translate }}</button>
}

<!-- Load when condition is true -->
@defer (when showAdvanced) {
  <app-advanced-filters [config]="filterConfig" />
}

<!-- Load on idle (prefetch) -->
@defer (on idle; prefetch on hover) {
  <app-analytics-dashboard />
} @placeholder {
  <div class="dashboard-placeholder">Click to load</div>
}
```

### Lazy loading standalone components

```typescript
{
  path: 'detail/:id',
  loadComponent: () =>
    import('./detail/detail.component').then(c => c.DetailComponent),
},
```

## Rendering performance

### track in @for loops

Always use `track` with a unique identifier:

```html
<!-- Good: track by unique ID -->
@for (item of items; track item.id) {
  <app-item-card [item]="item" />
}

<!-- Good: track by index for static lists -->
@for (column of columns; track $index) {
  <th>{{ column.label }}</th>
}

<!-- Avoid: track by object reference (causes full re-render) -->
@for (item of items; track item) {
  <app-item-card [item]="item" />
}
```

### Virtual scrolling

For large lists, use CDK virtual scroll:

```typescript
import { ScrollingModule } from '@angular/cdk/scrolling';

@Component({
  imports: [ScrollingModule],
  template: `
    <cdk-virtual-scroll-viewport itemSize="48" class="list-viewport">
      <div *cdkVirtualFor="let item of items; trackBy: trackById" class="list-item">
        {{ item.name }}
      </div>
    </cdk-virtual-scroll-viewport>
  `,
  styles: [`
    .list-viewport {
      height: 400px;
    }
    .list-item {
      height: 48px;
    }
  `],
})
export class VirtualListComponent {
  items: Item[] = []; // Can be thousands of items

  trackById(index: number, item: Item): string {
    return item.id;
  }
}
```

### ag-Grid server-side row model

For large datasets, use server-side pagination:

```typescript
gridOptions: GridOptions = {
  rowModelType: 'serverSide',
  pagination: true,
  paginationPageSize: 50,
  cacheBlockSize: 50,
  maxBlocksInCache: 10, // Limit cached blocks
  blockLoadDebounceMillis: 200, // Debounce rapid scrolling
};
```

## NgRx selector optimization

### Memoized selectors

Selectors only recompute when their inputs change:

```typescript
// Good: Memoized - won't recompute unless items or filter change
export const selectFilteredItems = createSelector(
  selectItems,
  selectFilter,
  (items, filter) => {
    return items.filter(item =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  },
);

// Bad: Creates new selector on each call (no memoization)
export const selectItemById = (id: string) =>
  createSelector(selectItems, (items) => items.find(i => i.id === id));

// Better: Use props-based selector (memoized per unique props)
export const selectItemById = (props: { id: string }) =>
  createSelector(selectItems, (items) => items.find(i => i.id === props.id));
```

### Avoid derived data in the store

Compute derived data in selectors, not in state:

```typescript
// Bad: storing derived data in state
on(Actions.FetchSuccess, (state, { items }) => ({
  ...state,
  items,
  filteredItems: items.filter(...), // Redundant
  itemCount: items.length,           // Redundant
}));

// Good: derive in selectors
export const selectFilteredItems = createSelector(
  selectItems,
  selectFilter,
  (items, filter) => items.filter(...),
);

export const selectItemCount = createSelector(
  selectItems,
  (items) => items.length,
);
```

### Selector composition for view models

Combine selectors to build view models:

```typescript
export const selectViewModel = createSelector(
  selectItems,
  selectLoading,
  selectError,
  selectFilter,
  (items, loading, error, filter) => ({
    items,
    loading,
    error,
    filter,
    isEmpty: items.length === 0 && !loading,
    hasError: error !== null,
  }),
);
```

## Memory leak prevention

### Subscription cleanup

```typescript
// Pattern 1: takeUntil with destroy$ subject
private destroy$ = new Subject<void>();

ngOnInit(): void {
  this.store.select(selector)
    .pipe(takeUntil(this.destroy$))
    .subscribe((data) => { ... });
}

ngOnDestroy(): void {
  this.destroy$.next();
  this.destroy$.complete();
}

// Pattern 2: DestroyRef (Angular 16+)
private destroyRef = inject(DestroyRef);

ngOnInit(): void {
  this.store.select(selector)
    .pipe(takeUntilDestroyed(this.destroyRef))
    .subscribe((data) => { ... });
}

// Pattern 3: async pipe (no manual cleanup needed)
// items$ = this.store.select(selectItems);
// Template: {{ items$ | async }}
```

### Common leak sources

```typescript
// Leak: Event listener without cleanup
ngOnInit(): void {
  window.addEventListener('resize', this.onResize);
}
ngOnDestroy(): void {
  window.removeEventListener('resize', this.onResize); // Don't forget!
}

// Leak: setInterval without cleanup
private intervalId: any;
ngOnInit(): void {
  this.intervalId = setInterval(() => { ... }, 1000);
}
ngOnDestroy(): void {
  clearInterval(this.intervalId);
}

// Leak: store subscription without takeUntil
ngOnInit(): void {
  // Bad: no unsubscribe
  this.store.select(selector).subscribe((data) => { ... });
}
```

## Bundle size optimization

### Tree-shakeable providers

```typescript
// Good: Tree-shakeable - removed if unused
@Injectable({ providedIn: 'root' })
export class MyService {}

// Bad: Not tree-shakeable
@NgModule({
  providers: [MyService], // Always included in bundle
})
```

### Import only what you need

```typescript
// Good: Specific imports
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

// Bad: Entire Material library
import { MaterialModule } from './material.module'; // Huge bundle impact
```

### Analyze bundle size

```bash
# Build with stats
ng build --stats-json

# Analyze with webpack-bundle-analyzer
npx webpack-bundle-analyzer dist/<app-name>/stats.json
```

## Template optimization

### Avoid function calls in templates

```html
<!-- Bad: Called on every change detection cycle -->
<div>{{ getFormattedDate(item.date) }}</div>
<div [class]="getItemClass(item)"></div>

<!-- Good: Use pipes (pure by default, memoized) -->
<div>{{ item.date | date:'medium' }}</div>

<!-- Good: Use computed signal -->
<div>{{ formattedDate() }}</div>

<!-- Good: Pre-compute in component -->
<div>{{ item.formattedDate }}</div>
```

### Pure pipes for repeated computations

```typescript
@Pipe({
  name: 'fileSize',
  pure: true, // Default - only recomputes when input reference changes
  standalone: true,
})
export class FileSizePipe implements PipeTransform {
  transform(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1048576).toFixed(1)} MB`;
  }
}
```

## Image optimization

### NgOptimizedImage

```typescript
import { NgOptimizedImage } from '@angular/common';

@Component({
  imports: [NgOptimizedImage],
  template: `
    <!-- Optimized image with lazy loading -->
    <img ngSrc="/assets/images/logo.png"
         width="200"
         height="100"
         priority />

    <!-- Lazy loaded (below fold) -->
    <img ngSrc="/assets/images/chart.png"
         width="800"
         height="400"
         loading="lazy" />
  `,
})
```

## Profiling and diagnostics

### Angular DevTools profiler

```typescript
// Enable in development
// angular.json
{
  "configurations": {
    "development": {
      "optimization": false,
      "sourceMap": true
    }
  }
}
```

### Custom performance marks

```typescript
@Injectable({ providedIn: 'root' })
export class PerfMonitor {
  mark(name: string): void {
    performance.mark(name);
  }

  measure(name: string, startMark: string, endMark: string): PerformanceMeasure {
    return performance.measure(name, startMark, endMark);
  }

  // Decorator for method timing
  static time(label: string) {
    return (target: any, key: string, descriptor: PropertyDescriptor) => {
      const original = descriptor.value;
      descriptor.value = function (...args: any[]) {
        const start = performance.now();
        const result = original.apply(this, args);
        if (result instanceof Promise) {
          return result.finally(() => {
            console.log(`${label}: ${(performance.now() - start).toFixed(2)}ms`);
          });
        }
        console.log(`${label}: ${(performance.now() - start).toFixed(2)}ms`);
        return result;
      };
    };
  }
}
```

### Change detection debugging

```typescript
// Count change detection cycles
@Component({...})
export class DebugComponent {
  private cdCount = 0;

  ngDoCheck(): void {
    this.cdCount++;
    if (this.cdCount % 100 === 0) {
      console.warn(`CD cycles: ${this.cdCount}`);
    }
  }
}
```

## Web workers for heavy computation

### Creating a web worker

```bash
ng generate web-worker data-processor
```

```typescript
// data-processor.worker.ts
addEventListener('message', ({ data }) => {
  const { type, payload } = data;

  switch (type) {
    case 'FILTER_ITEMS': {
      const filtered = payload.items.filter((item: any) =>
        item.score >= payload.minScore &&
        payload.categories.includes(item.category)
      );
      postMessage({ type: 'FILTER_RESULT', payload: filtered });
      break;
    }
    case 'COMPUTE_STATISTICS': {
      const stats = computeItemStatistics(payload.items);
      postMessage({ type: 'STATISTICS_RESULT', payload: stats });
      break;
    }
  }
});

function computeItemStatistics(items: any[]): any {
  // Heavy computation offloaded from main thread
  return {
    total: items.length,
    byCategory: groupBy(items, 'category'),
    scoreDistribution: computeDistribution(items, 'score'),
  };
}
```

### Using the worker in a service

```typescript
@Injectable({ providedIn: 'root' })
export class DataProcessorService {
  private worker: Worker | null = null;

  constructor() {
    if (typeof Worker !== 'undefined') {
      this.worker = new Worker(
        new URL('./data-processor.worker', import.meta.url),
      );
    }
  }

  filterItems(
    items: Item[],
    minScore: number,
    categories: string[],
  ): Observable<Item[]> {
    if (!this.worker) {
      // Fallback for SSR or no Worker support
      return of(items.filter(item =>
        item.score >= minScore && categories.includes(item.category)
      ));
    }

    return new Observable((observer) => {
      const handler = (event: MessageEvent) => {
        if (event.data.type === 'FILTER_RESULT') {
          observer.next(event.data.payload);
          observer.complete();
          this.worker!.removeEventListener('message', handler);
        }
      };

      this.worker!.addEventListener('message', handler);
      this.worker!.postMessage({
        type: 'FILTER_ITEMS',
        payload: { items, minScore, categories },
      });
    });
  }
}
```

## Incremental loading patterns

### Pagination with infinite scroll

```typescript
@Component({
  template: `
    <div class="list-container" (scroll)="onScroll($event)">
      @for (item of items; track item.id) {
        <app-item-row [item]="item" />
      }
      @if (loading) {
        <mat-spinner diameter="30" />
      }
    </div>
  `,
})
export class InfiniteListComponent {
  private store = inject(Store);
  items: Item[] = [];
  loading = false;
  private page = 1;
  private hasMore = true;

  onScroll(event: Event): void {
    const el = event.target as HTMLElement;
    const threshold = 200; // px from bottom

    if (
      el.scrollHeight - el.scrollTop - el.clientHeight < threshold &&
      !this.loading &&
      this.hasMore
    ) {
      this.loadMore();
    }
  }

  private loadMore(): void {
    this.page++;
    this.store.dispatch(Actions.FetchItems({ page: this.page, pageSize: 50 }));
  }
}
```

### Progressive data loading

```typescript
@Component({...})
export class DashboardComponent implements OnInit {
  // Load critical data first, defer non-critical
  ngOnInit(): void {
    // Priority 1: Essential data
    this.store.dispatch(Actions.FetchSummary());

    // Priority 2: Visible above fold
    setTimeout(() => {
      this.store.dispatch(Actions.FetchRecentItems());
    }, 0);

    // Priority 3: Below fold / secondary panels
    requestIdleCallback(() => {
      this.store.dispatch(Actions.FetchStatistics());
      this.store.dispatch(Actions.FetchNotifications());
    });
  }
}
```

## NgRx performance

### Avoiding unnecessary store updates

```typescript
// Bad: Dispatching when value hasn't changed
onFilterChange(filter: string): void {
  this.store.dispatch(Actions.SetFilter({ filter }));
}

// Good: Check before dispatching
onFilterChange(filter: string): void {
  this.store.select(selectFilter).pipe(first()).subscribe((current) => {
    if (current !== filter) {
      this.store.dispatch(Actions.SetFilter({ filter }));
    }
  });
}
```

### distinctUntilChanged in subscriptions

```typescript
// Prevent component updates when selected value hasn't changed
this.store.select(selectItems).pipe(
  distinctUntilChanged((prev, curr) => prev.length === curr.length),
  takeUntil(this.destroy$),
).subscribe((items) => {
  this.items = items;
  this.cdr.markForCheck();
});
```

### Flattening state reads

```typescript
// Bad: Multiple subscriptions
this.store.select(selectItems).subscribe(items => this.items = items);
this.store.select(selectLoading).subscribe(loading => this.loading = loading);
this.store.select(selectError).subscribe(error => this.error = error);

// Good: Single view model subscription
this.store.select(selectViewModel).pipe(
  takeUntil(this.destroy$),
).subscribe((vm) => {
  this.items = vm.items;
  this.loading = vm.loading;
  this.error = vm.error;
  this.cdr.markForCheck();
});

// Best: async pipe with view model
// vm$ = this.store.select(selectViewModel);
// Template: @if (vm$ | async; as vm) { ... }
```

## ag-Grid performance

### Column definitions optimization

```typescript
columnDefs: ColDef[] = [
  {
    field: 'name',
    // Enable caching for filter values
    filterParams: {
      suppressMiniFilter: false,
      cacheQuickFilter: true,
    },
  },
  {
    field: 'description',
    // Skip filtering/sorting for display-only columns
    sortable: false,
    filter: false,
    // Use value getter instead of complex cell renderer
    valueGetter: (params) => params.data?.description?.substring(0, 100),
  },
];
```

### Server-side pagination

```typescript
gridOptions: GridOptions = {
  rowModelType: 'serverSide',
  serverSideInitialRowCount: 0,
  cacheBlockSize: 100,
  maxBlocksInCache: 5, // Purge old blocks
  blockLoadDebounceMillis: 300,
  // Disable features you don't need
  suppressColumnVirtualisation: false,
  suppressRowVirtualisation: false,
  // Debounce sort/filter changes
  asyncTransactionWaitMillis: 200,
};
```

### Row buffer and DOM optimization

```typescript
gridOptions: GridOptions = {
  rowBuffer: 10, // Rows rendered outside viewport
  animateRows: false, // Disable for large datasets
  suppressCellFocus: true, // Better keyboard perf
  enableCellTextSelection: true,
  domLayout: 'normal', // Not 'autoHeight' for large lists
};
```

## ECharts performance

### Large dataset rendering

```typescript
chartOption: EChartsOption = {
  dataset: {
    source: largeDataset, // Use dataset API instead of series.data
  },
  series: [{
    type: 'scatter',
    encode: { x: 'x', y: 'y' },
    large: true, // Enable large mode for 5k+ points
    largeThreshold: 5000,
    progressive: 400, // Render incrementally
    progressiveThreshold: 3000,
  }],
  // Sampling for line charts
  series: [{
    type: 'line',
    sampling: 'lttb', // Largest-Triangle-Three-Buckets
    data: timeSeriesData,
  }],
};
```

### Lazy chart initialization

```html
@defer (on viewport) {
  <div echarts
       [options]="chartOption"
       [merge]="updateOption"
       class="chart-container">
  </div>
} @placeholder {
  <div class="chart-placeholder">
    <mat-icon>bar_chart</mat-icon>
    <span>{{ 'chart.loading' | translate }}</span>
  </div>
}
```

## Network optimization

### HTTP caching with interceptors

```typescript
export const cachingInterceptor: HttpInterceptorFn = (req, next) => {
  // Only cache GET requests
  if (req.method !== 'GET') {
    return next(req);
  }

  const cache = inject(HttpCacheService);
  const cached = cache.get(req.urlWithParams);

  if (cached) {
    return of(cached);
  }

  return next(req).pipe(
    tap((event) => {
      if (event instanceof HttpResponse) {
        cache.set(req.urlWithParams, event, 60000); // 1 min TTL
      }
    }),
  );
};
```

### Request deduplication

```typescript
@Injectable({ providedIn: 'root' })
export class DeduplicatedHttpService {
  private pendingRequests = new Map<string, Observable<any>>();

  get<T>(url: string): Observable<T> {
    const key = url;

    if (this.pendingRequests.has(key)) {
      return this.pendingRequests.get(key) as Observable<T>;
    }

    const request$ = this.http.get<T>(url).pipe(
      shareReplay(1),
      finalize(() => this.pendingRequests.delete(key)),
    );

    this.pendingRequests.set(key, request$);
    return request$;
  }

  private http = inject(HttpClient);
}
```

### Debounced search

```typescript
searchControl = new FormControl('');

results$ = this.searchControl.valueChanges.pipe(
  debounceTime(300),
  distinctUntilChanged(),
  filter((query): query is string => query !== null && query.length >= 2),
  switchMap((query) => this.searchService.search(query)),
  shareReplay(1),
);
```

## Runtime performance checklist

### Component level
- [ ] OnPush change detection on all components
- [ ] `track` expression in all `@for` loops using unique IDs
- [ ] No function calls in templates (use pipes or computed values)
- [ ] `@defer` for below-fold or heavy components
- [ ] Virtual scrolling for lists > 100 items
- [ ] Unsubscribe from all observables (takeUntil or async pipe)

### State management level
- [ ] Memoized selectors for derived data
- [ ] View model selectors to reduce subscriptions
- [ ] distinctUntilChanged where appropriate
- [ ] No redundant store dispatches
- [ ] Immutable state updates (spread operator)

### Network level
- [ ] Server-side pagination for large datasets
- [ ] Request deduplication
- [ ] Debounced user input (search, filters)
- [ ] HTTP caching for static data

### Build level
- [ ] Lazy loaded feature modules
- [ ] Tree-shakeable services (providedIn: 'root')
- [ ] Specific Material module imports (not barrel imports)
- [ ] Production build with optimization enabled
- [ ] Analyze bundle size regularly

### Grid / chart level
- [ ] Server-side row model for ag-Grid (>1000 rows)
- [ ] Limited cache blocks in ag-Grid
- [ ] Large mode for ECharts scatter plots (>5000 points)
- [ ] Sampling for ECharts line charts with dense data
- [ ] Lazy chart initialization with @defer
