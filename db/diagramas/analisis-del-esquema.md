# Ejercicio 7. El esquema del proyecto asignado

## Alcance y fuentes

Para el apartado 7.1 se toma como fuente principal el esquema relacional operacional definido en [db/DDLBASEObPub.sql](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/DDLBASEObPub.sql). Se contrasta con el EER y el diagrama relacional compartidos por el equipo. Para el apartado 7.2 se utiliza [db/arquitectura/ESQUEMA DEL DATA WAREHOUSE.sql](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/arquitectura/ESQUEMA%20DEL%20DATA%20WAREHOUSE.sql), porque contiene el almacén dimensional.

Es importante distinguir ambos esquemas: DDLBASEObPub.sql describe la base operacional y sus relaciones; el archivo dentro de db/arquitectura describe un almacén dimensional orientado a consultas analíticas. El EER y el modelo relacional no son una traducción exacta uno a uno: hay elementos conceptuales que no aparecen con la misma estructura en SQL y algunas tablas operacionales que amplían el EER. Esas diferencias se documentan sin asumir equivalencias que los diagramas no demuestran.

---

## 7.1. Las reglas detrás del esquema

Las reglas de los ejercicios 3 a 5 que se consideran son:

- **Regla 1:** cada entidad fuerte se convierte en una tabla con clave primaria.
- **Regla 2:** los atributos compuestos se descomponen en columnas para sus componentes simples.
- **Regla 3:** un atributo multivaluado se representa mediante una tabla separada con la clave de la entidad original y el valor.
- **Regla 4:** una relación uno a muchos se representa propagando la PK del lado uno como FK del lado muchos.
- **Regla 5:** una relación muchos a muchos se convierte en una tabla asociativa con las claves de ambas entidades y los atributos propios de la relación.
- **Regla 6:** una relación uno a uno se implementa con una FK y UNIQUE, con FK UNIQUE y NOT NULL cuando ambas partes son obligatorias, o fusionando las entidades cuando tiene sentido.
- **Regla 7:** las relaciones ternarias o de mayor grado se convierten en una tabla con las claves de todas las entidades participantes y los atributos propios de la relación.
- **Regla 8:** una entidad débil por identificación lleva una PK compuesta por la clave del propietario y el discriminador. Si la dependencia es solo de existencia, conserva su PK y añade una FK NOT NULL.
- **Regla 9:** las jerarquías se implementan con tablas por supertipo y subtipo, una tabla única con discriminador o tablas por subtipo sin supertipo.

### Análisis tabla por tabla del modelo relacional operacional

La tabla siguiente se basa en las declaraciones CREATE TABLE del archivo operacional. PK significa clave primaria y FK, clave foránea. Se distinguen las restricciones declaradas en el DDL de las relaciones que solo pueden inferirse conceptualmente del EER.

