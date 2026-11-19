# Fuentes de datos — Proyecto 2 (Inventario y rotación)

## Dataset

**AdventureWorks** — base de datos de ejemplo oficial de Microsoft (OLTP), en espejo CSV.

| Campo | Valor |
|---|---|
| Origen | Espejo CSV de <https://github.com/olafusimichael/AdventureWorksCSV> |
| Dataset original | AdventureWorks OLTP (Microsoft, ciclo 2008 R2 / 2011–2014) |
| Licencia | Datos ficticios de Microsoft, de uso libre para ejemplos y práctica |
| Naturaleza | **Ficticio.** Los montos son realistas pero no corresponden a una empresa real |
| Periodo de ventas | 2011-05-31 a 2014-06-30 (1.124 días con pedidos) |
| Fecha de descarga | 2026-10 (sesión anterior) |
| Verificado | 2026-11-10 |

Los CSV **no se versionan** en Git (22 MB). Verificar los hashes antes de cargar.

## Archivos, filas y hashes

Conteo medido el 2026-11-10 (filas sin encabezado):

| Archivo local | Tabla AdventureWorks | Filas | Bytes | SHA-256 |
|---|---|---|---|---|
| `product.csv` | `Production.Product` | 504 | 99.352 | `D4CFD51BFFF7822B26AC1B87D389406CFBD80F520BFC45DDA361C3879100B7F2` |
| `subcat.csv` | `Production.ProductSubcategory` | 37 | 3.050 | `F1A7813F0AECCB4D5DC554F0E9A80FFCC65B2593905F267B973ED2152C5197C9` |
| `cat.csv` | `Production.ProductCategory` | 4 | 355 | `199FB43349239606BB93CA9ACAAD477DAF0DE73B1B1A74810D9EF8CB816580CF` |
| `inv.csv` | `Production.ProductInventory` | 1.069 | 86.792 | `9E5162A31B3802E386B11BD0B8237D5A50A7DEBBEDC50D62B44D10E9632E3F1B` |
| `pv.csv` | `Purchasing.ProductVendor` | 460 | 40.279 | `B37790C84AB991302381EC6DA89E040FCB33B058D6AE1DE6F056B1A6D9CD6289` |
| `vendor.csv` | `Purchasing.Vendor` | 104 | 8.648 | `896ABFE5AF0ACB47B70BDF9CA063CE9AFF25456E6556B9D3E63A6284F540787A` |
| `vva.csv` | `Purchasing.vVendorWithAddresses` | 104 | 11.624 | `E869055952E5931DB33FE3826FADDAC6C68397B71ACA06385C54400CE9BDA312` |
| `soh.csv` | `Sales.SalesOrderHeader` | 31.465 | 8.316.142 | `79CDCC89797FBE1CAABB0951A4FDFBE4C235B19E1C29D4454B5E5B46EA2C1233` |
| `sod.csv` | `Sales.SalesOrderDetail` | 121.317 | 13.254.405 | `F9E2AEB551A92F4E915F75F9E5680728D6A8F00D0CC91F4E977B08C642E4C855` |

**Cobertura:** 504 productos (de los cuales ~500 activos), 121.317 líneas de venta en
31.465 pedidos, 1.069 posiciones producto–almacén y 460 combinaciones producto–proveedor
con lead time.

## Columnas que importan y su trampa

| Columna | Tabla | Uso | Trampa |
|---|---|---|---|
| `ProductID` | product / inv / pv / sod | Llave de producto | `ProductID` es entero, no texto. No confundir con `ProductNumber` |
| `SafetyStockLevel` | product | Stock de seguridad **fijado por la empresa** | Ya viene definido; el análisis puede compararlo contra el calculado, no reemplazarlo |
| `ReorderPoint` | product | Punto de reorden **fijado por la empresa** | Igual: es el valor oficial. El ejercicio es contrastar la fórmula contra el oficial |
| `StandardCost` | product | Base del costo de ventas | **Costo estándar, no real.** La rotación es una aproximación: se declara |
| `ListPrice` | product | Precio de lista | No es el precio de venta: el real está en `sod.UnitPrice` |
| `Quantity` | inv | Stock actual por almacén | Hay **varias filas por producto** (una por `LocationID`). Sumar, no tomar la primera |
| `AverageLeadTime` | pv | Días de entrega del proveedor | Hay varias filas por producto si tiene varios proveedores. Agregar con criterio y documentarlo |
| `OrderQty` | sod | Unidades vendidas | El grano es la línea de pedido, no el pedido |
| `LineTotal` | sod | Importe de la línea | Ya viene calculado (`UnitPrice × OrderQty × (1 − descuento)`). No recalcularlo |
| `StandardPrice` / `LastReceiptCost` | pv | Costo de compra | Es costo de **compra**, no de venta. No mezclar con `StandardCost` |
| `ProductSubcategoryID` | product | Categoría | **Tiene nulos** (productos sin subcategoría, ej. bicicletas terminadas). No perder esas filas |
| `ProductCategoryID` | subcat | Categoría padre | `cat.csv` solo tiene 4 categorías: Bikes, Components, Clothing, Accessories |

## Trampas adicionales

1. **Las fechas de `soh` están como texto** (`2011-06-01 00:00:00.000`). Convertir a
   `timestamp` en staging y a `date` en el modelo.
2. **`sod` se une por `SalesOrderID` a `soh`** para obtener la fecha. Sin ese join no hay
   serie temporal de ventas. Ojo: 121.317 líneas → 31.465 pedidos; el conteo de pedidos
   es `COUNT(DISTINCT SalesOrderID)`.
3. **Rotación no se calcula con ventas en unidades y stock en unidades** sin decidir la
   unidad de medida. La fórmula correcta es en **costo**:
   `costo de ventas del periodo / inventario promedio`. Si se hace en unidades, el
   resultado es "veces que se vendió el stock", que no es lo mismo entre productos de
   distinto precio.
4. **No hay histórico de stock.** `inv` es una foto. El "inventario promedio" del periodo
   se aproxima con la posición actual; se declara como limitación.
5. **El costo de ventas del periodo** se calcula como
   `SUM(sod.OrderQty × product.StandardCost)`, no con `LineTotal`.
6. **Productos sin ventas en el periodo** (los que nunca se vendieron) deben aparecer con
   rotación 0, no desaparecer del reporte. Es el corazón del análisis: el stock muerto.
   Se resuelve con `LEFT JOIN` desde el catálogo, no desde las ventas.
7. **Rango de fechas:** el dataset va del **2011-05-31 al 2014-06-30**, pero el volumen
   crece fuerte (1.607 pedidos en 2011 contra 14.182 en 2013): los primeros años no son
   comparables con los últimos. Para la rotación, usar una **ventana de 12 meses**
   (2013-07-01 a 2014-06-30) y declararla. Usar los 3 años completos mezcla regímenes de
   venta distintos e infla el inventario promedio.

## Nota de procedencia

El espejo CSV no incluye las tablas de clientes ni territorios. No hacen falta para
inventario: el análisis es producto–almacén–proveedor–venta.
