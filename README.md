# TBDD-003D.

Evaluación Parcial N°2 del ramo **BDY1103 — Bases de Datos**, correspondiente al caso práctico **FAZBEAR PIZZA**.

El objetivo de esta entrega es demostrar el manejo de objetos de programación en **PL/SQL**: procedimientos, funciones, packages y triggers, junto con sus pruebas de funcionamiento.

---

## Estructura del repositorio

| Archivo | Descripción |
|---|---|
| `README.md` | Documentación del proyecto (este archivo). |
| `PLSQL_FAZBEAR.sql` | Script principal: creación de todos los objetos PL/SQL y sus pruebas. |
| `texto y plsql.txt` | Origen del script (mismo contenido que `PLSQL_FAZBEAR.sql`). |

---

## Requisitos previos

Antes de ejecutar `PLSQL_FAZBEAR.sql` es necesario contar con:

1. Una base de datos **Oracle** accesible (Oracle XE, Live SQL, SQL Developer, SQL\*Plus, etc.).
2. Un usuario con permisos para crear objetos:
   `CREATE PROCEDURE`, `CREATE FUNCTION`, `CREATE PACKAGE`, `CREATE TRIGGER`, `CREATE TABLE`, `CREATE SEQUENCE`.
3. Ejecutar en orden los scripts previos (no incluidos en este repositorio):

   1. `FIX_BD_FAZBEAR.sql` → estructura de tablas e índices.
   2. `PLSQL_FAZBEAR_PIZZA.sql` → datos de prueba (clientes, locales, empleados, productos, inventario y pedidos).

---

## Orden de ejecución

```text
1. FIX_BD_FAZBEAR.sql
2. PLSQL_FAZBEAR_PIZZA.sql
3. PLSQL_FAZBEAR.sql
```

Desde SQL\*Plus o SQL Developer:

```sql
@FIX_BD_FAZBEAR.sql
@PLSQL_FAZBEAR_PIZZA.sql
@PLSQL_FAZBEAR.sql
```

> El script comienza con `SET SERVEROUTPUT ON` para habilitar la salida de `DBMS_OUTPUT`
> y utiliza `SHOW ERRORS` tras cada objeto para detectar errores de compilación.

---

## Tablas utilizadas

| Tabla | Uso |
|---|---|
| `Cliente` | Validación del cliente del pedido. |
| `Local` | Validación del local del pedido. |
| `Empleado` | Validación del empleado que registra. |
| `Producto` | Precio, estado y vínculo con inventario. |
| `Inventario` | Stock actual y stock mínimo. |
| `Pedido` | Cabecera del pedido (fecha, estado, total). |
| `detalle_pedido` | Líneas del pedido (cantidad, precio, subtotal). |
| `Auditoria_Pedido` | **Creada por el script**, almacena la auditoría de `Pedido`. |

Secuencias requeridas: `seq_pedido`, `seq_detalle_pedido`.
Secuencia creada por el script: `seq_auditoria_pedido`.

---

## Objetos creados por el script

### 1. Procedimientos

| Nombre | Parámetros | Descripción |
|---|---|---|
| `SP_LIQUIDAR_MES` | `p_mes`, `p_anio`, `p_total OUT` | Suma el total vendido en un mes y año determinados, ignorando pedidos cancelados. Valida que el mes esté entre 1 y 12. |
| `SP_REVISAR_STOCK_CRITICO` | ninguno | Recorre con un cursor explícito los productos cuyo stock actual es menor o igual al stock mínimo y los muestra por pantalla. |

### 2. Funciones

| Nombre | Parámetros | Descripción |
|---|---|---|
| `FN_CALCULAR_DESCUENTO` | `p_total`, `p_tipo_cliente` | Devuelve el **monto** del descuento: tipo 1 (REGULAR) = 0%, tipo 2 (VIP) = 10%. |
| `FN_TOTAL_VENTAS` | ninguno | Devuelve el total histórico vendido, ignorando pedidos cancelados. |

Ambas funciones pueden invocarse desde SQL y desde PL/SQL.

### 3. Package `PKG_GESTION_PEDIDOS`

**Elementos públicos** (visibles desde fuera del package):

