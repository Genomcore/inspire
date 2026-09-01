# Directives

Custom directives for reusable DOM manipulation and behavior: attribute
directives, structural directives (for portals and dynamic insertion — never
for control flow, which native `@if`/`@for`/`@switch` owns), host directives,
and the composition API.

## Attribute directives

Modify the appearance or behavior of an element:

```typescript
import { Directive, input, effect, inject, ElementRef } from '@angular/core';

@Directive({
  selector: '[appHighlight]',
})
export class Highlight {
  private el = inject(ElementRef<HTMLElement>);

  // Input with alias matching selector
  color = input('yellow', { alias: 'appHighlight' });

  constructor() {
    effect(() => {
      this.el.nativeElement.style.backgroundColor = this.color();
    });
  }
}

// Usage: <p appHighlight="lightblue">Highlighted text</p>
// Usage: <p appHighlight>Default yellow highlight</p>
```

### Using the host property

Prefer `host` over `@HostBinding`/`@HostListener`:

```typescript
@Directive({
  selector: '[appTooltip]',
  host: {
    '(mouseenter)': 'show()',
    '(mouseleave)': 'hide()',
    '[attr.aria-describedby]': 'tooltipId',
  },
})
export class Tooltip {
  text = input.required<string>({ alias: 'appTooltip' });
  position = input<'top' | 'bottom' | 'left' | 'right'>('top');

  tooltipId = `tooltip-${crypto.randomUUID()}`;
  private tooltipEl: HTMLElement | null = null;
  private el = inject(ElementRef<HTMLElement>);

  show() {
    this.tooltipEl = document.createElement('div');
    this.tooltipEl.id = this.tooltipId;
    this.tooltipEl.className = `tooltip tooltip-${this.position()}`;
    this.tooltipEl.textContent = this.text();
    this.tooltipEl.setAttribute('role', 'tooltip');
    document.body.appendChild(this.tooltipEl);
    this.positionTooltip();
  }

  hide() {
    this.tooltipEl?.remove();
    this.tooltipEl = null;
  }

  private positionTooltip() {
    // Position logic based on this.position() and this.el
  }
}

// Usage: <button appTooltip="Click to save" position="bottom">Save</button>
```

### Class and style manipulation

```typescript
@Directive({
  selector: '[appButton]',
  host: {
    'class': 'btn',
    '[class.btn-primary]': 'variant() === "primary"',
    '[class.btn-secondary]': 'variant() === "secondary"',
    '[class.btn-sm]': 'size() === "small"',
    '[class.btn-lg]': 'size() === "large"',
    '[class.disabled]': 'disabled()',
    '[attr.disabled]': 'disabled() || null',
  },
})
export class Button {
  variant = input<'primary' | 'secondary'>('primary');
  size = input<'small' | 'medium' | 'large'>('medium');
  disabled = input(false, { transform: booleanAttribute });
}

// Usage: <button appButton variant="primary" size="large">Click</button>
```

### Event handling

```typescript
@Directive({
  selector: '[appClickOutside]',
  host: {
    '(document:click)': 'onDocumentClick($event)',
  },
})
export class ClickOutside {
  private el = inject(ElementRef<HTMLElement>);

  clickOutside = output<void>();

  onDocumentClick(event: MouseEvent) {
    if (!this.el.nativeElement.contains(event.target as Node)) {
      this.clickOutside.emit();
    }
  }
}

// Usage: <div appClickOutside (clickOutside)="closeMenu()">...</div>
```

### Keyboard shortcuts

