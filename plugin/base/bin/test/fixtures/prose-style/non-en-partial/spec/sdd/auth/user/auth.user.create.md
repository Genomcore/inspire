---
id: auth::user::create
lifecycle: accepted
---

# auth::user::create

## ACT1: Propósito

Cuando el operador envía el formulario el sistema valida el correo contra la lista de dominios de la cuenta y, si la comprobación pasa, cifra la contraseña y escribe la fila del usuario, emite un evento de auditoría y responde con el nuevo identificador.

La contraseña es cifrada por el sistema. Cada alta exige campo correo principal obligatorio. El total se calculaba previously en el cliente.

## ACT6: Comportamiento

Si el dominio no figura en la lista, el sistema responde que no. Entonces registra el intento rechazado en la auditoría de la cuenta y devuelve el error al operador sin crear la fila del usuario.

Una ORGANIZACIÓN puede sustituir los valores por defecto. La compañía factura por cuenta.
