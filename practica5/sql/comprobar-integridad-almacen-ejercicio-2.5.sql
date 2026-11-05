-- =====================================================================
-- Ejercicio 2.5: integridad referencial en el almacén asignado
-- Proyecto: PublicMunicipalWorks_DWH
--
-- Revisa las claves foráneas entre las tablas de hechos y las dimensiones.
-- Copia ambas tablas de hechos en un esquema de prueba separado y vuelve a
-- agregar en las copias las doce claves foráneas del esquema original.
--
-- No modifica tablas ni restricciones del esquema warehouse.
-- El esquema de prueba se elimina al final del script.
-- =====================================================================

\set ON_ERROR_STOP on

\echo '=============================================================='
\echo 'Ejercicio 2.5 - Integridad referencial del almacén'
\echo '=============================================================='

BEGIN;

DO $
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_namespace
        WHERE nspname = 'ejercicio_2_5_copia'
    ) THEN
        RAISE EXCEPTION
            'Ya existe el esquema ejercicio_2_5_copia. Revísalo antes de volver a ejecutar el script.';
    END IF;
END
$;

CREATE SCHEMA ejercicio_2_5_copia;

\echo ''
\echo '1. Claves foraneas declaradas en las tablas originales de hechos'

SELECT
    c.conrelid::regclass AS tabla_hechos,
    c.conname AS nombre_restriccion,
    pg_get_constraintdef(c.oid) AS definicion,
    c.convalidated AS validada
FROM pg_constraint AS c
WHERE c.contype = 'f'
  AND c.conrelid IN (
      'warehouse.fact_eventos_auditoria'::regclass,
      'warehouse.fact_obra_mensual'::regclass
  )
ORDER BY tabla_hechos::text, nombre_restriccion;

\echo ''
\echo '2. Registros actuales en las tablas de hechos'

SELECT 'warehouse.fact_eventos_auditoria' AS tabla, COUNT(*) AS registros
FROM warehouse.fact_eventos_auditoria
UNION ALL
SELECT 'warehouse.fact_obra_mensual', COUNT(*)
FROM warehouse.fact_obra_mensual;

\echo ''
\echo '3. Crear copias de prueba de las tablas de hechos'

-- CREATE TABLE AS copia los datos y los tipos de columna, pero no copia
-- las claves primarias ni las claves foráneas. Así se puede probar la
-- incorporación de las relaciones sin tocar las tablas originales.
CREATE TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria AS
SELECT * FROM warehouse.fact_eventos_auditoria;

CREATE TABLE ejercicio_2_5_copia.copia_fact_obra_mensual AS
SELECT * FROM warehouse.fact_obra_mensual;

SELECT 'copia_fact_eventos_auditoria' AS tabla, COUNT(*) AS registros
FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria
UNION ALL
SELECT 'copia_fact_obra_mensual', COUNT(*)
FROM ejercicio_2_5_copia.copia_fact_obra_mensual;

\echo ''
\echo '4. Buscar hechos que apunten a dimensiones inexistentes'
\echo 'Los valores NULL de las referencias opcionales no se consideran huerfanos.'

