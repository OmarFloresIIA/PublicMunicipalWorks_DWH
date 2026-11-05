# Ejercicio 2.5. Integridad referencial en el almacén asignado

## Propósito

El ejercicio solicita identificar las tablas de hechos y sus dimensiones, explicar la granularidad de cada hecho, revisar las claves foráneas entre hechos y dimensiones y buscar registros que apunten a dimensiones inexistentes. Si faltan claves foráneas, se deben probar en una copia para comprobar si los datos las cumplen.

El análisis utiliza el esquema del almacén definido en [db/arquitectura/ESQUEMA DEL DATA WAREHOUSE.sql](../db/arquitectura/ESQUEMA%20DEL%20DATA%20WAREHOUSE.sql) de la rama `TestDefinitivo`.

> **Alcance de los datos:** el repositorio genera una población sintética para reproducir el escenario del proyecto. Las consultas de este ejercicio comprueban la integridad de esa población cargada; no certifican información real de operación municipal.

---

## 1. Tablas de hechos, dimensiones y granularidad

El almacén contiene diez dimensiones y dos tablas de hechos.

### 1.1. Dimensiones

| Dimensión | Tipo SCD | Qué describe |
|---|---|---|
| `dim_tiempo` | Tipo 0 | Calendario: fecha, año, trimestre, mes, día y periodos. |
| `dim_tipo_evento` | Tipo 0 | Catálogo de eventos que puede registrar el sistema. |
| `dim_obra` | Tipo 2 | Datos de las obras y sus versiones históricas. |
| `dim_region` | Tipo 2 | Comunidad, barrio y colonia con historial de cambios. |
| `dim_constructora` | Tipo 2 | Datos de las constructoras con historial. |
| `dim_personal` | Tipo 2 | Personal, rol y asignaciones con historial. |
| `dim_fuente` | Tipo 1 | Fuente de financiamiento con sus valores actuales. |
| `dim_presupuesto` | Tipo 2 | Presupuesto y proyectista asociado, conservando versiones. |
| `dim_poblador` | Tipo 1 | Datos actuales del poblador. |
| `dim_propuesta` | Tipo 1 | Datos actuales de la propuesta ciudadana. |

Las dimensiones Tipo 0 son catálogos que se mantienen sin cambios; las Tipo 1 sustituyen el valor anterior por el actual; y las Tipo 2 conservan versiones para representar cambios históricos.

### 1.2. Tabla de hechos: `warehouse.fact_eventos_auditoria`

**Granularidad:** un renglón representa un evento individual de auditoría registrado en una fecha y clasificado mediante un tipo de evento.

Su clave primaria está formada por `(tiempo_key, evento_key)`. La tabla está particionada por rango de `tiempo_key`.

Sus dimensiones relacionadas son:

- `dim_tiempo`: fecha en la que ocurrió el evento.
- `dim_tipo_evento`: clase de evento registrado.
- `dim_obra`: obra relacionada, cuando aplica.
- `dim_region`: región relacionada, cuando aplica.
- `dim_personal`: persona que ejecutó la acción, cuando aplica.
- `dim_constructora`: constructora relacionada, cuando aplica.
- `dim_fuente`: fuente presupuestaria relacionada, cuando aplica.
- `dim_presupuesto`: presupuesto relacionado, cuando aplica.
- `dim_poblador`: poblador relacionado, cuando aplica.
- `dim_propuesta`: propuesta relacionada, cuando aplica.

Las columnas de fecha y tipo de evento son obligatorias. Las demás referencias pueden ser `NULL`, porque no todos los tipos de evento se relacionan con todas las dimensiones.

Entre sus medidas y datos descriptivos se encuentran montos de presupuesto, costo y ejercicio, porcentajes de avance, días transcurridos, votos, indicadores del evento, descripción, documento y evidencia.

### 1.3. Tabla de hechos: `warehouse.fact_obra_mensual`

**Granularidad:** un renglón representa el estado acumulado de una obra para un mes determinado. Es un *snapshot periódico* por obra y mes.

Su clave primaria está formada por `(tiempo_key, obra_key)`. Cada combinación de obra y fecha de corte mensual puede aparecer una sola vez.

Sus dimensiones relacionadas son:

- `dim_tiempo`: mes de corte del resumen.
- `dim_obra`: obra a la que corresponde el resumen.

Entre sus medidas se encuentran presupuesto total, costo acumulado, saldo presupuestario, porcentaje ejercido, avance físico y presupuestario acumulado, días de retraso y cantidades de informes, evidencias y permisos.