| Elemento | Tipo | Descripción |
|---|---|---|
| `REGISTRAR_PEDIDO` | Procedimiento | Valida cliente, local y empleado; crea el pedido con estado `P` y devuelve el ID generado. |
| `AGREGAR_DETALLE` | Procedimiento | Valida cantidad, pedido y producto; valida stock, descuenta inventario y actualiza el total. |
| `OBTENER_TOTAL_PEDIDO` | Función | Retorna el total actual de un pedido. |

**Elementos privados** (solo visibles dentro del package):

| Elemento | Tipo | Descripción |
|---|---|---|
| `VALIDAR_STOCK` | Procedimiento | Verifica que exista stock suficiente antes de insertar el detalle. |
| `CALCULAR_SUBTOTAL` | Función | Calcula `cantidad * precio`. |

### 4. Triggers

| Nombre | Nivel | Descripción |
|---|---|---|
| `TGR_VALIDAR_ESTADO_PEDIDO` | **Fila** (`FOR EACH ROW`) | `BEFORE UPDATE OF estado` sobre `Pedido`. Solo permite los estados `P`, `X`, `E`, `C` e impide que un pedido cancelado vuelva a estar activo. Usa `:OLD` y `:NEW`. |
| `TGR_AUDITAR_PEDIDOS` | **Sentencia** (sin `FOR EACH ROW`) | `AFTER INSERT OR UPDATE OR DELETE` sobre `Pedido`. Registra una sola fila en `Auditoria_Pedido` por sentencia SQL, sin importar cuántas filas afecte. |

---

## Pruebas incluidas

| Prueba | Qué verifica |
|---|---|
| 1 | `SP_LIQUIDAR_MES` con mes/año actuales. |
| 2 | `SP_REVISAR_STOCK_CRITICO` y su listado de productos. |
| 3 | `FN_CALCULAR_DESCUENTO` invocada desde SQL. |
| 4 | `FN_CALCULAR_DESCUENTO` invocada desde PL/SQL. |
| 5 | `FN_TOTAL_VENTAS` invocada desde SQL. |
| 6 | `FN_TOTAL_VENTAS` invocada desde PL/SQL. |
| 7 | Package completo: registrar pedido → agregar 2 productos → descontar inventario → consultar total. |
| 8 | Error de stock: se solicitan 999 unidades y se espera `ORA-20001`. |
| 9 | Trigger de fila: cancelar un pedido y tratar de reactivarlo (luego `ROLLBACK` al savepoint). |
| 10 | Trigger de sentencia: un solo `UPDATE` que afecta varias filas genera **un solo** registro de auditoría. |

Al final se ejecutan consultas de verificación sobre `Pedido`, `detalle_pedido`,
`Inventario`, `Auditoria_Pedido` y `user_objects` (todos los objetos deben aparecer como `VALID`).

---

## Códigos de error personalizados

| Código | Mensaje |
|---|---|
| `ORA-20001` | Stock insuficiente. |
| `ORA-20002` | El producto no existe en el inventario. |
| `ORA-20003` | El cliente indicado no existe. |
| `ORA-20004` | El local indicado no existe. |
| `ORA-20005` | El empleado indicado no existe. |
| `ORA-20006` | La cantidad debe ser mayor que cero. |
| `ORA-20007` | El pedido indicado no existe. |
| `ORA-20008` | No se pueden agregar productos a un pedido cancelado. |
| `ORA-20009` | El producto no existe o se encuentra inactivo. |
| `ORA-20010` | El pedido indicado no existe (al consultar el total). |
| `ORA-20011` | Estado de pedido inválido. |
| `ORA-20012` | Un pedido cancelado no puede volver a activarse. |
| `ORA-20020` | El mes debe estar entre 1 y 12. |
| `ORA-20021` | El total no puede ser negativo. |

---

## Notas

- Los procedimientos, funciones, packages y triggers usan `CREATE OR REPLACE`, por lo que el script es reproejecutable.
- `Auditoria_Pedido` y `seq_auditoria_pedido` se crean con `CREATE TABLE` / `CREATE SEQUENCE`: si ya existen, esas sentencias devolverán `ORA-00955` / `ORA-00956` (se puede comentar esa sección en la segunda ejecución).
- Las pruebas 7 y 10 ejecutan `COMMIT`; la prueba 9 usa `SAVEPOINT`/`ROLLBACK` para no alterar los datos.
- Código fuente original: `texto y plsql.txt`.
