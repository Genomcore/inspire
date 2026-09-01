# Tooling

Angular CLI and development tooling: project setup, code generation, dev
server, builds, tests, linting, workspace configuration, budgets, path
aliases, proxies, and CI examples.

## Project setup

### Create a new project

```bash
# Create new standalone project (default since v17)
ng new my-app

# With specific options
ng new my-app --style=scss --routing --ssr=false

# Skip tests
ng new my-app --skip-tests

# Minimal setup
ng new my-app --minimal --inline-style --inline-template
```

### Project structure

```
my-app/
├── src/
│   ├── app/
│   │   ├── app.component.ts
│   │   ├── app.config.ts
│   │   └── app.routes.ts
│   ├── index.html
│   ├── main.ts
│   └── styles.scss
├── public/                  # Static assets
├── angular.json             # CLI configuration
├── package.json
├── tsconfig.json
└── tsconfig.app.json
```

## Code generation

### Components

```bash
# Generate component
ng generate component features/user-profile
ng g c features/user-profile  # Short form

# With options
ng g c shared/button --inline-template --inline-style
ng g c features/dashboard --skip-tests
ng g c features/settings --change-detection=OnPush

# Flat (no folder)
ng g c shared/icon --flat

# Dry run (preview)
ng g c features/checkout --dry-run
```

### Services

```bash
# Generate service (providedIn: 'root' by default)
ng g service services/auth
ng g s services/user

# Skip tests
ng g s services/api --skip-tests
```

### Other schematics

```bash
# Directive
ng g directive directives/highlight
ng g d directives/tooltip

# Pipe
ng g pipe pipes/truncate
ng g p pipes/date-format

# Guard (functional by default)
ng g guard guards/auth

# Interceptor (functional by default)
ng g interceptor interceptors/auth

# Interface
ng g interface models/user

# Enum
ng g enum models/status

# Class
ng g class models/product
```

## Development server

```bash
# Start dev server
ng serve
ng s  # Short form

# With options
ng serve --port 4201
ng serve --open  # Open browser
ng serve --host 0.0.0.0  # Expose to network

# Production mode locally
ng serve --configuration=production

# With SSL
ng serve --ssl --ssl-key ./ssl/key.pem --ssl-cert ./ssl/cert.pem
```

## Building

### Development build

```bash
ng build
```

### Production build

```bash
ng build --configuration=production
ng build -c production  # Short form

# With specific options
ng build -c production --source-map=false
ng build -c production --named-chunks
```

### Build output

```
dist/my-app/
├── browser/
│   ├── index.html
│   ├── main-[hash].js
│   ├── polyfills-[hash].js
│   └── styles-[hash].css
└── server/              # If SSR enabled
    └── main.js
```

## Testing

### Unit tests

```bash
# Run tests
ng test
ng t  # Short form

# Single run (CI)
ng test --watch=false --browsers=ChromeHeadless

# With coverage
ng test --code-coverage

# Specific file
ng test --include=**/user.service.spec.ts
```

### E2E tests

```bash
# Run e2e (if configured)
ng e2e
```

## Linting

```bash
# Run linter
ng lint

# Fix auto-fixable issues
ng lint --fix
```

## Configuration

### angular.json key sections

```json
{
  "projects": {
    "my-app": {
      "architect": {
        "build": {
          "builder": "@angular-devkit/build-angular:application",
          "options": {
            "outputPath": "dist/my-app",
            "index": "src/index.html",
            "browser": "src/main.ts",
            "polyfills": ["zone.js"],
            "tsConfig": "tsconfig.app.json",
            "assets": ["{ \"glob\": \"**/*\", \"input\": \"public\" }"],
            "styles": ["src/styles.scss"],
            "scripts": []
          },
          "configurations": {
            "production": {
              "budgets": [
                {
                  "type": "initial",
                  "maximumWarning": "500kB",
                  "maximumError": "1MB"
                }
              ],
              "outputHashing": "all"
            },
            "development": {
              "optimization": false,
              "extractLicenses": false,
              "sourceMap": true
            }
          }
        }
      }
    }
  }
}
```

### Environment configuration

