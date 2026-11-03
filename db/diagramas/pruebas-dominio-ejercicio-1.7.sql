-- =====================================================================
-- Ejercicio 1.7, punto 3: restricciones de dominio adicionales
-- Proyecto asignado: Obras Públicas Temascaltepec
--
-- Este archivo NO modifica las tablas originales de public.
-- Crea copias temporales de las tres tablas, carga sus datos y agrega
-- restricciones CHECK únicamente a esas copias.
--
-- Al ejecutar el archivo con psql, las tablas temporales desaparecen
-- al terminar la conexión. Se pueden ejecutar las consultas en una base
-- local ya poblada por scripts/generate_synthetic_data.py.
-- =====================================================================

\set ON_ERROR_STOP on

\echo '=============================================================='
\echo 'Ejercicio 1.7 - Punto 3: validacion de restricciones de dominio'
\echo 'Se trabajara sobre copias temporales; public no sera modificado.'
\echo '=============================================================='

BEGIN;

-- Si el archivo se ejecuta más de una vez en la misma sesión, limpia
-- las copias temporales anteriores.
DROP TABLE IF EXISTS pg_temp.copia_obra;
DROP TABLE IF EXISTS pg_temp.copia_costos;
DROP TABLE IF EXISTS pg_temp.copia_informes;

-- Copia de las tablas y de sus datos.
-- LIKE conserva tipos, valores DEFAULT, NOT NULL y CHECK ya declarados;
-- no copia PK, índices ni claves foráneas.
CREATE TEMP TABLE copia_obra
  (LIKE public.obra INCLUDING DEFAULTS INCLUDING CONSTRAINTS);
INSERT INTO copia_obra SELECT * FROM public.obra;

CREATE TEMP TABLE copia_costos
  (LIKE public.costos INCLUDING DEFAULTS INCLUDING CONSTRAINTS);
INSERT INTO copia_costos SELECT * FROM public.costos;

CREATE TEMP TABLE copia_informes
  (LIKE public.informes INCLUDING DEFAULTS INCLUDING CONSTRAINTS);
INSERT INTO copia_informes SELECT * FROM public.informes;

\echo ''
\echo '1. Evaluacion de los datos existentes en las copias'
\echo 'Un resultado de 0 en incumplimientos significa que los datos cumplen.'

SELECT
  'obra: fecha_final >= fecha_inicio' AS restriccion,
  COUNT(*) AS registros_evaluados,
  COUNT(*) FILTER (WHERE fecha_final < fecha_inicio) AS incumplimientos
FROM copia_obra
UNION ALL
SELECT
  'costos: costo >= 0',
  COUNT(*),
  COUNT(*) FILTER (WHERE costo < 0)
FROM copia_costos
UNION ALL
SELECT
  'informes: mes pertenece a los 12 meses validos',
  COUNT(*),
  COUNT(*) FILTER (
    WHERE mes IS NULL
       OR mes NOT IN (
         'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
         'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
       )
  )
FROM copia_informes;

\echo ''
\echo '2. Incorporacion de las tres restricciones a las copias'
\echo 'Si hay datos que incumplen una regla, PostgreSQL rechazara el ALTER TABLE.'

ALTER TABLE copia_obra
  ADD CONSTRAINT ck_copia_obra_fechas
  CHECK (fecha_final >= fecha_inicio);

ALTER TABLE copia_costos
  ADD CONSTRAINT ck_copia_costos_no_negativo
  CHECK (costo >= 0);

ALTER TABLE copia_informes
  ADD CONSTRAINT ck_copia_informes_mes_valido
  CHECK (
    mes IN (
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    )
  );

\echo ''
\echo '3. Pruebas negativas: comprobar que cada restriccion rechaza un valor invalido'

-- Prueba 1: intenta dejar una obra con fecha final anterior a la inicial.
DO $$
DECLARE
  v_id_obra text;
  v_rechazado boolean := false;
BEGIN
  SELECT id_obra INTO v_id_obra
  FROM copia_obra
  ORDER BY id_obra
  LIMIT 1;

  IF v_id_obra IS NULL THEN
    RAISE EXCEPTION 'No hay obras en la copia para realizar la prueba negativa.';
  END IF;

  BEGIN
    UPDATE copia_obra
       SET fecha_final = fecha_inicio - 1
     WHERE id_obra = v_id_obra;
  EXCEPTION WHEN check_violation THEN
    v_rechazado := true;
  END;

  IF NOT v_rechazado THEN
    RAISE EXCEPTION 'FALLO: la restriccion de fechas permitio una fecha final anterior.';
  END IF;

  RAISE NOTICE 'OK: la restriccion rechazo una fecha_final anterior a fecha_inicio.';
END
$$;

-- Prueba 2: intenta registrar un gasto con costo negativo.
DO $$
DECLARE
  v_id_gasto text;
  v_rechazado boolean := false;
BEGIN
  SELECT id_gasto INTO v_id_gasto
  FROM copia_costos
  ORDER BY id_gasto
  LIMIT 1;

  IF v_id_gasto IS NULL THEN
    RAISE EXCEPTION 'No hay costos en la copia para realizar la prueba negativa.';
  END IF;

  BEGIN
    UPDATE copia_costos
       SET costo = -1
     WHERE id_gasto = v_id_gasto;
  EXCEPTION WHEN check_violation THEN
    v_rechazado := true;
  END;

  IF NOT v_rechazado THEN
    RAISE EXCEPTION 'FALLO: la restriccion permitio un costo negativo.';
  END IF;

  RAISE NOTICE 'OK: la restriccion rechazo un costo negativo.';
END
$$;

-- Prueba 3: intenta registrar un nombre de mes que no existe.
DO $$
DECLARE
  v_id_informe text;
  v_rechazado boolean := false;
BEGIN
  SELECT id_informe INTO v_id_informe
  FROM copia_informes
  ORDER BY id_informe
  LIMIT 1;

  IF v_id_informe IS NULL THEN
    RAISE EXCEPTION 'No hay informes en la copia para realizar la prueba negativa.';
  END IF;

  BEGIN
    UPDATE copia_informes
       SET mes = 'MesInvalido'
     WHERE id_informe = v_id_informe;
  EXCEPTION WHEN check_violation THEN
    v_rechazado := true;
  END;

  IF NOT v_rechazado THEN
    RAISE EXCEPTION 'FALLO: la restriccion permitio un mes invalido.';
  END IF;

  RAISE NOTICE 'OK: la restriccion rechazo un nombre de mes invalido.';
END
$$;

\echo ''
\echo '4. Resultado'
\echo 'Si se llego a este mensaje, las tres reglas se pudieron agregar a las copias'
\echo 'y las tres pruebas negativas fueron rechazadas por PostgreSQL.'
\echo 'Las tablas originales public.obra, public.costos y public.informes no cambiaron.'

COMMIT;

-- Las tablas TEMP se eliminan automáticamente cuando termina esta sesión.