```typescript
@Directive({
  selector: '[appShortcut]',
  host: {
    '(document:keydown)': 'onKeydown($event)',
  },
})
export class Shortcut {
  key = input.required<string>({ alias: 'appShortcut' });
  ctrl = input(false, { transform: booleanAttribute });
  shift = input(false, { transform: booleanAttribute });
  alt = input(false, { transform: booleanAttribute });

  triggered = output<KeyboardEvent>();

  onKeydown(event: KeyboardEvent) {
    const keyMatch = event.key.toLowerCase() === this.key().toLowerCase();
    const ctrlMatch = this.ctrl() ? event.ctrlKey || event.metaKey : !event.ctrlKey && !event.metaKey;
    const shiftMatch = this.shift() ? event.shiftKey : !event.shiftKey;
    const altMatch = this.alt() ? event.altKey : !event.altKey;

    if (keyMatch && ctrlMatch && shiftMatch && altMatch) {
      event.preventDefault();
      this.triggered.emit(event);
    }
  }
}

// Usage: <button appShortcut="s" ctrl (triggered)="save()">Save (Ctrl+S)</button>
```

## Structural directives

Use structural directives for DOM manipulation beyond control flow (portals,
overlays, dynamic insertion points). For conditionals and loops, use native
`@if`, `@for`, `@switch`.

### Portal directive

Render content in a different DOM location:

```typescript
import { Directive, inject, TemplateRef, ViewContainerRef, OnInit, OnDestroy, input } from '@angular/core';

@Directive({
  selector: '[appPortal]',
})
export class Portal implements OnInit, OnDestroy {
  private templateRef = inject(TemplateRef<any>);
  private viewContainerRef = inject(ViewContainerRef);
  private viewRef: EmbeddedViewRef<any> | null = null;

  // Target container selector or element
  target = input<string | HTMLElement>('body', { alias: 'appPortal' });

  ngOnInit() {
    const container = this.getContainer();
    if (container) {
      this.viewRef = this.viewContainerRef.createEmbeddedView(this.templateRef);
      this.viewRef.rootNodes.forEach(node => container.appendChild(node));
    }
  }

  ngOnDestroy() {
    this.viewRef?.destroy();
  }

  private getContainer(): HTMLElement | null {
    const target = this.target();
    if (typeof target === 'string') {
      return document.querySelector(target);
    }
    return target;
  }
}

// Usage: Render modal at body level
// <div *appPortal="'body'">
//   <div class="modal">Modal content</div>
// </div>
```

### Lazy render directive

Defer rendering until a condition is met (one-time):

```typescript
@Directive({
  selector: '[appLazyRender]',
})
export class LazyRender {
  private templateRef = inject(TemplateRef<any>);
  private viewContainer = inject(ViewContainerRef);
  private rendered = false;

  condition = input.required<boolean>({ alias: 'appLazyRender' });

  constructor() {
    effect(() => {
      // Only render once when condition becomes true
      if (this.condition() && !this.rendered) {
        this.viewContainer.createEmbeddedView(this.templateRef);
        this.rendered = true;
      }
    });
  }
}

// Usage: Render heavy component only when tab is first activated
// <div *appLazyRender="activeTab() === 'reports'">
//   <app-heavy-reports />
// </div>
```

### Template outlet with context

```typescript
interface TemplateContext<T> {
  $implicit: T;
  item: T;
  index: number;
}

@Directive({
  selector: '[appTemplateOutlet]',
})
export class TemplateOutlet<T> {
  private viewContainer = inject(ViewContainerRef);
  private currentView: EmbeddedViewRef<TemplateContext<T>> | null = null;

  template = input.required<TemplateRef<TemplateContext<T>>>({ alias: 'appTemplateOutlet' });
  context = input.required<T>({ alias: 'appTemplateOutletContext' });
  index = input(0, { alias: 'appTemplateOutletIndex' });

  constructor() {
    effect(() => {
      const template = this.template();
      const context = this.context();
      const index = this.index();

      if (this.currentView) {
        this.currentView.context.$implicit = context;
        this.currentView.context.item = context;
        this.currentView.context.index = index;
        this.currentView.markForCheck();
      } else {
        this.currentView = this.viewContainer.createEmbeddedView(template, {
          $implicit: context,
          item: context,
          index,
        });
      }
    });
  }
}

// Usage: Custom list with template
// <ng-template #itemTemplate let-item let-i="index">
//   <div>{{ i }}: {{ item.name }}</div>
// </ng-template>
// <ng-container
//   *appTemplateOutlet="itemTemplate; context: item; index: i"
// />
```

