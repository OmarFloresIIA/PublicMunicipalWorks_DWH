# Ejercicio 8 — Cambio de esquema para la issue #16

**Propuesta:** [Guardar la ubicación real de las obras y comprobar que las fotos se tomaron ahí](https://github.com/oatbrend/PRACTICA2-DB/issues/16)  
**Autor de la issue original:** oatbrend  
**Área:** Ingeniería en Inteligencia Artificial

## 1. Tablas, columnas y restricciones nuevas o modificadas

En `obra` se agregan `latitud`, `longitud`, `precision_ubicacion_m` y `metodo_ubicacion`. En `imagenes_informe` se añaden `latitud`, `longitud`, `fecha_captura`, `distancia_a_obra_m` y `fuera_de_rango`. Las columnas existentes no se sustituyen, para conservar la compatibilidad con los datos históricos.

Se crea `analisis_ubicacion_ia`, que guarda cada salida de análisis vinculada con la imagen mediante la FK `id_imagen`. Sus columnas incluyen la clase predicha, si se detectó anomalía, puntaje de anomalía, confianza, distancia calculada, umbral, fecha de análisis, versión del modelo y un campo JSONB con información adicional. La tabla mantiene el historial; una nueva versión del modelo crea otra fila y no elimina el resultado anterior.

Se añaden CHECK para limitar latitud a [-90, 90], longitud a [-180, 180], puntajes y confianza a [0, 1], distancia y precisión a valores no negativos, y método de ubicación a `gps`, `manual` o `aproximada`. Se agregan índices para recuperar los resultados de cada imagen por fecha y localizar análisis marcados como anomalía.

## 2. Justificación de los tipos de datos

Las coordenadas y las distancias usan `DOUBLE PRECISION`, ya que requieren valores decimales y no son cantidades enteras. La precisión de la ubicación y la distancia se expresan en metros. `TIMESTAMPTZ` conserva el momento de la captura y del análisis, importante para auditoría entre dispositivos con zonas horarias distintas. `version_modelo` usa `VARCHAR(100)` porque las versiones suelen ser etiquetas, por ejemplo `geo-anomaly-v1.2`. `JSONB` guarda metadatos complementarios y la salida estructurada del modelo sin exigir una columna nueva por cada parámetro futuro. `BOOLEAN` representa de forma directa si se marcó una foto como fuera de rango y si el modelo detectó anomalía.

El embedding o los datos de entrada no son suficientes para reproducir el resultado. Por ello, `analisis_ubicacion_ia` también conserva la predicción, su puntaje, la versión del modelo, la fecha y la imagen que se calificó. La distancia puede calcularse con Haversine sin extensiones; PostGIS es una mejora posible si más adelante se requieren tipos geográficos y consultas espaciales indexadas.

## 3. Consulta nueva

`consulta-ubicacion-ia.sql` une `analisis_ubicacion_ia`, `imagenes_informe`, `informes` y `obra`. Devuelve la obra y evidencia concretas, ambas ubicaciones, distancia, estado fuera de rango, clase predicha, puntaje, confianza, marca temporal y versión del modelo. Requiere la nueva tabla de análisis y los nuevos atributos geográficos, así que no puede ejecutarse sobre el esquema previo sin aplicar el cambio.

## 4. Nota de media cuartilla: regla, estrategia y datos existentes

La propuesta aplica la regla 1 al ampliar la representación de Obra y Evidencia mediante atributos nuevos, y la regla 4 porque cada análisis se relaciona con la imagen que califica mediante una clave foránea. La salida del análisis se mantiene en una tabla separada para no mezclar los metadatos originales de la fotografía con predicciones potencialmente cambiantes. Esta separación permite conservar varias evaluaciones para la misma imagen, comparar versiones del modelo y revisar cuándo cambió la clasificación. La FK a `imagenes_informe(id_imagen)` identifica exactamente la evidencia examinada; por medio de `informes` se recupera la obra a la que pertenece.

Se eligieron coordenadas y medidas `DOUBLE PRECISION` para guardar decimales, `TIMESTAMPTZ` para registrar captura y análisis, `BOOLEAN` para las banderas, `VARCHAR` para la versión del modelo y `JSONB` para detalles adicionales de la salida. Los CHECK limitan los dominios de coordenadas y puntajes. El ejemplo calcula distancia con Haversine y usa un umbral demostrativo de 100 metros; ese umbral debe ser una decisión validada por el equipo, no una verdad universal sobre la posición de una foto.

Cuando se aplica el cambio a una copia de la base, las obras e imágenes que ya existían no se borran. Sus nuevas coordenadas, fechas de captura, distancias y banderas permanecen en `NULL` hasta que se recuperen datos GPS o se procese la evidencia. No se inventa la ubicación de las fotos históricas. La tabla `analisis_ubicacion_ia` comienza vacía y se llena cuando el servicio de IA ejecuta el análisis. El archivo de datos de prueba introduce una obra y una imagen sintéticas y marca claramente la salida como demostrativa; sus valores no deben presentarse como una inferencia real. La ejecución final debe realizarse en una copia local de PostgreSQL y documentarse con una captura auténtica de la consulta y su resultado.

## Archivos

- Cambio de esquema: [`db/diagramas/issue16/cambio-usuario.sql`](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/diagramas/issue16/cambio-usuario.sql)
- Consulta: [`consulta-ubicacion-ia.sql`](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/diagramas/issue16/consulta-ubicacion-ia.sql)
- Datos demostrativos: [`datos-demo-ubicacion-ia.sql`](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/diagramas/issue16/datos-demo-ubicacion-ia.sql)

**Estado de evidencia:** los scripts quedan versionados en el repositorio, pero falta ejecutarlos sobre una copia local y tomar la captura real. Los valores del script demo están etiquetados como sintéticos.
