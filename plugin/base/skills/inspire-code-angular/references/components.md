# Components

Component authoring conventions: declaration styles, smart/dumb split, OnPush
change detection, the modern control-flow template syntax, Material patterns,
communication, and component tests. Examples use the `app-` selector prefix and
an `app-` BEM class prefix — the project declares its own selector and class
prefixes; substitute them throughout. Angular Material and ag-Grid sections
apply only when the project uses those libraries.

## Component declaration

### Standalone component (preferred for new components)

```typescript
import { Component, ChangeDetectionStrategy, inject, input, output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-feature-card',
  templateUrl: './feature-card.component.html',
  styleUrls: ['./feature-card.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [
    CommonModule,
    MatIconModule,
    MatButtonModule,
    TranslateModule,
  ],
})
export class FeatureCardComponent {
  // Component logic
}
```

### Module-based component (existing pattern)

In a codebase that still carries NgModules, follow the existing pattern rather
than mixing styles within a feature:

```typescript
@Component({
  selector: 'app-feature-list',
  templateUrl: './feature-list.component.html',
  styleUrls: ['./feature-list.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class FeatureListComponent implements OnInit, OnDestroy {
  // Component logic
}
```

Register in the module:

```typescript
const COMPONENTS = [
  FeatureListComponent,
  FeatureDetailComponent,
];

@NgModule({
  declarations: [...COMPONENTS],
  imports: [
    SharedModule,
    FeatureRoutingModule,
    // Standalone components imported directly
    FeatureCardComponent,
  ],
})
export class FeatureModule {}
```

## Smart vs dumb component pattern

### Smart component (container)

Handles state management, API calls, and business logic:

