# Fazbear Pizza — Evaluación Parcial N.º 2

**BDY1103 — Taller de Base de Datos · Sección 003D**  
**Integrantes:** Vicente Placencia, Diego Díaz y Gabriel Vargas.

Solución de gestión de pedidos y reportes mediante procedimientos, funciones, un package con miembros públicos y privados y triggers de fila y de sentencia.

## Estado de la entrega

**Entrega autorizada para publicación por Vicente, con pruebas de consulta e integración completadas y documentación actualizada.**

Se comprobó en Oracle del equipo que las ocho entradas de los objetos EV2 están en `VALID` y que la consulta de errores de compilación no devuelve filas. También se ejecutaron las pruebas de consulta y la prueba integrada del package y los triggers, con aserciones y reversión comprobada de los datos utilizados. Esto no equivale a haber cubierto concurrencia ni todos los casos límite.

## Estructura

```text
Documentacion/
├── Informe_EV2_Fazbear_Pizza_Breve.docx
├── Fazbear_Pizza_PPT_FNAF_pixel_total.pptx
└── Evidencias/
    └── capturas PNG
Plsql/
├── FIX_BD_FAZBEAR.sql
├── DATOS_FAZBEAR.sql
├── PLSQL_FAZBEAR_PARCIAL2.sql
└── Validacion/
    ├── 01_DIAGNOSTICO.sql
    ├── 02_REVISION_PREVIA.sql
    ├── 03_PRUEBAS_CONSULTA.sql
    └── 04_PRUEBAS_PEDIDOS.sql
README.md
```

El informe conserva la maquetación revisada por Vicente. Con su autorización se actualizaron únicamente textos del informe y del PPT para reflejar las ejecuciones reales, sin alterar estilos, tablas, imágenes, saltos ni posiciones. Los tres scripts principales se conservan tal como se recibieron en el ZIP. Las imágenes se entregan por separado para mantener breve el informe. No se incluyen instaladores de fuentes ni credenciales.

## Entorno comprobado

- Oracle ejecutado en Docker; conexión desde VS Code con extensión Oracle.
- Usuario y esquema de las capturas: `FNAF`.
- Contenedor Oracle de la sesión: `FREEPDB1`.
- Versión devuelta por el motor: `Oracle AI Database 26ai Free Release 23.26.2.0.0` (log de pruebas de consulta).

## Archivos SQL y ejecución

| Archivo | Contenido |
|---|---|
| `FIX_BD_FAZBEAR.sql` | Creación de las 16 tablas base y las secuencias de pedidos y detalles; incluye limpieza destructiva. |
| `DATOS_FAZBEAR.sql` | Carga inicial de entidades y un pedido histórico. |
| `PLSQL_FAZBEAR_PARCIAL2.sql` | Objetos de EV2, tabla y secuencia de auditoría, y diez pruebas. |
| `Validacion/` | Consultas auxiliares para documentar la revisión y validación. |

**Advertencia:** `FIX_BD_FAZBEAR.sql` contiene `DROP TABLE ... PURGE`. No ejecutarlo sobre información que deba conservarse. `DATOS_FAZBEAR.sql` no es una carga idempotente. El script principal incluye pruebas que modifican datos y hacen `COMMIT`.

En un esquema de pruebas nuevo, el orden previsto es estructura, datos y objetos/pruebas. En una base existente se deben revisar primero tablas, datos, secuencias y triggers. No repetir el proceso completo sin analizar el estado actual. La tabla y secuencia de auditoría no se limpian en el script base.

En la sesión documentada se conservó la estructura y los datos de EV1. Se ejecutó únicamente la definición de objetos de EV2, hasta el último `SHOW ERRORS` anterior a la sección de pruebas.

## Objetos de EV2

| Objeto | Finalidad |
|---|---|
| `SP_LIQUIDAR_MES` | Acumulado de pedidos no cancelados para un mes y año, mediante OUT. |
| `SP_REVISAR_STOCK_CRITICO` | Listado de productos con saldo menor o igual al mínimo. |
| `FN_CALCULAR_DESCUENTO` | Monto de descuento del 10% para tipo VIP 2; no aplica el descuento al pedido. |
| `FN_TOTAL_VENTAS` | Acumulado de todos los pedidos no cancelados, incluidos pendientes. |
| `PKG_GESTION_PEDIDOS` | Registrar cabecera, agregar detalle y consultar total; cuenta con auxiliares privados. |
| `TGR_VALIDAR_ESTADO_PEDIDO` | Validar actualizaciones de estado e impedir reactivación de cancelados. |
| `TGR_AUDITAR_PEDIDOS` | Registrar una entrada por sentencia INSERT, UPDATE o DELETE sobre Pedido. |

Siete nombres producen ocho entradas en `USER_OBJECTS`, al contar `PACKAGE` y `PACKAGE BODY` por separado.

## Evidencias disponibles

