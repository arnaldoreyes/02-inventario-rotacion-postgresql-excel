# Reporte de Validación y Auditoría — Proyecto 2 (Inventario y Rotación)

**Fecha de auditoría:** 2026-11-20  
**Alcance:** Conciliación integral entre el modelo SQL en PostgreSQL (`03_modeling/01_crear_modelo_inventario.sql`), los CSV exportados desde pgAdmin (`03_modeling/mod_productos_inventario.csv` y `03_modeling/mod_ventas_12m_mensual.csv`) y el libro operativo de Excel (`04_presentation/tablero_inventario_adventureworks.xlsx`).

> **Nota sobre nombres de carpetas:** El repositorio sigue la estructura numerada estándar del portafolio (`03_modeling/`, `04_presentation/`, `05_validation/`). Los entregables de esta auditoría se alojan en `05_validation/` para mantener coherencia con el resto del proyecto.

---

## 1. Tabla comparativa de conciliación (SQL/CSV vs. Excel)

Todos los totales se verificaron con precisión exacta a 2 decimales contra las 4 hojas del libro (`Resumen_Ejecutivo`, `Modelo_Inventario`, `Ventas_12m` y `Tablas_Dinamicas`), incluyendo conciliación **fila a fila** sobre los 295 productos terminados (`0` diferencias en `ingresos_12m`, `estado_inventario` y `clasificacion_abc`).

| Métrica | Valor SQL/CSV | Valor Excel (`tablero_inventario_adventureworks.xlsx`) | Diferencia | Estado |
|---|---:|---:|---:|---|
| Catálogo de productos terminados (filas) | 295 | 295 (`Modelo_Inventario`) | 0 | **OK** |
| Registros serie mensual 12m (filas) | 1.732 | 1.732 (`Ventas_12m`) | 0 | **OK** |
| Ventana temporal comparable | 12 meses (`2013-07` a `2014-06`) | 12 meses (`2013-07` a `2014-06`) | 0 | **OK** |
| Ingresos totales 12m (cuadre producto vs. mensual) | \$45.004.579,66 | \$45.004.579,66 *(tarjeta: \$45,004,580)* | \$0,00 | **OK** |
| Unidades vendidas 12m | 142.072 | 142.072 (`Ventas_12m` y `Modelo_Inventario`) | 0 | **OK** |
| Costo de ventas 12m (costo estándar) | \$38.769.292,59 | \$38.769.292,59 (`Ventas_12m` y `Modelo_Inventario`) | \$0,00 | **OK** |
| Valor total de inventario | \$19.225.868,07 | \$19.225.868,07 *(tarjeta: \$19,225,868)* | \$0,00 | **OK** |
| Stock total actual (unidades) | 77.818 | 77.818 (`Modelo_Inventario` y `Resumen_Ejecutivo!D7`) | 0 | **OK** |
| Stock muerto — productos | 65 | 65 (`Tablas_Dinamicas!B3`) | 0 | **OK** |
| Stock muerto — valor inventario | \$7.769.065,64 | \$7.769.065,64 *(tarjeta: \$7,769,066)* | \$0,00 | **OK** |
| Stock muerto — % del inventario | 40,41 % | 40,41 % *(tarjeta: 40.4%)* | 0,00 pp | **OK** |
| Quiebre de stock — productos | 47 | 47 (`Resumen_Ejecutivo!H6` y `Tablas_Dinamicas!B5`) | 0 | **OK** |
| Quiebre de stock — ingresos 12m en riesgo | \$3.496.673,67 | \$3.496.673,67 *(tarjeta: \$3,496,674)* | \$0,00 | **OK** |
| Reordenar — productos / valor inventario | 2 / \$119.441,85 | 2 / \$119.441,85 (`Tablas_Dinamicas`) | 0 / \$0,00 | **OK** |
| OK — productos / valor inventario | 152 / \$11.337.360,58 | 152 / \$11.337.360,58 (`Tablas_Dinamicas`) | 0 / \$0,00 | **OK** |
| Sin stock ni ventas — productos | 29 | 29 (`Tablas_Dinamicas!B6`) | 0 | **OK** |
| Costo de reposición total (quiebre + reorden) | \$6.389.876,73 *(16.529 uds)* | \$6.389.876,73 *(tarjeta: \$6,389,877)* | \$0,00 | **OK** |
| Pareto Clase A (productos / % ingresos) | 41 / 79,71 % (\$35.874.947,16) | 41 / 79,71 % (\$35.874.947,16) | 0 / 0,00 pp | **OK** |
| Pareto Clase B (productos / % ingresos) | 48 / 15,18 % (\$6.831.086,11) | 48 / 15,18 % (\$6.831.086,11) | 0 / 0,00 pp | **OK** |
| Pareto Clase C (productos / % ingresos) | 112 / 5,11 % (\$2.298.546,39) | 112 / 5,11 % (\$2.298.546,39) | 0 / 0,00 pp | **OK** |
| Pareto Sin ventas (productos / % ingresos) | 94 / 0,00 % (\$0,00) | 94 / 0,00 % (\$0,00) | 0 / 0,00 pp | **OK** |