```typescript
// src/environments/environment.ts
export const environment = {
  production: false,
  apiUrl: 'http://localhost:3000/api',
};

// src/environments/environment.prod.ts
export const environment = {
  production: true,
  apiUrl: 'https://api.example.com',
};
```

Configure in angular.json:

```json
{
  "configurations": {
    "production": {
      "fileReplacements": [
        {
          "replace": "src/environments/environment.ts",
          "with": "src/environments/environment.prod.ts"
        }
      ]
    }
  }
}
```

## Adding libraries

### Angular libraries

```bash
# Add Angular Material
ng add @angular/material

# Add Angular PWA
ng add @angular/pwa

# Add Angular SSR
ng add @angular/ssr

# Add Angular Localize
ng add @angular/localize
```

### Third-party libraries

```bash
# Install and configure
npm install @ngrx/signals

# Some libraries have schematics
ng add @ngrx/store
```

## Updating Angular

```bash
# Check for updates
ng update

# Update Angular core and CLI
ng update @angular/core @angular/cli

# Update all packages
ng update --all

# Force update (skip peer dependency checks)
ng update @angular/core @angular/cli --force
```

## Performance analysis

```bash
# Build with stats
ng build -c production --stats-json

# Analyze bundle (install esbuild-visualizer)
npx esbuild-visualizer --metadata dist/my-app/browser/stats.json --open
```

## Caching

```bash
# Enable persistent build cache (default since v17)
# Configured in angular.json:
{
  "cli": {
    "cache": {
      "enabled": true,
      "path": ".angular/cache",
      "environment": "all"
    }
  }
}

# Clear cache
rm -rf .angular/cache
```

## Custom schematics

### Generate a schematic collection

```bash
# Install schematics CLI
npm install -g @angular-devkit/schematics-cli

# Create schematic collection
schematics blank --name=my-schematics
```

### Simple component schematic

```typescript
// src/my-component/index.ts
import { Rule, SchematicContext, Tree, apply, url, template, move, mergeWith } from '@angular-devkit/schematics';
import { strings } from '@angular-devkit/core';

export function myComponent(options: { name: string; path: string }): Rule {
  return (tree: Tree, context: SchematicContext) => {
    const templateSource = apply(url('./files'), [
      template({
        ...options,
        ...strings,
      }),
      move(options.path),
    ]);

    return mergeWith(templateSource)(tree, context);
  };
}
```

### Use custom schematics

```bash
# Link locally
npm link ./my-schematics

# Use
ng generate my-schematics:my-component --name=test --path=src/app
```

## Build optimization

### Budget configuration

```json
{
  "budgets": [
    {
      "type": "initial",
      "maximumWarning": "500kB",
      "maximumError": "1MB"
    },
    {
      "type": "anyComponentStyle",
      "maximumWarning": "4kB",
      "maximumError": "8kB"
    },
    {
      "type": "anyScript",
      "maximumWarning": "100kB",
      "maximumError": "200kB"
    }
  ]
}
```

### Browser targets

Modern Angular builds for modern browsers by default:

```
# .browserslistrc
last 2 Chrome versions
last 2 Firefox versions
last 2 Safari versions
last 2 Edge versions
```

### Code splitting

```typescript
// Lazy load routes for automatic code splitting
export const routes: Routes = [
  {
    path: 'admin',
    loadChildren: () => import('./admin/admin.routes').then(m => m.adminRoutes),
  },
  {
    path: 'reports',
    loadComponent: () => import('./reports/reports.component').then(m => m.Reports),
  },
];
```

### Tree shaking

Ensure proper imports for tree shaking:

```typescript
// Good - tree shakeable
import { map, filter } from 'rxjs';

// Avoid - imports entire library
import * as rxjs from 'rxjs';
```

### Preload strategy

```typescript
// app.config.ts
import { provideRouter, withPreloading, PreloadAllModules } from '@angular/router';

export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes, withPreloading(PreloadAllModules)),
  ],
};
```

## Multi-project workspace

### Create a workspace

```bash
# Create empty workspace
ng new my-workspace --create-application=false

cd my-workspace

# Add applications
ng generate application main-app
ng generate application admin-app

# Add library
ng generate library shared-ui
ng generate library data-access
```

### Workspace structure

