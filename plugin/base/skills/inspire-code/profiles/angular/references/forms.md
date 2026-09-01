# Forms

Type-safe reactive forms with the Reactive Forms API (FormBuilder, FormGroup,
FormControl, FormArray): typed controls, validation, dynamic forms, state
management, and custom form controls via ControlValueAccessor. Reactive Forms
are the production-stable choice; template-driven forms are not used.

## Basic setup

```typescript
import { Component, inject } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';

@Component({
  selector: 'app-login',
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()">
      <label>
        Email
        <input type="email" formControlName="email" />
      </label>
      @if (form.controls.email.errors?.['required'] && form.controls.email.touched) {
        <p class="error">Email is required</p>
      }
      @if (form.controls.email.errors?.['email'] && form.controls.email.touched) {
        <p class="error">Enter a valid email address</p>
      }

      <label>
        Password
        <input type="password" formControlName="password" />
      </label>
      @if (form.controls.password.errors?.['required'] && form.controls.password.touched) {
        <p class="error">Password is required</p>
      }

      <button type="submit" [disabled]="form.invalid">Login</button>
    </form>
  `,
})
export class Login {
  private fb = inject(FormBuilder);

  form = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required]],
  });

  onSubmit() {
    if (this.form.valid) {
      const credentials = this.form.getRawValue();
      console.log('Submitting:', credentials);
    }
  }
}
```

## Typed forms

### Typed FormControl

```typescript
import { FormControl } from '@angular/forms';

// Inferred type: FormControl<string | null>
const name = new FormControl('');

// Non-nullable (no reset to null)
const email = new FormControl('', { nonNullable: true });
// Type: FormControl<string>

// With validators
const username = new FormControl('', {
  nonNullable: true,
  validators: [Validators.required, Validators.minLength(3)],
});
```

### Typed FormGroup

```typescript
import { FormGroup, FormControl } from '@angular/forms';

interface UserForm {
  name: FormControl<string>;
  email: FormControl<string>;
  age: FormControl<number | null>;
}

const form = new FormGroup<UserForm>({
  name: new FormControl('', { nonNullable: true }),
  email: new FormControl('', { nonNullable: true }),
  age: new FormControl<number | null>(null),
});

// Typed value access
const name: string = form.controls.name.value;
```

### NonNullableFormBuilder

```typescript
import { inject } from '@angular/core';
import { NonNullableFormBuilder, Validators } from '@angular/forms';

@Component({...})
export class Profile {
  private fb = inject(NonNullableFormBuilder);

  form = this.fb.group({
    name: ['', Validators.required],           // FormControl<string>
    email: ['', [Validators.required, Validators.email]],
    preferences: this.fb.group({
      newsletter: [false],                      // FormControl<boolean>
      theme: ['light' as 'light' | 'dark'],    // FormControl<'light' | 'dark'>
    }),
  });
}
```

## Nested FormGroups

```typescript
@Component({
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()">
      <input formControlName="name" placeholder="Name" />

      <div formGroupName="address">
        <input formControlName="street" placeholder="Street" />
        <input formControlName="city" placeholder="City" />
        <input formControlName="zip" placeholder="ZIP" />
      </div>

      <button type="submit">Submit</button>
    </form>
  `,
})
export class Profile {
  private fb = inject(NonNullableFormBuilder);

  form = this.fb.group({
    name: ['', Validators.required],
    address: this.fb.group({
      street: [''],
      city: ['', Validators.required],
      zip: ['', [Validators.required, Validators.pattern(/^\d{5}$/)]],
    }),
  });
}
```

## Dynamic forms with FormArray

```typescript
import { FormArray } from '@angular/forms';

@Component({
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="form">
      <div formArrayName="items">
        @for (item of items.controls; track $index; let i = $index) {
          <div [formGroupName]="i">
            <input formControlName="product" placeholder="Product" />
            <input formControlName="quantity" type="number" />
            <button type="button" (click)="removeItem(i)">Remove</button>
          </div>
        }
      </div>
      <button type="button" (click)="addItem()">Add Item</button>
    </form>
  `,
})
export class Order {
  private fb = inject(NonNullableFormBuilder);

  form = this.fb.group({
    items: this.fb.array([this.createItem()]),
  });

  get items() {
    return this.form.controls.items;
  }

  createItem() {
    return this.fb.group({
      product: ['', Validators.required],
      quantity: [1, [Validators.required, Validators.min(1)]],
    });
  }

  addItem() {
    this.items.push(this.createItem());
  }

  removeItem(index: number) {
    this.items.removeAt(index);
  }
}
```

## Validation

### Built-in validators

```typescript
import { Validators } from '@angular/forms';