---

## 2. Checklist de integridad técnica

- [x] **Duplicados:** `0` duplicados por `product_id` en `mod_productos_inventario` (295/295) y `0` duplicados por `(anio_mes, product_id)` en `mod_ventas_12m_mensual` (1.732/1.732).
- [x] **Nulos y negativos anómalos:** `0` nulos en llaves/métricas obligatorias y `0` valores negativos en stock, costos, unidades o ingresos. *(Nota: `lead_time_promedio_dias` tiene 212 nulos esperados por productos fabricados internamente sin proveedor externo en `pv`.)*
- [x] **Fórmulas del libro Excel:** `0` errores (`#DIV/0!`, `#N/A`, `#VALOR!`, `#REF!`, `#NOMBRE?`, `#NUM!`) en las **6.422 fórmulas** auditadas entre `Resumen_Ejecutivo` (8), `Modelo_Inventario` (2.950) y `Ventas_12m` (3.464), más `Tablas_Dinamicas` (0 errores).
- [x] **Conciliación fila a fila (295 productos):** `0` diferencias en `ingresos_12m`, `0` en `estado_inventario` y `0` en `clasificacion_abc` entre la lógica SQL y la tabla `tb_inventario` de Excel.
- [x] **Scripts y CSVs en `03_modeling/`:** confirmados `01_crear_modelo_inventario.sql`, `mod_productos_inventario.csv` y `mod_ventas_12m_mensual.csv`.
- [x] **Libro y capturas en `04_presentation/`:** confirmado `tablero_inventario_adventureworks.xlsx` y las 3 capturas en `04_presentation/capturas/` (`01_resumen_ejecutivo.png`, `02_modelo_inventario_alertas.png`, `03_auditoria_tablas_dinamicas.png`).
- [x] **Higiene libre de temporales ocultos:** verificado tras cerrar Microsoft Excel (`04_presentation/~$tablero_inventario_adventureworks.xlsx` eliminado; `.gitignore` mantiene excluido `~$*.xlsx`, `AGENTS.md` y los CSV crudos de `01_raw/entrada/`).
- [x] **Validación ejecutada en PostgreSQL 18 (pgAdmin 4):** `05_validation/validacion_inventario.sql` ejecutado y confirmado sobre el esquema `public`.

---

## 3. Notas técnicas y observaciones de auditoría

1. **Nota técnica en el cálculo de `pct_acumulado_ingresos` (sin impacto en resultados):** en Excel (`Modelo_Inventario`, col. `V`) el acumulado Pareto se calcula con `SUMIFS(ingresos_12m, ">=" & ingresos_12m) / SUM(ingresos_12m)`, mientras que en SQL (`mod_kpis_inventario`) se usa función ventana con desempate por `product_id`. En el dataset actual la clasificación ABC coincide **295/295 (100 %)**; se deja documentado por trazabilidad ante eventuales empates exactos en futuras cargas.
2. **Detalle visual menor en `03_auditoria_tablas_dinamicas.png` (opcional):** en la captura de `Tablas_Dinamicas`, algunos encabezados de columnas (`Cuenta de produ`, `Suma de valor_`, `Suma de ingres`) se ven ligeramente recortados por el ancho de columna. No afecta cálculos ni la hoja `Resumen_Ejecutivo`.

---

## 4. Veredicto

**VALIDACIÓN APROBADA AL 100 % (SQL/PostgreSQL ↔ CSV ↔ Excel: 0 diferencias fila a fila en 295 productos, 0 errores en 6.422 fórmulas y carpeta libre de temporales).**  
Listo para cierre documental (`README.md`) y aprobación del drill de defensa del proyecto.
