# Testing

Unit and integration testing with Jasmine + TestBed (Karma runner), CDK
component harnesses, signal-based component tests, and E2E with Playwright.
Where the project adopts Cypress component testing, its conventions are in
the last section.

## Basic component test

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Counter } from './counter.component';

describe('Counter', () => {
  let component: Counter;
  let fixture: ComponentFixture<Counter>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Counter], // Standalone component
    }).compileComponents();

    fixture = TestBed.createComponent(Counter);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should increment count', () => {
    expect(component.count()).toBe(0);

    component.increment();

    expect(component.count()).toBe(1);
  });

  it('should display count in template', () => {
    component.count.set(5);
    fixture.detectChanges();

    const element = fixture.nativeElement.querySelector('.count');
    expect(element.textContent).toContain('5');
  });
});
```

## Testing signals

### Direct signal testing

```typescript
import { signal, computed } from '@angular/core';

describe('Signal logic', () => {
  it('should update computed when signal changes', () => {
    const count = signal(0);
    const doubled = computed(() => count() * 2);

    expect(doubled()).toBe(0);

    count.set(5);
    expect(doubled()).toBe(10);

    count.update(c => c + 1);
    expect(doubled()).toBe(12);
  });
});
```

### Testing component signals

```typescript
@Component({
  selector: 'app-todo-list',
  template: `
    <ul>
      @for (todo of filteredTodos(); track todo.id) {
        <li>{{ todo.text }}</li>
      }
    </ul>
    <p>{{ remaining() }} remaining</p>
  `,
})
export class TodoList {
  todos = signal<Todo[]>([]);
  filter = signal<'all' | 'active' | 'done'>('all');

  filteredTodos = computed(() => {
    const todos = this.todos();
    switch (this.filter()) {
      case 'active': return todos.filter(t => !t.done);
      case 'done': return todos.filter(t => t.done);
      default: return todos;
    }
  });

  remaining = computed(() => this.todos().filter(t => !t.done).length);
}

describe('TodoList', () => {
  let component: TodoList;
  let fixture: ComponentFixture<TodoList>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TodoList],
    }).compileComponents();

    fixture = TestBed.createComponent(TodoList);
    component = fixture.componentInstance;
  });

  it('should filter active todos', () => {
    component.todos.set([
      { id: '1', text: 'Task 1', done: false },
      { id: '2', text: 'Task 2', done: true },
      { id: '3', text: 'Task 3', done: false },
    ]);

    component.filter.set('active');

    expect(component.filteredTodos().length).toBe(2);
    expect(component.remaining()).toBe(2);
  });

  it('should render filtered todos', () => {
    component.todos.set([
      { id: '1', text: 'Active Task', done: false },
      { id: '2', text: 'Done Task', done: true },
    ]);
    component.filter.set('active');
    fixture.detectChanges();

    const items = fixture.nativeElement.querySelectorAll('li');
    expect(items.length).toBe(1);
    expect(items[0].textContent).toContain('Active Task');
  });
});
```

## Testing OnPush components

OnPush components require explicit change detection:

```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<span>{{ data().name }}</span>`,
})
export class OnPushCmpt {
  data = input.required<{ name: string }>();
}

describe('OnPushCmpt', () => {
  it('should update when input signal changes', () => {
    const fixture = TestBed.createComponent(OnPushCmpt);

    // Set input using setInput (for signal inputs)
    fixture.componentRef.setInput('data', { name: 'Initial' });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Initial');

    // Update input
    fixture.componentRef.setInput('data', { name: 'Updated' });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Updated');
  });
});
```

## Testing services

### Basic service test

```typescript
import { TestBed } from '@angular/core/testing';

@Injectable({ providedIn: 'root' })
export class CounterSvc {
  private _count = signal(0);
  readonly count = this._count.asReadonly();

  increment() {
    this._count.update(c => c + 1);
  }

  reset() {
    this._count.set(0);
  }
}

describe('CounterSvc', () => {
  let service: CounterSvc;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(CounterSvc);
  });

  it('should increment count', () => {
    expect(service.count()).toBe(0);

    service.increment();
    expect(service.count()).toBe(1);

    service.increment();
    expect(service.count()).toBe(2);
  });

  it('should reset count', () => {
    service.increment();
    service.increment();

    service.reset();

    expect(service.count()).toBe(0);
  });
});
```

### Service with HTTP dependencies