| Tabla | Relación con el EER y regla aplicable | PK y FK declaradas | Restricciones y observaciones |
|---|---|---|---|
| **constructora** | Se corresponde de forma aproximada con CONTRATISTA. Regla 1. | **PK:** id_constructora. **FK:** ninguna. | id_constructora, nombre_const y tipo_ejecutor son NOT NULL. rfc es UNIQUE y admite nulos. El EER muestra razón social, domicilio y teléfono; no todos estos atributos aparecen en la tabla operacional. |
| **fuente_presupuestaria** | Se aproxima a FUENTE. Regla 1. | **PK:** id_fuente. **FK:** ninguna. | id_fuente, grado_nivel y programa son NOT NULL. En el EER también aparecen clave, denominación y nivel de gobierno. La tabla financia del SQL no conserva los atributos fecha_oficio y monto_asignado que aparecen en la relación FINANCIA del EER. |
| **personal** | Representa parte de la estructura de personal y se vincula con la jerarquía del EER. Regla 1 y, parcialmente, regla 9. | **PK:** codigo_personal. **FK:** ninguna en esta tabla. | codigo_personal, nombre, apellido_paterno y rol son NOT NULL. username es UNIQUE, pero admite nulos. rol tiene CHECK que limita el valor a Supervisor, Director, Secretario o Proyectista. apellido_materno y password_hash admiten nulos. No existe una tabla común usuario. |
| **region** | Solo se aproxima parcialmente a COMUNIDAD. Regla 1. | **PK:** id_region. **FK:** ninguna. | id_region, comunidad y barrio son NOT NULL; colonia admite nulos. El EER muestra una entidad COMUNIDAD con clave, nombre, número de habitantes, latitud y longitud; no existe una tabla equivalente con todos esos atributos. |
| **pobladores** | Se aproxima al subtipo CIUDADANO. La separación respecto de personal afecta la regla 9. | **PK:** id, identidad autogenerada. **FK:** ninguna en esta tabla. | id usa GENERATED ALWAYS AS IDENTITY. nombre, apellidos, comunidad, username, password_hash y curp son NOT NULL. username y curp son UNIQUE. creado_en tiene DEFAULT now(). comunidad es texto, no una FK a una entidad Comunidad. |
| **proyectista** | Tabla de subtipo operacional asociada a personal; no aparece con ese nombre en la jerarquía del EER compartido. Regla 9 aplicada parcialmente. | **PK:** codigo_personal. **FK:** codigo_personal → personal(codigo_personal); id_constructora → constructora(id_constructora). | codigo_personal, empresa e id_constructora son NOT NULL. La PK compartida con la FK vincula el subtipo con personal. El EER representa Director y Supervisor, pero no Proyectista. |
| **supervisor** | Se aproxima al subtipo SUPERVISOR. Regla 9: tabla general y tabla de subtipo. | **PK:** codigo_personal. **FK:** codigo_personal → personal(codigo_personal). | codigo_personal es NOT NULL; telefono admite nulos. El EER parece mostrar cedula_profesional como atributo específico, mientras que el SQL almacena telefono. No existe una tabla director equivalente al subtipo del EER. |
| **propuestas_obras** | Se corresponde con PROPUESTA. Regla 1 y regla 4 para la relación con quien registra la propuesta. | **PK:** id, identidad autogenerada. **FK:** poblador_id → pobladores(id). | poblador_id, titulo, region, descripcion_obra, descripcion_beneficiados, pros_comunidad y anio_convocatoria son NOT NULL. anio_convocatoria tiene DEFAULT basado en el año actual; creado_en tiene DEFAULT now(). La FK no es UNIQUE, lo que permite varias propuestas por poblador. |
| **obra** | Se corresponde con OBRA. Regla 1 y regla 4 para sus relaciones con constructora, región y supervisor. | **PK:** id_obra. **FK:** id_constructora → constructora(id_constructora); id_region → region(id_region); codigo_supervisor → supervisor(codigo_personal). | codigo_expediente es NOT NULL y UNIQUE. id_obra, nombre_obra, fecha_inicio, fecha_final, descripcion, beneficiarios, id_constructora, id_region, codigo_supervisor y estado son NOT NULL. estado tiene DEFAULT true; etapa admite nulos. El EER especializa OBRA en VIAL, EDIFICACIÓN e HIDRÁULICA, pero no hay tablas de esos subtipos ni discriminador explícito en el SQL. |
| **votos_propuestas** | Implementa VOTA entre ciudadano y propuesta. Conceptualmente se aproxima a la regla 5 por ser una asociación con atributos propios. | **PK:** id, identidad autogenerada. **FK:** poblador_id → pobladores(id); propuesta_id → propuestas_obras(id). | poblador_id, propuesta_id y periodo_voto son NOT NULL; creado_en tiene DEFAULT now(). No se usa una PK compuesta por las dos FK ni hay UNIQUE sobre poblador_id, propuesta_id y periodo_voto, por lo que la base permite repetición de esa combinación. Una PK propia puede ser apropiada si cada fila es un evento de voto, pero la unicidad del negocio debe definirse. |
| **acta_entrega** | No aparece como entidad independiente en el EER; es una ampliación operacional. La relación con obra se analiza con la regla 6. | **PK:** id_acta. **FK:** id_obra → obra(id_obra). | id_obra es NOT NULL y UNIQUE. acta_entrega y fecha_expedicion son NOT NULL. Cada acta registrada debe corresponder a una obra y una obra puede tener como máximo un acta; la estructura permite que una obra todavía no tenga acta. |
| **financia** | Implementa FINANCIA entre obra y fuente. Regla 5: tabla asociativa muchos a muchos. | **PK compuesta:** id_obra, id_fuente. **FK:** id_obra → obra(id_obra); id_fuente → fuente_presupuestaria(id_fuente). | Ambas FK forman la PK, así que son obligatorias. El EER incluye fecha_oficio y monto_asignado como atributos de FINANCIA, pero la tabla operacional no los declara. Se conserva la asociación, pero no todos los atributos propios de la relación. |
| **informes** | Se corresponde con REPORTE_AVANCE y las relaciones GENERA/participación de supervisor. Regla 1 y regla 4. | **PK:** id_informe. **FK:** id_obra → obra(id_obra); codigo_supervisor → supervisor(codigo_personal). | Los atributos del informe, porcentajes, documentos, descripción y ambas FK son NOT NULL. Dos CHECK exigen que porcentaje_avance_fisico y porcentaje_avance_presupuestario estén entre 0 y 100. No hay DEFAULT en esta tabla. |
| **opcion_seleccion** | Se puede relacionar conceptualmente con ADJUDICA entre obra y contratista, aunque la referencia a la constructora no se implementa como FK. | **PK:** id_participante. **FK:** id_obra → obra(id_obra). | constructora, aprobado, razones_decision e id_obra son NOT NULL. constructora es texto, no FK a constructora(id_constructora), por lo que el gestor no valida que coincida con una constructora registrada. id_participante no tiene FK declarada. |
| **permisos** | Ampliación operacional no identificada como entidad separada en el EER suministrado. Regla 1 y regla 4 respecto de obra. | **PK:** id_oficio. **FK:** id_obra → obra(id_obra). | id_oficio, nombre_instancia, oficio_acreditacion e id_obra son NOT NULL. No declara UNIQUE, CHECK ni DEFAULT. Una obra puede tener varios permisos. |
| **presupuesto_obra** | Extensión del esquema operacional. Representa presupuesto y una relación de uno a uno con obra; también enlaza con proyectista. Reglas 1, 4 y 6 según las cardinalidades asumidas. | **PK:** id_presupuesto. **FK:** id_proyectista → proyectista(codigo_personal); id_obra → obra(id_obra). | presupuesto_total, id_proyectista e id_obra son NOT NULL. id_obra también es UNIQUE: cada presupuesto corresponde a una obra y como máximo puede existir un presupuesto por obra. El esquema no exige que cada obra tenga presupuesto. |
| **costos** | Ampliación operacional que registra gastos asociados con un presupuesto. Regla 1 y regla 4. | **PK:** id_gasto. **FK:** id_presupuesto → presupuesto_obra(id_presupuesto). | id_gasto, categoria, costo, descripcion e id_presupuesto son NOT NULL. No hay CHECK que limite, por ejemplo, costo a valores no negativos. |
| **firmantes** | Ampliación operacional para registrar personas firmantes de un acta. Regla 1 y regla 4. | **PK:** id_firmante. **FK:** id_acta → acta_entrega(id_acta). | id_firmante, nombre, apellido_paterno, cargo e id_acta son NOT NULL; apellido_materno admite nulos. Tiene PK propia, por lo que no es una entidad débil por identificación según la regla 8. |
| **imagenes_informe** | Se corresponde de forma cercana con EVIDENCIA asociada a REPORTE_AVANCE mediante ADJUNTA. Regla 1 para la entidad y regla 4 para la relación con informe. La regla 3 solo sería directa si EVIDENCIA estuviera modelada como atributo multivaluado. | **PK:** id_imagen. **FK:** id_informe → informes(id_informe). | id_imagen es UUID NOT NULL DEFAULT gen_random_uuid(). id_informe, url_publica, ruta_r2 y nombre_original son NOT NULL. fecha_subida tiene DEFAULT now(); tipo_mime y tamaño_bytes admiten nulos. Cada imagen se identifica independientemente. |

