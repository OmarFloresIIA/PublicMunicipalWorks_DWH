# Ejercicio 7.3. Comparación entre el modelo EER y el modelo relacional

## Propósito

El objetivo de esta comparación es observar cómo los conceptos del EER reconstruido por el equipo se implementan —o dejan de implementarse de forma directa— en el esquema relacional operacional de Obras Públicas. Para ello se utilizan el diagrama EER compartido, el diagrama relacional y el archivo [db/DDLBASEObPub.sql](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/DDLBASEObPub.sql) del repositorio.

El EER expresa entidades, atributos, relaciones, especializaciones y cardinalidades del dominio. El relacional implementa estas estructuras con tablas, columnas, claves primarias, claves foráneas y restricciones. Ambos modelos describen el mismo dominio general, pero no existe una correspondencia exacta entre todos sus elementos: la comparación identifica tanto las transformaciones logradas como las diferencias observables.

## Tabla comparativa

| Elemento solicitado | En el modelo EER | En el modelo relacional | Qué se ganó y qué se perdió |
|---|---|---|---|
| **Entidades fuertes** | Se identifican entidades como USUARIO, COMUNIDAD, PROPUESTA, REPORTE_AVANCE, OBRA, CONTRATISTA, FUENTE y EVIDENCIA. Cada una representa un concepto del dominio y muestra atributos propios. | Se corresponden de manera aproximada con tablas como pobladores y personal (para las especializaciones de usuario), propuestas_obras, informes, obra, constructora, fuente_presupuestaria e imagenes_informe. Las tablas cuentan con claves primarias declaradas. | **Se ganó:** identificadores, tipos de datos y restricciones que permiten almacenar y consultar registros estructurados. **Se perdió:** la correspondencia no es exacta. No existe una tabla usuario ni una tabla comunidad con todos los atributos conceptuales del EER. Algunas entidades fueron divididas o simplificadas. |
| **Entidades débiles** | Una entidad débil depende de otra para identificarse; suele representarse con rectángulo doble y una relación identificadora. En el EER compartido no se distingue con certeza una entidad débil por identificación. | imagenes_informe tiene id_imagen como PK y id_informe como FK; firmantes tiene id_firmante como PK e id_acta como FK. Ambas poseen identificador propio. | **Se ganó:** cada imagen o firmante puede identificarse y administrarse de forma independiente. **Se perdió:** si el EER pretendía que una de ellas fuera débil por identificación, el esquema no emplea la PK compuesta que exige la regla 8. Sin símbolos inequívocos en el EER, no se debe afirmar que exista una violación concreta de esa regla; dependencia por FK no equivale automáticamente a debilidad. |
| **Relaciones muchos a muchos** | VOTA conecta conceptualmente CIUDADANO con PROPUESTA. FINANCIA conecta OBRA con FUENTE y tiene atributos propios visibles, entre ellos fecha_oficio y monto_asignado. | votos_propuestas guarda poblador_id y propuesta_id como FK, además de periodo_voto y creado_en. financia usa id_obra e id_fuente como FK y PK compuesta por ambas. | **Se ganó:** las asociaciones se almacenan explícitamente y las FK evitan referencias a registros inexistentes. financia aplica de manera directa la estructura de la regla 5 al usar una PK compuesta. **Se perdió:** votos_propuestas usa una PK artificial y no impone UNIQUE sobre poblador, propuesta y periodo; por ello admite repeticiones de esa combinación. Además, financia omite fecha_oficio y monto_asignado, atributos de FINANCIA presentes en el EER. |
| **Jerarquías** | USUARIO se especializa en CIUDADANO y SERVIDOR_PÚBLICO con marcador d (disjunta). SERVIDOR_PÚBLICO se especializa en roles como DIRECTOR y SUPERVISOR. OBRA se especializa en VIAL, EDIFICACIÓN e HIDRÁULICA. La imagen disponible no permite asegurar si todas las especializaciones son totales o parciales. | pobladores y personal están separados, sin una tabla supertipo usuario. supervisor y proyectista comparten codigo_personal como PK/FK hacia personal. No hay tabla director, y obra no tiene tablas para Vial, Edificación e Hidráulica ni un discriminador explícito para distinguir esos subtipos. | **Se ganó:** separar supervisor y proyectista permite almacenar atributos específicos de esos roles; personal.rol restringe los valores permitidos. **Se perdió:** las jerarquías del EER no se conservan uniformemente. No se comparte la información común en una tabla usuario, la jerarquía del servidor público se representa parcialmente y no se pueden distinguir estructuralmente los subtipos de obra ni almacenar sus atributos particulares mediante tablas propias. |
| **Atributos multivaluados** | El EER presenta EVIDENCIA como entidad con atributos (identificador, URL, tipo, fecha de carga, nombre de archivo y tamaño) vinculada con REPORTE_AVANCE mediante ADJUNTA. No se reconoce con certeza un atributo representado mediante doble óvalo. | imagenes_informe guarda una fila por evidencia, con id_imagen como PK e id_informe como FK, además de URL, ruta, nombre original, tipo MIME, tamaño y fecha. | **Se ganó:** cada evidencia tiene sus propios metadatos y puede administrarse individualmente. **Se perdió:** no se sigue literalmente la regla 3 de un atributo multivaluado convertido en tabla con PK compuesta por la clave de la entidad y el valor, pues se usa UUID propio. Esto es razonable porque EVIDENCIA está modelada como entidad independiente, no como un simple atributo multivaluado. |