```typescript
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';

@Injectable({ providedIn: 'root' })
export class UserService {
  private http = inject(HttpClient);

  getUser(id: string) {
    return this.http.get<User>(`/api/users/${id}`);
  }
}

describe('UserService', () => {
  let service: UserService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
      ],
    });

    service = TestBed.inject(UserService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify(); // Verify no outstanding requests
  });

  it('should fetch user by id', () => {
    const mockUser: User = { id: '1', name: 'Test User' };

    service.getUser('1').subscribe(user => {
      expect(user).toEqual(mockUser);
    });

    const req = httpMock.expectOne('/api/users/1');
    expect(req.request.method).toBe('GET');
    req.flush(mockUser);
  });
});
```

## Mocking dependencies

### Using Jasmine spies

```typescript
describe('ComponentWithDependency', () => {
  let userServiceSpy: jasmine.SpyObj<UserService>;

  beforeEach(async () => {
    userServiceSpy = jasmine.createSpyObj('UserService', ['getUser', 'updateUser']);
    userServiceSpy.getUser.and.returnValue(of({ id: '1', name: 'Test' }));

    await TestBed.configureTestingModule({
      imports: [UserProfile],
      providers: [
        { provide: UserService, useValue: userServiceSpy },
      ],
    }).compileComponents();
  });

  it('should call getUser on init', () => {
    const fixture = TestBed.createComponent(UserProfile);
    fixture.detectChanges();

    expect(userServiceSpy.getUser).toHaveBeenCalledWith('1');
  });
});
```

### Mock signal-based service

```typescript
// Create mock with signal
const mockAuth = {
  user: signal<User | null>(null),
  isAuthenticated: computed(() => mockAuth.user() !== null),
  login: jasmine.createSpy('login'),
  logout: jasmine.createSpy('logout'),
};

beforeEach(async () => {
  await TestBed.configureTestingModule({
    imports: [ProtectedCmpt],
    providers: [
      { provide: AuthService, useValue: mockAuth },
    ],
  }).compileComponents();
});

it('should show content when authenticated', () => {
  mockAuth.user.set({ id: '1', name: 'Test User' });

  const fixture = TestBed.createComponent(ProtectedCmpt);
  fixture.detectChanges();

  expect(fixture.nativeElement.querySelector('.protected-content')).toBeTruthy();
});
```

## Testing inputs and outputs

```typescript
@Component({
  selector: 'app-item',
  template: `
    <div (click)="select()">{{ item().name }}</div>
  `,
})
export class ItemCmpt {
  item = input.required<Item>();
  selected = output<Item>();

  select() {
    this.selected.emit(this.item());
  }
}

describe('ItemCmpt', () => {
  it('should emit selected event on click', () => {
    const fixture = TestBed.createComponent(ItemCmpt);
    const item: Item = { id: '1', name: 'Test Item' };

    fixture.componentRef.setInput('item', item);
    fixture.detectChanges();

    // Subscribe to output
    let emittedItem: Item | undefined;
    fixture.componentInstance.selected.subscribe(i => emittedItem = i);

    // Trigger click
    fixture.nativeElement.querySelector('div').click();

    expect(emittedItem).toEqual(item);
  });
});
```

## Testing async operations

### Using fakeAsync

```typescript
import { fakeAsync, tick, flush } from '@angular/core/testing';

it('should debounce search', fakeAsync(() => {
  const fixture = TestBed.createComponent(SearchCmpt);
  fixture.detectChanges();

  // Type in search
  fixture.componentInstance.query.set('test');

  // Advance time for debounce
  tick(300);
  fixture.detectChanges();

  expect(fixture.componentInstance.results().length).toBeGreaterThan(0);

  // Flush any remaining timers
  flush();
}));
```

### Using waitForAsync

```typescript
import { waitForAsync } from '@angular/core/testing';

it('should load data', waitForAsync(() => {
  const fixture = TestBed.createComponent(DataCmpt);
  fixture.detectChanges();

  fixture.whenStable().then(() => {
    fixture.detectChanges();
    expect(fixture.componentInstance.data()).toBeDefined();
  });
}));
```

## Component harnesses

Use Angular CDK component harnesses for more maintainable tests.

### Creating a harness