### Reglas que se observan en conjunto

**Regla 2: atributos compuestos.** El EER muestra nombre_completo en USUARIO, mientras que el relacional descompone los nombres en varias columnas: pobladores guarda nombre y apellidos; personal guarda nombre, apellido_paterno y apellido_materno. La descomposición se aproxima a la regla 2, pero el SQL no mantiene una tabla común usuario y las columnas no son idénticas entre los dos grupos.

**Regla 3: atributos multivaluados.** En el EER suministrado no se distingue con seguridad un atributo dibujado con doble óvalo. EVIDENCIA aparece como entidad con atributos y una relación ADJUNTA. Por eso, imagenes_informe se explica mejor como una tabla para una entidad relacionada que como la conversión literal de un atributo multivaluado simple.

**Regla 4: relaciones uno a muchos.** Hay ejemplos claros: obra guarda FK a constructora, región y supervisor; informes apunta a obra y supervisor; imagenes_informe apunta a informes; propuestas_obras apunta a pobladores; firmantes apunta a acta_entrega; y costos apunta a presupuesto_obra. Las FK impiden registrar referencias a filas inexistentes.

**Regla 5: relaciones muchos a muchos.** financia aplica directamente la regla mediante una PK compuesta por las dos FK. votos_propuestas representa otra asociación, pero con una PK artificial y sin unicidad sobre la combinación poblador, propuesta y periodo. Además, financia no incluye fecha_oficio y monto_asignado del EER.

