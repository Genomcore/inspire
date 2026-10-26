# NgRx state management

Applies when the project uses NgRx; skip otherwise. Redux-pattern reactive
state management: actions, reducers, selectors, effects, ComponentStore for
local state, persistence via meta-reducers, and NgRx tests.

## Actions (createAction)

### Basic actions

```typescript
import { createAction, props } from '@ngrx/store';

// Simple action (no payload)
export const ResetState = createAction('[Feature] Reset State');

// Action with props
export const LoadItems = createAction(
  '[Feature] Load Items',
  props<{ page: number; pageSize: number }>()
);
```

### Async action triplet (Request/Success/Error)

```typescript
// Standard async pattern
export const FetchDocuments = createAction(
  '[Documents] Fetch Documents',
  props<{ templateId: string; filters?: DocumentFilters }>()
);

export const FetchDocumentsSuccess = createAction(
  '[Documents] Fetch Documents Success',
  props<{ documents: Document[] }>()
);

export const FetchDocumentsError = createAction(
  '[Documents] Fetch Documents Error',
  props<{ error: HttpErrorResponse }>()
);
```

**Naming convention:** `[Domain] Action Name` with Request/Success/Error
suffixes for async operations.

## Reducers (createReducer)

### State interface and initial state

```typescript
export interface FeatureState {
  items: Item[];
  selectedId: string | null;
  loading: boolean;
  error: any | null;
}

export const initialState: FeatureState = {
  items: [],
  selectedId: null,
  loading: false,
  error: null,
};
```

### Reducer with on() handlers

```typescript
import { createReducer, on, Action } from '@ngrx/store';

const _featureReducer = createReducer(
  initialState,

  on(FeatureActions.FetchItems, (state) => ({
    ...state,
    loading: true,
    error: null,
  })),

  on(FeatureActions.FetchItemsSuccess, (state, { items }) => ({
    ...state,
    items,
    loading: false,
  })),

  on(FeatureActions.FetchItemsError, (state, { error }) => ({
    ...state,
    loading: false,
    error,
  })),

  on(FeatureActions.SelectItem, (state, { id }) => ({
    ...state,
    selectedId: id,
  })),

  // Reset on logout or context swap
  on(
    AuthActions.LogoutRequest,
    WorkspaceActions.SwapWorkspaceSuccess,
    () => initialState,
  ),
);

export const featureReducer = (state: FeatureState | undefined, action: Action) => {
  return _featureReducer(state, action);
};
```

### RequestType utility

For consistent async state tracking:

```typescript
export interface RequestType<T> {
  error: any | null;
  invalidated: boolean;
  loading: boolean;
  results: T[];
}

export const INIT_REQUEST: RequestType<any> = {
  error: null,
  invalidated: true,
  loading: false,
  results: [],
};
```

```typescript
// Usage in state
export interface RecordState {
  records: RequestType<Record>;
  recordsByTemplate: { [key: string]: RequestType<Record> };
}

export const initialState: RecordState = {
  records: INIT_REQUEST,
  recordsByTemplate: {},
};
```

## Selectors (createSelector)

### Feature selector

```typescript
import { createFeatureSelector, createSelector } from '@ngrx/store';

export const sliceName = 'Feature';

const selectFeatureState = createFeatureSelector<FeatureState>(sliceName);
```

### Basic selectors

```typescript
export const selectItems = createSelector(
  selectFeatureState,
  (state) => state.items,
);

export const selectLoading = createSelector(
  selectFeatureState,
  (state) => state.loading,
);

export const selectSelectedId = createSelector(
  selectFeatureState,
  (state) => state.selectedId,
);
```

### Composed selectors

```typescript
// Derive data from multiple selectors
export const selectSelectedItem = createSelector(
  selectItems,
  selectSelectedId,
  (items, selectedId) => items.find(item => item.id === selectedId) ?? null,
);

export const selectItemCount = createSelector(
  selectItems,
  (items) => items.length,
);
```

### Parameterized selectors (props-based)

```typescript
export const selectItemsByCategory = (props: { category: string }) =>
  createSelector(
    selectItems,
    (items) => items.filter(item => item.category === props.category),
  );

// Usage in component
this.store.select(selectItemsByCategory({ category: 'reports' }));
```

## Effects (createEffect)

### Standard effect pattern