## Lectura de la comparación

### 1. Entidades fuertes y nombres diferentes

La transformación de una entidad fuerte en una tabla es la correspondencia más directa entre EER y relacional, pero la comparación debe basarse en el significado y no solo en el nombre. CONTRATISTA se aproxima a constructora y FUENTE a fuente_presupuestaria. COMUNIDAD, en cambio, no tiene una tabla equivalente completa: region conserva comunidad, barrio y colonia, pero no la clave, las coordenadas ni el número de habitantes que se muestran en el EER.

También hay una diferencia en USUARIO. El EER propone atributos comunes antes de especializar a ciudadanos y servidores públicos; el esquema relacional conserva los datos en pobladores y personal por separado. Esto evita una tabla común, pero dificulta asegurar reglas comunes para todos los usuarios y repite parte de la estructura de identificación.

### 2. Relaciones y atributos propios

financia representa correctamente la asociación entre Obra y Fuente mediante una PK compuesta por las dos FK. Sin embargo, la regla 5 indica que también deben incluirse los atributos propios de la relación. En el EER, FINANCIA presenta fecha_oficio y monto_asignado, que no aparecen en la tabla operacional. Por eso, aunque se conserva la asociación, se pierde parte de la información conceptual.

votos_propuestas conserva ambas FK y los datos temporales, pero no impone UNIQUE sobre la combinación de votante, propuesta y periodo. Si el sistema debe permitir un solo voto por propuesta y periodo, falta una restricción. Si cada fila representa un evento de voto y se admiten varios eventos, esa decisión debe documentarse como regla de negocio.

### 3. Especializaciones y su implementación

La regla 9 contempla tres estrategias: A) tabla para el supertipo y cada subtipo; B) tabla única con discriminador; C) una tabla por subtipo sin supertipo, apropiada cuando la especialización es total y disjunta.

- **USUARIO → CIUDADANO / SERVIDOR_PÚBLICO:** pobladores y personal se almacenan por separado, sin una tabla usuario común, lo que se aproxima a la estrategia C. El EER marca disyunción con d. La totalidad o parcialidad debe confirmarse en el archivo fuente por la conexión al círculo; no debe inferirse solo del marcador.
- **SERVIDOR_PÚBLICO → DIRECTOR / SUPERVISOR:** supervisor se representa mediante una tabla relacionada con personal, aproximándose a la estrategia A. Director aparece solo como valor de personal.rol, no como tabla de subtipo. El relacional añade proyectista, que no aparece en la jerarquía del EER compartido.
- **OBRA → VIAL / EDIFICACIÓN / HIDRÁULICA:** el SQL conserva una sola tabla obra y no incluye tabla por subtipo ni un discriminador. No implementa completamente ninguna de las tres estrategias, de modo que la clase de obra y sus atributos particulares no pueden representarse de forma estructurada.

La diferencia no es solo de organización física: al no reflejar las especializaciones, el relacional puede perder restricciones y atributos que el EER considera parte del significado del dominio.

### 4. Entidades débiles frente a dependencias referenciales

Una FK hacia otra tabla no convierte automáticamente a una entidad en débil. imagenes_informe, firmantes y costos tienen claves propias. En el EER proporcionado no se reconocen claramente rectángulos dobles ni relaciones identificadoras dobles; por tanto, no se concluye que alguna sea una entidad débil por identificación.

De igual forma, EVIDENCIA aparece como entidad con atributos y relación ADJUNTA. Por ello, imagenes_informe se entiende mejor como una tabla de entidad asociada a informe que como la traducción literal de un atributo multivaluado. La regla 3 se aplicaría directamente si el EER mostrara expresamente un atributo multivaluado.

## Conclusión

El esquema relacional implementa varias transformaciones importantes: entidades con PK, relaciones uno a muchos mediante FK, la asociación Obra–Fuente mediante PK compuesta y evidencias individuales vinculadas con informes. Las diferencias más importantes frente al EER se encuentran en la ausencia de una tabla común usuario y de una tabla comunidad completa, la implementación incompleta de las jerarquías de personal y obra, la omisión de atributos de FINANCIA y la falta de una restricción que garantice la unicidad de un voto por poblador, propuesta y periodo.

La comparación muestra que una transformación no consiste solo en crear tablas y claves: debe preservar también los atributos de las relaciones, las cardinalidades y las restricciones conceptuales. Cuando el modelo relacional se aparta del EER, la decisión debe documentarse para evitar pérdida de información o ambigüedades en las reglas del sistema.

## Fuentes

- Esquema relacional operacional: [db/DDLBASEObPub.sql](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/DDLBASEObPub.sql).
- Diagrama EER reconstruido y diagrama relacional: imágenes compartidas por el equipo en la conversación.
