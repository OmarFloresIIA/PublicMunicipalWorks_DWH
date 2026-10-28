-- Consulta de evidencia del Ejercicio 8 / Issue #16.
-- Muestra la foto evaluada, ubicación de obra y foto, resultado del análisis,
-- la fecha, el modelo y el dato que indica si la fila es solo demostrativa.

SELECT
    a.id_analisis,
    inf.id_obra,
    o.nombre_obra,
    i.id_imagen,
    i.url_publica,
    o.latitud AS obra_latitud,
    o.longitud AS obra_longitud,
    i.latitud AS foto_latitud,
    i.longitud AS foto_longitud,
    i.fecha_captura,
    i.distancia_a_obra_m,
    i.fuera_de_rango AS estado_almacenado,
    a.clase_predicha,
    a.es_anomalia,
    a.puntaje_anomalia,
    a.confianza,
    a.umbral_distancia_m,
    a.fecha_analisis,
    a.version_modelo,
    a.salida_modelo ->> 'demostracion' AS es_dato_demostrativo
FROM public.analisis_ubicacion_ia AS a
JOIN public.imagenes_informe AS i
  ON i.id_imagen = a.id_imagen
JOIN public.informes AS inf
  ON inf.id_informe = i.id_informe
JOIN public.obra AS o
  ON o.id_obra = inf.id_obra
ORDER BY a.fecha_analisis DESC, a.id_analisis DESC
LIMIT 20;
