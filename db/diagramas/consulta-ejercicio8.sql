-- Ejercicio 8, punto 3: consultar resultados producidos y guardados por el modelo.
-- Requiere cambio-usuario.sql y filas en analisis_propuesta_ia.

SELECT
    a.id_analisis,
    p.id AS id_propuesta,
    p.titulo AS propuesta_evaluada,
    a.tipo_resultado,
    t.nombre AS tema_predicho,
    a.puntaje_pertenencia,
    propuesta_similar.id AS id_propuesta_similar,
    propuesta_similar.titulo AS propuesta_similar,
    a.similitud,
    a.es_repetida,
    a.fecha_prediccion,
    a.version_modelo,
    a.salida_modelo ->> 'demostracion' AS es_dato_demostrativo
FROM public.analisis_propuesta_ia AS a
JOIN public.propuestas_obras AS p
  ON p.id = a.id_propuesta
LEFT JOIN public.tema_propuesta AS t
  ON t.id_tema = a.id_tema
LEFT JOIN public.propuestas_obras AS propuesta_similar
  ON propuesta_similar.id = a.id_propuesta_similar
ORDER BY a.fecha_prediccion DESC, a.id_analisis DESC
LIMIT 20;