```typescript
import { ComponentHarness, HarnessPredicate } from '@angular/cdk/testing';

export class CounterHarness extends ComponentHarness {
  static hostSelector = 'app-counter';

  // Locators
  private getIncrementButton = this.locatorFor('button.increment');
  private getDecrementButton = this.locatorFor('button.decrement');
  private getCountDisplay = this.locatorFor('.count');

  // Actions
  async increment(): Promise<void> {
    const button = await this.getIncrementButton();
    await button.click();
  }

  async decrement(): Promise<void> {
    const button = await this.getDecrementButton();
    await button.click();
  }

  // Queries
  async getCount(): Promise<number> {
    const display = await this.getCountDisplay();
    const text = await display.text();
    return parseInt(text, 10);
  }

  // Filter factory
  static with(options: { count?: number } = {}): HarnessPredicate<CounterHarness> {
    return new HarnessPredicate(CounterHarness, options)
      .addOption('count', options.count, async (harness, count) => {
        return (await harness.getCount()) === count;
      });
  }
}
```

### Using harnesses in tests

```typescript
import { TestbedHarnessEnvironment } from '@angular/cdk/testing/testbed';
import { HarnessLoader } from '@angular/cdk/testing';

describe('Counter with Harness', () => {
  let loader: HarnessLoader;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Counter],
    }).compileComponents();

    const fixture = TestBed.createComponent(Counter);
    loader = TestbedHarnessEnvironment.loader(fixture);
  });

  it('should increment count', async () => {
    const counter = await loader.getHarness(CounterHarness);

    expect(await counter.getCount()).toBe(0);

    await counter.increment();
    expect(await counter.getCount()).toBe(1);

    await counter.increment();
    expect(await counter.getCount()).toBe(2);
  });

  it('should find counter with specific count', async () => {
    const counter = await loader.getHarness(CounterHarness);
    await counter.increment();
    await counter.increment();

    // Find counter with count of 2
    const counterWith2 = await loader.getHarness(CounterHarness.with({ count: 2 }));
    expect(counterWith2).toBeTruthy();
  });
});
```

## Testing the router

### RouterTestingHarness

```typescript
import { RouterTestingHarness } from '@angular/router/testing';
import { provideRouter } from '@angular/router';

describe('Router Navigation', () => {
  let harness: RouterTestingHarness;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', component: HomeCmpt },
          { path: 'users/:id', component: UserCmpt },
        ]),
      ],
    }).compileComponents();

    harness = await RouterTestingHarness.create();
  });

  it('should navigate to user page', async () => {
    const component = await harness.navigateByUrl('/users/123', UserCmpt);

    expect(component.id()).toBe('123');
  });

  it('should display user name', async () => {
    await harness.navigateByUrl('/users/123');

    expect(harness.routeNativeElement?.textContent).toContain('User 123');
  });
});
```

### Testing guards

```typescript
describe('AuthGuard', () => {
  let authService: jasmine.SpyObj<AuthService>;

  beforeEach(() => {
    authService = jasmine.createSpyObj('AuthService', ['isAuthenticated']);

    TestBed.configureTestingModule({
      providers: [
        { provide: AuthService, useValue: authService },
        provideRouter([
          { path: 'login', component: LoginCmpt },
          {
            path: 'dashboard',
            component: DashboardCmpt,
            canActivate: [authGuard],
          },
        ]),
      ],
    });
  });

  it('should allow access when authenticated', async () => {
    authService.isAuthenticated.and.returnValue(true);

    const harness = await RouterTestingHarness.create();
    await harness.navigateByUrl('/dashboard');

    expect(harness.routeNativeElement?.textContent).toContain('Dashboard');
  });

  it('should redirect to login when not authenticated', async () => {
    authService.isAuthenticated.and.returnValue(false);

    const harness = await RouterTestingHarness.create();
    await harness.navigateByUrl('/dashboard');

    expect(TestBed.inject(Router).url).toBe('/login');
  });
});
```

## Testing forms

### Testing reactive forms

