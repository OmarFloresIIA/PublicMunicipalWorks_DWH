-- Ejercicio 8 - Issue #16 (propuesta de oatbrend)
-- Guardar ubicación real de obras y analizar si la evidencia fotográfica está fuera de rango.
-- PostgreSQL; ejecutar después de db/DDLBASEObPub.sql en una COPIA de la base.
-- No requiere PostGIS: las coordenadas se almacenan como DOUBLE PRECISION.
-- Se mantiene el nombre solicitado por la práctica dentro de su carpeta individual.

BEGIN;

-- 1) Coordenadas de ubicación real para cada obra.
ALTER TABLE public.obra
    ADD COLUMN IF NOT EXISTS latitud DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitud DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS precision_ubicacion_m DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS metodo_ubicacion VARCHAR(20);

-- 2) Metadatos geográficos de la foto capturada por el supervisor.
ALTER TABLE public.imagenes_informe
    ADD COLUMN IF NOT EXISTS latitud DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS longitud DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS fecha_captura TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS distancia_a_obra_m DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS fuera_de_rango BOOLEAN;

-- 3) Restricciones de dominio e integridad de coordenadas de obra.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'obra_latitud_rango_ck'
                     AND conrelid = 'public.obra'::regclass) THEN
        ALTER TABLE public.obra ADD CONSTRAINT obra_latitud_rango_ck
            CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'obra_longitud_rango_ck'
                     AND conrelid = 'public.obra'::regclass) THEN
        ALTER TABLE public.obra ADD CONSTRAINT obra_longitud_rango_ck
            CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'obra_coordenadas_completas_ck'
                     AND conrelid = 'public.obra'::regclass) THEN
        ALTER TABLE public.obra ADD CONSTRAINT obra_coordenadas_completas_ck
            CHECK ((latitud IS NULL AND longitud IS NULL)
                OR (latitud IS NOT NULL AND longitud IS NOT NULL));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'obra_precision_no_negativa_ck'
                     AND conrelid = 'public.obra'::regclass) THEN
        ALTER TABLE public.obra ADD CONSTRAINT obra_precision_no_negativa_ck
            CHECK (precision_ubicacion_m IS NULL OR precision_ubicacion_m >= 0);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'obra_metodo_ubicacion_ck'
                     AND conrelid = 'public.obra'::regclass) THEN
        ALTER TABLE public.obra ADD CONSTRAINT obra_metodo_ubicacion_ck
            CHECK (metodo_ubicacion IS NULL
                OR metodo_ubicacion IN ('gps', 'manual', 'aproximada'));
    END IF;
END $$;

-- 4) Restricciones para coordenadas de cada imagen y distancias calculadas.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'imagenes_latitud_rango_ck'
                     AND conrelid = 'public.imagenes_informe'::regclass) THEN
        ALTER TABLE public.imagenes_informe ADD CONSTRAINT imagenes_latitud_rango_ck
            CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'imagenes_longitud_rango_ck'
                     AND conrelid = 'public.imagenes_informe'::regclass) THEN
        ALTER TABLE public.imagenes_informe ADD CONSTRAINT imagenes_longitud_rango_ck
            CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'imagenes_coordenadas_completas_ck'
                     AND conrelid = 'public.imagenes_informe'::regclass) THEN
        ALTER TABLE public.imagenes_informe ADD CONSTRAINT imagenes_coordenadas_completas_ck
            CHECK ((latitud IS NULL AND longitud IS NULL)
                OR (latitud IS NOT NULL AND longitud IS NOT NULL));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conname = 'imagenes_distancia_no_negativa_ck'
                     AND conrelid = 'public.imagenes_informe'::regclass) THEN
        ALTER TABLE public.imagenes_informe ADD CONSTRAINT imagenes_distancia_no_negativa_ck
            CHECK (distancia_a_obra_m IS NULL OR distancia_a_obra_m >= 0);
    END IF;
END $$;

-- 5) Historial de salidas del modelo. Cada resultado referencia la imagen
-- (evidencia) que se está calificando. No se sobrescriben inferencias previas.
CREATE TABLE IF NOT EXISTS public.analisis_ubicacion_ia (
    id_analisis          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_imagen            UUID NOT NULL
                         REFERENCES public.imagenes_informe(id_imagen) ON DELETE CASCADE,
    tipo_resultado       VARCHAR(40) NOT NULL DEFAULT 'deteccion_anomalia',
    clase_predicha       VARCHAR(40) NOT NULL,
    es_anomalia          BOOLEAN NOT NULL,
    puntaje_anomalia     DOUBLE PRECISION,
    confianza            DOUBLE PRECISION,
    distancia_calculada_m DOUBLE PRECISION,
    umbral_distancia_m   DOUBLE PRECISION,
    fecha_analisis       TIMESTAMPTZ NOT NULL DEFAULT now(),
    version_modelo       VARCHAR(100) NOT NULL,
    salida_modelo        JSONB NOT NULL DEFAULT '{}'::jsonb,

    CONSTRAINT analisis_ubicacion_tipo_ck
        CHECK (tipo_resultado IN ('deteccion_anomalia', 'validacion_ubicacion')),
    CONSTRAINT analisis_ubicacion_clase_ck
        CHECK (clase_predicha IN
               ('dentro_rango', 'fuera_rango', 'ubicacion_no_disponible', 'requiere_revision')),
    CONSTRAINT analisis_ubicacion_puntaje_ck
        CHECK (puntaje_anomalia IS NULL OR puntaje_anomalia BETWEEN 0 AND 1),
    CONSTRAINT analisis_ubicacion_confianza_ck
        CHECK (confianza IS NULL OR confianza BETWEEN 0 AND 1),
    CONSTRAINT analisis_ubicacion_distancia_ck
        CHECK (distancia_calculada_m IS NULL OR distancia_calculada_m >= 0),
    CONSTRAINT analisis_ubicacion_umbral_ck
        CHECK (umbral_distancia_m IS NULL OR umbral_distancia_m >= 0)
);

CREATE INDEX IF NOT EXISTS idx_analisis_ubicacion_imagen_fecha
    ON public.analisis_ubicacion_ia (id_imagen, fecha_analisis DESC);
CREATE INDEX IF NOT EXISTS idx_analisis_ubicacion_anomalia_fecha
    ON public.analisis_ubicacion_ia (es_anomalia, fecha_analisis DESC);
CREATE INDEX IF NOT EXISTS idx_imagenes_fuera_rango
    ON public.imagenes_informe (fuera_de_rango) WHERE fuera_de_rango = TRUE;

COMMIT;

-- Después de este cambio:
-- 1) Ejecutar datos-demo-ubicacion-ia.sql únicamente en una base local de práctica.
-- 2) Ejecutar consulta-ubicacion-ia.sql para mostrar la salida y su versión.
-- Las filas demo están etiquetadas; no son la salida de un modelo real.
