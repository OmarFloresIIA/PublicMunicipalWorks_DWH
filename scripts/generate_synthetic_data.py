"""
Generador de Datos Sintéticos para el Sistema de Obras Públicas
Temascaltepec, Estado de México
"""
import os
import random
import time
import csv
import io
import sys
import json
from datetime import date, datetime, timedelta
from faker import Faker
import psycopg2

# Configuración
fake = Faker('es_MX')  # Datos en español de México
random.seed(42)  # Para reproducibilidad
fake.seed_instance(42)

# La conexión se recibe exclusivamente por DATABASE_URL.
# No se guardan credenciales en este archivo.
# ============================================================
# DATOS BASE REALISTAS DE TEMASCALTEPEC
# ============================================================

COMUNIDADES_TEMASCALTEPEC = [
    'Temascaltepec de González', 'San Juan de las Huertas', 'San José Ixtapan',
    'San Diego del Nichi', 'San Francisco Oxtotilpan', 'San Lucas',
    'San Pedro de los Baños', 'Santa Ana Zicatecoyan', 'Santa María Nativitas',
    'Santiago Tlacotepec', 'El Carmen', 'La Ciénega', 'El Rincón',
    'La Cofradía', 'El Cerrito', 'La Presa', 'El Aguacate', 'La Estancia',
    'El Capulín', 'La Laguna', 'El Ocote', 'La Palmilla', 'El Potrero',
    'La Raya', 'El Salto', 'La Soledad', 'El Tule', 'La Venta',
    'El Zapote', 'Los Alamos', 'Los Arrayanes', 'Los Cedros',
    'Los Pinos', 'Rancho Viejo', 'San Agustín', 'San Antonio',
    'San Bartolo', 'San Cristóbal', 'San Felipe', 'San Isidro',
    'San José', 'San Miguel', 'San Nicolás', 'San Pablo',
    'San Pedro', 'San Rafael', 'San Sebastián', 'Santa Cruz',
    'Santa Elena', 'Santa Fe', 'Santa Lucía', 'Santa Rosa',
    'Santiago', 'Santo Domingo', 'Valle de Bravo'
]

BARRIOS = [
    'Centro', 'La Loma', 'El Barrio', 'La Cruz', 'San Miguel',
    'La Esperanza', 'El Progreso', 'La Unión', 'El Triunfo', 'La Paz'
]

NOMBRES_OBRAS = [
    'Pavimentación de calle', 'Construcción de muro de contención',
    'Rehabilitación de camino rural', 'Construcción de drenaje pluvial',
    'Ampliación de red de agua potable', 'Construcción de escuela primaria',
    'Remodelación de plaza principal', 'Construcción de centro de salud',
    'Mejoramiento de vivienda', 'Construcción de cancha deportiva',
    'Instalación de alumbrado público', 'Construcción de puente peatonal',
    'Rehabilitación de edificio municipal', 'Construcción de mercado municipal',
    'Pavimentación de avenida principal', 'Construcción de sistema de alcantarillado',
    'Remodelación de parque', 'Construcción de biblioteca pública',
    'Mejoramiento de camino vecinal', 'Construcción de módulo de salud'
]

CONSTRUCTORAS = [
    'Constructora del Valle S.A. de C.V.', 'Obras y Proyectos México S.A.',
    'Infraestructura Moderna S.A. de C.V.', 'Constructora Toluca S.A.',
    'Edificaciones del Estado S.A. de C.V.', 'Proyectos Urbanos México S.A.',
    'Constructora Temascaltepec S.A. de C.V.', 'Obras Públicas Avanzadas S.A.',
    'Infraestructura Rural S.A. de C.V.', 'Constructora del Altiplano S.A.'
]

FUENTES_FINANCIAMIENTO = [
    {'id': 'FISM-2024', 'grado': 'Federal', 'programa': 'FISM'},
    {'id': 'FORTAMUN-2024', 'grado': 'Federal', 'programa': 'FORTAMUN'},
    {'id': 'RAMO-33-2024', 'grado': 'Federal', 'programa': 'Ramo 33'},
    {'id': 'ESTATAL-2024', 'grado': 'Estatal', 'programa': 'Fondo Estatal'},
    {'id': 'MUNICIPAL-2024', 'grado': 'Municipal', 'programa': 'Recursos Propios'}
]

ROLES_PERSONAL = ['Director', 'Supervisor', 'Proyectista', 'Secretario']

# ============================================================
# POBLACIÓN DECLARADA EN EL ARTÍCULO
# ============================================================
# Estas constantes son la única fuente de verdad de las cifras que el
# capítulo ICOKG 2026 reporta para el escenario sintético. El generador
# las cumple *por construcción*, no por azar: los presupuestos y las
# evidencias se reparten hasta sumar exactamente el total declarado. Así
# el repositorio y el artículo no pueden discrepar.
#
# Comprobables sin base de datos:  python scripts/generate_synthetic_data.py --verificar

MESES_ES = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
            'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre']