```typescript
describe('ProfileForm', () => {
  let component: ProfileForm;
  let fixture: ComponentFixture<ProfileForm>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ProfileForm],
    }).compileComponents();

    fixture = TestBed.createComponent(ProfileForm);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should be invalid when empty', () => {
    expect(component.form.valid).toBeFalse();
  });

  it('should validate form with correct data', () => {
    component.form.patchValue({
      name: 'John',
      email: 'john@example.com',
    });

    expect(component.form.valid).toBeTrue();
  });

  it('should show validation errors', () => {
    const emailControl = component.form.controls.email;
    emailControl.setValue('invalid');
    emailControl.markAsTouched();
    fixture.detectChanges();

    const errorElement = fixture.nativeElement.querySelector('.error');
    expect(errorElement.textContent).toContain('Invalid email');
  });

  it('should disable submit button when invalid', () => {
    const button = fixture.nativeElement.querySelector('button[type="submit"]');
    expect(button.disabled).toBeTrue();
  });

  it('should submit form with valid data', () => {
    spyOn(component, 'onSubmit');

    component.form.patchValue({
      name: 'John',
      email: 'john@example.com',
    });
    fixture.detectChanges();

    const form = fixture.nativeElement.querySelector('form');
    form.dispatchEvent(new Event('submit'));

    expect(component.onSubmit).toHaveBeenCalled();
  });
});
```

### Testing FormArray

```typescript
describe('OrderForm', () => {
  it('should add and remove items', () => {
    const fixture = TestBed.createComponent(OrderForm);
    const component = fixture.componentInstance;
    fixture.detectChanges();

    expect(component.items.length).toBe(1);

    component.addItem();
    expect(component.items.length).toBe(2);

    component.removeItem(0);
    expect(component.items.length).toBe(1);
  });

  it('should validate items', () => {
    const fixture = TestBed.createComponent(OrderForm);
    const component = fixture.componentInstance;

    component.items.at(0).patchValue({ product: '', quantity: 0 });

    expect(component.items.at(0).valid).toBeFalse();

    component.items.at(0).patchValue({ product: 'Widget', quantity: 1 });

    expect(component.items.at(0).valid).toBeTrue();
  });
});
```

### Testing custom ControlValueAccessor

```typescript
describe('RatingComponent', () => {
  @Component({
    imports: [ReactiveFormsModule, RatingComponent],
    template: `<app-rating [formControl]="ratingControl"></app-rating>`,
  })
  class TestHost {
    ratingControl = new FormControl(0);
  }

  it('should update form control on click', () => {
    const fixture = TestBed.createComponent(TestHost);
    fixture.detectChanges();

    const stars = fixture.nativeElement.querySelectorAll('mat-icon');
    stars[2].click(); // Click 3rd star
    fixture.detectChanges();

    expect(fixture.componentInstance.ratingControl.value).toBe(3);
  });

  it('should reflect form control value', () => {
    const fixture = TestBed.createComponent(TestHost);
    fixture.componentInstance.ratingControl.setValue(4);
    fixture.detectChanges();

    const component = fixture.debugElement.query(
      By.directive(RatingComponent)
    ).componentInstance;

    expect(component.value).toBe(4);
  });

  it('should be disabled when control is disabled', () => {
    const fixture = TestBed.createComponent(TestHost);
    fixture.componentInstance.ratingControl.disable();
    fixture.detectChanges();

    const component = fixture.debugElement.query(
      By.directive(RatingComponent)
    ).componentInstance;

    expect(component.disabled).toBeTrue();
  });
});
```

## Testing directives

### Attribute directive

```typescript
@Directive({
  selector: '[appHighlight]',
  host: {
    '[style.backgroundColor]': 'color()',
  },
})
export class HighlightDirective {
  color = input('yellow', { alias: 'appHighlight' });
}

describe('HighlightDirective', () => {
  @Component({
    imports: [HighlightDirective],
    template: `<p appHighlight="lightblue">Test</p>`,
  })
  class TestHost {}

  it('should apply background color', () => {
    const fixture = TestBed.createComponent(TestHost);
    fixture.detectChanges();

    const p = fixture.nativeElement.querySelector('p');
    expect(p.style.backgroundColor).toBe('lightblue');
  });
});
```

### Structural directive

```typescript
@Directive({
  selector: '[appIf]',
})
export class IfDirective {
  private templateRef = inject(TemplateRef);
  private viewContainer = inject(ViewContainerRef);

  @Input() set appIf(condition: boolean) {
    if (condition) {
      this.viewContainer.createEmbeddedView(this.templateRef);
    } else {
      this.viewContainer.clear();
    }
  }
}

describe('IfDirective', () => {
  @Component({
    imports: [IfDirective],
    template: `<p *appIf="show">Visible</p>`,
  })
  class TestHost {
    show = false;
  }

  it('should show content when condition is true', () => {
    const fixture = TestBed.createComponent(TestHost);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('p')).toBeNull();

    fixture.componentInstance.show = true;
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('p')).toBeTruthy();
  });
});
```

