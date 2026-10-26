# Ejercicio 8. Cambio de esquema por integrante

**Integrante:** OmarFloresIIA  
**Issue original:** [#11 — Agrupar por tema las propuestas de la gente y avisar cuando se repiten](https://github.com/oatbrend/PRACTICA2-DB/issues/11)  
**Área:** Ingeniería en Inteligencia Artificial

## 1. Tablas, columnas y restricciones nuevas

La propuesta de IA consiste en agrupar propuestas ciudadanas por tema y detectar textos con significado similar. Se modifica el esquema operacional PostgreSQL declarado en `db/DDLBASEObPub.sql`.

- `tema_propuesta`: nuevo catálogo de temas, con PK `id_tema`, nombre único, palabras clave y versión del modelo asociado a la creación/actualización del tema.
- `propuestas_obras`: añade `id_tema`, `puntaje_pertenencia`, `id_propuesta_similar`, `similitud` e `id_region`. Las FK conectan la propuesta con el tema, con otra propuesta candidata a duplicado y con `region`. `id_region` queda nullable durante la migración porque el campo de texto `region` ya existente debe mapearse a los identificadores reales antes de poder exigir su obligatoriedad. Los puntajes se restringen al intervalo [0,1] y una propuesta no puede apuntar a sí misma como similar.
- `propuesta_embedding`: guarda la representación numérica del texto, su propuesta de origen, versión del modelo y fecha de generación. La combinación propuesta/modelo es única.
- `analisis_propuesta_ia`: tabla de resultados históricos. Cada fila guarda la propuesta evaluada, tema predicho, posible propuesta similar, tipo de resultado, puntajes, bandera de repetición, fecha de predicción, versión del modelo y salida adicional.

## Tipos de dato elegidos

Los puntajes usan `DOUBLE PRECISION` porque son valores continuos y pueden conservar decimales como 0.87 o 0.91; `CHECK` impide valores fuera de [0,1]. `TIMESTAMPTZ` registra el instante de predicción junto con información de zona horaria. `version_modelo` usa texto para permitir identificadores como `sentence-transformer-v2.1` o versiones internas. `salida_modelo` usa `JSONB` para guardar metadatos estructurados sin tener que modificar la tabla cuando el modelo agregue información. El embedding se representa como `DOUBLE PRECISION[]`, evitando depender de la extensión opcional `pgvector`; la similitud se calcula en el servicio de IA y el valor resultante se almacena en la tabla histórica. Para búsqueda vectorial directamente en PostgreSQL podría migrarse después a `vector(n)` con `pgvector` instalado.

## 2. Archivo SQL y ejecución

El archivo `db/cambio-usuario.sql` contiene las instrucciones `CREATE TABLE`, `ALTER TABLE`, claves foráneas, restricciones e índices. Ejecutarlo sobre una **copia** de la base del proyecto después de crear el esquema operacional con `db/DDLBASEObPub.sql`.

Para obtener filas visibles en la consulta, `db/diagramas/datos-demo-ejercicio8.sql` crea un poblador y dos propuestas identificadas explícitamente como `DEMO_EJ8`, además de resultados artificiales etiquetados como `demo-manual-0.1`. Estos valores se incluyen exclusivamente para probar el esquema y la consulta: no son la salida de un modelo de IA ejecutado. En una demostración formal debe explicarse esta diferencia o sustituirse la fila por una predicción real del modelo.

La consulta del punto 3 está en `db/diagramas/consulta-ejercicio8.sql`. Se debe ejecutar después de ambos scripts anteriores. La captura de pantalla debe tomarse en pgAdmin/psql después de ejecutar los comandos sobre la copia local; no se adjunta una captura generada artificialmente.

## 3. Consulta que depende del cambio

`consulta-ejercicio8.sql` une `analisis_propuesta_ia` con `propuestas_obras`, `tema_propuesta` y la propuesta similar. Devuelve el tema asignado, puntaje, propuesta candidata a repetición, similitud, marca de repetición, momento de inferencia y versión del modelo. Esta consulta no puede ejecutarse antes del cambio porque las tablas `analisis_propuesta_ia` y `tema_propuesta`, sus referencias y los nuevos atributos no existen en el esquema original.

Con los datos demostrativos, se esperan dos filas: una clasificación de tema y una detección de similitud. Ambas tendrán la versión `demo-manual-0.1`; `salida_modelo.demostracion` mostrará `true`, para identificar sin ambigüedad que son filas sintéticas.

## 4. Nota de media cuartilla: regla, estrategia y datos existentes

El cambio aplica principalmente la regla 1, porque agrega la entidad `tema_propuesta` y las tablas `propuesta_embedding` y `analisis_propuesta_ia`. También emplea la regla 4 para relacionar cada propuesta con un tema, otra propuesta candidata a duplicado y una región mediante claves foráneas. La estrategia separa los vectores de entrada de los resultados de inferencia: `propuesta_embedding` almacena la representación numérica del texto, mientras que `analisis_propuesta_ia` conserva cada predicción con fecha, versión de modelo y la FK a la propuesta evaluada. Esta separación es necesaria porque el modelo podría reclasificar una propuesta después de entrenarse con nuevos datos; sobrescribir el resultado anterior impediría reproducir el historial.

Se eligieron `DOUBLE PRECISION` para los puntajes y la similitud debido a que son valores continuos entre cero y uno, `TIMESTAMPTZ` para guardar cuándo se produjo cada resultado, `VARCHAR/TEXT` para la versión del modelo y `JSONB` para detalles adicionales de salida. El embedding se guarda como arreglo `DOUBLE PRECISION[]`, un tipo soportado por PostgreSQL sin instalar extensiones. El servicio de IA calcula la similitud y la guarda como escalar; si en el futuro se requiere búsqueda vectorial dentro de la base, podrá evaluarse `pgvector`.

Los registros que ya existen no se eliminan ni se recalculan al ejecutar el cambio. Las columnas nuevas de `propuestas_obras` quedan en `NULL`, ya que el modelo todavía no ha analizado esas propuestas. La nueva columna `id_region` también queda en `NULL`: como `region` era texto libre y la tabla `region` utiliza `id_region`, es necesario mapear manualmente los valores existentes antes de realizar una migración y, si procede, hacerla obligatoria. La tabla de embeddings y la tabla de resultados empiezan vacías hasta que se ejecute el modelo o el proceso demostrativo. Así se preserva la información anterior y se distingue entre datos reales, resultados futuros y filas sintéticas de prueba.

## 5. Evidencia pendiente de ejecución

Este entorno de preparación no dispone de un servidor PostgreSQL ni de Docker, por lo que no se afirma que el SQL se haya ejecutado aquí. La evidencia final requerida por la práctica es una captura de pgAdmin/psql donde se vea la ejecución correcta de `cambio-usuario.sql` y el resultado de `consulta-ejercicio8.sql` sobre una copia de la base.