form = this.fb.group({
  name: ['', [Validators.required]],
  email: ['', [Validators.required, Validators.email]],
  age: [null, [Validators.min(18), Validators.max(120)]],
  password: ['', [Validators.required, Validators.minLength(8), Validators.maxLength(64)]],
  phone: ['', [Validators.pattern(/^\d{3}-\d{3}-\d{4}$/)]],
});
```

### Custom validators

```typescript
import { AbstractControl, ValidationErrors, ValidatorFn } from '@angular/forms';

export function forbiddenValue(forbidden: string): ValidatorFn {
  return (control: AbstractControl): ValidationErrors | null => {
    return control.value === forbidden
      ? { forbiddenValue: { value: control.value } }
      : null;
  };
}

// Usage
name: ['', [Validators.required, forbiddenValue('admin')]],
```

### Cross-field validation

```typescript
export function passwordMatch(): ValidatorFn {
  return (group: AbstractControl): ValidationErrors | null => {
    const password = group.get('password')?.value;
    const confirm = group.get('confirmPassword')?.value;
    return password === confirm ? null : { passwordMismatch: true };
  };
}

// Usage
form = this.fb.group({
  password: ['', [Validators.required, Validators.minLength(8)]],
  confirmPassword: ['', Validators.required],
}, { validators: passwordMatch() });
```

### Async validators

```typescript
import { AsyncValidatorFn } from '@angular/forms';
import { map, catchError, of } from 'rxjs';

export function uniqueEmail(userService: UserService): AsyncValidatorFn {
  return (control: AbstractControl) => {
    return userService.checkEmail(control.value).pipe(
      map(exists => exists ? { emailTaken: true } : null),
      catchError(() => of(null))
    );
  };
}

// Usage
email: ['',
  [Validators.required, Validators.email],  // sync validators
  [uniqueEmail(this.userService)]            // async validators
],
```

### Conditional validation

```typescript
@Component({...})
export class Order {
  form = this.fb.group({
    applyDiscount: [false],
    promoCode: [''],
  });

  constructor() {
    this.form.controls.applyDiscount.valueChanges.subscribe(apply => {
      const promoControl = this.form.controls.promoCode;
      if (apply) {
        promoControl.addValidators(Validators.required);
      } else {
        promoControl.removeValidators(Validators.required);
      }
      promoControl.updateValueAndValidity();
    });
  }
}
```

## Form state management

### State properties

```typescript
// Check states
form.valid      // All validations pass
form.invalid    // Has validation errors
form.pending    // Async validation in progress
form.dirty      // Value changed by user
form.pristine   // Value not changed
form.touched    // Control has been focused
form.untouched  // Control never focused

// Update values
form.setValue({ name: 'John', email: 'john@example.com' }); // Must include all
form.patchValue({ name: 'John' }); // Partial update

// Reset
form.reset();
form.reset({ name: 'Default' });

// Disable/Enable
form.disable();
form.enable();
form.controls.email.disable();

// Mark states
form.markAllAsTouched(); // Show all errors
form.markAsPristine();
form.markAsDirty();
```

### Value changes observable

```typescript
// Subscribe to value changes
form.valueChanges.subscribe(value => {
  console.log('Form value:', value);
});

// Single control with debounce
form.controls.email.valueChanges.pipe(
  debounceTime(300),
  distinctUntilChanged()
).subscribe(email => {
  this.validateEmail(email);
});

// Status changes
form.statusChanges.subscribe(status => {
  console.log('Form status:', status); // VALID, INVALID, PENDING
});
```

### Unified events (Angular 18+)

```typescript
import {
  ValueChangeEvent, StatusChangeEvent,
  FormSubmittedEvent, FormResetEvent
} from '@angular/forms';