```typescript
import { Injectable } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { catchError, map, mergeMap, of } from 'rxjs';

@Injectable()
export class FeatureEffects {
  constructor(
    private actions$: Actions,
    private featureService: FeatureService,
    private alertsService: AlertsService,
  ) {}

  fetchItems$ = createEffect(() => {
    return this.actions$.pipe(
      ofType(FeatureActions.FetchItems),
      mergeMap(({ page, pageSize }) =>
        this.featureService.getItems(page, pageSize).pipe(
          map((items) => FeatureActions.FetchItemsSuccess({ items })),
        ),
      ),
      catchError((error) => of(FeatureActions.FetchItemsError({ error }))),
    );
  });
}
```

### Non-dispatching effect (side effects)

```typescript
// Error notification effect
fetchItemsError$ = createEffect(
  () => {
    return this.actions$.pipe(
      ofType(FeatureActions.FetchItemsError),
      map(({ error }) => {
        this.alertsService.showAlertInSnackbar(error.message);
      }),
    );
  },
  { dispatch: false },
);
```

### Effect with store access

```typescript
updateItem$ = createEffect(() => {
  return this.actions$.pipe(
    ofType(FeatureActions.UpdateItem),
    switchMap(({ id, changes }) =>
      this.store.select(selectSelectedItem).pipe(
        first(),
        switchMap((item) =>
          this.featureService.update(id, { ...item, ...changes }).pipe(
            map((updated) => FeatureActions.UpdateItemSuccess({ item: updated })),
            catchError((error) => of(FeatureActions.UpdateItemError({ error }))),
          ),
        ),
      ),
    ),
  );
});
```

### Effect with dialog

```typescript
showError$ = createEffect(
  () => {
    return this.actions$.pipe(
      ofType(FeatureActions.CriticalError),
      map(({ error }) => {
        if (error?.printable) {
          this.dialog.open(ErrorDialogComponent, {
            data: { message: error.message },
          });
        }
      }),
    );
  },
  { dispatch: false },
);
```

**Operator guidelines:**
- `mergeMap` — independent parallel operations
- `switchMap` — cancel previous on new request (search, navigation)
- `concatMap` — sequential order matters (create, update)
- `exhaustMap` — ignore new until current completes (login, submit)

## ComponentStore (local state)

For component-scoped state management:

```typescript
import { ComponentStore } from '@ngrx/component-store';
import { Injectable } from '@angular/core';
import { Observable, switchMap, tap } from 'rxjs';

interface DetailState {
  entity: Entity | null;
  loading: boolean;
  error: string | null;
}

@Injectable()
export class DetailStore extends ComponentStore<DetailState> {
  constructor(private apiService: ApiService) {
    super({
      entity: null,
      loading: false,
      error: null,
    });
  }

  // Selectors
  readonly entity$ = this.select((state) => state.entity);
  readonly loading$ = this.select((state) => state.loading);
  readonly error$ = this.select((state) => state.error);

  // Composed selector
  readonly vm$ = this.select(
    this.entity$,
    this.loading$,
    this.error$,
    (entity, loading, error) => ({ entity, loading, error }),
  );

  // Updaters
  readonly setEntity = this.updater((state, entity: Entity) => ({
    ...state,
    entity,
    loading: false,
  }));

  readonly setLoading = this.updater((state, loading: boolean) => ({
    ...state,
    loading,
  }));

  // Effects
  readonly loadEntity = this.effect((id$: Observable<string>) =>
    id$.pipe(
      tap(() => this.setLoading(true)),
      switchMap((id) =>
        this.apiService.getById(id).pipe(
          tap({
            next: (res) => {
              if (res.success) {
                this.setEntity(res.data);
              } else {
                this.patchState({ error: res.message, loading: false });
              }
            },
            error: (err) => {
              this.patchState({ error: err.message, loading: false });
            },
          }),
        ),
      ),
    ),
  );
}
```

### Using ComponentStore in components

```typescript
@Component({
  selector: 'app-entity-detail',
  providers: [DetailStore], // New instance per component
  template: `
    @if (vm$ | async; as vm) {
      @if (vm.loading) {
        <mat-spinner />
      } @else if (vm.entity) {
        <div>{{ vm.entity.name }}</div>
      } @else if (vm.error) {
        <div class="error">{{ vm.error }}</div>
      }
    }
  `,
})
export class EntityDetailComponent implements OnInit {
  private store = inject(DetailStore);

  vm$ = this.store.vm$;

  ngOnInit(): void {
    this.store.loadEntity(this.entityId);
  }
}
```

