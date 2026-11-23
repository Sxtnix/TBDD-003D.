# Fazbear Pizza · Evaluación Parcial 3

Modelo documental de pedidos con un listado de trabajo por local y un resumen de montos en CLP. Usa la base `fazbear_pizza_ev3` y la colección `pedidos`.

## Ejecutar en MongoDB for VS Code

1. Abre esta carpeta en VS Code. En **MongoDB for VS Code**, agrega y activa la conexión al clúster de pruebas de MongoDB Atlas. La cuenta requiere permiso de escritura y de creación de la colección y sus índices en `fazbear_pizza_ev3`.
2. Abre [01_carga.mongodb.js](MongoDB/01_carga.mongodb.js) y pulsa **Run All From Playground** (▶). Crea la colección validada y carga ocho pedidos ficticios. Al repetir la carga se insertan solo los faltantes.
3. Ejecuta [02_crud.mongodb.js](MongoDB/02_crud.mongodb.js). La demo crea sus propios documentos, comprueba las operaciones y limpia el lote usando su identificador y `esPrueba: true`.
4. Ejecuta [03_consultas_y_resumen.mongodb.js](MongoDB/03_consultas_y_resumen.mongodb.js). Revisa las salidas en **Output** de VS Code.

## Resultados del conjunto de referencia

El pedido temporal parte en 12.000 CLP y sube a 24.000 CLP tras aumentar la cantidad. Una vez cancelado, el comando de reactivación encuentra cero coincidencias. El borrado comprueba que quedan cero documentos del lote temporal.

Con los ocho pedidos iniciales, noviembre de 2026 suma **72.000 CLP en cinco pedidos no cancelados**. Puerto Montt suma 42.000 CLP y Puerto Varas, 30.000 CLP. El histórico suma 86.000 CLP. Los montos incluyen los estados `P`, `X` y `E`, según el criterio de la EV2. Las consultas excluyen los datos temporales.

Los montos corresponden a la carga original. Conserva la URI de conexión en la extensión de VS Code y fuera del repositorio.
