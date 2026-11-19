# Inventario y rotación — control de stock con punto de reorden

Análisis de inventario sobre el dataset **AdventureWorks** (base de ejemplo de Microsoft):
rotación real de cada producto, días de cobertura, riesgo de quiebre y punto de reorden
por producto y proveedor.

**Stack:** PostgreSQL 18 · Excel
**Perfil:** Analista de Datos de Operaciones

> **Estado:** pendiente. Se abre al cerrar el Proyecto 1.
> Este README se completa igual que el del Proyecto 1: primero las preguntas, después los
> hallazgos, y ningún número sin validar en `05_validation/`.

---

## El problema de negocio

Tener stock de más inmoviliza capital y ocupa almacén; tener stock de menos rompe la
venta y quema al cliente. La operación de inventario vive en ese equilibrio, y el trabajo
del analista es decir **qué producto está en riesgo, cuánto cuesta y cuándo pedir**.

La diferencia que casi todos confunden y que este proyecto separa:

- **Cobertura** = para cuántos días alcanza el stock actual. Es una foto de hoy.
- **Rotación** = cuántas veces se vació y repuso el inventario en un periodo. Es una
  película, y necesita historial de ventas.

Un producto puede tener cobertura alta y rotación alta (vende mucho pero hay mucho
stock) o cobertura alta y rotación baja (está muerto en el almacén). Son dos problemas
distintos con dos acciones distintas.

## Preguntas de negocio

| # | Pregunta | Indicador | Estado |
|---|---|---|---|
| 01 | ¿Qué productos rotan y cuáles están inmovilizados? | Rotación por producto = costo de ventas / inventario promedio | Pendiente |
| 02 | ¿Para cuántos días alcanza el stock actual? | Cobertura en días = stock / venta diaria promedio | Pendiente |
| 03 | ¿Qué productos están en riesgo de quiebre? | Cobertura < lead time del proveedor | Pendiente |
| 04 | ¿Cuál debería ser el punto de reorden de cada producto? | Demanda durante lead time + stock de seguridad | Pendiente |
| 05 | ¿Qué proveedores son el cuello de botella del inventario? | Lead time promedio y variabilidad por proveedor | Pendiente |
| 06 | ¿Cuánto capital está inmovilizado en productos de baja rotación? | Valor de inventario en la cola de rotación | Pendiente |

## Modelo de datos

```
hecho_ventas_diarias   (product_id, fecha, unidades, importe, costo_estandar)
hecho_inventario       (product_id, location_id, cantidad)
dim_producto           (product_id → nombre, subcategoría, categoría, costo, precio)
dim_proveedor          (vendor_id → nombre, lead time, país)
dim_tiempo             (fecha → año, mes, trimestre, día hábil)
```

## Pipeline

```
01_raw/          DDL + carga de los 9 CSV de AdventureWorks
02_staging/      Vistas stg_*: tipado, nulos, normalización
03_modeling/     Hechos, dimensiones, calendario y vistas vw_*
04_presentation/ Libro Excel: tabla estructurada, SUMIFS, tabla dinámica, Power Query
05_validation/   Cuadre del libro contra SQL + checklist
```

**Nota sobre la presentación:** en este proyecto el entregable es un **libro de Excel**,
no un tablero. Es el formato real del reporte de inventario en operaciones: se filtra,
se comenta y se manda por correo. El libro incluye tabla estructurada, `SUMIFS` con
criterios por celda, tabla dinámica, segmentaciones y una hoja de escenario de reposición.

## Limitaciones

- **El costo es estándar, no real.** AdventureWorks no trae el costo de cada
  transacción; la rotación se calcula con `StandardCost × OrderQty`. Es una aproximación
  declarada, no un costo contable.
- **El stock es una foto, no un histórico.** `ProductInventory` trae la cantidad actual
  por almacén; no hay serie temporal de stock. La rotación usa el promedio de las
  posiciones de inventario disponibles.
- **Dataset ficticio.** AdventureWorks es una base de ejemplo de Microsoft: los montos
  son realistas pero no corresponden a ninguna empresa real. Se declara en el README.

## Fuente

| Campo | Detalle |
|---|---|
| Dataset | AdventureWorks (OLTP de ejemplo, Microsoft) |
| Espejo CSV | <https://github.com/olafusimichael/AdventureWorksCSV> |
| Licencia | Datos ficticios de uso libre |
| Archivos | 9 CSV en `01_raw/entrada/` |

El detalle de archivos, hashes y trampas está en [`01_raw/sources.md`](01_raw/sources.md).