## Store registration

### Feature store module

```typescript
import { StoreModule } from '@ngrx/store';
import { EffectsModule } from '@ngrx/effects';

@NgModule({
  imports: [
    StoreModule.forFeature('Feature', featureReducer),
    EffectsModule.forFeature([FeatureEffects]),
  ],
})
export class FeatureStoreModule {}
```

### Root store with meta-reducers

```typescript
@NgModule({
  imports: [
    StoreModule.forRoot(
      {},
      {
        runtimeChecks: {
          strictStateImmutability: false,
          strictActionImmutability: false,
          strictStateSerializability: false,
          strictActionSerializability: false,
        },
        metaReducers: getMetaReducers(localStorageService),
      },
    ),
    EffectsModule.forRoot([]),
    // Feature stores imported here
    FeatureStoreModule,
  ],
})
export class RootStoreModule {}
```

## Component usage

### Dispatching actions

```typescript
@Component({...})
export class FeatureListComponent implements OnInit, OnDestroy {
  private store = inject(Store);
  private destroy$ = new Subject<void>();

  items: Item[] = [];
  loading = false;

  ngOnInit(): void {
    this.store
      .select(FeatureSelectors.selectItems)
      .pipe(takeUntil(this.destroy$))
      .subscribe((items) => {
        this.items = items;
      });

    this.store.dispatch(FeatureActions.FetchItems({ page: 1, pageSize: 20 }));
  }

  onSelect(id: string): void {
    this.store.dispatch(FeatureActions.SelectItem({ id }));
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

## localStorage persistence

Persist specific state slices to localStorage using meta-reducers:

```typescript
import { ActionReducer } from '@ngrx/store';

export const persisterFactory = (
  key: string,
  persistItems: string[],
  localStorageService: LocalStorageService,
) => {
  return (reducer: ActionReducer<any>): ActionReducer<any> => {
    let init = true;
    return (state, action) => {
      const next = reducer(state, action);

      if (init || action.type === LocalStorageChanged.type) {
        init = false;
        if (Object.keys(next).includes(key)) {
          // Hydrate from localStorage on init
          next[key] = { ...next[key], ...localStorageService.retrieve(key) };
        }
        return { ...next };
      }

      // Persist specific properties to localStorage
      localStorageService.store(
        key,
        Object.entries(next[key]).reduce((acc, [k, v]) => {
          if (persistItems.includes(k)) {
            acc[k] = v;
          }
          return acc;
        }, {} as Record<string, any>),
      );

      return { ...next };
    };
  };
};
```

### Registering persistence

```typescript
// In state file, define which keys to persist
export const localStorageValues = ['session', 'preferences'];

// In root store module
export const getMetaReducers = (localStorageService: LocalStorageService) => {
  return [
    persisterFactory(
      AuthSelectors.sliceName,
      AuthStates.localStorageValues,
      localStorageService,
    ),
    persisterFactory(
      WorkspaceSelectors.sliceName,
      WorkspaceStates.localStorageValues,
      localStorageService,
    ),
  ];
};
```

## Meta-reducers

Meta-reducers wrap existing reducers with additional behavior:

```typescript
// Logging meta-reducer
export function logger(reducer: ActionReducer<any>): ActionReducer<any> {
  return (state, action) => {
    console.group(action.type);
    console.log('prev state', state);
    console.log('action', action);
    const nextState = reducer(state, action);
    console.log('next state', nextState);
    console.groupEnd();
    return nextState;
  };
}

// Conditional meta-reducer (dev only)
export const metaReducers = !environment.production ? [logger] : [];
```

### Reset state meta-reducer

```typescript
export function resetState(reducer: ActionReducer<any>): ActionReducer<any> {
  return (state, action) => {
    if (action.type === AuthActions.LogoutRequest.type) {
      // Reset entire app state on logout
      return reducer(undefined, action);
    }
    return reducer(state, action);
  };
}
```

## Entity merging

Custom utility for intelligent entity merging when the same entity arrives at
different levels of detail (a list fetch vs a detail fetch):

```typescript
export enum InfoLevel {
  Join = 'join',
  Full = 'full',
}