```typescript
@Component({
  selector: 'app-document-list',
  templateUrl: './document-list.component.html',
  styleUrls: ['./document-list.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class DocumentListComponent implements OnInit, OnDestroy {
  private store = inject(Store);
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);
  private destroy$ = new Subject<void>();

  documents: Document[] = [];
  loading = false;

  ngOnInit(): void {
    this.store
      .select(DocumentSelectors.selectDocuments)
      .pipe(takeUntil(this.destroy$))
      .subscribe((documents) => {
        this.documents = documents.items;
        this.cdr.markForCheck();
      });

    this.store
      .select(DocumentSelectors.selectLoading)
      .pipe(takeUntil(this.destroy$))
      .subscribe((loading) => {
        this.loading = loading;
        this.cdr.markForCheck();
      });

    this.fetchData();
  }

  fetchData(): void {
    this.store.dispatch(DocumentActions.FetchDocuments({ page: 1, pageSize: 20 }));
  }

  onDocumentSelect(documentId: string): void {
    this.router.navigate(['/documents', documentId]);
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

### Dumb component (presentational)

Receives data via inputs, emits events via outputs. No store interaction:

```typescript
@Component({
  selector: 'app-document-card',
  templateUrl: './document-card.component.html',
  styleUrls: ['./document-card.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: true,
  imports: [MatIconModule, MatButtonModule, TranslateModule, NgClass],
})
export class DocumentCardComponent {
  @Input() document!: Document;
  @Input() selected = false;

  @Output() select = new EventEmitter<string>();
  @Output() delete = new EventEmitter<string>();

  onSelect(): void {
    this.select.emit(this.document.id);
  }

  onDelete(): void {
    this.delete.emit(this.document.id);
  }
}
```

## OnPush change detection

Always use `ChangeDetectionStrategy.OnPush` and trigger updates manually:

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class MyComponent {
  private cdr = inject(ChangeDetectorRef);

  ngOnInit(): void {
    // After async subscription updates local state
    this.store.select(selector).pipe(
      takeUntil(this.destroy$),
    ).subscribe((data) => {
      this.data = data;
      this.cdr.markForCheck(); // Required for OnPush
    });
  }
}
```

**When `markForCheck()` is needed:**
- After store subscription updates local properties
- After any async operation that modifies component state
- Inside `setTimeout` or `setInterval` callbacks
- After manual DOM operations

**When it's NOT needed:**
- Template bindings to `| async` pipe (handles it automatically)
- `@Input` changes (Angular detects reference changes)
- Event handlers triggered by template events (click, input, etc.)

## Template syntax

### New control flow (use for new code)

```html
<!-- @if / @else -->
@if (loading) {
  <mat-spinner />
} @else if (items.length === 0) {
  <div class="no-data">{{ 'common.noData' | translate }}</div>
} @else {
  <div class="items-grid">
    <!-- content -->
  </div>
}

<!-- @for with track -->
@for (item of items; track item.id) {
  <app-item-card
    [item]="item"
    [selected]="item.id === selectedId"
    (select)="onSelect($event)"
  />
} @empty {
  <div class="empty-state">{{ 'common.noResults' | translate }}</div>
}

<!-- @switch -->
@switch (status) {
  @case ('active') {
    <span class="badge badge--active">{{ 'status.active' | translate }}</span>
  }
  @case ('inactive') {
    <span class="badge badge--inactive">{{ 'status.inactive' | translate }}</span>
  }
  @default {
    <span class="badge">{{ status }}</span>
  }
}
```

### Async pipe pattern

```html
<!-- Observable binding -->
@if (items$ | async; as items) {
  @for (item of items; track item.id) {
    <div>{{ item.name }}</div>
  }
}

<!-- Multiple async streams -->
@if (vm$ | async; as vm) {
  <app-detail
    [entity]="vm.entity"
    [loading]="vm.loading"
    [error]="vm.error"
  />
}
```

## Material Design patterns

Applies when the project uses Angular Material; skip otherwise.

### Table

```html
<table mat-table class="mat-table-no-wrap" [dataSource]="datasource">
  <ng-container matColumnDef="name">
    <th mat-header-cell *matHeaderCellDef>{{ 'common.name' | translate }}</th>
    <td mat-cell *matCellDef="let element">
      <div [title]="element.name">{{ element.name }}</div>
    </td>
  </ng-container>

  <ng-container matColumnDef="status">
    <th mat-header-cell *matHeaderCellDef>{{ 'common.status' | translate }}</th>
    <td mat-cell *matCellDef="let element">
      <span [ngClass]="'status--' + element.status">{{ element.status }}</span>
    </td>
  </ng-container>

  <tr mat-header-row *matHeaderRowDef="displayedColumns"></tr>
  <tr mat-row *matRowDef="let row; columns: displayedColumns"
      (click)="onRowClick(row)"
      class="clickable-row">
  </tr>
</table>
```

### Form fields with select

```html
<mat-form-field>
  <mat-select
    multiple
    [matTooltip]="'filter.quality' | translate"
    [(ngModel)]="selectedValues"
    (selectionChange)="onFilterChange()"
  >
    @for (option of options | keyvalue; track option.value) {
      <mat-option [value]="option.value">
        {{ option.value }}
      </mat-option>
    }
  </mat-select>
</mat-form-field>
```

### Dialog

```typescript
// Open dialog
const dialogRef = this.dialog.open(ConfirmDialogComponent, {
  data: {
    title: 'Confirm Delete',
    message: 'Are you sure?',
  },
  width: '400px',
});

dialogRef.afterClosed().subscribe((confirmed) => {
  if (confirmed) {
    this.store.dispatch(Actions.Delete({ id }));
  }
});
```

### Buttons and icons

```html
<!-- Icon button -->
<button mat-icon-button [matTooltip]="'action.edit' | translate" (click)="onEdit()">
  <mat-icon>edit</mat-icon>
</button>

<!-- Raised button -->
<button mat-raised-button color="primary" (click)="onSave()" [disabled]="!isValid">
  {{ 'common.save' | translate }}
</button>

<!-- Icon with custom color -->
<mat-icon [ngStyle]="{ color: contextColor }">circle</mat-icon>
```

## Input/output patterns

### Traditional decorators

```typescript
@Input() items: Item[] = [];
@Input() selectedId: string | null = null;
@Input() mode: 'view' | 'edit' = 'view';

@Output() select = new EventEmitter<string>();
@Output() delete = new EventEmitter<string>();
```

### Observable inputs

```typescript
// Input as Observable (for header-style components)
@Input() columns: Observable<HeaderColumn[][]> = of([]);
@Input() buttons: Observable<ButtonDef[]> = of([]);
```

### Input with OnChanges

```typescript
@Input() templateId!: string;
@Input() filters!: FilterConfig;

ngOnChanges(changes: SimpleChanges): void {
  if (changes['templateId'] || changes['filters']) {
    this.fetchData();
  }
}
```

## Translation (i18n)

Applies when the project uses @ngx-translate (or an equivalent runtime i18n
layer). User-facing strings never appear hardcoded in templates.

```html
<!-- Pipe in template -->
{{ 'document.title' | translate }}

<!-- With params -->
{{ 'document.count' | translate: { count: items.length } }}

<!-- In attributes -->
[matTooltip]="'action.delete' | translate"
[title]="'common.name' | translate"
[placeholder]="'search.placeholder' | translate"
```

## Lifecycle management

```typescript
export class MyComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  ngOnInit(): void {
    // Subscribe with automatic cleanup
    this.store.select(selector)
      .pipe(takeUntil(this.destroy$))
      .subscribe((data) => { ... });

    // Multiple subscriptions all cleaned up via destroy$
    combineLatest([
      this.store.select(selectorA),
      this.store.select(selectorB),
    ]).pipe(
      takeUntil(this.destroy$),
    ).subscribe(([a, b]) => { ... });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

## Naming conventions

- **Selector prefix:** the project's declared prefix (e.g. `app-document-list`)
- **File naming:** `feature-name.component.ts/html/scss/spec.ts`
- **Class naming:** `FeatureNameComponent`
- **BEM SCSS:** `.app-feature-name__section__element` — with the project's own
  class prefix

## Base class inheritance

Use abstract base classes to share common behavior across similar components:

```typescript
// Abstract grid component
export abstract class AbstractServerSideGridComponent implements OnInit, OnDestroy {
  protected store = inject(Store);
  protected cdr = inject(ChangeDetectorRef);
  protected destroy$ = new Subject<void>();

  abstract gridApi: GridApi;
  abstract columnDefs: ColDef[];

  protected abstract fetchData(params: IServerSideGetRowsParams): void;

  onGridReady(params: GridReadyEvent): void {
    this.gridApi = params.api;
    this.gridApi.setGridOption('serverSideDatasource', {
      getRows: (params) => this.fetchData(params),
    });
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}

// Concrete implementation
@Component({
  selector: 'app-order-grid',
  templateUrl: './order-grid.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class OrderGridComponent extends AbstractServerSideGridComponent {
  gridApi!: GridApi;
  columnDefs: ColDef[] = [
    { field: 'reference', headerName: 'Reference' },
    { field: 'status', headerName: 'Status' },
    { field: 'category', headerName: 'Category' },
  ];

  protected fetchData(params: IServerSideGetRowsParams): void {
    this.store.dispatch(OrderActions.FetchOrders({
      startRow: params.request.startRow,
      endRow: params.request.endRow,
    }));
  }
}
```

## ag-Grid components

Applies when the project uses ag-Grid; skip otherwise.

### Custom cell renderer

```typescript
@Component({
  selector: 'app-status-cell',
  template: `
    <span [ngClass]="'status--' + params.value">
      {{ params.value }}
    </span>
  `,
  standalone: true,
  imports: [NgClass],
})
export class StatusCellRendererComponent implements ICellRendererAngularComp {
  params!: ICellRendererParams;

  agInit(params: ICellRendererParams): void {
    this.params = params;
  }

  refresh(params: ICellRendererParams): boolean {
    this.params = params;
    return true;
  }
}
```

### Grid configuration

```typescript
@Component({...})
export class DataGridComponent {
  defaultColDef: ColDef = {
    sortable: true,
    filter: true,
    resizable: true,
    minWidth: 100,
  };

  gridOptions: GridOptions = {
    rowModelType: 'serverSide',
    pagination: true,
    paginationPageSize: 50,
    cacheBlockSize: 50,
    animateRows: true,
    rowSelection: 'multiple',
  };

  columnDefs: ColDef[] = [
    {
      field: 'name',
      headerName: this.translate.instant('common.name'),
      flex: 1,
    },
    {
      field: 'status',
      headerName: this.translate.instant('common.status'),
      cellRenderer: StatusCellRendererComponent,
      width: 120,
    },
    {
      field: 'actions',
      headerName: '',
      cellRenderer: ActionsCellRendererComponent,
      width: 80,
      sortable: false,
      filter: false,
    },
  ];
}
```

## Dynamic component loading

### Using ViewContainerRef

```typescript
@Component({
  selector: 'app-dynamic-host',
  template: `<ng-container #container></ng-container>`,
})
export class DynamicHostComponent {
  @ViewChild('container', { read: ViewContainerRef }) container!: ViewContainerRef;

  loadComponent(component: Type<any>, data: any): void {
    this.container.clear();
    const ref = this.container.createComponent(component);
    ref.instance.data = data;
  }
}
```

### Using NgTemplateOutlet

```html
<!-- Template switching pattern -->
<ng-container [ngTemplateOutlet]="getTemplate()"></ng-container>

<ng-template #summary>
  <app-summary [data]="summaryData" />
</ng-template>

<ng-template #details>
  <app-details [data]="detailsData" />
</ng-template>

<ng-template #chart>
  <app-chart [data]="chartData" />
</ng-template>
```

```typescript
@ViewChild('summary') summaryTemplate!: TemplateRef<any>;
@ViewChild('details') detailsTemplate!: TemplateRef<any>;
@ViewChild('chart') chartTemplate!: TemplateRef<any>;

getTemplate(): TemplateRef<any> {
  switch (this.activeTab) {
    case 'summary': return this.summaryTemplate;
    case 'details': return this.detailsTemplate;
    case 'chart': return this.chartTemplate;
  }
}
```

## Complex layouts

### Tab-based layout

```html
<mat-tab-group (selectedTabChange)="onTabChange($event)">
  <mat-tab [label]="'tabs.overview' | translate">
    <ng-template matTabContent>
      <app-overview [entityId]="entityId" />
    </ng-template>
  </mat-tab>
  <mat-tab [label]="'tabs.items' | translate">
    <ng-template matTabContent>
      <app-item-list [entityId]="entityId" />
    </ng-template>
  </mat-tab>
</mat-tab-group>
```

### Header with actions

```html
<div class="app-page-header">
  <div class="app-page-header__title">
    <mat-icon [ngStyle]="{ color: contextColor }">{{ icon }}</mat-icon>
    <h2>{{ title }}</h2>
    <span class="app-page-header__badge" [ngClass]="'badge--' + status">
      {{ status | translate }}
    </span>
  </div>
  <div class="app-page-header__actions">
    @for (button of buttons; track button.id) {
      <button
        mat-icon-button
        [matTooltip]="button.tooltip | translate"
        (click)="button.click()"
        [disabled]="button.disabled"
      >
        <mat-icon>{{ button.icon }}</mat-icon>
      </button>
    }
  </div>
</div>
```

## SCSS patterns

Design tokens come from the project's shared style layer (see `styles.md`).

### Design token imports

```scss
@use 'src/assets/styles/typography';
@use 'src/assets/styles/spacing';
@use 'src/assets/styles/colors';
@use 'src/assets/styles/globals';
@use 'src/assets/styles/mixins';
```

### Host selector with BEM

```scss
:host {
  display: block;

  .app-feature-card {
    border-radius: globals.$border-radius;
    padding: globals.$margin-large;

    &__header {
      display: flex;
      align-items: center;
      gap: spacing.$space-md;

      &__title {
        font-size: typography.$font-size-lg;
        font-weight: typography.$font-weight-bold;
      }

      &__badge {
        border-radius: 12px;
        padding: spacing.$space-xs spacing.$space-sm;
        font-size: typography.$font-size-sm;
      }
    }

    &__body {
      margin-top: spacing.$space-lg;
    }

    &__actions {
      display: flex;
      justify-content: flex-end;
      gap: spacing.$space-sm;
    }
  }
}
```

### Material overrides

```scss
// Override Material component styles (use sparingly)
::ng-deep {
  .mat-mdc-form-field-subscript-wrapper {
    display: none;
  }

  .mat-mdc-tab-body-content {
    padding: globals.$margin-large;
  }
}

// Prefer :host ::ng-deep for scoped overrides
:host ::ng-deep .mat-mdc-dialog-content {
  max-height: 80vh;
}
```

### Responsive patterns

```scss
:host {
  .app-grid-layout {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: spacing.$space-lg;

    @media (max-width: 768px) {
      grid-template-columns: 1fr;
    }
  }
}
```

### Status colors

```scss
.status {
  &--active {
    color: colors.$color-success;
    background-color: rgba(colors.$color-success, 0.1);
  }

  &--inactive {
    color: colors.$color-neutral;
    background-color: rgba(colors.$color-neutral, 0.1);
  }

  &--error {
    color: colors.$color-error;
    background-color: rgba(colors.$color-error, 0.1);
  }
}
```

## Component communication

### Parent to child (input binding)

```html
<app-child
  [items]="filteredItems"
  [config]="gridConfig"
  [mode]="currentMode"
/>
```

### Child to parent (event emission)

```html
<!-- In child template -->
<button (click)="onAction()">Action</button>

<!-- In parent template -->
<app-child (action)="handleChildAction($event)" />
```

### Sibling communication via service

```typescript
@Injectable({ providedIn: 'root' })
export class SelectionService {
  private _selected = new BehaviorSubject<string | null>(null);
  readonly selected$ = this._selected.asObservable();

  select(id: string): void {
    this._selected.next(id);
  }

  clear(): void {
    this._selected.next(null);
  }
}
```

### ViewChild for direct access

```typescript
@ViewChild(ChildComponent) child!: ChildComponent;
@ViewChild('myInput') inputRef!: ElementRef<HTMLInputElement>;

onParentAction(): void {
  this.child.refresh();
  this.inputRef.nativeElement.focus();
}
```

## Testing components

### Smart component test

```typescript
describe('DocumentListComponent', () => {
  let component: DocumentListComponent;
  let fixture: ComponentFixture<DocumentListComponent>;
  let store: MockStore;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [DocumentListComponent],
      imports: [SharedModule],
      providers: [
        provideMockStore({
          selectors: [
            { selector: DocumentSelectors.selectDocuments, value: { items: [] } },
            { selector: DocumentSelectors.selectLoading, value: false },
          ],
        }),
      ],
    }).compileComponents();

    store = TestBed.inject(MockStore);
    fixture = TestBed.createComponent(DocumentListComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should dispatch fetch on init', () => {
    const dispatchSpy = spyOn(store, 'dispatch');
    component.ngOnInit();
    expect(dispatchSpy).toHaveBeenCalledWith(
      DocumentActions.FetchDocuments(jasmine.objectContaining({ page: 1 })),
    );
  });

  it('should display documents from store', () => {
    store.overrideSelector(DocumentSelectors.selectDocuments, {
      items: [{ id: '1', title: 'Document A' }],
    });
    store.refreshState();
    fixture.detectChanges();

    expect(component.documents.length).toBe(1);
  });
});
```

### Dumb component test

```typescript
describe('DocumentCardComponent', () => {
  let component: DocumentCardComponent;
  let fixture: ComponentFixture<DocumentCardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DocumentCardComponent], // Standalone
    }).compileComponents();

    fixture = TestBed.createComponent(DocumentCardComponent);
    component = fixture.componentInstance;
    component.document = { id: '1', title: 'Document A', status: 'active' };
    fixture.detectChanges();
  });

  it('should emit select event', () => {
    const selectSpy = spyOn(component.select, 'emit');
    component.onSelect();
    expect(selectSpy).toHaveBeenCalledWith('1');
  });

  it('should render document title', () => {
    const el = fixture.nativeElement.querySelector('.document-title');
    expect(el.textContent).toContain('Document A');
  });
});
```