## Host directives

Compose directives on components or other directives:

```typescript
// Reusable behavior directives
@Directive({
  selector: '[focusable]',
  host: {
    'tabindex': '0',
    '(focus)': 'onFocus()',
    '(blur)': 'onBlur()',
    '[class.focused]': 'isFocused()',
  },
})
export class Focusable {
  isFocused = signal(false);

  onFocus() { this.isFocused.set(true); }
  onBlur() { this.isFocused.set(false); }
}

@Directive({
  selector: '[disableable]',
  host: {
    '[class.disabled]': 'disabled()',
    '[attr.aria-disabled]': 'disabled()',
  },
})
export class Disableable {
  disabled = input(false, { transform: booleanAttribute });
}

// Component using host directives
@Component({
  selector: 'app-custom-button',
  hostDirectives: [
    Focusable,
    {
      directive: Disableable,
      inputs: ['disabled'],
    },
  ],
  host: {
    'role': 'button',
    '(click)': 'onClick($event)',
    '(keydown.enter)': 'onClick($event)',
    '(keydown.space)': 'onClick($event)',
  },
  template: `<ng-content />`,
})
export class CustomButton {
  private disableable = inject(Disableable);

  clicked = output<void>();

  onClick(event: Event) {
    if (!this.disableable.disabled()) {
      this.clicked.emit();
    }
  }
}

// Usage: <app-custom-button disabled>Click me</app-custom-button>
```

### Exposing host directive outputs

```typescript
@Directive({
  selector: '[hoverable]',
  host: {
    '(mouseenter)': 'onEnter()',
    '(mouseleave)': 'onLeave()',
    '[class.hovered]': 'isHovered()',
  },
})
export class Hoverable {
  isHovered = signal(false);

  hoverChange = output<boolean>();

  onEnter() {
    this.isHovered.set(true);
    this.hoverChange.emit(true);
  }

  onLeave() {
    this.isHovered.set(false);
    this.hoverChange.emit(false);
  }
}

@Component({
  selector: 'app-card',
  hostDirectives: [
    {
      directive: Hoverable,
      outputs: ['hoverChange'],
    },
  ],
  template: `<ng-content />`,
})
export class Card {}

// Usage: <app-card (hoverChange)="onHover($event)">...</app-card>
```

## Directive composition API

Combine multiple behaviors:

```typescript
// Base directives
@Directive({ selector: '[withRipple]' })
export class Ripple {
  // Ripple effect implementation
}

@Directive({ selector: '[withElevation]' })
export class Elevation {
  elevation = input(2);
}

// Composed component
@Component({
  selector: 'app-material-button',
  hostDirectives: [
    Ripple,
    {
      directive: Elevation,
      inputs: ['elevation'],
    },
    {
      directive: Disableable,
      inputs: ['disabled'],
    },
  ],
  template: `<ng-content />`,
})
export class MaterialButton {}
```

## DOM manipulation patterns

### Auto-focus directive

```typescript
@Directive({
  selector: '[appAutoFocus]',
})
export class AutoFocus {
  private el = inject(ElementRef<HTMLElement>);

  enabled = input(true, { alias: 'appAutoFocus', transform: booleanAttribute });
  delay = input(0);

  constructor() {
    afterNextRender(() => {
      if (this.enabled()) {
        setTimeout(() => {
          this.el.nativeElement.focus();
        }, this.delay());
      }
    });
  }
}

// Usage: <input appAutoFocus />
// Usage: <input [appAutoFocus]="shouldFocus()" [delay]="100" />
```

### Text selection directive