```
my-workspace/
├── projects/
│   ├── main-app/
│   │   └── src/
│   ├── admin-app/
│   │   └── src/
│   ├── shared-ui/
│   │   └── src/
│   └── data-access/
│       └── src/
├── angular.json
└── package.json
```

### Build a specific project

```bash
ng build main-app
ng build shared-ui
ng serve admin-app
```

### Library configuration

```json
// projects/shared-ui/ng-package.json
{
  "$schema": "../../node_modules/ng-packagr/ng-package.schema.json",
  "dest": "../../dist/shared-ui",
  "lib": {
    "entryFile": "src/public-api.ts"
  }
}
```

### Using a library in an app

```typescript
// After building library: ng build shared-ui
import { Button } from 'shared-ui';

@Component({
  imports: [Button],
  template: `<lib-button>Click</lib-button>`,
})
export class App {}
```

## CI configuration

### GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm run test -- --watch=false --browsers=ChromeHeadless --code-coverage

      - name: Build
        run: npm run build -- -c production
```

### GitLab CI

```yaml
# .gitlab-ci.yml
image: node:20

cache:
  paths:
    - node_modules/
    - .angular/cache/

stages:
  - install
  - test
  - build

install:
  stage: install
  script:
    - npm ci

test:
  stage: test
  script:
    - npm run lint
    - npm run test -- --watch=false --browsers=ChromeHeadless

build:
  stage: build
  script:
    - npm run build -- -c production
  artifacts:
    paths:
      - dist/
```

## Path aliases

### Configure tsconfig.json

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@app/*": ["src/app/*"],
      "@env/*": ["src/environments/*"],
      "@shared/*": ["src/app/shared/*"],
      "@features/*": ["src/app/features/*"],
      "@core/*": ["src/app/core/*"]
    }
  }
}
```

### Usage

```typescript
// Instead of relative imports
import { User } from '../../../core/services/user.service';

// Use path alias
import { User } from '@core/services/user.service';
```

## Proxy configuration

### Development proxy

```json
// proxy.conf.json
{
  "/api": {
    "target": "http://localhost:3000",
    "secure": false,
    "changeOrigin": true
  },
  "/auth": {
    "target": "http://localhost:4000",
    "secure": false,
    "pathRewrite": {
      "^/auth": ""
    }
  }
}
```

### Configure in angular.json

```json
{
  "serve": {
    "options": {
      "proxyConfig": "proxy.conf.json"
    }
  }
}
```

### Or via CLI

```bash
ng serve --proxy-config proxy.conf.json
```

## Custom builders

### Using esbuild (default for new projects since v17)

The `application` builder uses esbuild by default. Existing projects may
still use `@angular-builders/custom-webpack` or
`@angular-devkit/build-angular:browser`. Both remain supported.

```json
{
  "architect": {
    "build": {
      "builder": "@angular-devkit/build-angular:application",
      "options": {
        "browser": "src/main.ts"
      }
    }
  }
}
```

### SSR configuration

```bash
# Add SSR
ng add @angular/ssr
```

```json
{
  "architect": {
    "build": {
      "options": {
        "server": "src/main.server.ts",
        "prerender": true,
        "ssr": {
          "entry": "server.ts"
        }
      }
    }
  }
}
```

## Debugging

### Source maps

```json
{
  "configurations": {
    "development": {
      "sourceMap": true
    },
    "production": {
      "sourceMap": {
        "scripts": true,
        "styles": false,
        "hidden": true,
        "vendor": false
      }
    }
  }
}
```

### Verbose logging

```bash
ng build --verbose
ng serve --verbose
```

### Debug tests

```bash
# Run tests with debugging
ng test --browsers=Chrome

# In Chrome DevTools, open Sources tab and set breakpoints
```

## Package scripts

```json
{
  "scripts": {
    "start": "ng serve",
    "build": "ng build",
    "build:prod": "ng build -c production",
    "test": "ng test",
    "test:ci": "ng test --watch=false --browsers=ChromeHeadless --code-coverage",
    "lint": "ng lint",
    "lint:fix": "ng lint --fix",
    "analyze": "ng build -c production --stats-json && npx esbuild-visualizer --metadata dist/my-app/browser/stats.json --open",
    "update": "ng update"
  }
}
```
