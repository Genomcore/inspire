# Styles and design system

SCSS conventions for a two-layer design system: a shared **design-system
package** (colors, typography, spacing, breakpoints, layout — imported here as
`<design-system>/styles/...`; substitute the project's actual package) plus
**app-specific globals** (`src/assets/styles/`). Concrete token values (brand
colors, exact scales) live in the project's design system —
`05_screens/design-system.md` is the source of truth; the values shown here
are the token *roles* and naming conventions. Examples use the `app-` BEM
class prefix — the project declares its own.

## Imports

Always import design tokens via namespaced `@use`:

```scss
// Design system tokens (from the design-system package)
@use '<design-system>/styles/colors';
@use '<design-system>/styles/typography';
@use '<design-system>/styles/spacing';

// App-specific variables and mixins
@use 'src/assets/styles/globals';
@use 'src/assets/styles/mixins';
```

**Import only what you use.** If you only need spacing, don't import colors or
typography.

## Color system

### Primary and semantic colors (from globals)

Token roles — the project's design system supplies the values:

```scss
// Brand
globals.$color-primary            // Primary brand color
globals.$color-primary-variant    // Muted primary
globals.$color-secondary          // Secondary brand color
globals.$color-secondary-variant  // Darker secondary

// Surfaces
globals.$color-background         // Page background
globals.$color-surface            // Card/panel background

// Text
globals.$color-text               // Default text
globals.$color-text-disabled      // Disabled text

// Semantic
globals.$color-success
globals.$color-error

// Inputs
globals.$color-input-bg           // Input background
globals.$color-input-disabled

// Borders
globals.$color-border
globals.$color-divider
```

### Palette colors (from the design-system package)

```scss
// Grey scale
colors.$paletteGrey95             // Hover backgrounds
colors.$color_mediumGrey
colors.$color_darkGrey
colors.$color_lightGrey

// Alert/status colors
colors.$color_ok
colors.$color_error
colors.$color_warning
colors.$color_info

// Light variants (for badge/alert backgrounds)
colors.$color_lightOk
colors.$color_lightError
colors.$color_lightWarning
colors.$color_lightInfo

// Temperature gradient (data visualization, best → worst)
colors.$color_veryGood
colors.$color_good
colors.$color_regular
colors.$color_bad
colors.$color_veryBad

// Shadow
colors.$shadow
```

### Data visualization colors (from globals)

```scss
globals.$color-red
globals.$color-orange
globals.$color-yellow
globals.$color-green
globals.$color-blue
globals.$color-purple
globals.$color-green-dark
```

## Typography

### Font sizes

```scss
typography.$font-size-2xl       // 32px - Page titles
typography.$font-size-xl        // 24px - Section headers
typography.$font-size-l        // 20px - Subsection headers
typography.$font-size-m        // 16px - Body text (default)
typography.$font-size-s        // 14px - Subtitles, secondary text
typography.$font-size-xs       // 12px - Detail, fine print
typography.$font-size-2xs      // 10px - Notifications
```

### Typography mixins

```scss
@include typography.h1-text();              // Bold 32px
@include typography.h2-text();              // Bold 24px
@include typography.h3-text();              // Bold 20px
@include typography.h4-text();              // Bold 16px
@include typography.button-text();          // Bold 16px
@include typography.body-text-bold();       // Bold 16px
@include typography.body-text-regular();    // Normal 16px
@include typography.subtitle-text-bold();   // Bold 14px
@include typography.subtitle-text-regular(); // Normal 14px
@include typography.detail-text();          // Normal 12px
```

### Font weights (from globals)

```scss
globals.$font-weight-medium     // 300
globals.$font-width             // 500 - Normal
globals.$font-bold              // 600 - Bold
globals.$font-weight-large      // 700 - Extra bold
```

### Line heights

```scss
globals.$line-height-small      // 16px
globals.$line-height            // 20px
globals.$line-height-large      // 30px
globals.$line-height-xlarge     // 40px
globals.$line-height-big        // 48px
```

## Spacing

### Design system scale (from the design-system package)

```scss
spacing.$space_2xs              // 4px
spacing.$space_xs               // 8px
spacing.$space_s                // 12px
spacing.$space_m                // 16px
spacing.$space_l                // 24px
spacing.$space_xl               // 32px
spacing.$space_2xl              // 48px
spacing.$space_3xl              // 72px
```

### App-specific margins (from globals)

```scss
globals.$margin-xs              // 4px
globals.$margin                 // 8px
globals.$margin-intermedium     // 12px
globals.$margin-medium          // 16px
globals.$margin-large           // 24px
globals.$margin-mlarge          // 28px
globals.$margin-xlarge          // 32px
globals.$margin-big             // 40px
globals.$margin-xbig            // 48px
```

### App-specific padding (from globals)

```scss
globals.$padding-xs             // 6px
globals.$padding                // 8px
globals.$padding-medium         // 14px
globals.$padding-big            // 16px
globals.$padding-xbig           // 24px
```

## Border and border radius

```scss
globals.$border-radius-xs       // 4px - Buttons, small elements
globals.$border-radius-s       // 3px - Compact radius
globals.$border-radius         // 6px - Standard (most common)
globals.$border-radius-m       // 8px - Medium
globals.$border-radius-big     // 16px - Cards, large containers

globals.$border-thickness      // 1.5px
```

## Component SCSS structure

### Standard pattern

```scss
@use '<design-system>/styles/colors';
@use '<design-system>/styles/typography';
@use '<design-system>/styles/spacing';
@use 'src/assets/styles/globals';

:host {
  display: block;

  .app-feature-name {
    display: flex;
    flex-direction: column;
    gap: spacing.$space_l;

    &__header {
      display: flex;
      align-items: center;
      gap: spacing.$space_m;
      padding: globals.$padding-xbig;
      min-height: globals.$height-card-header;

      &__title {
        font-size: typography.$font-size-xl;
        font-weight: globals.$font-bold;
        line-height: globals.$line-height-large;
        color: globals.$color-text;
      }

      &__subtitle {
        @include typography.subtitle-text-regular();
        color: globals.$color-text-disabled;
      }
    }

    &__body {
      padding: globals.$padding-xbig;
    }

    &__footer {
      display: flex;
      justify-content: flex-end;
      gap: spacing.$space_xs;
      padding: globals.$padding-big;
    }
  }
}
```

### Card pattern

```scss
.app-card {
  display: flex;
  flex-direction: column;
  padding: globals.$padding-big;
  gap: globals.$padding-xs;
  background: globals.$color-surface;
  box-shadow: colors.$shadow;
  border-radius: globals.$border-radius;
  margin-bottom: globals.$margin-medium;

  &--clickable {
    cursor: pointer;

    &:hover {
      background-color: colors.$paletteGrey95;
    }
  }
}
```

### Table pattern

```scss
.app-table-container {
  width: 100%;

  table {
    width: 100%;
    border-collapse: collapse;
    border-radius: globals.$border-radius;
    overflow: hidden;
    box-shadow: colors.$shadow;
  }

  .clickable-row {
    cursor: pointer;

    &:hover {
      background-color: colors.$paletteGrey95;
    }
  }

  // Column widths
  .mat-column-name { width: globals.$flex-size-30; }
  .mat-column-status { width: globals.$flex-size-10; text-align: center; }
  .mat-column-actions { width: globals.$flex-size-5; }
}
```

### Status badge pattern

```scss
.app-badge {
  display: inline-flex;
  align-items: center;
  padding: spacing.$space_2xs spacing.$space_xs;
  border-radius: 12px;
  @include typography.detail-text();

  &--success {
    color: globals.$color-success;
    background-color: colors.$color_lightOk;
  }

  &--error {
    color: globals.$color-error;
    background-color: colors.$color_lightError;
  }

  &--warning {
    color: colors.$color_warning;
    background-color: colors.$color_lightWarning;
  }

  &--info {
    color: colors.$color_info;
    background-color: colors.$color_lightInfo;
  }
}
```

## Material Design overrides

Applies when the project uses Angular Material. Use `::ng-deep` sparingly and
scoped to `:host`:

```scss
// Scoped Material override
:host ::ng-deep {
  .mat-mdc-form-field-subscript-wrapper {
    display: none;
  }

  .mat-mdc-tab-body-content {
    padding: globals.$margin-large;
  }
}
```

### Form field

```scss
:host ::ng-deep {
  // Remove subscript wrapper (hint/error space)
  .mat-mdc-form-field-subscript-wrapper {
    display: none;
  }

  // Compact form field
  .mat-mdc-form-field {
    .mat-mdc-text-field-wrapper {
      height: 40px;
      background-color: globals.$color-input-bg;
      border-radius: globals.$border-radius-xs;
    }
  }

  // Disabled state
  .mat-mdc-form-field.mat-form-field-disabled {
    .mat-mdc-text-field-wrapper {
      background-color: globals.$color-input-disabled;
    }
  }
}
```

### Select

```scss
:host ::ng-deep {
  // Select panel
  .app-select-panel {
    .mat-mdc-option.mdc-list-item--selected {
      background-color: colors.$color_lightInfo;
    }
  }

  // Custom arrow icon
  .mat-mdc-select-arrow-wrapper {
    .mat-mdc-select-arrow {
      width: 8px;
      height: 8px;
      border-left: 2px solid globals.$color-primary;
      border-bottom: 2px solid globals.$color-primary;
      border-right: none;
      border-top: none;
      transform: rotate(-45deg);
    }
  }
}
```

### Dialog

```scss
:host ::ng-deep {
  .mat-mdc-dialog-container {
    border-radius: globals.$border-radius-m;

    .mat-mdc-dialog-title {
      @include typography.h3-text();
      padding: globals.$padding-xbig;
    }

    .mat-mdc-dialog-content {
      padding: 0 globals.$padding-xbig;
      max-height: 80vh;
    }

    .mat-mdc-dialog-actions {
      padding: globals.$padding-big globals.$padding-xbig;
      gap: spacing.$space_xs;
    }
  }
}
```

### Tabs

```scss
:host ::ng-deep {
  .mat-mdc-tab-group {
    .mat-mdc-tab-header {
      border-bottom: globals.$border-thickness solid globals.$color-divider;
    }

    .mat-mdc-tab-body-content {
      padding: globals.$margin-large;
    }

    // Active tab indicator color
    .mdc-tab-indicator__content--underline {
      border-color: globals.$color-primary;
    }
  }
}
```

### Tooltip

```scss
// Global tooltip styling (in styles.scss or override file)
.mat-mdc-tooltip .mdc-tooltip__surface {
  background-color: globals.$color-secondary;
  @include typography.detail-text();
  border-radius: globals.$border-radius-xs;
  max-width: 300px;
}
```

## Shared mixins

```scss
@use 'src/assets/styles/mixins';

// Clickable row hover effect
@include mixins.clickable-row-mixin;

// Clickable hover (standalone)
@include mixins.clickable-hover-mixin;

// Stroked button (primary/secondary)
@include mixins.stroked-button;

// Button with icon
@include mixins.button-with-icon-start;

// Custom scrollbar
&::-webkit-scrollbar { @include mixins.scrollbar(); }
&::-webkit-scrollbar-track { @include mixins.scrollbar-track(); }
&::-webkit-scrollbar-thumb { @include mixins.scrollbar-thumb(); }
```

## Responsive design

### Breakpoints

```scss
@use '<design-system>/styles/global' as breakpoints;

// Mobile:           360px - 719px
// Tablet:           720px - 1023px
// Tablet Landscape: 1024px - 1279px
// Desktop:          1280px+
```

### Media query mixins

```scss
@use '<design-system>/styles/global' as breakpoints;

:host {
  .app-dashboard {
    display: grid;
    gap: spacing.$space_l;

    // Desktop: 3 columns
    @include breakpoints.for-desktop() {
      grid-template-columns: repeat(3, 1fr);
    }

    // Tablet landscape: 2 columns
    @include breakpoints.for-tablet-landscape() {
      grid-template-columns: repeat(2, 1fr);
    }

    // Tablet: 2 columns, tighter gap
    @include breakpoints.for-tablet() {
      grid-template-columns: repeat(2, 1fr);
      gap: spacing.$space_m;
    }

    // Mobile: single column
    @include breakpoints.for-mobile() {
      grid-template-columns: 1fr;
      gap: spacing.$space_s;
    }
  }
}
```

### Responsive container pattern

```scss
:host {
  .app-container {
    width: 100%;
    max-width: globals.$width-default-view; // e.g. 1200px
    margin-left: auto;
    margin-right: auto;
    padding: 0 globals.$padding-xbig;

    &--wide {
      max-width: globals.$width-max-view; // e.g. 1280px
    }

    &--narrow {
      max-width: globals.$width-narrow-view; // e.g. 960px
    }
  }
}
```

### Grid layout system

```scss
@use '<design-system>/styles/layout';

// 12-column responsive grid
:host {
  @include layout.container-grid(12, 58px, 24px); // Desktop
}

// Or manual grid
.app-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: spacing.$space_l;
}
```

## Layout patterns

### Page layout

```scss
:host {
  .app-page {
    display: flex;
    flex-direction: column;
    height: 100%;

    &__header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: globals.$padding-xbig;
      min-height: globals.$height-card-header;
      border-bottom: globals.$border-thickness solid globals.$color-divider;
    }

    &__content {
      flex: 1;
      overflow-y: auto;
      padding: globals.$padding-xbig;

      // Custom scrollbar
      &::-webkit-scrollbar { @include mixins.scrollbar(); }
      &::-webkit-scrollbar-track { @include mixins.scrollbar-track(); }
      &::-webkit-scrollbar-thumb { @include mixins.scrollbar-thumb(); }
    }

    &__footer {
      display: flex;
      justify-content: flex-end;
      gap: spacing.$space_xs;
      padding: globals.$padding-big;
      border-top: globals.$border-thickness solid globals.$color-divider;
    }
  }
}
```

### Sidebar layout

```scss
:host {
  .app-sidebar-layout {
    display: flex;
    height: 100%;

    &__sidebar {
      width: 280px;
      min-width: 280px;
      padding: globals.$padding-left-sidebar;
      border-right: globals.$border-thickness solid globals.$color-divider;
      overflow-y: auto;
    }

    &__main {
      flex: 1;
      padding: globals.$padding-right-sidebar;
      overflow-y: auto;
    }
  }
}
```

### Flex row with alignment

```scss
.app-row {
  display: flex;
  align-items: center;
  gap: spacing.$space_xs;

  &--between {
    justify-content: space-between;
  }

  &--end {
    justify-content: flex-end;
  }

  &--wrap {
    flex-wrap: wrap;
  }
}
```

### Center content (no data / empty state)

```scss
.app-empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: globals.$margin-xbig;
  margin-top: globals.$margin-top-no-data; // e.g. 6rem
  color: globals.$color-text-disabled;

  mat-icon {
    font-size: 48px;
    width: 48px;
    height: 48px;
    margin-bottom: spacing.$space_m;
  }
}
```

## ag-Grid theming

Applies when the project uses ag-Grid; skip otherwise.

### Custom theme

```scss
@use 'src/assets/styles/globals';

// Theme parameters
$app-grid-params: (
  background-color: globals.$color-row,
  odd-row-background-color: globals.$color-row-odd,
  header-background-color: globals.$color-background,
  font-family: Roboto,
  font-size: globals.$font-size,
  border-radius: globals.$border-radius,
  row-height: 50px,
  header-height: 50px,
  header-foreground-color: globals.$color-text,
  foreground-color: globals.$color-text,
  selected-row-background-color: colors.$color_lightInfo,
  range-selection-border-color: globals.$color-primary,
);
```

### Cell styling

```scss
:host ::ng-deep {
  .ag-theme-app {
    // Row hover
    .ag-row:hover {
      background-color: globals.$color-hover-background;
    }

    // Cell padding
    .ag-cell {
      padding: 0 spacing.$space_xs;
      display: flex;
      align-items: center;
    }

    // Header styling
    .ag-header-cell {
      font-weight: globals.$font-bold;
      text-transform: uppercase;
      font-size: typography.$font-size-xs;
    }

    // Conflicting row highlight
    .ag-row.row-conflicting {
      background-color: globals.$color-row-conflicting;
    }
  }
}
```

## Data visualization colors

### Chart color palette

```scss
// Sequential palette for charts
$chart-colors: (
  globals.$color-blue,
  globals.$color-green,
  globals.$color-orange,
  globals.$color-red,
  globals.$color-purple,
  globals.$color-yellow,
  globals.$color-green-dark,
);

// Temperature scale (quantitative, best → worst)
$temperature-scale: (
  good: colors.$color_veryGood,
  moderate: colors.$color_good,
  neutral: colors.$color_regular,
  poor: colors.$color_bad,
  critical: colors.$color_veryBad,
);
```

### Severity badge colors

```scss
.app-severity {
  display: inline-flex;
  align-items: center;
  padding: spacing.$space_2xs spacing.$space_xs;
  border-radius: globals.$border-radius-xs;
  @include typography.detail-text();
  font-weight: globals.$font-bold;

  &--critical {
    color: colors.$color_veryBad;
    background-color: colors.$color_lightError;
  }

  &--high {
    color: colors.$color_bad;
    background-color: rgba(colors.$color_bad, 0.1);
  }

  &--medium {
    color: colors.$color_regular;
    background-color: colors.$color_lightInfo;
  }

  &--low {
    color: colors.$color_good;
    background-color: colors.$color_lightOk;
  }

  &--ok {
    color: colors.$color_veryGood;
    background-color: colors.$color_lightOk;
  }
}
```

## Animation patterns

### Transition utilities

```scss
// Standard transition
$transition-fast: 150ms ease-in-out;
$transition-default: 200ms ease-in-out;
$transition-slow: 300ms ease-in-out;

// Hover transitions
.app-card--clickable {
  transition: background-color $transition-fast,
              box-shadow $transition-default;

  &:hover {
    background-color: colors.$paletteGrey95;
    box-shadow: 0px 2px 16px rgba(0, 0, 0, 0.16);
  }
}

// Expand/collapse
.app-collapsible {
  overflow: hidden;
  transition: max-height $transition-slow;

  &--collapsed {
    max-height: 0;
  }

  &--expanded {
    max-height: 1000px;
  }
}
```

### Loading skeleton

```scss
.app-skeleton {
  background: linear-gradient(
    90deg,
    globals.$color-input-bg 25%,
    colors.$color_lightGrey 50%,
    globals.$color-input-bg 75%
  );
  background-size: 200% 100%;
  animation: shimmer 1.5s infinite;
  border-radius: globals.$border-radius-xs;

  &--text {
    height: 14px;
    width: 60%;
    margin-bottom: spacing.$space_xs;
  }

  &--title {
    height: 24px;
    width: 40%;
    margin-bottom: spacing.$space_m;
  }

  &--avatar {
    height: 40px;
    width: 40px;
    border-radius: 50%;
  }
}

@keyframes shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

## Dark mode support

The design system uses the `light-dark()` CSS function for automatic dark
mode:

```scss
// CSS variables with light/dark support
:root {
  --color_shadow: 0px 0px 12px 0px light-dark(
    rgba(0, 0, 0, 0.12),
    rgba(69, 69, 69, 1)
  );
}

// Dynamic palette colors (auto-switch)
colors.$lightDarkPrimary0    // through $lightDarkPrimary100
colors.$lightDarkGrey0       // through $lightDarkGrey100
colors.$lightDarkError0      // through $lightDarkError100
```

## Utility classes

### Available global utilities (from styles.scss)

```scss
// Margins
.margin              // 5px all
.margin-left         // 5px left
.margin-right        // 5px right
.margin-top          // 5px top
.margin-bottom       // 5px bottom

// Padding
.padding             // 5px all
.padding-left        // 5px left
.padding-right       // 5px right
.padding-top         // 5px top
.padding-bottom      // 5px bottom

// Text alignment
.align-right
.align-left

// Font styles
.font-italic
.font-error          // Error color + bold

// Layout
.width-all           // width: 100%
```

### Input row pattern (label + value)

```scss
// Used for form-like read-only displays
.input-row {
  color: globals.$color-text;

  label {
    font-weight: globals.$font-width;

    &:after {
      content: ':';
    }
  }
}
```

## Z-index scale

```scss
$z-index-options: 10;      // Dropdowns, tooltips
$z-index-login: 15;        // Login overlay
// Material dialog: 1000 (framework default)
// Material snackbar: 1001
```

## File organization

```
src/
├── styles.scss                           # Root: global styles & utilities
└── assets/styles/
    ├── _globals.scss                     # App variables, colors, spacing
    ├── _palette.scss                     # Material color palette
    ├── styles.scss                       # Aggregator (imports all)
    ├── mixins.scss                       # Shared mixins
    └── overrides/
        ├── ag-grid.override.scss         # ag-Grid theme
        ├── mat-table.override.scss       # Material Table
        ├── select.override.scss          # Material Select
        └── ...                           # Other library overrides

<design-system package>/styles/
├── _colors.scss                          # Color palettes & CSS vars
├── _typography.scss                      # Font sizes & mixins
├── _spacing.scss                         # Spacing scale
├── _global.scss                          # Breakpoints & media queries
├── _layout.scss                          # Grid system
└── overrides/                            # Material overrides
```

## Naming conventions

- **Component root class:** `.app-feature-name` (the project's class prefix)
- **BEM blocks:** `.app-feature-name__section__element`
- **BEM modifiers:** `.app-feature-name--variant`
- **State classes:** `.is-active`, `.is-disabled`, `.is-loading`
- **SCSS variables:** `$kebab-case` (e.g., `$card-width`)

## Key rules

1. Always use `:host` as the root scope
2. Prefer design tokens over hardcoded values
3. Use `globals.$` for app-specific values, `spacing.$`/`typography.$`/`colors.$` for design-system tokens
4. Use BEM naming with the project's class prefix
5. Avoid `!important` except in global utility classes
6. Use `::ng-deep` only when necessary, always scoped with `:host`
7. Define component-local variables at the top of the file

## Quick reference

| Need | Use |
|------|-----|
| Primary color | `globals.$color-primary` |
| Text color | `globals.$color-text` |
| Background | `globals.$color-background` |
| Card bg | `globals.$color-surface` |
| Shadow | `colors.$shadow` |
| Border radius | `globals.$border-radius` |
| Standard gap | `spacing.$space_l` |
| Body padding | `globals.$padding-xbig` |
| Small gap | `spacing.$space_xs` |
| Font size body | `typography.$font-size-m` |
| Font size small | `typography.$font-size-s` |
| Font bold | `globals.$font-bold` |
| Hover bg | `colors.$paletteGrey95` |
| Divider | `globals.$color-divider` |