```typescript
@Directive({
  selector: '[appSelectAll]',
  host: {
    '(focus)': 'onFocus()',
    '(click)': 'onClick($event)',
  },
})
export class SelectAll {
  private el = inject(ElementRef<HTMLInputElement>);

  onFocus() {
    // Delay to ensure value is set
    setTimeout(() => this.el.nativeElement.select(), 0);
  }

  onClick(event: MouseEvent) {
    // Select all on first click if not already focused
    if (document.activeElement !== this.el.nativeElement) {
      this.el.nativeElement.select();
    }
  }
}

// Usage: <input appSelectAll value="Select me on focus" />
```

### Copy to clipboard

```typescript
@Directive({
  selector: '[appCopyToClipboard]',
  host: {
    '(click)': 'copy()',
    '[style.cursor]': '"pointer"',
  },
})
export class CopyToClipboard {
  text = input.required<string>({ alias: 'appCopyToClipboard' });

  copied = output<void>();
  error = output<Error>();

  async copy() {
    try {
      await navigator.clipboard.writeText(this.text());
      this.copied.emit();
    } catch (err) {
      this.error.emit(err as Error);
    }
  }
}

// Usage:
// <button [appCopyToClipboard]="textToCopy" (copied)="showToast('Copied!')">
//   Copy
// </button>
```

## Form directives

### Trim input

```typescript
@Directive({
  selector: 'input[appTrim], textarea[appTrim]',
  host: {
    '(blur)': 'onBlur()',
  },
})
export class Trim {
  private el = inject(ElementRef<HTMLInputElement | HTMLTextAreaElement>);
  private ngControl = inject(NgControl, { optional: true, self: true });

  onBlur() {
    const value = this.el.nativeElement.value;
    const trimmed = value.trim();

    if (value !== trimmed) {
      this.el.nativeElement.value = trimmed;
      this.ngControl?.control?.setValue(trimmed);
    }
  }
}

// Usage: <input appTrim formControlName="name" />
```

### Input mask

```typescript
@Directive({
  selector: '[appMask]',
  host: {
    '(input)': 'onInput($event)',
    '(keydown)': 'onKeydown($event)',
  },
})
export class Mask {
  private el = inject(ElementRef<HTMLInputElement>);

  // Mask pattern: 9 = digit, A = letter, * = any
  mask = input.required<string>({ alias: 'appMask' });

  onInput(event: InputEvent) {
    const input = this.el.nativeElement;
    const value = input.value;
    const masked = this.applyMask(value);

    if (value !== masked) {
      input.value = masked;
    }
  }

  onKeydown(event: KeyboardEvent) {
    // Allow navigation keys
    if (['Backspace', 'Delete', 'ArrowLeft', 'ArrowRight', 'Tab'].includes(event.key)) {
      return;
    }

    const input = this.el.nativeElement;
    const position = input.selectionStart ?? 0;
    const maskChar = this.mask()[position];

    if (!maskChar) {
      event.preventDefault();
      return;
    }

    if (!this.isValidChar(event.key, maskChar)) {
      event.preventDefault();
    }
  }

  private applyMask(value: string): string {
    const mask = this.mask();
    let result = '';
    let valueIndex = 0;

    for (let i = 0; i < mask.length && valueIndex < value.length; i++) {
      const maskChar = mask[i];
      const inputChar = value[valueIndex];

      if (maskChar === '9' || maskChar === 'A' || maskChar === '*') {
        if (this.isValidChar(inputChar, maskChar)) {
          result += inputChar;
          valueIndex++;
        } else {
          valueIndex++;
          i--;
        }
      } else {
        result += maskChar;
        if (inputChar === maskChar) {
          valueIndex++;
        }
      }
    }

    return result;
  }

  private isValidChar(char: string, maskChar: string): boolean {
    switch (maskChar) {
      case '9': return /\d/.test(char);
      case 'A': return /[a-zA-Z]/.test(char);
      case '*': return /[a-zA-Z0-9]/.test(char);
      default: return char === maskChar;
    }
  }
}

// Usage: <input appMask="(999) 999-9999" placeholder="(555) 123-4567" />
```

### Character counter