**Regla 6: relaciones uno a uno.** acta_entrega y presupuesto_obra declaran id_obra como FK y UNIQUE. Cada registro dependiente pertenece a una obra y una obra puede tener como máximo un registro de cada tipo. Sin embargo, la FK no exige que todas las obras tengan acta o presupuesto, lo cual permite una participación opcional del lado de obra.

**Regla 7: relaciones de orden superior.** En el EER compartido no se distingue con claridad una relación ternaria o de grado superior; las relaciones visibles parecen binarias. Por ello, no se asigna esta regla a una tabla concreta sin evidencia suficiente.

**Regla 8: entidades débiles.** No se reconocen claramente rectángulos dobles ni rombos identificadores dobles en el EER. imagenes_informe, firmantes y costos tienen claves propias y FK a otras tablas. Son dependientes por referencia, pero eso no demuestra que sean débiles por identificación.

**Regla 9: jerarquías.** El EER muestra USUARIO especializado en CIUDADANO y SERVIDOR_PÚBLICO, roles de DIRECTOR y SUPERVISOR, y OBRA especializada en VIAL, EDIFICACIÓN e HIDRÁULICA. Las marcas d muestran disyunción en las especializaciones donde aparecen; la totalidad o parcialidad debe confirmarse con la notación del círculo y sus conexiones. El relacional separa pobladores y personal sin supertipo usuario, implementa supervisor y proyectista con tabla general y tabla de subtipo, no tiene tabla director y no representa los subtipos de obra mediante tablas o discriminador. Por ello, la regla 9 se aplica solo parcialmente.

### Restricciones declaradas e integridad

- **UNIQUE:** constructora.rfc, personal.username, pobladores.username, pobladores.curp, obra.codigo_expediente, acta_entrega.id_obra y presupuesto_obra.id_obra.
- **CHECK:** personal.rol se limita a Supervisor, Director, Secretario o Proyectista; los dos porcentajes de informes están restringidos al intervalo de 0 a 100.
- **NOT NULL y DEFAULT:** se declaran en diferentes atributos; entre los ejemplos están el estado inicial de obra, el año de convocatoria, marcas de creación y el UUID de imagen.
- **Relaciones sin FK:** opcion_seleccion.constructora y pobladores.comunidad son textos, no claves foráneas. El gestor no asegura que esos valores coincidan con una constructora o comunidad registrada.
- **Índices:** mejoran el acceso, pero un índice ordinario no reemplaza una FK ni implica unicidad.

---

## 7.2. Dónde se aparta de las reglas

El Data Warehouse no constituye una traducción estricta del EER. Su propósito es analizar eventos, cambios y resultados históricos, por lo que incorpora desnormalización y estructuras propias del análisis.

### 1. Claves subrogadas y conservación de versiones

Las dimensiones dim_obra, dim_region, dim_constructora, dim_personal y dim_presupuesto utilizan claves como obra_key, region_key y personal_key, junto con fecha_efectiva, fecha_expiracion y es_actual. En dim_obra, obra_key es la PK y obra_id conserva el identificador operacional.

- **Se gana:** diferentes versiones de una misma obra o persona pueden conservarse y asociarse a hechos del periodo correcto.
- **Se pierde o complica:** una entidad de negocio puede ocupar varias filas; las consultas deben escoger la versión correcta y obra_id no es único en dim_obra.
- **Relación con las reglas:** la regla 1 no exige claves subrogadas ni historial; son decisiones adicionales del diseño dimensional.

### 2. Aplanamiento de la jerarquía de personal

El relacional separa personal, supervisor y proyectista. El Data Warehouse concentra la información en dim_personal con rol y banderas es_supervisor, es_proyectista, es_director y es_secretario.