WITH revisiones AS (
    SELECT
        'fact_eventos_auditoria' AS tabla_hechos,
        'tiempo_key -> dim_tiempo' AS relacion,
        COUNT(*) FILTER (
            WHERE f.tiempo_key IS NOT NULL AND d.tiempo_key IS NULL
        ) AS huerfanos
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_tiempo d ON d.tiempo_key = f.tiempo_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'tipo_evento_key -> dim_tipo_evento',
        COUNT(*) FILTER (
            WHERE f.tipo_evento_key IS NOT NULL AND d.tipo_evento_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_tipo_evento d ON d.tipo_evento_key = f.tipo_evento_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'obra_key -> dim_obra',
        COUNT(*) FILTER (
            WHERE f.obra_key IS NOT NULL AND d.obra_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_obra d ON d.obra_key = f.obra_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'region_key -> dim_region',
        COUNT(*) FILTER (
            WHERE f.region_key IS NOT NULL AND d.region_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_region d ON d.region_key = f.region_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'personal_key -> dim_personal',
        COUNT(*) FILTER (
            WHERE f.personal_key IS NOT NULL AND d.personal_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_personal d ON d.personal_key = f.personal_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'constructora_key -> dim_constructora',
        COUNT(*) FILTER (
            WHERE f.constructora_key IS NOT NULL AND d.constructora_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_constructora d ON d.constructora_key = f.constructora_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'fuente_key -> dim_fuente',
        COUNT(*) FILTER (
            WHERE f.fuente_key IS NOT NULL AND d.fuente_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_fuente d ON d.fuente_key = f.fuente_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'presupuesto_key -> dim_presupuesto',
        COUNT(*) FILTER (
            WHERE f.presupuesto_key IS NOT NULL AND d.presupuesto_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_presupuesto d ON d.presupuesto_key = f.presupuesto_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'poblador_key -> dim_poblador',
        COUNT(*) FILTER (
            WHERE f.poblador_key IS NOT NULL AND d.poblador_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_poblador d ON d.poblador_key = f.poblador_key

    UNION ALL
    SELECT
        'fact_eventos_auditoria',
        'propuesta_key -> dim_propuesta',
        COUNT(*) FILTER (
            WHERE f.propuesta_key IS NOT NULL AND d.propuesta_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    LEFT JOIN warehouse.dim_propuesta d ON d.propuesta_key = f.propuesta_key

    UNION ALL
    SELECT
        'fact_obra_mensual',
        'tiempo_key -> dim_tiempo',
        COUNT(*) FILTER (
            WHERE f.tiempo_key IS NOT NULL AND d.tiempo_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_obra_mensual f
    LEFT JOIN warehouse.dim_tiempo d ON d.tiempo_key = f.tiempo_key

    UNION ALL
    SELECT
        'fact_obra_mensual',
        'obra_key -> dim_obra',
        COUNT(*) FILTER (
            WHERE f.obra_key IS NOT NULL AND d.obra_key IS NULL
        )
    FROM ejercicio_2_5_copia.copia_fact_obra_mensual f
    LEFT JOIN warehouse.dim_obra d ON d.obra_key = f.obra_key
)
SELECT tabla_hechos, relacion, huerfanos
FROM revisiones
ORDER BY tabla_hechos, relacion;

\echo ''
\echo '5. Listar hechos huerfanos, si existe alguno'
\echo 'La consulta siguiente debe devolver cero filas si las referencias estan completas.'

WITH huerfanos AS (
    SELECT
        'fact_eventos_auditoria'::text AS tabla_hechos,
        'tiempo_key -> dim_tiempo'::text AS relacion,
        (f.tiempo_key::text || '/' || f.evento_key::text) AS identificador_hecho,
        f.tiempo_key::text AS clave_inexistente
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.tiempo_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_tiempo d
          WHERE d.tiempo_key = f.tiempo_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'tipo_evento_key -> dim_tipo_evento',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.tipo_evento_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.tipo_evento_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_tipo_evento d
          WHERE d.tipo_evento_key = f.tipo_evento_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'obra_key -> dim_obra',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.obra_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.obra_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_obra d
          WHERE d.obra_key = f.obra_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'region_key -> dim_region',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.region_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.region_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_region d
          WHERE d.region_key = f.region_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'personal_key -> dim_personal',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.personal_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.personal_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_personal d
          WHERE d.personal_key = f.personal_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'constructora_key -> dim_constructora',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.constructora_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.constructora_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_constructora d
          WHERE d.constructora_key = f.constructora_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'fuente_key -> dim_fuente',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.fuente_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.fuente_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_fuente d
          WHERE d.fuente_key = f.fuente_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'presupuesto_key -> dim_presupuesto',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.presupuesto_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.presupuesto_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_presupuesto d
          WHERE d.presupuesto_key = f.presupuesto_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'poblador_key -> dim_poblador',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.poblador_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.poblador_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_poblador d
          WHERE d.poblador_key = f.poblador_key
      )

    UNION ALL
    SELECT 'fact_eventos_auditoria', 'propuesta_key -> dim_propuesta',
           (f.tiempo_key::text || '/' || f.evento_key::text), f.propuesta_key::text
    FROM ejercicio_2_5_copia.copia_fact_eventos_auditoria f
    WHERE f.propuesta_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_propuesta d
          WHERE d.propuesta_key = f.propuesta_key
      )

    UNION ALL
    SELECT 'fact_obra_mensual', 'tiempo_key -> dim_tiempo',
           (f.tiempo_key::text || '/' || f.obra_key::text), f.tiempo_key::text
    FROM ejercicio_2_5_copia.copia_fact_obra_mensual f
    WHERE f.tiempo_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_tiempo d
          WHERE d.tiempo_key = f.tiempo_key
      )

    UNION ALL
    SELECT 'fact_obra_mensual', 'obra_key -> dim_obra',
           (f.tiempo_key::text || '/' || f.obra_key::text), f.obra_key::text
    FROM ejercicio_2_5_copia.copia_fact_obra_mensual f
    WHERE f.obra_key IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM warehouse.dim_obra d
          WHERE d.obra_key = f.obra_key
      )
)
SELECT tabla_hechos, relacion, identificador_hecho, clave_inexistente
FROM huerfanos
ORDER BY tabla_hechos, relacion, identificador_hecho;

\echo ''
\echo '6. Agregar las doce claves foraneas a las copias de prueba'
\echo 'Este paso verifica que los registros existentes satisfacen las relaciones.'

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_tiempo
    FOREIGN KEY (tiempo_key) REFERENCES warehouse.dim_tiempo(tiempo_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_tipo
    FOREIGN KEY (tipo_evento_key) REFERENCES warehouse.dim_tipo_evento(tipo_evento_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_obra
    FOREIGN KEY (obra_key) REFERENCES warehouse.dim_obra(obra_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_region
    FOREIGN KEY (region_key) REFERENCES warehouse.dim_region(region_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_personal
    FOREIGN KEY (personal_key) REFERENCES warehouse.dim_personal(personal_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_constructora
    FOREIGN KEY (constructora_key) REFERENCES warehouse.dim_constructora(constructora_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_fuente
    FOREIGN KEY (fuente_key) REFERENCES warehouse.dim_fuente(fuente_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_presupuesto
    FOREIGN KEY (presupuesto_key) REFERENCES warehouse.dim_presupuesto(presupuesto_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_poblador
    FOREIGN KEY (poblador_key) REFERENCES warehouse.dim_poblador(poblador_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_eventos_auditoria
    ADD CONSTRAINT fk_copia_eventos_propuesta
    FOREIGN KEY (propuesta_key) REFERENCES warehouse.dim_propuesta(propuesta_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_obra_mensual
    ADD CONSTRAINT fk_copia_mensual_tiempo
    FOREIGN KEY (tiempo_key) REFERENCES warehouse.dim_tiempo(tiempo_key);

ALTER TABLE ejercicio_2_5_copia.copia_fact_obra_mensual
    ADD CONSTRAINT fk_copia_mensual_obra
    FOREIGN KEY (obra_key) REFERENCES warehouse.dim_obra(obra_key);

\echo ''
\echo '7. Confirmar que las doce claves foraneas quedaron creadas en las copias'

SELECT
    n.nspname AS esquema_copia,
    c.relname AS tabla_copia,
    con.conname AS nombre_restriccion,
    pg_get_constraintdef(con.oid) AS definicion
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE con.contype = 'f'
  AND n.nspname = 'ejercicio_2_5_copia'
ORDER BY c.relname, con.conname;

\echo ''
\echo '8. Resultado'
\echo 'Si el script llega a este mensaje, las doce claves foraneas pudieron'
\echo 'agregarse a las copias y todos los registros actuales cumplen esas relaciones.'
\echo 'Las tablas originales de warehouse no fueron modificadas.'

DROP SCHEMA ejercicio_2_5_copia CASCADE;

COMMIT;

-- El esquema de prueba y sus copias se eliminan dentro de la transacción.