export function mergeEntities<T extends { id: string; info_level?: InfoLevel }>(
  left: T[],
  right: T[],
): T[] {
  const map = new Map<string, T>();

  // Add left entities
  for (const entity of left) {
    map.set(entity.id, {
      ...entity,
      info_level: entity.info_level ?? InfoLevel.Join,
      is_synced: true,
    });
  }

  // Merge right entities, preferring higher info_level
  for (const entity of right) {
    const existing = map.get(entity.id);
    if (!existing || infoLevelRank(entity.info_level) >= infoLevelRank(existing.info_level)) {
      map.set(entity.id, { ...entity, is_synced: true });
    }
  }

  return Array.from(map.values());
}

function infoLevelRank(level?: InfoLevel): number {
  switch (level) {
    case InfoLevel.Full: return 2;
    case InfoLevel.Join: return 1;
    default: return 0;
  }
}
```

### Usage in reducers

```typescript
on(RecordActions.FetchRecordsSuccess, (state, { records }) => ({
  ...state,
  records: {
    ...state.records,
    results: mergeEntities(state.records.results, records),
    loading: false,
    invalidated: false,
  },
})),
```

## Cross-tab synchronization

Sync state across browser tabs using storage events:

```typescript
// Action for cross-tab updates
export const LocalStorageChanged = createAction('[App] LocalStorage Changed');

// In root store module
@NgModule({...})
export class RootStoreModule {
  constructor(private store: Store) {
    // Listen for storage changes from other tabs
    window.addEventListener('storage', (event) => {
      if (event.key && ['Auth', 'Workspace'].includes(event.key)) {
        this.store.dispatch(LocalStorageChanged());
      }
    });
  }
}
```

## Action tracking in ComponentStore

Track loading/success/error states for multiple operations:

```typescript
interface ActionState {
  loading: boolean;
  error: boolean;
  success: boolean;
  message?: string;
}

interface DetailState {
  entity: Entity | null;
  GET_ENTITY: ActionState;
  UPDATE_ENTITY: ActionState;
  DELETE_ENTITY: ActionState;
}

@Injectable()
export class DetailStore extends ComponentStore<DetailState> {
  constructor(private api: ApiService) {
    super({
      entity: null,
      GET_ENTITY: { loading: false, error: false, success: false },
      UPDATE_ENTITY: { loading: false, error: false, success: false },
      DELETE_ENTITY: { loading: false, error: false, success: false },
    });
  }

  // Action state updaters
  readonly setGetEntityAction = this.updater(
    (state, action: Partial<ActionState>) => ({
      ...state,
      GET_ENTITY: { ...state.GET_ENTITY, ...action },
    }),
  );

  // Effect with action tracking
  readonly getEntity = this.effect((id$: Observable<string>) =>
    id$.pipe(
      tap(() => this.setGetEntityAction({ loading: true, error: false, success: false })),
      switchMap((id) =>
        this.api.getById(id).pipe(
          tap({
            next: (res) => {
              if (res.success) {
                this.patchState({ entity: res.data });
                this.setGetEntityAction({ loading: false, success: true, message: res.message });
              } else {
                this.setGetEntityAction({ loading: false, error: true, message: res.message });
              }
            },
            error: (err) => {
              this.setGetEntityAction({ loading: false, error: true, message: err.message });
            },
          }),
        ),
      ),
    ),
  );
}
```

## Multiple feature stores composition

Combine selectors from different feature stores:

```typescript
// Cross-store selector
export const selectRecordWithTemplate = createSelector(
  RecordSelectors.selectChosenRecord,
  TemplateSelectors.selectTemplates,
  (record, templates) => {
    if (!record) return null;
    const template = templates.find(t => t.id === record.templateId);
    return { ...record, template };
  },
);

// In effects - reading from multiple stores
navigateToRecord$ = createEffect(() => {
  return this.actions$.pipe(
    ofType(RecordActions.SelectRecord),
    withLatestFrom(
      this.store.select(WorkspaceSelectors.selectCurrentWorkspace),
      this.store.select(AuthSelectors.selectAccount),
    ),
    map(([{ recordId }, workspace, account]) => {
      this.router.navigate([
        '/accounts', account.id,
        '/workspaces', workspace.id,
        '/records', recordId,
      ]);
    }),
  );
}, { dispatch: false });
```

## Keyed state (dynamic collections)

Manage collections keyed by dynamic identifiers:

```typescript
interface FeatureState {
  itemsByCategory: { [category: string]: RequestType<Item> };
}