- **Se gana:** se consultan atributos comunes y tipos de personal desde una sola dimensión, reduciendo combinaciones de tablas.
- **Se pierde o complica:** rol y las banderas pueden contradecirse; el DDL no declara un CHECK que garantice su coherencia. También se difuminan las diferencias entre supertipo y subtipos del EER.
- **Relación con las reglas:** se aproxima a la estrategia B de la regla 9, pero no hay un discriminador ni restricciones suficientes para garantizar toda la semántica de la jerarquía.

### 3. Aplanamiento de la ubicación

dim_region combina comunidad, barrio y colonia. Además, dim_propuesta almacena region como texto, sin FK hacia dim_region. El EER modela COMUNIDAD como entidad con clave, nombre, habitantes y coordenadas.

- **Se gana:** se facilita filtrar y agrupar por ubicación con menos combinaciones.
- **Se pierde o complica:** pueden aparecer nombres de ubicación inconsistentes y se pierde parte de la estructura territorial, como coordenadas y número de habitantes.
- **Relación con las reglas:** una transformación estricta preservaría la entidad COMUNIDAD y sus relaciones; el almacén combina niveles de ubicación para simplificar las consultas.

### 4. Atributos derivados y medidas agregadas almacenadas

dim_tiempo almacena año, trimestre, mes, nombres de días, semana, día del año y banderas de calendario, aunque varios atributos se derivan de fecha. fact_obra_mensual almacena saldo_presupuesto, porcentaje_ejercido, costo_acumulado, informes_registrados, imagenes_evidencia y permisos_obtenidos. dim_fuente guarda total_obras_financiadas y monto_total_asignado.

- **Se gana:** las consultas analíticas pueden leer valores precalculados sin volver a calcular o agregar todos los registros operacionales.
- **Se pierde o complica:** si la carga no actualiza los valores de forma coordinada, los totales pueden quedar desfasados y la misma información se conserva más de una vez.
- **Relación con las reglas:** las reglas básicas transforman atributos y relaciones, pero no exigen almacenar medidas derivadas ni agregados.

### 5. Tabla de hechos polivalente

fact_eventos_auditoria relaciona tiempo, tipo de evento y diversas dimensiones de obra, región, personal, constructora, fuente, presupuesto, poblador y propuesta. También contiene medidas, descripciones y datos de auditoría. Su PK es tiempo_key junto con evento_key y está particionada por tiempo_key.

- **Se gana:** distintos sucesos administrativos, financieros, técnicos y ciudadanos se consultan desde una estructura común, y es posible particionar por periodos.
- **Se pierde o complica:** muchas FK admiten nulos porque no todos los eventos usan todas las dimensiones. La interpretación de cada fila depende del tipo de evento y de la correcta carga de los datos.
- **Relación con las reglas:** no es la transformación literal de una sola relación ternaria del EER; concentra distintos contextos de evento en una tabla de hechos general.

### 6. Relaciones lógicas sin FK declarada en dimensiones

dim_obra contiene constructora_key, region_key y supervisor_key sin REFERENCES. También dim_presupuesto.proyectista_key y dim_propuesta.poblador_key carecen de FK declarada. En contraste, las tablas de hechos sí declaran varias FK.

- **Se gana:** los procesos de carga pueden integrar dimensiones por etapas y resolver claves durante la carga ETL.
- **Se pierde:** el gestor no impide referencias a claves inexistentes y la integridad depende de validaciones externas. La ausencia de FK no es por sí misma una ventaja de desnormalización, sino una reducción de garantías.
- **Relación con las reglas:** se aparta de la regla 4, que usa la FK para materializar relaciones uno a muchos.

### Conclusión de 7.2

El almacén dimensional facilita análisis históricos y de resumen mediante claves subrogadas, versiones, atributos aplanados y medidas precalculadas. A cambio, algunas relaciones dejan de conservar la granularidad o las restricciones del esquema operacional. Conviene distinguir las decisiones analíticas deliberadas —como mantener historial— de las omisiones de integridad, como las FK no declaradas.

## Fuentes

- Esquema relacional operacional: [db/DDLBASEObPub.sql](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/DDLBASEObPub.sql).
- Esquema dimensional: [db/arquitectura/ESQUEMA DEL DATA WAREHOUSE.sql](https://github.com/OmarFloresIIA/PublicMunicipalWorks_DWH/blob/TestDefinitivo/db/arquitectura/ESQUEMA%20DEL%20DATA%20WAREHOUSE.sql).
- Modelo EER y esquema relacional: diagramas compartidos por el equipo en la conversación.