Todas están en [Documentacion/Evidencias](Documentacion/Evidencias). Se mantienen los nombres originales del registro del equipo.

| Captura | Qué respalda |
|---|---|
| `01_conexion.png` | Usuario, esquema, contenedor y fecha de la sesión. |
| `02_tablas.png` | Existencia de las 16 tablas base antes de EV2. |
| `03_estado_objetos.png` y `04_errores_compilacion.png` | Estado previo: solo package anterior; no certifican instalación EV2 completa. |
| `05_datos_Existentes.png` | Conteos de los registros iniciales. |
| `06_secuencias_existentes.png` | Existencia de las secuencias; LAST_NUMBER con caché no equivale al próximo ID. |
| `07_Columnas_modelo.png` | Vista parcial de columnas; la captura no muestra las 50 filas completas. |
| `08_0_Package_actual.png` y `08_1_Package_Actual_2.png` | Fuente visible del package anterior al reemplazo. |
| `09_Triggers_existentes.png` | Trigger de duplicados activo heredado de EV1. |
| `10_0_resumen_pedido.png`, `10_1_resumen_inventario.png`, `10_2_resumen_stock.png` | Datos anteriores a las pruebas; contrastar el contenido de cada imagen, no solo el nombre. |
| `11_text_format_trgr.png` | Fuente del trigger antiguo de duplicados. |
| `12_validar_funcionamiento_mitad_plsql.png` | Instalación y compilación de objetos; pese al nombre, no demuestra funcionamiento. |
| `13_objetos_ev2_valid.png` | Ocho entradas de EV2 en VALID. |
| `14_errores_ev2.png` | Consulta de errores de los objetos EV2 sin filas. |
| `15_pruebas_consulta.txt.txt` | Ejecución real: mes actual 0; septiembre 2026 e histórico 12.000; stock 50 no crítico; descuento VIP 5.000, regular/NULL cero; error ORA-20021 esperado. Se conserva el nombre recibido con doble extensión. |
| `16_pruebas_pedidos.txt` | Ejecución real: pedido 120 por 24.000, stock 50 a 48; errores ORA-20001, ORA-20006 y ORA-20012; dos filas actualizadas con un registro adicional de auditoría; reversión a un pedido, un detalle, stock 50 y auditoría cero. |
| `Modelo_Relacional_Fazbear.png` | Esquema de referencias elaborado a partir del DDL del ZIP; no es una captura de ejecución ni un diagrama exportado desde Oracle. |

### Interpretación de la prueba integrada

El pedido temporal 120 contiene dos unidades de la pizza de 12.000. Se rechazaron una solicitud de 49 unidades cuando quedaban 48 y una cantidad cero, comprobando que no alteraran detalles, total o existencias. Se canceló el pedido y se rechazó su reactivación. ORA-06512 y ORA-04088 aparecen en el contexto del error esperado de ese trigger; el bloque completo terminó correctamente.

La prueba de sentencia actualizó dos pedidos y llevó el conteo de auditoría de dos a tres: un incremento de uno. Después se revirtieron los cambios de la prueba y se comprobaron los conteos y stock iniciales. Los valores consumidos por las secuencias no se revierten; los saltos de identificadores son normales.

El trigger heredado de duplicados permaneció activo y no impidió esta inserción individual. No se reprodujo ORA-04091 en esta ejecución. Su consulta de Pedido desde un trigger de fila sigue requiriendo revisión antes de admitir otros escenarios, como inserciones de varias filas. No se declara validada su prevención de duplicados ni se incluye como objeto propio del script EV2.

## Cobertura de las pruebas y trabajo futuro

- Pruebas de consulta completadas y registradas. Aún falta incorporar cualquier escenario adicional acordado, como meses inválidos o un inventario en estado crítico.
- Package, errores específicos, auditoría y reversión comprobados en `16_pruebas_pedidos.txt`. No se han ejecutado todos los escenarios adicionales ni se presenta esta suite como una ejecución literal de las diez pruebas originales del ZIP.
- Informe y PPT actualizados textualmente con autorización: período septiembre de 2026, ocho entradas VALID, resultados de los logs y referencias a las evidencias externas. Se conservaron sus elementos de formato y diseño.
- Los logs respaldan la prueba significativa. La explicación del aprendizaje individual y de las decisiones corresponde a cada integrante durante la defensa.

## Limitaciones conocidas

La comprobación de stock del package no protege todavía frente a dos sesiones simultáneas. El SQL directo puede omitir validaciones del package. No hay anulación con reposición de stock ni aplicación automática del descuento. Las pruebas negativas originales capturan cualquier excepción, por lo que sus mensajes de éxito no bastan: se debe verificar SQLCODE y los datos.

La fecha del pedido existente en la sesión revisada es 19/09/2026, no la fecha relativa que tendría una nueva carga del ZIP. El acumulado mensual debe interpretarse con la fecha real. La compilación no se presenta como sustituto de las pruebas.
