# FEAT-01: Inicio de sesión del operador

**State:** 🟡 Planned
**Priority:** Core

## Actor: Actor
Operador

## Preconditions: Precondiciones
El operador tiene una cuenta.

## Main flow: Flujo principal
1. El operador envía correo y contraseña.
2. El sistema emite una sesión.

## Alternative flows: Flujos alternativos
### AF-1: Ya ha iniciado sesión

## Error flows: Flujos de error
### EF-1: Contraseña incorrecta

## Postconditions: Postcondiciones
Existe una sesión para el operador.

## Acceptance criteria: Criterios de aceptación
- [ ] AC-1: Un correo y una contraseña válidos producen una sesión.
