-- DATOS SINTÉTICOS DE DEMOSTRACIÓN PARA ISSUE #16.
-- Ejecutar solo en una copia local/desarrollo después de cambio-usuario.sql.
-- Simula una foto a unos 330 m de la obra; no representa una inferencia real.
-- La clasificación insertada está etiquetada como DEMO.

BEGIN;

INSERT INTO public.constructora (id_constructora, rfc, nombre_const, tipo_ejecutor)
VALUES ('DEMO-OATB-CONST', NULL, 'Constructora demostrativa OATB', 'privado')
ON CONFLICT (id_constructora) DO NOTHING;

INSERT INTO public.region (id_region, comunidad, barrio, colonia)
VALUES ('DEMO-OATB-REG', 'Temascaltepec', 'Barrio demostrativo', NULL)
ON CONFLICT (id_region) DO NOTHING;

INSERT INTO public.personal (codigo_personal, nombre, apellido_paterno, apellido_materno, rol)
VALUES ('DEMO-OATB-SUP', 'Supervisor', 'Demostracion', NULL, 'Supervisor')
ON CONFLICT (codigo_personal) DO NOTHING;

INSERT INTO public.supervisor (codigo_personal, telefono)
VALUES ('DEMO-OATB-SUP', NULL)
ON CONFLICT (codigo_personal) DO NOTHING;

INSERT INTO public.obra (
    id_obra, codigo_expediente, nombre_obra, etapa, fecha_inicio, fecha_final,
    descripcion, beneficiarios, id_constructora, id_region, codigo_supervisor,
    estado, latitud, longitud, precision_ubicacion_m, metodo_ubicacion
)
VALUES (
    'DEMO-OATB-OBRA', 'DEMO-OATB-EXP', 'Obra demostrativa para validar geolocalización',
    1, CURRENT_DATE, CURRENT_DATE + 90,
    'Registro sintético para verificar la distancia entre la obra y una evidencia.',
    'Solo registros demostrativos', 'DEMO-OATB-CONST', 'DEMO-OATB-REG',
    'DEMO-OATB-SUP', TRUE, 19.045000, -100.045000, 5.0, 'gps'
)
ON CONFLICT (id_obra) DO UPDATE SET
    latitud = EXCLUDED.latitud,
    longitud = EXCLUDED.longitud,
    precision_ubicacion_m = EXCLUDED.precision_ubicacion_m,
    metodo_ubicacion = EXCLUDED.metodo_ubicacion;

INSERT INTO public.informes (
    id_informe, ano_infor, mes, porcentaje_avance_fisico,
    porcentaje_avance_presupuestario, doc_infome, descripcion, id_obra, codigo_supervisor
)
VALUES (
    'DEMO-OATB-INF', EXTRACT(YEAR FROM CURRENT_DATE)::integer,
    to_char(CURRENT_DATE, 'TMMonth'), 10, 10,
    'DEMO-OATB-documento', 'Informe sintético para demostrar validación de ubicación.',
    'DEMO-OATB-OBRA', 'DEMO-OATB-SUP'
)
ON CONFLICT (id_informe) DO NOTHING;

INSERT INTO public.imagenes_informe (
    id_imagen, id_informe, url_publica, ruta_r2, nombre_original,
    tipo_mime, tamaño_bytes, fecha_subida, latitud, longitud, fecha_captura
)
VALUES (
    'eeee1111-2222-4333-8444-555566667777'::uuid, 'DEMO-OATB-INF',
    'https://example.invalid/demo-ejercicio8-foto.jpg',
    'demo/issue16/imagen-sintetica.jpg', 'imagen-demo-ubicacion.jpg',
    'image/jpeg', 123456, now(), 19.048000, -100.045000, now() - interval '10 minutes'
)
ON CONFLICT (id_imagen) DO UPDATE SET
    latitud = EXCLUDED.latitud,
    longitud = EXCLUDED.longitud,
    fecha_captura = EXCLUDED.fecha_captura;

-- Distancia geodésica aproximada en metros con fórmula de Haversine.
WITH distancia AS (
    SELECT i.id_imagen,
           2.0 * 6371000.0 * asin(sqrt(least(1.0,
               power(sin(radians(i.latitud - o.latitud) / 2.0), 2) +
               cos(radians(o.latitud)) * cos(radians(i.latitud)) *
               power(sin(radians(i.longitud - o.longitud) / 2.0), 2)
           ))) AS metros
    FROM public.imagenes_informe i
    JOIN public.informes inf ON inf.id_informe = i.id_informe
    JOIN public.obra o ON o.id_obra = inf.id_obra
    WHERE i.id_imagen = 'eeee1111-2222-4333-8444-555566667777'::uuid
)
UPDATE public.imagenes_informe i
SET distancia_a_obra_m = d.metros,
    fuera_de_rango = (d.metros > 100.0)
FROM distancia d
WHERE i.id_imagen = d.id_imagen;

DELETE FROM public.analisis_ubicacion_ia
WHERE version_modelo = 'demo-geofoto-0.1'
  AND salida_modelo ->> 'demostracion' = 'true'
  AND id_imagen = 'eeee1111-2222-4333-8444-555566667777'::uuid;

INSERT INTO public.analisis_ubicacion_ia (
    id_imagen, tipo_resultado, clase_predicha, es_anomalia,
    puntaje_anomalia, confianza, distancia_calculada_m, umbral_distancia_m,
    fecha_analisis, version_modelo, salida_modelo
)
SELECT i.id_imagen,
       'deteccion_anomalia',
       CASE
           WHEN i.latitud IS NULL OR i.longitud IS NULL THEN 'ubicacion_no_disponible'
           WHEN COALESCE(i.fuera_de_rango, FALSE) THEN 'fuera_rango'
           ELSE 'dentro_rango'
       END,
       COALESCE(i.fuera_de_rango, FALSE),
       CASE WHEN COALESCE(i.fuera_de_rango, FALSE) THEN 0.96 ELSE 0.04 END,
       0.93,
       i.distancia_a_obra_m,
       100.0,
       now(),
       'demo-geofoto-0.1',
       jsonb_build_object(
           'demostracion', true,
           'nota', 'Salida sintética generada para probar el esquema; no proviene de un modelo entrenado.',
           'umbral_m', 100.0,
           'metodo_distancia', 'Haversine'
       )
FROM public.imagenes_informe i
WHERE i.id_imagen = 'eeee1111-2222-4333-8444-555566667777'::uuid;

COMMIT;