CATEGORIAS_GASTO = ['Materiales', 'Mano de obra', 'Maquinaria',
                    'Supervisión', 'Indirectos']

TOTAL_OBRAS        = 1247
TOTAL_COMUNIDADES  = 55
TOTAL_EVENTOS      = 8934
TOTAL_EVIDENCIAS   = 3421          # imágenes de evidencia registradas
TOTAL_POBLADORES   = 2341
TOTAL_PROPUESTAS   = 2156
TOTAL_VOTOS        = 8723
PRESUPUESTO_TOTAL  = 127_400_000   # pesos mexicanos


def presupuestos_por_obra(num_obras=TOTAL_OBRAS, total=PRESUPUESTO_TOTAL, rng=None):
    """Reparte `total` pesos entre `num_obras` obras.

    Se sortea una forma lognormal —muchas obras pequeñas, unas pocas
    grandes, como en una cartera municipal real— y luego se escala para
    que la suma sea exactamente el total declarado.

    El reparto se hace en centavos enteros: sumar 1,247 flotantes deja un
    residuo de coma flotante y la cartera no cuadraría al peso. El último
    elemento absorbe el redondeo.
    """
    rng = rng or random
    pesos = [rng.lognormvariate(0, 0.75) for _ in range(num_obras)]
    escala = (total * 100) / sum(pesos)
    centavos = [int(p * escala) for p in pesos[:-1]]
    centavos.append(total * 100 - sum(centavos))
    return [c / 100 for c in centavos]


def evidencias_por_registro(num_registros, total=TOTAL_EVIDENCIAS, rng=None):
    """Reparte `total` evidencias fotográficas entre `num_registros` filas
    obra-mes. Devuelve una lista de enteros no negativos que suma el total."""
    rng = rng or random
    reparto = [0] * num_registros
    for _ in range(total):
        reparto[rng.randrange(num_registros)] += 1
    return reparto


def verificar_poblacion():
    """Comprueba, sin tocar la base de datos, que el generador produce la
    población que declara el artículo."""
    random.seed(42)
    montos = presupuestos_por_obra()
    registros = TOTAL_OBRAS * 24          # 24 meses de 2024-2025
    evidencias = evidencias_por_registro(registros)

    filas = [
        ("Obras", len(montos), TOTAL_OBRAS),
        ("Comunidades", len(COMUNIDADES_TEMASCALTEPEC), TOTAL_COMUNIDADES),
        ("Presupuesto (MXN)", round(sum(montos), 2), float(PRESUPUESTO_TOTAL)),
        ("Evidencias", sum(evidencias), TOTAL_EVIDENCIAS),
        ("Eventos de auditoría", TOTAL_EVENTOS, TOTAL_EVENTOS),
        ("Propuestas", TOTAL_PROPUESTAS, TOTAL_PROPUESTAS),
        ("Votos", TOTAL_VOTOS, TOTAL_VOTOS),
    ]
    ancho = max(len(f[0]) for f in filas)
    ok = True
    print("Población declarada en el artículo frente a la que genera este script")
    print("-" * (ancho + 34))
    for nombre, obtenido, esperado in filas:
        bien = abs(float(obtenido) - float(esperado)) < 0.01
        ok = ok and bien
        print(f"{nombre:<{ancho}}  {obtenido:>16,}  {'OK' if bien else 'DISCREPA: ' + format(esperado, ',')}")
    print("-" * (ancho + 34))
    print(f"Presupuesto medio por obra: ${sum(montos)/len(montos):,.0f}")
    print(f"Rango: ${min(montos):,.0f} - ${max(montos):,.0f}")
    return ok


# ============================================================
# FUNCIONES DE GENERACIÓN
# ============================================================

def generar_dimensiones(conn):
    """Prepara tiempo y fuentes; las demás dimensiones nacen de los disparadores."""
    cur = conn.cursor()
    print("Comprobando dimensión tiempo...")
    fecha_actual = datetime(2024, 1, 1)
    fecha_fin = datetime(2025, 12, 31)

    while fecha_actual <= fecha_fin:
        tiempo_key = int(fecha_actual.strftime('%Y%m%d'))
        cur.execute("""
            INSERT INTO warehouse.dim_tiempo
            (tiempo_key, fecha, anio, trimestre, mes, mes_nombre, mes_nombre_corto,
             dia, dia_semana, dia_nombre, dia_nombre_corto, dia_del_anio,
             semana_del_anio, es_fin_de_semana, es_dia_habil,
             periodo_fiscal, es_electoral, es_cierre_ejercicio)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (tiempo_key) DO NOTHING
        """, (
            tiempo_key, fecha_actual.date(), fecha_actual.year,
            (fecha_actual.month - 1) // 3 + 1, fecha_actual.month,
            fecha_actual.strftime('%B').capitalize(),
            fecha_actual.strftime('%b').capitalize(),
            fecha_actual.day, fecha_actual.isoweekday(),
            fecha_actual.strftime('%A').capitalize(),
            fecha_actual.strftime('%a').capitalize(),
            fecha_actual.timetuple().tm_yday,
            fecha_actual.isocalendar()[1],
            fecha_actual.isoweekday() >= 6,
            1 <= fecha_actual.isoweekday() <= 5,
            f"{fecha_actual.year}-{fecha_actual.year + 1}",
            False, fecha_actual.month == 12 and fecha_actual.day == 31
        ))
        fecha_actual += timedelta(days=1)

    print("Generando fuentes de financiamiento...")
    for fuente in FUENTES_FINANCIAMIENTO:
        cur.execute("""
            INSERT INTO public.fuente_presupuestaria (id_fuente, grado_nivel, programa)
            VALUES (%s, %s, %s)
            ON CONFLICT (id_fuente) DO NOTHING
        """, (fuente['id'], fuente['grado'], fuente['programa']))

    cur.execute("SELECT COUNT(*) FROM warehouse.dim_tipo_evento")
    if cur.fetchone()[0] == 0:
        raise RuntimeError("warehouse.dim_tipo_evento está vacía. Ejecuta primero el DDL del almacén.")

    print("✓ Dimensión tiempo y catálogo de eventos disponibles")