```typescript
@Directive({
  selector: '[appCharCount]',
})
export class CharCount {
  private el = inject(ElementRef<HTMLInputElement | HTMLTextAreaElement>);

  maxLength = input.required<number>({ alias: 'appCharCount' });

  currentLength = signal(0);
  remaining = computed(() => this.maxLength() - this.currentLength());
  isOverLimit = computed(() => this.remaining() < 0);

  constructor() {
    effect(() => {
      this.currentLength.set(this.el.nativeElement.value.length);
    });

    // Listen for input changes
    afterNextRender(() => {
      this.el.nativeElement.addEventListener('input', () => {
        this.currentLength.set(this.el.nativeElement.value.length);
      });
    });
  }
}

// Usage with template:
// <textarea appCharCount="500" #counter="appCharCount"></textarea>
// <span>{{ counter.remaining() }} characters remaining</span>
```

## Intersection Observer

### Lazy load directive

```typescript
@Directive({
  selector: '[appLazyLoad]',
})
export class LazyLoad implements OnDestroy {
  private el = inject(ElementRef<HTMLElement>);
  private observer: IntersectionObserver | null = null;

  src = input.required<string>({ alias: 'appLazyLoad' });
  placeholder = input('/assets/placeholder.png');

  loaded = output<void>();

  constructor() {
    afterNextRender(() => {
      this.setupObserver();
    });
  }

  private setupObserver() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.loadImage();
            this.observer?.disconnect();
          }
        });
      },
      { rootMargin: '50px' }
    );

    this.observer.observe(this.el.nativeElement);

    // Set placeholder
    if (this.el.nativeElement instanceof HTMLImageElement) {
      this.el.nativeElement.src = this.placeholder();
    }
  }

  private loadImage() {
    const element = this.el.nativeElement;

    if (element instanceof HTMLImageElement) {
      element.src = this.src();
      element.onload = () => this.loaded.emit();
    } else {
      element.style.backgroundImage = `url(${this.src()})`;
      this.loaded.emit();
    }
  }

  ngOnDestroy() {
    this.observer?.disconnect();
  }
}

// Usage: <img [appLazyLoad]="imageUrl" alt="Lazy loaded image" />
```

### Infinite scroll

```typescript
@Directive({
  selector: '[appInfiniteScroll]',
})
export class InfiniteScroll implements OnDestroy {
  private el = inject(ElementRef<HTMLElement>);
  private observer: IntersectionObserver | null = null;

  threshold = input(0.1);
  disabled = input(false);

  scrolled = output<void>();

  constructor() {
    afterNextRender(() => {
      this.setupObserver();
    });

    effect(() => {
      if (this.disabled()) {
        this.observer?.disconnect();
      } else {
        this.setupObserver();
      }
    });
  }

  private setupObserver() {
    this.observer?.disconnect();

    this.observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !this.disabled()) {
          this.scrolled.emit();
        }
      },
      { threshold: this.threshold() }
    );

    this.observer.observe(this.el.nativeElement);
  }

  ngOnDestroy() {
    this.observer?.disconnect();
  }
}

// Usage:
// <div class="list">
//   @for (item of items(); track item.id) {
//     <div>{{ item.name }}</div>
//   }
//   <div appInfiniteScroll (scrolled)="loadMore()" [disabled]="isLoading()">
//     Loading...
//   </div>
// </div>
```

## Resize Observer

```typescript
@Directive({
  selector: '[appResize]',
})
export class Resize implements OnDestroy {
  private el = inject(ElementRef<HTMLElement>);
  private observer: ResizeObserver | null = null;

  width = signal(0);
  height = signal(0);

  resized = output<{ width: number; height: number }>();

  constructor() {
    afterNextRender(() => {
      this.observer = new ResizeObserver((entries) => {
        const entry = entries[0];
        const { width, height } = entry.contentRect;

        this.width.set(width);
        this.height.set(height);
        this.resized.emit({ width, height });
      });

      this.observer.observe(this.el.nativeElement);
    });
  }

  ngOnDestroy() {
    this.observer?.disconnect();
  }
}

// Usage:
// <div appResize #resize="appResize">
//   Size: {{ resize.width() }}x{{ resize.height() }}
// </div>
```

