-- DATOS DE DEMOSTRACIÓN: solo para una copia local/de práctica.
-- La salida se marca como demostrativa; NO es una inferencia real de un modelo.
-- Ejecutar después de cambio-usuario.sql. El script puede repetirse sin duplicar
-- las filas de demostración que crea.

DO $$
DECLARE
    v_poblador_id integer;
    v_propuesta_a integer;
    v_propuesta_b integer;
    v_tema_id integer;
BEGIN
    INSERT INTO public.tema_propuesta (nombre, palabras_clave, version_modelo)
    VALUES (
        'DEMO_EJ8_Infraestructura_vial',
        ARRAY['camino', 'calle', 'pavimentación', 'bache']::text[],
        'demo-manual-0.1'
    )
    ON CONFLICT (nombre) DO UPDATE
        SET palabras_clave = EXCLUDED.palabras_clave,
            version_modelo = EXCLUDED.version_modelo
    RETURNING id_tema INTO v_tema_id;

    SELECT id INTO v_poblador_id
    FROM public.pobladores
    WHERE username = 'demo_ej8_ia'
    LIMIT 1;

    IF v_poblador_id IS NULL THEN
        INSERT INTO public.pobladores
            (nombre, apellidos, comunidad, username, password_hash, curp)
        VALUES
            ('Usuario demostrativo', 'Ejercicio Ocho', 'Temascaltepec',
             'demo_ej8_ia', 'NO_USAR_COMO_CREDENCIAL', 'DEMOEJ8IA000000000')
        RETURNING id INTO v_poblador_id;
    END IF;

    SELECT id INTO v_propuesta_a
    FROM public.propuestas_obras
    WHERE poblador_id = v_poblador_id
      AND titulo = 'DEMO_EJ8_Reparacion_de_caminos'
    LIMIT 1;

    IF v_propuesta_a IS NULL THEN
        INSERT INTO public.propuestas_obras
            (poblador_id, titulo, region, descripcion_obra,
             descripcion_beneficiados, pros_comunidad, anio_convocatoria)
        VALUES
            (v_poblador_id, 'DEMO_EJ8_Reparacion_de_caminos', 'Temascaltepec',
             'Reparar caminos y cubrir baches en calles de la comunidad.',
             'Personas que transitan por las calles y caminos locales.',
             'Mejora la movilidad y el acceso a servicios.',
             EXTRACT(YEAR FROM CURRENT_DATE)::integer)
        RETURNING id INTO v_propuesta_a;
    END IF;

    SELECT id INTO v_propuesta_b
    FROM public.propuestas_obras
    WHERE poblador_id = v_poblador_id
      AND titulo = 'DEMO_EJ8_Mejorar_calles_y_baches'
    LIMIT 1;

    IF v_propuesta_b IS NULL THEN
        INSERT INTO public.propuestas_obras
            (poblador_id, titulo, region, descripcion_obra,
             descripcion_beneficiados, pros_comunidad, anio_convocatoria)
        VALUES
            (v_poblador_id, 'DEMO_EJ8_Mejorar_calles_y_baches', 'Temascaltepec',
             'Atender baches y mejorar el estado de las calles de la localidad.',
             'Habitantes y conductores de la comunidad.',
             'Facilita los traslados cotidianos.',
             EXTRACT(YEAR FROM CURRENT_DATE)::integer)
        RETURNING id INTO v_propuesta_b;
    END IF;

    UPDATE public.propuestas_obras
       SET id_tema = v_tema_id,
           puntaje_pertenencia = 0.87,
           id_propuesta_similar = v_propuesta_b,
           similitud = 0.91
     WHERE id = v_propuesta_a;

    DELETE FROM public.analisis_propuesta_ia
    WHERE version_modelo = 'demo-manual-0.1'
      AND salida_modelo ->> 'demostracion' = 'true';

    INSERT INTO public.analisis_propuesta_ia
        (id_propuesta, id_tema, id_propuesta_similar, tipo_resultado,
         puntaje_pertenencia, similitud, es_repetida, fecha_prediccion,
         version_modelo, salida_modelo)
    VALUES
        (v_propuesta_a, v_tema_id, NULL, 'clasificacion_tema',
         0.87, NULL, false, now(), 'demo-manual-0.1',
         jsonb_build_object(
             'demostracion', true,
             'nota', 'Salida sintética para probar el esquema; no proviene de una inferencia real.'
         )),
        (v_propuesta_a, v_tema_id, v_propuesta_b, 'deteccion_similitud',
         0.87, 0.91, true, now(), 'demo-manual-0.1',
         jsonb_build_object(
             'demostracion', true,
             'nota', 'Similitud sintética para probar el esquema; no proviene de una inferencia real.'
         ));
END $$;

-- Ejecutar a continuación consulta-ejercicio8.sql para mostrar dos filas de ejemplo.