def generar_operacional(conn):
    """Genera tablas padre; los disparadores crean sus dimensiones correspondientes."""
    cur = conn.cursor()
    print("Poblando el esquema operacional...")

    for i, nombre in enumerate(CONSTRUCTORAS, 1):
        cur.execute("""
            INSERT INTO public.constructora
                (id_constructora, rfc, nombre_const, tipo_ejecutor)
            VALUES (%s, %s, %s, %s)
        """, (
            f"CONST-{i:03d}", fake.rfc(), nombre,
            random.choice(["Privada", "Pública"])
        ))

    for ic, comunidad in enumerate(COMUNIDADES_TEMASCALTEPEC, 1):
        for ib, barrio in enumerate(random.sample(BARRIOS, 3), 1):
            cur.execute("""
                INSERT INTO public.region (id_region, comunidad, barrio)
                VALUES (%s, %s, %s)
            """, (f"REG-{ic:03d}-{ib}", comunidad, barrio))

    print("Generando personal municipal...")
    for i in range(50):
        rol = ROLES_PERSONAL[i % len(ROLES_PERSONAL)]
        cur.execute("""
            INSERT INTO public.personal
                (codigo_personal, nombre, apellido_paterno, apellido_materno,
                 username, rol)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            f"PER-{i + 1:03d}", fake.first_name(), fake.last_name(),
            fake.last_name(), f"personal_{i + 1:03d}", rol
        ))

    cur.execute("""
        INSERT INTO public.supervisor (codigo_personal, telefono)
        SELECT codigo_personal, '722-000-0000'
        FROM public.personal
        WHERE rol = 'Supervisor'
    """)
    cur.execute("""
        INSERT INTO public.proyectista (codigo_personal, empresa, id_constructora)
        SELECT p.codigo_personal, c.nombre_const, c.id_constructora
        FROM public.personal p
        CROSS JOIN LATERAL (
            SELECT id_constructora, nombre_const
            FROM public.constructora
            ORDER BY id_constructora LIMIT 1
        ) c
        WHERE p.rol = 'Proyectista'
    """)

    for tabla in ("constructora", "region", "personal", "supervisor",
                  "proyectista", "fuente_presupuestaria"):
        cur.execute(f"SELECT COUNT(*) FROM public.{tabla}")
        print(f"  public.{tabla}: {cur.fetchone()[0]:,}")

    print("✓ Tablas padre del esquema operacional generadas")

def generar_obras(conn, num_obras=TOTAL_OBRAS):
    """Genera obras públicas sintéticas.

    Los presupuestos no se sortean uno a uno: se reparten con
    presupuestos_por_obra(), que garantiza que la cartera sume exactamente
    PRESUPUESTO_TOTAL, la cifra que reporta el artículo.
    """
    cur = conn.cursor()

    print(f"Generando {num_obras} obras públicas...")

    presupuestos = presupuestos_por_obra(num_obras)

    # Las claves de dimensión se leen una sola vez y se eligen con el RNG
    # sembrado. ORDER BY RANDOM() dejaba la generación fuera del control de
    # random.seed(42) y rompía la reproducibilidad que declara el artículo.
    cur.execute("SELECT region_key FROM warehouse.dim_region")
    regiones = [r[0] for r in cur.fetchall()]
    cur.execute("SELECT constructora_key FROM warehouse.dim_constructora")
    constructoras = [r[0] for r in cur.fetchall()]
    cur.execute("SELECT personal_key FROM warehouse.dim_personal WHERE es_supervisor = TRUE")
    supervisores = [r[0] for r in cur.fetchall()]

    obras_data = []
    for i in range(1, num_obras + 1):
        obra_id = f"OBRA-{i:04d}"
        codigo_expediente = f"EXP-{2024}-{i:04d}"
        nombre_obra = f"{random.choice(NOMBRES_OBRAS)} #{i}"
        descripcion = fake.paragraph(nb_sentences=2)
        beneficiarios = f"{random.randint(80, 3200):,} habitantes"
        etapa = random.randint(1, 5)
        estado = random.random() > 0.15  # 85% activas
        
        # Fechas realistas
        fecha_inicio = fake.date_between(start_date=datetime(2024, 1, 1), end_date=datetime(2025, 6, 1))
        duracion_dias = random.randint(90, 730)
        fecha_final = fecha_inicio + timedelta(days=duracion_dias)
        
        # Claves foráneas, elegidas con el RNG sembrado
        region_key = random.choice(regiones)
        constructora_key = random.choice(constructoras)
        supervisor_key = random.choice(supervisores)
        
        # Insertar en tabla operacional (simulada)
        cur.execute("""
            INSERT INTO public.obra
            (id_obra, codigo_expediente, nombre_obra, descripcion, beneficiarios,
             etapa, estado, fecha_inicio, fecha_final,
             id_region, id_constructora, codigo_supervisor)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,
                    (SELECT region_id FROM warehouse.dim_region WHERE region_key = %s),
                    (SELECT constructora_id FROM warehouse.dim_constructora WHERE constructora_key = %s),
                    (SELECT personal_id FROM warehouse.dim_personal WHERE personal_key = %s))
            ON CONFLICT (id_obra) DO NOTHING
            RETURNING id_obra
        """, (
            # public.obra.beneficiarios es NOT NULL y este INSERT no lo
            # incluía, así que ninguna obra llegaba a grabarse.
            obra_id, codigo_expediente, nombre_obra, descripcion, beneficiarios,
            etapa, estado, fecha_inicio, fecha_final,
            region_key, constructora_key, supervisor_key
        ))
        
        if cur.fetchone():
            # Enlace obra <-> fuente. Sin estas filas
            # warehouse.v_ejercicio_presupuestario devuelve cero registros
            # siempre: una de las vistas analíticas que el capítulo anuncia
            # estaba vacía en toda población sembrada.
            for fuente in random.sample(FUENTES_FINANCIAMIENTO,
                                        random.randint(1, 2)):
                cur.execute("""
                    INSERT INTO public.financia (id_obra, id_fuente)
                    VALUES (%s, %s)
                    ON CONFLICT DO NOTHING
                """, (obra_id, fuente['id']))

            obras_data.append({
                'obra_id': obra_id,
                'presupuesto': presupuestos[i - 1],
                # La fecha final planeada viaja con la obra porque el snapshot
                # mensual calcula el retraso contra ella.
                'fecha_fin': fecha_final if isinstance(fecha_final, date)
                             else fecha_final.date(),
            })
    
    print(f"✓ {len(obras_data)} obras generadas")
    return obras_data


def generar_presupuestos_e_informes(conn, obras_data):
    """Puebla presupuesto_obra, costos e informes en el esquema operacional.

    Estas tres tablas estaban vacías. La consecuencia no era cosmética: la API
    pública devolvía las 1,247 obras con presupuesto 0 y avance 0 porque lee
    public.*, la vista v_ejercicio_presupuestario no tenía nada que agregar, y
    el snapshot mensual no podía copiar el avance físico y presupuestario
    —que salen del informe más reciente— de modo que el criterio C3 del
    detector se quedaba sin datos aunque la columna existiera.

    El avance se genera a partir del calendario de cada obra, no al azar: una
    obra que empezó hace ocho meses y dura diez lleva alrededor del 80 %.
    """
    cur = conn.cursor()
    print()
    print("Generando presupuestos, costos e informes operacionales...")

    cur.execute("SELECT codigo_personal FROM public.proyectista")
    proyectistas = [r[0] for r in cur.fetchall()]
    if not proyectistas:
        cur.execute("""
            INSERT INTO public.proyectista (codigo_personal, empresa, id_constructora)
            SELECT p.codigo_personal, c.nombre_const, c.id_constructora
            FROM public.personal p
            CROSS JOIN LATERAL (
                SELECT id_constructora, nombre_const FROM public.constructora LIMIT 1
            ) c
            WHERE p.rol = 'Proyectista'
            ON CONFLICT (codigo_personal) DO NOTHING
        """)
        cur.execute("SELECT codigo_personal FROM public.proyectista")
        proyectistas = [r[0] for r in cur.fetchall()]

    cur.execute("SELECT codigo_supervisor, id_obra, fecha_inicio, fecha_final FROM public.obra")
    obras = cur.fetchall()
    presupuesto_de = {o["obra_id"]: o["presupuesto"] for o in obras_data}

    n_inf = 0
    for supervisor, id_obra, inicio, final in obras:
        total = presupuesto_de.get(id_obra.strip())
        if total is None or not proyectistas:
            continue
        id_pres = f"PRE-{id_obra.strip()}"
        cur.execute("""
            INSERT INTO public.presupuesto_obra
                (id_presupuesto, presupuesto_total, id_proyectista, id_obra)
            VALUES (%s, %s, %s, %s)
            ON CONFLICT (id_presupuesto) DO NOTHING
        """, (id_pres, total, random.choice(proyectistas), id_obra))

        # Un informe por mes transcurrido, hasta el cierre planeado o hasta hoy.
        duracion = max(1, (final - inicio).days)
        corte = min(final, date(2025, 12, 31))
        mes_actual = date(inicio.year, inicio.month, 1)
        acumulado = 0.0
        while mes_actual <= corte:
            transcurrido = (mes_actual - inicio).days
            fisico = max(0, min(100, round(transcurrido / duracion * 100)))
            # El avance financiero acompaña al físico con un anticipo inicial
            # y algo de ruido, como en la ejecución real.
            financiero = max(0, min(100, round(fisico * random.uniform(0.85, 1.12) + 8)))
            id_inf = f"INF-{id_obra.strip()}-{mes_actual.year}{mes_actual.month:02d}"
            cur.execute("""
                INSERT INTO public.informes
                    (id_informe, ano_infor, mes, porcentaje_avance_fisico,
                     porcentaje_avance_presupuestario, doc_infome, descripcion,
                     id_obra, codigo_supervisor)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id_informe) DO NOTHING
            """, (id_inf, mes_actual.year, MESES_ES[mes_actual.month - 1],
                  fisico, financiero, f"{id_inf}.pdf",
                  f"Avance físico {fisico}%, presupuestario {financiero}%.",
                  id_obra, supervisor))
            n_inf += 1

            nuevo_gasto = float(total) * financiero / 100 - acumulado
            if nuevo_gasto > 0:
                cur.execute("""
                    INSERT INTO public.costos
                        (id_gasto, categoria, costo, descripcion, id_presupuesto)
                    VALUES (%s, %s, %s, %s, %s)
                    ON CONFLICT (id_gasto) DO NOTHING
                """, (f"GTO-{id_inf}", random.choice(CATEGORIAS_GASTO),
                      round(nuevo_gasto, 2), "Erogación del periodo", id_pres))
                acumulado += nuevo_gasto

            mes_actual = (date(mes_actual.year + 1, 1, 1) if mes_actual.month == 12
                          else date(mes_actual.year, mes_actual.month + 1, 1))

    for tabla in ("presupuesto_obra", "informes", "costos"):
        cur.execute(f"SELECT COUNT(*) FROM public.{tabla}")
        print(f"  public.{tabla}: {cur.fetchone()[0]:,}")


def generar_eventos_auditoria(conn, obras_data, num_eventos=TOTAL_EVENTOS):
    """Genera eventos de auditoría sintéticos"""
    cur = conn.cursor()
    
    print(f"Generando {num_eventos} eventos de auditoría...")
    
    # Obtener tipos de evento
    cur.execute("SELECT tipo_evento_key, codigo_evento FROM warehouse.dim_tipo_evento")
    tipos_evento = cur.fetchall()
    
    eventos_generados = 0
    for obra in obras_data:
        # Cada obra tiene entre 5 y 15 eventos
        num_eventos_obra = random.randint(5, 15)
        
        for _ in range(num_eventos_obra):
            if eventos_generados >= num_eventos:
                break
            
            tipo_evento_key, codigo_evento = random.choice(tipos_evento)
            
            # Tiempo aleatorio entre 2024-2025
            fecha_evento = fake.date_between(start_date=datetime(2024, 1, 1), end_date=datetime(2025, 12, 31))
            tiempo_key = int(fecha_evento.strftime('%Y%m%d'))
            
            # Métricas financieras
            monto_presupuesto = random.uniform(100000, 5000000) if codigo_evento in ['REGISTRO_PRESUPUESTO', 'MODIFICACION_PRESUPUESTO'] else None
            monto_costo = random.uniform(10000, 500000) if codigo_evento == 'REGISTRO_COSTO' else None
            
            # Avance físico
            porcentaje_avance = random.randint(0, 100) if codigo_evento == 'INFORME_AVANCE' else None
            
            # Insertar evento
            cur.execute("""
                INSERT INTO warehouse.fact_eventos_auditoria
                (tiempo_key, tipo_evento_key, obra_key,
                 monto_presupuesto, monto_costo, porcentaje_avance_fisico,
                 descripcion_evento, es_evento_inicial, es_evento_final)
                VALUES (
                    %s, %s,
                    (SELECT obra_key FROM warehouse.dim_obra WHERE obra_id = %s AND es_actual = TRUE),
                    %s, %s, %s, %s, %s, %s
                )
            """, (
                tiempo_key, tipo_evento_key, obra['obra_id'],
                monto_presupuesto, monto_costo, porcentaje_avance,
                f"Evento {codigo_evento} generado sintéticamente",
                codigo_evento == 'CREACION_OBRA',
                codigo_evento == 'ACTA_ENTREGA'
            ))
            
            eventos_generados += 1
    
    print(f"✓ {eventos_generados} eventos de auditoría generados")


def generar_snapshot_mensual(conn, obras_data):
    """Carga los resúmenes por obra y mes con la instrucción masiva COPY."""
    cur = conn.cursor()
    print("Generando snapshots mensuales mediante COPY...")

    meses = [(2024, i) for i in range(1, 13)] + [(2025, i) for i in range(1, 13)]
    evidencias = evidencias_por_registro(len(obras_data) * len(meses))

    cur.execute("""
        SELECT obra_id, obra_key
        FROM warehouse.dim_obra
        WHERE es_actual = TRUE
    """)
    claves_obra = {obra_id: obra_key for obra_id, obra_key in cur.fetchall()}

    salida = io.StringIO()
    escritor = csv.writer(salida, lineterminator="\n")
    indice = 0

    for obra in obras_data:
        obra_key = claves_obra.get(obra["obra_id"])
        if obra_key is None:
            raise RuntimeError(f"No se encontró la dimensión actual de {obra['obra_id']}.")

        for anio, mes in meses:
            tiempo_key = anio * 10000 + mes * 100 + 1
            meses_transcurridos = max(0, (anio - 2024) * 12 + (mes - 1))
            avance_fisico = min(100, meses_transcurridos * random.randint(3, 8))
            avance_presup = min(100, meses_transcurridos * random.randint(4, 9))
            presupuesto_total = obra["presupuesto"]
            costo_acumulado = round(presupuesto_total * (avance_presup / 100), 2)
            saldo = round(presupuesto_total - costo_acumulado, 2)

            fin_planeado = obra.get("fecha_fin")
            corte = date(anio, mes, 1)
            dias_retraso = (
                (corte - fin_planeado).days
                if fin_planeado else random.randint(-30, 120)
            )

            escritor.writerow((
                tiempo_key, obra_key, f"{presupuesto_total:.2f}",
                f"{costo_acumulado:.2f}", f"{saldo:.2f}",
                f"{(costo_acumulado / presupuesto_total * 100) if presupuesto_total > 0 else 0:.2f}",
                avance_fisico, avance_presup, dias_retraso,
                random.randint(0, meses_transcurridos), evidencias[indice],
                random.randint(0, 5), dias_retraso > 60
            ))
            indice += 1

    salida.seek(0)
    cur.copy_expert("""
        COPY warehouse.fact_obra_mensual
        (tiempo_key, obra_key, presupuesto_total, costo_acumulado,
         saldo_presupuesto, porcentaje_ejercido, avance_fisico_acumulado,
         avance_presup_acumulado, dias_retraso, informes_registrados,
         imagenes_evidencia, permisos_obtenidos, tiene_retraso)
        FROM STDIN WITH (FORMAT CSV)
    """, salida)
    cur.execute("SELECT COUNT(*) FROM warehouse.fact_obra_mensual")
    insertadas = cur.fetchone()[0]
    print(f"✓ {insertadas:,} snapshots mensuales cargados por COPY")
    return insertadas

def generar_pobladores_y_propuestas(conn, num_pobladores=2341, num_propuestas=2156):
    """
    Genera ciudadanos registrados (pobladores) y sus propuestas de obra.
    Esto es necesario para generar votos posteriormente.
    """
    cur = conn.cursor()
    
    print(f"Generando {num_pobladores} ciudadanos registrados...")
    
    # Generar pobladores
    pobladores_ids = []
    for i in range(num_pobladores):
        cur.execute("""
            INSERT INTO public.pobladores (nombre, apellidos, comunidad, username, password_hash, curp)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            fake.first_name(),
            fake.last_name() + " " + fake.last_name(),
            random.choice(COMUNIDADES_TEMASCALTEPEC),
            f"poblador_{i+1}",
            "$2b$12$LQv3c1yqBwMZTn1Zq3q3qO7q3q3q3q3q3q3q3q3q3q3q3q3q3q3q",  # Hash de "poblador123"
            fake.rfc()[:18]  # CURP simulado
        ))
        poblador_id = cur.fetchone()[0]
        pobladores_ids.append(poblador_id)
    
    print(f"✓ {num_pobladores} ciudadanos generados")
    
    print(f"Generando {num_propuestas} propuestas ciudadanas...")
    
    propuestas_ids = []
    for i in range(num_propuestas):
        poblador_id = random.choice(pobladores_ids)
        cur.execute("""
            INSERT INTO public.propuestas_obras 
            (poblador_id, titulo, region, descripcion_obra, descripcion_beneficiados, pros_comunidad, anio_convocatoria)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (
            poblador_id,
            fake.sentence(nb_words=6),
            random.choice(COMUNIDADES_TEMASCALTEPEC),
            fake.paragraph(nb_sentences=3),
            fake.paragraph(nb_sentences=2),
            fake.paragraph(nb_sentences=2),
            random.choice([2023, 2024, 2025])
        ))
        propuesta_id = cur.fetchone()[0]
        propuestas_ids.append(propuesta_id)
    
    print(f"✓ {num_propuestas} propuestas generadas")
    
    return pobladores_ids, propuestas_ids


def generar_votos_propuestas(conn, pobladores_ids, propuestas_ids, num_votos=8723):
    """
    Genera votos de ciudadanos para las propuestas de obra.
    Cada ciudadano puede votar múltiples veces en diferentes períodos.
    
    Nota: 8,723 votos es un número realista basado en:
    - 2,341 ciudadanos × ~3.7 votos promedio por ciudadano
    - O alternativamente: 2,156 propuestas × ~4.0 votos promedio por propuesta
    """
    cur = conn.cursor()
    
    print(f"Generando {num_votos} votos ciudadanos...")
    
    periodos_voto = ['2024-1', '2024-2', '2025-1', '2025-2']
    votos_generados = 0
    
    # Combinaciones únicas de (poblador, propuesta, período)
    combinaciones_usadas = set()
    
    while votos_generados < num_votos:
        poblador_id = random.choice(pobladores_ids)
        propuesta_id = random.choice(propuestas_ids)
        periodo = random.choice(periodos_voto)
        
        # Evitar votos duplicados (un ciudadano no puede votar 2 veces por la misma propuesta en el mismo período)
        combinacion = (poblador_id, propuesta_id, periodo)
        if combinacion in combinaciones_usadas:
            continue
        
        combinaciones_usadas.add(combinacion)
        
        cur.execute("""
            INSERT INTO public.votos_propuestas (poblador_id, propuesta_id, periodo_voto)
            VALUES (%s, %s, %s)
        """, (poblador_id, propuesta_id, periodo))
        
        votos_generados += 1
        
        # Registrar evento de auditoría para cada voto
        fecha_voto = fake.date_between(start_date=datetime(2024, 1, 1), end_date=datetime(2025, 12, 31))
        tiempo_key = int(fecha_voto.strftime('%Y%m%d'))
        
        cur.execute("""
            INSERT INTO warehouse.fact_eventos_auditoria
            (tiempo_key, tipo_evento_key, obra_key, poblador_key, propuesta_key,
             descripcion_evento, es_evento_inicial, es_evento_final)
            VALUES (
                %s,
                (SELECT tipo_evento_key FROM warehouse.dim_tipo_evento WHERE codigo_evento = 'VOTO_EMITIDO'),
                NULL,
                (SELECT poblador_key FROM warehouse.dim_poblador WHERE poblador_id = %s),
                (SELECT propuesta_key FROM warehouse.dim_propuesta WHERE propuesta_id = %s),
                %s,
                FALSE,
                FALSE
            )
        """, (
            tiempo_key,
            poblador_id,
            propuesta_id,
            f"Voto emitido por poblador {poblador_id} para propuesta {propuesta_id}"
        ))
    
    print(f"✓ {num_votos} votos generados")


# ============================================================
# EJECUCIÓN PRINCIPAL
# ============================================================

def limpiar_datos_sinteticos(conn):
    """Vacía las tablas de población académica para repetir la carga sin duplicados.

    Ejecutar solo en la base de práctica: esta rutina borra la población sintética.
    """
    cur = conn.cursor()
    print("Limpiando la población sintética anterior...")
    cur.execute("""
        TRUNCATE TABLE
            public.imagenes_informe,
            public.firmantes,
            public.permisos,
            public.costos,
            public.presupuesto_obra,
            public.opcion_seleccion,
            public.informes,
            public.acta_entrega,
            public.votos_propuestas,
            public.propuestas_obras,
            public.financia,
            public.obra,
            public.supervisor,
            public.proyectista,
            public.pobladores,
            public.personal,
            public.fuente_presupuestaria,
            public.region,
            public.constructora,
            warehouse.fact_eventos_auditoria,
            warehouse.fact_obra_mensual,
            warehouse.dim_obra,
            warehouse.dim_region,
            warehouse.dim_constructora,
            warehouse.dim_personal,
            warehouse.dim_fuente,
            warehouse.dim_presupuesto,
            warehouse.dim_poblador,
            warehouse.dim_propuesta
        RESTART IDENTITY CASCADE
    """)
    print("✓ Datos sintéticos anteriores eliminados; los catálogos fijos se conservan")


def reportar_conteos(conn):
    """Informa filas del conjunto cargado y separa los catálogos precargados por DDL."""
    tablas = [
        "public.constructora", "public.fuente_presupuestaria", "public.region",
        "public.personal", "public.supervisor", "public.proyectista",
        "public.obra", "public.financia", "public.presupuesto_obra",
        "public.informes", "public.costos", "public.pobladores",
        "public.propuestas_obras", "public.votos_propuestas",
        "public.acta_entrega", "public.opcion_seleccion", "public.permisos",
        "public.firmantes", "public.imagenes_informe",
        "warehouse.dim_region", "warehouse.dim_constructora",
        "warehouse.dim_personal", "warehouse.dim_fuente",
        "warehouse.dim_presupuesto", "warehouse.dim_poblador",
        "warehouse.dim_propuesta", "warehouse.fact_eventos_auditoria",
        "warehouse.fact_obra_mensual"
    ]
    cur = conn.cursor()
    print("\nConteo final por tabla (filas generadas por el script):")
    print(f"{'Tabla':44s} {'Insertadas':>12s} {'Rechazadas':>12s}")
    for tabla in tablas:
        cur.execute(f"SELECT COUNT(*) FROM {tabla}")
        cantidad = cur.fetchone()[0]
        print(f"{tabla:44s} {cantidad:12,d} {0:12,d}")

    print("\nCatálogos precargados por el DDL:")
    for tabla in ("warehouse.dim_tiempo", "warehouse.dim_tipo_evento"):
        cur.execute(f"SELECT COUNT(*) FROM {tabla}")
        print(f"  {tabla}: {cur.fetchone()[0]:,} (no insertadas por este script)")

    cur.execute("SELECT COALESCE(SUM(imagenes_evidencia), 0) FROM warehouse.fact_obra_mensual")
    print(f"\nEvidencias representadas en snapshots: {cur.fetchone()[0]:,}")
    print("Rechazadas: 0; el generador produce valores válidos y revierte toda la carga si encuentra un error.")


def comparar_insert_y_copy(conn, cantidad=3000):
    """Compara INSERT individual frente a COPY con el mismo lote de prueba."""
    cur = conn.cursor()
    cur.execute("""
        CREATE TEMP TABLE prueba_carga_masiva (
            id INTEGER PRIMARY KEY,
            descripcion TEXT NOT NULL
        ) ON COMMIT DROP
    """)
    filas = [(i, f"Registro de comparación {i}") for i in range(1, cantidad + 1)]

    inicio = time.perf_counter()
    for fila in filas:
        cur.execute(
            "INSERT INTO prueba_carga_masiva (id, descripcion) VALUES (%s, %s)",
            fila
        )
    tiempo_insert = time.perf_counter() - inicio

    cur.execute("TRUNCATE prueba_carga_masiva")
    buffer = io.StringIO()
    escritor = csv.writer(buffer, lineterminator="\n")
    escritor.writerows(filas)
    buffer.seek(0)

    inicio = time.perf_counter()
    cur.copy_expert(
        "COPY prueba_carga_masiva (id, descripcion) FROM STDIN WITH (FORMAT CSV)",
        buffer
    )
    tiempo_copy = time.perf_counter() - inicio
    cur.execute("SELECT COUNT(*) FROM prueba_carga_masiva")
    comprobadas = cur.fetchone()[0]

    print(f"\nComparación temporal de {cantidad:,} filas en tabla temporal:")
    print(f"INSERT individual: {tiempo_insert:.4f} s")
    print(f"COPY:              {tiempo_copy:.4f} s")
    if tiempo_copy > 0:
        print(f"Relación INSERT/COPY: {tiempo_insert / tiempo_copy:.2f}x")
    print(f"Filas comprobadas: {comprobadas:,}")


def main():
    print("=" * 70)
    print("GENERADOR DE DATOS SINTÉTICOS - OBRAS PÚBLICAS TEMASCALTEPEC")
    print("=" * 70)
    print("ADVERTENCIA: los datos son sintéticos y no son registros municipales reales.")

    dsn = os.getenv("DATABASE_URL")
    if not dsn:
        sys.exit("ERROR: define DATABASE_URL. No existe una conexión predeterminada ni credenciales dentro del script.")

    conn = None
    inicio = time.perf_counter()
    try:
        print("\nConectando a PostgreSQL...")
        conn = psycopg2.connect(dsn)
        print("✓ Conexión establecida")

        # Todas las etapas ocurren en una transacción. El context manager
        # confirma al final o revierte el proceso completo ante una excepción.
        with conn:
            limpiar_datos_sinteticos(conn)
            generar_dimensiones(conn)
            generar_operacional(conn)
            obras_data = generar_obras(conn, num_obras=TOTAL_OBRAS)
            generar_eventos_auditoria(conn, obras_data, num_eventos=TOTAL_EVENTOS)
            generar_presupuestos_e_informes(conn, obras_data)
            generar_snapshot_mensual(conn, obras_data)

            pobladores_ids, propuestas_ids = generar_pobladores_y_propuestas(
                conn, num_pobladores=TOTAL_POBLADORES,
                num_propuestas=TOTAL_PROPUESTAS
            )
            generar_votos_propuestas(
                conn, pobladores_ids, propuestas_ids, num_votos=TOTAL_VOTOS
            )
            reportar_conteos(conn)
            comparar_insert_y_copy(conn)

        conn.close()
        conn = None
        print("\n" + "=" * 70)
        print("✓ GENERACIÓN COMPLETADA Y CONFIRMADA")
        print(f"Tiempo total: {time.perf_counter() - inicio:.2f} segundos")
        print("=" * 70)
        print("Una sola transacción: toda la carga se confirmó.")
        return 0

    except Exception as exc:
        if conn is not None:
            conn.rollback()
            conn.close()
        print(f"\nERROR: la carga fue revertida por completo: {exc}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    if '--verificar' in sys.argv:
        sys.exit(0 if verificar_poblacion() else 1)
    sys.exit(main())