const initialState: FeatureState = {
  itemsByCategory: {},
};

// Reducer
on(FeatureActions.FetchItemsByCategorySuccess, (state, { category, items }) => ({
  ...state,
  itemsByCategory: {
    ...state.itemsByCategory,
    [category]: {
      results: items,
      loading: false,
      error: null,
      invalidated: false,
    },
  },
})),

// Selector
export const selectItemsByCategory = (props: { category: string }) =>
  createSelector(
    selectFeatureState,
    (state) => state.itemsByCategory[props.category] ?? INIT_REQUEST,
  );
```

## Testing NgRx

### Testing reducers

```typescript
describe('featureReducer', () => {
  it('should set loading on fetch', () => {
    const action = FeatureActions.FetchItems({ page: 1, pageSize: 20 });
    const state = featureReducer(initialState, action);

    expect(state.loading).toBe(true);
    expect(state.error).toBeNull();
  });

  it('should set items on success', () => {
    const items = [{ id: '1', name: 'Test' }];
    const action = FeatureActions.FetchItemsSuccess({ items });
    const state = featureReducer(initialState, action);

    expect(state.items).toEqual(items);
    expect(state.loading).toBe(false);
  });

  it('should reset on logout', () => {
    const loadedState = { ...initialState, items: [{ id: '1' }], loading: true };
    const action = AuthActions.LogoutRequest();
    const state = featureReducer(loadedState, action);

    expect(state).toEqual(initialState);
  });
});
```

### Testing selectors

```typescript
describe('Feature Selectors', () => {
  const state: FeatureState = {
    items: [
      { id: '1', name: 'A', category: 'reports' },
      { id: '2', name: 'B', category: 'records' },
    ],
    selectedId: '1',
    loading: false,
    error: null,
  };

  it('should select items', () => {
    const result = selectItems.projector(state);
    expect(result.length).toBe(2);
  });

  it('should select selected item', () => {
    const result = selectSelectedItem.projector(state.items, state.selectedId);
    expect(result?.name).toBe('A');
  });

  it('should select items by category', () => {
    const selector = selectItemsByCategory({ category: 'reports' });
    const result = selector.projector(state);
    expect(result.length).toBe(1);
  });
});
```

### Testing effects

```typescript
describe('FeatureEffects', () => {
  let effects: FeatureEffects;
  let actions$: Observable<any>;
  let featureService: jasmine.SpyObj<FeatureService>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        FeatureEffects,
        provideMockActions(() => actions$),
        {
          provide: FeatureService,
          useValue: jasmine.createSpyObj('FeatureService', ['getItems']),
        },
        {
          provide: AlertsService,
          useValue: jasmine.createSpyObj('AlertsService', ['showAlertInSnackbar']),
        },
      ],
    });

    effects = TestBed.inject(FeatureEffects);
    featureService = TestBed.inject(FeatureService) as jasmine.SpyObj<FeatureService>;
  });

  it('should dispatch success on fetch', () => {
    const items = [{ id: '1', name: 'Test' }];
    featureService.getItems.and.returnValue(of(items));

    actions$ = hot('-a', { a: FeatureActions.FetchItems({ page: 1, pageSize: 20 }) });
    const expected = cold('-b', { b: FeatureActions.FetchItemsSuccess({ items }) });

    expect(effects.fetchItems$).toBeObservable(expected);
  });
});
```

### Testing ComponentStore

```typescript
describe('DetailStore', () => {
  let store: DetailStore;
  let apiService: jasmine.SpyObj<ApiService>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        DetailStore,
        {
          provide: ApiService,
          useValue: jasmine.createSpyObj('ApiService', ['getById']),
        },
      ],
    });

    store = TestBed.inject(DetailStore);
    apiService = TestBed.inject(ApiService) as jasmine.SpyObj<ApiService>;
  });

  it('should load entity', (done) => {
    const entity = { id: '1', name: 'Test' };
    apiService.getById.and.returnValue(of({ success: true, data: entity }));

    store.entity$.subscribe((result) => {
      if (result) {
        expect(result).toEqual(entity);
        done();
      }
    });

    store.loadEntity('1');
  });
});
```