## Drag and drop

```typescript
@Directive({
  selector: '[appDraggable]',
  host: {
    'draggable': 'true',
    '[class.dragging]': 'isDragging()',
    '(dragstart)': 'onDragStart($event)',
    '(dragend)': 'onDragEnd($event)',
  },
})
export class Draggable {
  data = input<any>(null, { alias: 'appDraggable' });
  effectAllowed = input<DataTransfer['effectAllowed']>('move');

  isDragging = signal(false);

  dragStart = output<DragEvent>();
  dragEnd = output<DragEvent>();

  onDragStart(event: DragEvent) {
    this.isDragging.set(true);

    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = this.effectAllowed();
      event.dataTransfer.setData('application/json', JSON.stringify(this.data()));
    }

    this.dragStart.emit(event);
  }

  onDragEnd(event: DragEvent) {
    this.isDragging.set(false);
    this.dragEnd.emit(event);
  }
}

@Directive({
  selector: '[appDropZone]',
  host: {
    '[class.drag-over]': 'isDragOver()',
    '(dragover)': 'onDragOver($event)',
    '(dragleave)': 'onDragLeave($event)',
    '(drop)': 'onDrop($event)',
  },
})
export class DropZone {
  isDragOver = signal(false);

  dropped = output<any>();

  onDragOver(event: DragEvent) {
    event.preventDefault();
    this.isDragOver.set(true);
  }

  onDragLeave(event: DragEvent) {
    this.isDragOver.set(false);
  }

  onDrop(event: DragEvent) {
    event.preventDefault();
    this.isDragOver.set(false);

    const data = event.dataTransfer?.getData('application/json');
    if (data) {
      this.dropped.emit(JSON.parse(data));
    }
  }
}

// Usage:
// <div [appDraggable]="item">Drag me</div>
// <div appDropZone (dropped)="onItemDropped($event)">Drop here</div>
```

## Permission directive

```typescript
@Directive({
  selector: '[appHasPermission]',
})
export class HasPermission {
  private templateRef = inject(TemplateRef<any>);
  private viewContainer = inject(ViewContainerRef);
  private authService = inject(Auth);
  private hasView = false;

  permission = input.required<string | string[]>({ alias: 'appHasPermission' });
  mode = input<'any' | 'all'>('any');

  constructor() {
    effect(() => {
      const hasPermission = this.checkPermission();

      if (hasPermission && !this.hasView) {
        this.viewContainer.createEmbeddedView(this.templateRef);
        this.hasView = true;
      } else if (!hasPermission && this.hasView) {
        this.viewContainer.clear();
        this.hasView = false;
      }
    });
  }

  private checkPermission(): boolean {
    const required = this.permission();
    const permissions = Array.isArray(required) ? required : [required];
    const userPermissions = this.authService.permissions();

    if (this.mode() === 'all') {
      return permissions.every(p => userPermissions.includes(p));
    }

    return permissions.some(p => userPermissions.includes(p));
  }
}

// Usage:
// <button *appHasPermission="'admin'">Admin Only</button>
// <div *appHasPermission="['edit', 'delete']; mode: 'all'">Edit & Delete</div>
```

## Export directive reference

```typescript
@Directive({
  selector: '[appToggle]',
  exportAs: 'appToggle',
})
export class Toggle {
  isOpen = signal(false);

  toggle() {
    this.isOpen.update(v => !v);
  }

  open() {
    this.isOpen.set(true);
  }

  close() {
    this.isOpen.set(false);
  }
}

// Usage:
// <div appToggle #toggle="appToggle">
//   <button (click)="toggle.toggle()">Toggle</button>
//   @if (toggle.isOpen()) {
//     <div>Content</div>
//   }
// </div>
```
