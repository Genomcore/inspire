# FEAT-01: Inicio de sesión del operador

Un operador registrado inicia sesión.

**State:** 🟡 Planned
**Priority:** Core

## UC1: Actor
Un operador registrado.

## UC2: Precondiciones
- `P1` — La cuenta existe y no está suspendida.

## UC3: Flujo principal
1. `B1` — El operador envía sus credenciales.
2. `B2` — El sistema las verifica.

## UC4: Flujos alternativos
### AF-1: Un dispositivo recordado

## UC5: Flujos de error
### EF-1: Una contraseña incorrecta

## UC6: Postcondiciones
- `Q1` — Existe una sesión para el operador.

## UC7: Criterios de aceptación
- [ ] AC-1: Un par correcto produce una sesión.