El generador construye los snapshots para 24 meses, de enero de 2024 a diciembre de 2025. Esto representa hasta 24 renglones mensuales por cada obra.

---

## 2. Revisión de las claves foráneas entre hechos y dimensiones

La revisión de `db/arquitectura/ESQUEMA DEL DATA WAREHOUSE.sql` muestra que **las claves foráneas ya están declaradas en las dos tablas de hechos**.

| Tabla de hechos | Columna | Dimensión referenciada |
|---|---|---|
| `fact_eventos_auditoria` | `tiempo_key` | `dim_tiempo(tiempo_key)` |
| `fact_eventos_auditoria` | `tipo_evento_key` | `dim_tipo_evento(tipo_evento_key)` |
| `fact_eventos_auditoria` | `obra_key` | `dim_obra(obra_key)` |
| `fact_eventos_auditoria` | `region_key` | `dim_region(region_key)` |
| `fact_eventos_auditoria` | `personal_key` | `dim_personal(personal_key)` |
| `fact_eventos_auditoria` | `constructora_key` | `dim_constructora(constructora_key)` |
| `fact_eventos_auditoria` | `fuente_key` | `dim_fuente(fuente_key)` |
| `fact_eventos_auditoria` | `presupuesto_key` | `dim_presupuesto(presupuesto_key)` |
| `fact_eventos_auditoria` | `poblador_key` | `dim_poblador(poblador_key)` |
| `fact_eventos_auditoria` | `propuesta_key` | `dim_propuesta(propuesta_key)` |
| `fact_obra_mensual` | `tiempo_key` | `dim_tiempo(tiempo_key)` |
| `fact_obra_mensual` | `obra_key` | `dim_obra(obra_key)` |

En total se identifican doce relaciones de integridad referencial: diez en la tabla de eventos de auditoría y dos en la tabla de snapshots mensuales.

Por lo tanto, no se necesita agregar claves foráneas al esquema original. Hacerlo duplicaría restricciones que ya existen.

---

## 3. Búsqueda de hechos huérfanos y comprobación en una copia

Aunque el esquema ya declara las claves foráneas, se necesita comprobar que la población cargada mantiene la integridad referencial. Para ello se utiliza el archivo:

`practica5/sql/comprobar-integridad-almacen-ejercicio-2.5.sql`

El script realiza este procedimiento:

1. Consulta el catálogo de PostgreSQL para mostrar las claves foráneas declaradas en las tablas originales de hechos y si están validadas.
2. Muestra cuántos registros hay en cada tabla de hechos.
3. Crea copias de prueba de `fact_eventos_auditoria` y `fact_obra_mensual`, con sus datos, pero sin copiar sus claves foráneas.
4. Busca referencias a dimensiones inexistentes mediante `LEFT JOIN` y `NOT EXISTS`. Las referencias opcionales con valor `NULL` no se cuentan como huérfanas.
5. Intenta agregar a las copias las mismas doce claves foráneas del esquema original.
6. Muestra las claves creadas en las copias.

### 3.1. ¿Por qué se prueban las relaciones en copias?

Como las doce claves ya aparecen en el esquema original, el punto que pide agregarlas solo sería necesario si faltaran. En este caso se vuelven a crear en las copias de prueba para comprobar directamente que todos los registros actuales pueden quedar protegidos por esas relaciones, sin alterar la base original.

Si existe una referencia a una dimensión que no está presente, la consulta de huérfanos mostrará el registro y la incorporación de la clave foránea correspondiente fallará. Si el script llega al mensaje final, las doce relaciones pudieron agregarse a las copias.

### 3.2. Instrucciones para levantar y poblar la base

Desde la raíz del repositorio, usando Git Bash:

```bash
docker compose -f ./docker/compose.yml up -d --build
```

Comprobar que PostgreSQL y la API estén activos:

```bash
docker compose -f ./docker/compose.yml ps
```

Si la base todavía no tiene la población sintética, ejecuta:

```bash
docker compose -f ./docker/compose.yml --profile tools run --rm seed
```

El servicio `seed` limpia y vuelve a generar la población sintética que administra. No lo ejecutes si tienes datos locales que quieras conservar. Si ya realizaste la carga para el ejercicio 1.7 y la base sigue poblada, puedes omitir este paso.

### 3.3. Copiar el archivo SQL al contenedor