form.events.subscribe(event => {
  if (event instanceof ValueChangeEvent) {
    console.log('Value changed:', event.value);
  }
  if (event instanceof StatusChangeEvent) {
    console.log('Status changed:', event.status);
  }
  if (event instanceof FormSubmittedEvent) {
    console.log('Form submitted');
  }
  if (event instanceof FormResetEvent) {
    console.log('Form reset');
  }
});
```

## Error display pattern

```typescript
@Component({
  template: `
    <input formControlName="email" />

    @if (form.controls.email.invalid && form.controls.email.touched) {
      <div class="errors">
        @if (form.controls.email.errors?.['required']) {
          <span>Email is required</span>
        }
        @if (form.controls.email.errors?.['email']) {
          <span>Invalid email format</span>
        }
      </div>
    }
  `,
})
export class Form {
  // Helper for cleaner templates
  hasError(controlName: string, errorKey: string): boolean {
    const control = this.form.get(controlName);
    return control?.hasError(errorKey) && control?.touched || false;
  }
}
```

## Form submission pattern

```typescript
@Component({
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()">
      <!-- fields -->
      <button type="submit" [disabled]="form.invalid || isSubmitting">
        {{ isSubmitting ? 'Submitting...' : 'Submit' }}
      </button>
    </form>
  `,
})
export class Form {
  isSubmitting = false;

  async onSubmit() {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.isSubmitting = true;
    try {
      await this.api.submit(this.form.getRawValue());
      this.form.reset();
    } catch (error) {
      // Handle error
    } finally {
      this.isSubmitting = false;
    }
  }
}
```

## Custom form controls (ControlValueAccessor)

`ControlValueAccessor` is the bridge between Reactive Forms and custom form
controls. Implement it to make any component work with `formControlName`,
`formControl`, and `ngModel`.

```typescript
interface ControlValueAccessor {
  writeValue(value: any): void;           // Called when form sets value
  registerOnChange(fn: any): void;        // Register callback for value changes
  registerOnTouched(fn: any): void;       // Register callback for blur/touch
  setDisabledState?(isDisabled: boolean): void; // Called when control is enabled/disabled
}
```

### Basic custom control

```typescript
import { Component, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';

@Component({
  selector: 'app-toggle',
  template: `
    <button
      type="button"
      [class.active]="value"
      [disabled]="disabled"
      (click)="toggle()"
      (blur)="onTouched()"
    >
      {{ value ? 'ON' : 'OFF' }}
    </button>
  `,
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => ToggleComponent),
      multi: true,
    },
  ],
})
export class ToggleComponent implements ControlValueAccessor {
  value = false;
  disabled = false;

  // Callbacks registered by the form
  private onChange: (value: boolean) => void = () => {};
  onTouched: () => void = () => {};

  toggle(): void {
    if (!this.disabled) {
      this.value = !this.value;
      this.onChange(this.value);
    }
  }

  // ControlValueAccessor implementation
  writeValue(value: boolean): void {
    this.value = value;
  }

  registerOnChange(fn: (value: boolean) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(isDisabled: boolean): void {
    this.disabled = isDisabled;
  }
}
```

Usage in a form:

```typescript
@Component({
  imports: [ReactiveFormsModule, ToggleComponent],
  template: `
    <form [formGroup]="form">
      <app-toggle formControlName="active"></app-toggle>
    </form>
  `,
})
export class Settings {
  form = this.fb.group({
    active: [false],
  });
}
```

### Star rating example

```typescript
import { Component, forwardRef } from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';

@Component({
  selector: 'app-rating',
  imports: [MatIconModule],
  template: `
    <div class="star-rating-container">
      @for (star of stars; track star) {
        <mat-icon
          (click)="rate(star)"
          (blur)="onTouched()"
          class="star-icon"
          [class.filled]="star <= value"
          [class.disabled]="disabled"
        >
          {{ star <= value ? 'star' : 'star_border' }}
        </mat-icon>
      }
    </div>
  `,
  styles: [`
    .star-icon { cursor: pointer; color: #ffc107; }
    .star-icon.disabled { cursor: default; opacity: 0.5; }
  `],
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => RatingComponent),
      multi: true,
    },
  ],
})
export class RatingComponent implements ControlValueAccessor {
  value = 0;
  disabled = false;
  stars = [1, 2, 3, 4, 5];

  private onChange: (value: number) => void = () => {};
  onTouched: () => void = () => {};

  rate(index: number): void {
    if (!this.disabled) {
      this.value = index;
      this.onChange(this.value);
      this.onTouched();
    }
  }

  writeValue(value: number): void {
    this.value = value ?? 0;
  }

  registerOnChange(fn: (value: number) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(isDisabled: boolean): void {
    this.disabled = isDisabled;
  }
}
```

Usage in a form:

```typescript
@Component({
  imports: [ReactiveFormsModule, RatingComponent],
  template: `
    <form [formGroup]="form" (ngSubmit)="submit()">
      <div class="form-field">
        <label>Rating</label>
        <app-rating formControlName="rating"></app-rating>
        @if (form.controls.rating.errors?.['min'] && form.controls.rating.touched) {
          <span class="error">Please select a rating</span>
        }
      </div>
      <p>Current rating: {{ form.controls.rating.value }}</p>
      <button type="submit">Submit</button>
    </form>
  `,
})
export class ReviewForm {
  private fb = inject(FormBuilder);

  form = this.fb.group({
    rating: [0, [Validators.required, Validators.min(1)]],
  });

  submit(): void {
    if (this.form.valid) {
      console.log(this.form.getRawValue());
    }
  }
}
```

### Custom control with validation

Add built-in validation to a custom control using `NG_VALIDATORS`:

```typescript
import { Component, forwardRef, Input } from '@angular/core';
import {
  ControlValueAccessor,
  NG_VALUE_ACCESSOR,
  NG_VALIDATORS,
  Validator,
  AbstractControl,
  ValidationErrors,
} from '@angular/forms';

@Component({
  selector: 'app-color-picker',
  template: `
    <div class="color-grid">
      @for (color of colors; track color) {
        <button
          type="button"
          [style.background-color]="color"
          [class.selected]="color === value"
          [disabled]="disabled"
          (click)="selectColor(color)"
          (blur)="onTouched()"
        ></button>
      }
    </div>
  `,
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => ColorPickerComponent),
      multi: true,
    },
    {
      provide: NG_VALIDATORS,
      useExisting: forwardRef(() => ColorPickerComponent),
      multi: true,
    },
  ],
})
export class ColorPickerComponent implements ControlValueAccessor, Validator {
  @Input() colors: string[] = ['#f44336', '#2196f3', '#4caf50', '#ff9800', '#9c27b0'];
  @Input() required = false;

  value: string | null = null;
  disabled = false;

  private onChange: (value: string | null) => void = () => {};
  onTouched: () => void = () => {};

  selectColor(color: string): void {
    if (!this.disabled) {
      this.value = color;
      this.onChange(this.value);
      this.onTouched();
    }
  }

  // ControlValueAccessor
  writeValue(value: string | null): void {
    this.value = value;
  }

  registerOnChange(fn: (value: string | null) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(isDisabled: boolean): void {
    this.disabled = isDisabled;
  }

  // Validator
  validate(control: AbstractControl): ValidationErrors | null {
    if (this.required && !this.value) {
      return { required: true };
    }
    return null;
  }
}
```

### Custom control with Material

Applies when the project uses Angular Material. Integrate with `mat-form-field`
using `MatFormFieldControl`:

```typescript
import { Component, forwardRef, Optional, Self } from '@angular/core';
import { ControlValueAccessor, NgControl } from '@angular/forms';
import { MatFormFieldControl } from '@angular/material/form-field';
import { Subject } from 'rxjs';

@Component({
  selector: 'app-phone-input',
  template: `
    <div class="phone-input">
      <input
        class="area-code"
        maxlength="3"
        [value]="areaCode"
        [disabled]="disabled"
        (input)="onAreaCodeChange($event)"
        (blur)="onTouched()"
        placeholder="000"
      />
      <span>-</span>
      <input
        class="number"
        maxlength="7"
        [value]="number"
        [disabled]="disabled"
        (input)="onNumberChange($event)"
        (blur)="onTouched()"
        placeholder="0000000"
      />
    </div>
  `,
  providers: [
    {
      provide: MatFormFieldControl,
      useExisting: PhoneInputComponent,
    },
  ],
})
export class PhoneInputComponent implements ControlValueAccessor, MatFormFieldControl<string> {
  static nextId = 0;
  id = `app-phone-input-${PhoneInputComponent.nextId++}`;
  controlType = 'phone-input';
  placeholder = '';
  focused = false;
  stateChanges = new Subject<void>();

  areaCode = '';
  number = '';
  disabled = false;

  private onChange: (value: string) => void = () => {};
  onTouched: () => void = () => {};

  constructor(@Optional() @Self() public ngControl: NgControl) {
    if (this.ngControl) {
      this.ngControl.valueAccessor = this;
    }
  }

  get value(): string {
    return this.areaCode && this.number
      ? `${this.areaCode}-${this.number}`
      : '';
  }

  get empty(): boolean {
    return !this.areaCode && !this.number;
  }

  get errorState(): boolean {
    return !!(this.ngControl?.errors && this.ngControl?.touched);
  }

  get shouldLabelFloat(): boolean {
    return this.focused || !this.empty;
  }

  onAreaCodeChange(event: Event): void {
    this.areaCode = (event.target as HTMLInputElement).value;
    this.emitChange();
  }

  onNumberChange(event: Event): void {
    this.number = (event.target as HTMLInputElement).value;
    this.emitChange();
  }

  private emitChange(): void {
    this.onChange(this.value);
    this.stateChanges.next();
  }

  // ControlValueAccessor
  writeValue(value: string): void {
    if (value) {
      const parts = value.split('-');
      this.areaCode = parts[0] || '';
      this.number = parts[1] || '';
    } else {
      this.areaCode = '';
      this.number = '';
    }
    this.stateChanges.next();
  }

  registerOnChange(fn: (value: string) => void): void {
    this.onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(isDisabled: boolean): void {
    this.disabled = isDisabled;
    this.stateChanges.next();
  }

  // MatFormFieldControl
  onContainerClick(): void {}

  setDescribedByIds(ids: string[]): void {}

  ngOnDestroy(): void {
    this.stateChanges.complete();
  }
}
```

Usage with mat-form-field:

```html
<mat-form-field>
  <mat-label>Phone</mat-label>
  <app-phone-input formControlName="phone"></app-phone-input>
  <mat-error>Enter a valid phone number</mat-error>
</mat-form-field>
```