## Testing pipes

```typescript
@Pipe({ name: 'truncate' })
export class TruncatePipe implements PipeTransform {
  transform(value: string, length: number = 50): string {
    if (value.length <= length) return value;
    return value.substring(0, length) + '...';
  }
}

describe('TruncatePipe', () => {
  let pipe: TruncatePipe;

  beforeEach(() => {
    pipe = new TruncatePipe();
  });

  it('should not truncate short strings', () => {
    expect(pipe.transform('Hello', 10)).toBe('Hello');
  });

  it('should truncate long strings', () => {
    expect(pipe.transform('Hello World', 5)).toBe('Hello...');
  });

  it('should use default length', () => {
    const longString = 'a'.repeat(60);
    const result = pipe.transform(longString);
    expect(result.length).toBe(53); // 50 + '...'
  });
});
```

## Test utilities

### Custom test helpers

```typescript
// test-utils.ts
export function setSignalInput<T>(
  fixture: ComponentFixture<any>,
  inputName: string,
  value: T
): void {
  fixture.componentRef.setInput(inputName, value);
  fixture.detectChanges();
}

export async function waitForSignal<T>(
  signalFn: () => T,
  predicate: (value: T) => boolean,
  timeout = 5000
): Promise<T> {
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const value = signalFn();
    if (predicate(value)) return value;
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  throw new Error('Timeout waiting for signal');
}

// Usage
it('should load data', async () => {
  const fixture = TestBed.createComponent(DataCmpt);
  fixture.detectChanges();

  await waitForSignal(
    () => fixture.componentInstance.data(),
    data => data !== undefined
  );

  expect(fixture.componentInstance.data()).toBeDefined();
});
```

### Test fixtures / factories

Use factory functions so each test sets only the significant fields:

```typescript
// Shared test fixtures
const createTestUser = (overrides: Partial<User> = {}): User => ({
  id: '1',
  name: 'Test User',
  email: 'test@example.com',
  ...overrides,
});

const createTestProduct = (overrides: Partial<Product> = {}): Product => ({
  id: '1',
  name: 'Test Product',
  price: 99.99,
  ...overrides,
});

describe('OrderCmpt', () => {
  it('should calculate total', () => {
    const fixture = TestBed.createComponent(OrderCmpt);
    fixture.componentRef.setInput('user', createTestUser());
    fixture.componentRef.setInput('products', [
      createTestProduct({ price: 10 }),
      createTestProduct({ id: '2', price: 20 }),
    ]);
    fixture.detectChanges();

    expect(fixture.componentInstance.total()).toBe(30);
  });
});
```

### Shared test data

- Small data (1-2 lines): local variable in the `describe` block.
- Larger shared data: extract to `*.spec.data.ts` in the same folder.
- Never duplicate identical values across spec files.
- Don't hardcode expected user-facing text — assert against the centralized
  constants / i18n keys the code uses.
- Trace calculations — never guess expected values.
- Verify aria-labels match actual values.

## E2E testing setup

### Playwright configuration

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:4000',
    trace: 'on-first-retry',
  },
  webServer: {
    command: 'npm run serve',
    url: 'http://localhost:4000',
    reuseExistingServer: !process.env.CI,
  },
});
```

### E2E test example

```typescript
// e2e/login.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Login', () => {
  test('should login successfully', async ({ page }) => {
    await page.goto('/login');

    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('h1')).toContainText('Welcome');
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.goto('/login');

    await page.fill('input[name="email"]', 'wrong@example.com');
    await page.fill('input[name="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');

    await expect(page.locator('.error')).toBeVisible();
    await expect(page.locator('.error')).toContainText('Invalid credentials');
  });
});
```

## Cypress component testing

Applies when the project adopts Cypress component testing alongside (or
instead of) TestBed component specs; skip otherwise.

- File: `*.cy.ts` alongside the component; services keep Jasmine `*.spec.ts`.
- Use `@cypress/angular` for mounting.
- Test user interactions, visual states, and emitted events — component tests
  own the visual/interaction level; business logic stays in service specs.
- Run: `npm test` (Karma/Jasmine) · `npm run cy:test-components` (Cypress
  component tests) — or the project's equivalents.