```bash
MSYS_NO_PATHCONV=1 docker compose -f ./docker/compose.yml cp ./practica5/sql/comprobar-integridad-almacen-ejercicio-2.5.sql db:/tmp/comprobar-integridad-almacen-ejercicio-2.5.sql
```

El prefijo `MSYS_NO_PATHCONV=1` evita que Git Bash convierta la ruta `/tmp/...` del contenedor en una ruta de Windows.

### 3.4. Ejecutar las consultas y pruebas

```bash
MSYS_NO_PATHCONV=1 docker compose -f ./docker/compose.yml exec -T db psql -U obras -d obras_publicas -v ON_ERROR_STOP=1 -f /tmp/comprobar-integridad-almacen-ejercicio-2.5.sql
```

El comando utiliza el usuario `obras` y la base `obras_publicas`, definidos en `docker/compose.yml` de la rama `TestDefinitivo`.

### 3.5. Interpretación de resultados

Se deben revisar tres partes de la salida:

- **Claves declaradas:** deben aparecer diez referencias para `fact_eventos_auditoria` y dos para `fact_obra_mensual`. La columna `validada` permite revisar si PostgreSQL considera validada cada restricción.
- **Búsqueda de huérfanos:** la columna `huerfanos` debe indicar cero para cada relación. La consulta de detalle debe devolver cero filas si no existen referencias rotas.
- **Prueba en copias:** si las doce claves foráneas se agregan correctamente y aparece el mensaje final, los registros copiados cumplen las relaciones. Las tablas originales no se modifican.

No se deben escribir cantidades de registros ni resultados definitivos antes de ejecutar el archivo en la instancia local; los conteos se obtienen de la salida real de PostgreSQL.

---

## 4. ¿Por qué un almacén de datos a veces omite claves foráneas?

En algunos almacenes de datos se decide no declarar físicamente todas las claves foráneas por razones de operación:

1. **Velocidad de carga:** al insertar millones de hechos, comprobar cada referencia puede aumentar el costo de las cargas masivas.
2. **Proceso ETL/ELT:** la integridad puede revisarse antes o durante la transformación, mediante consultas de calidad de datos, en lugar de delegarla por completo al motor.
3. **Dimensiones que llegan tarde:** un hecho puede recibirse antes de que exista o se haya resuelto su registro dimensional. Algunos procesos utilizan una fila temporal o un miembro desconocido hasta completar la dimensión.
4. **Plataformas analíticas:** ciertos motores o arquitecturas priorizan la lectura y la carga masiva, y dejan la validación referencial en los procesos de integración.

Omitir una clave foránea no significa que la relación deje de ser necesaria; significa que el proceso de carga debe hacerse responsable de verificarla.

### Riesgos de omitirlas

- Se pueden almacenar hechos que apunten a claves dimensionales inexistentes.
- Una consulta con `INNER JOIN` puede excluir esos hechos y producir totales incompletos.
- Los indicadores y reportes pueden quedar incorrectos sin que la carga necesariamente se detenga.
- Se dificulta rastrear el origen del error y mantener la consistencia de los análisis.

En el esquema revisado, las doce claves foráneas están declaradas. Por ello, el diseño utiliza la validación del propio PostgreSQL para proteger esas referencias.

---

## 5. Conclusión

El almacén dimensional del proyecto asignado cuenta con dos tablas de hechos: una para eventos individuales de auditoría y otra para snapshots mensuales por obra. Ambas utilizan dimensiones compartidas, principalmente tiempo y obra.

La revisión del DDL permitió identificar diez claves foráneas en `fact_eventos_auditoria` y dos en `fact_obra_mensual`. Como las doce relaciones ya están declaradas, no hace falta modificar el esquema original. La prueba en copias de prueba permite verificar que los datos cargados cumplen las mismas relaciones sin poner en riesgo la base utilizada por el proyecto.

La salida del script debe utilizarse para completar los conteos y determinar si se encontraron hechos huérfanos en la instancia local.

## Fuentes

- [Esquema del Data Warehouse — rama TestDefinitivo](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/arquitectura/ESQUEMA%20DEL%20DATA%20WAREHOUSE.sql).
- [Funciones y triggers — rama TestDefinitivo](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/arquitectura/FUNCIONES%20Y%20TRIGGERS.sql).
- [README — rama TestDefinitivo](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/README.md), sección **Running the reference API**.
- [Script de comprobación de integridad referencial](./sql/comprobar-integridad-almacen-ejercicio-2.5.sql).
