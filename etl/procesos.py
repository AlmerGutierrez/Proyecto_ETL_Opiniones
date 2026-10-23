"""Lógica de negocio del ETL: valida, transforma y carga cada archivo respetando las relaciones."""
from datetime import date

import pymysql

from . import transformacion as T
from . import validacion as V
from .config import (CANALES, CLASIFICACIONES, COLUMNAS_REQUERIDAS, TIPO_FUENTE_POR_ARCHIVO, TIPOS_FUENTE)
from .excepciones import ErrorDeCarga, EstructuraInvalidaError, ValidacionError
from .extraccion import leer_csv
from .reporte import Estadisticas


class Contexto:
    """Estado compartido de una ejecución: conexión, conjuntos de claves y fuentes asignadas."""

    def __init__(self, repo, datos, ejecucion, log):
        self.repo, self.datos, self.ejecucion, self.log = repo, datos, ejecucion, log
        self.hoy = date.today()
        self.ids_fuentes = repo.ids("fuente_datos", "IdFuente")
        self.ids_clientes = repo.ids("cliente", "IdCliente")
        self.ids_productos = repo.ids("producto", "IdProducto")
        self.emails = repo.emails()
        self.claves = repo.claves_opinion()
        self.fuente_de = {}

    def asignar_fuente(self, archivo):
        tipo = TIPO_FUENTE_POR_ARCHIVO[archivo]
        id_fuente = self.repo.fuente_por_tipo(tipo)
        if id_fuente is None:
            raise ErrorDeCarga(f"No existe ninguna fuente de tipo '{tipo}' para asociar a {archivo}")
        self.fuente_de[archivo] = id_fuente
        self.log.info(f"Supuesto: {archivo} se asocia a IdFuente {id_fuente} (TipoFuente='{tipo}')")


# ---------------------------------------------------------------- reglas comunes
def _duplicado(existentes, clave, campo):
    if clave in existentes:
        raise ValidacionError("Registro duplicado", campo, f"{clave} ya existe")


def _referencias(ctx, id_cliente, id_producto):
    if id_cliente is not None and id_cliente not in ctx.ids_clientes:
        raise ValidacionError("Integridad referencial", "IdCliente", f"cliente {id_cliente} no existe en la tabla cliente")
    if id_producto not in ctx.ids_productos:
        raise ValidacionError("Integridad referencial", "IdProducto", f"producto {id_producto} no existe en la tabla producto")


# ---------------------------------------------------------------- maestros
def transformar_fuente(ctx, f):
    id_ = V.patron(V.obligatorio(f, "IdFuente"), "IdFuente", r"F\d{1,9}", "F###")
    tipo = V.en_catalogo(V.obligatorio(f, "TipoFuente"), "TipoFuente", TIPOS_FUENTE)
    fecha = V.fecha(V.obligatorio(f, "FechaCarga"), "FechaCarga", ctx.hoy)
    _duplicado(ctx.ids_fuentes, id_, "IdFuente")
    return id_, tipo, fecha


def insertar_fuente(ctx, d):
    ctx.repo.insertar_fuente(*d)
    ctx.ids_fuentes.add(d[0])


def transformar_cliente(ctx, f):
    id_ = V.entero(V.obligatorio(f, "IdCliente"), "IdCliente", minimo=1)
    nombre = V.longitud(T.limpiar_texto(V.obligatorio(f, "Nombre")), "Nombre", 100)
    correo = V.longitud(V.email(V.obligatorio(f, "Email").lower()), "Email", 150)
    _duplicado(ctx.ids_clientes, id_, "IdCliente")
    _duplicado(ctx.emails, correo, "Email")
    return id_, nombre, correo


def insertar_cliente(ctx, d):
    ctx.repo.insertar_cliente(*d)
    ctx.ids_clientes.add(d[0])
    ctx.emails.add(d[2])


def transformar_producto(ctx, f):
    id_ = V.entero(V.obligatorio(f, "IdProducto"), "IdProducto", minimo=1)
    nombre = V.longitud(T.limpiar_texto(V.obligatorio(f, "Nombre")), "Nombre", 100)
    categoria = V.longitud(T.limpiar_texto(V.obligatorio(f, "Categoría")), "Categoría", 50)
    _duplicado(ctx.ids_productos, id_, "IdProducto")
    return id_, nombre, categoria


def insertar_producto(ctx, d):
    ctx.repo.insertar_producto(*d)
    ctx.ids_productos.add(d[0])


# ---------------------------------------------------------------- opiniones
def transformar_encuesta(ctx, f):
    origen = str(V.entero(V.obligatorio(f, "IdOpinion"), "IdOpinion", minimo=1))
    cliente = V.entero(V.obligatorio(f, "IdCliente"), "IdCliente", minimo=1)
    producto = V.entero(V.obligatorio(f, "IdProducto"), "IdProducto", minimo=1)
    fecha = V.fecha(V.obligatorio(f, "Fecha"), "Fecha", ctx.hoy)
    comentario = T.limpiar_texto(V.obligatorio(f, "Comentario"))
    clasif = V.en_catalogo(V.obligatorio(f, "Clasificación"), "Clasificación", CLASIFICACIONES)
    puntaje = V.entero(V.obligatorio(f, "PuntajeSatisfacción"), "PuntajeSatisfacción", 1, 5)
    V.obligatorio(f, "Fuente")
    _duplicado(ctx.claves, ("Encuesta", origen), "IdOpinion")
    _referencias(ctx, cliente, producto)
    return dict(origen=origen, cliente=cliente, producto=producto, fecha=fecha, comentario=comentario,
                extra=(clasif, puntaje), fuente=ctx.fuente_de["surveys_part1.csv"])


def insertar_encuesta(ctx, d):
    ctx.repo.llamar("sp_registrar_opinion_encuesta",
                    [d["origen"], d["cliente"], d["producto"], d["fuente"], d["fecha"], d["comentario"], *d["extra"]])
    ctx.claves.add(("Encuesta", d["origen"]))


def transformar_social(ctx, f):
    origen = V.patron(V.obligatorio(f, "IdComment"), "IdComment", r"T\d+", "T####")
    crudo = (f.get("IdCliente") or "").strip()
    cliente = T.codigo_a_entero(crudo, "C", "IdCliente") if crudo else None   # vacío = comentario anónimo
    producto = T.codigo_a_entero(V.obligatorio(f, "IdProducto"), "P", "IdProducto")
    canal = V.en_catalogo(V.obligatorio(f, "Fuente"), "Fuente", CANALES)
    fecha = V.fecha(V.obligatorio(f, "Fecha"), "Fecha", ctx.hoy)
    comentario = T.limpiar_texto(V.obligatorio(f, "Comentario"))
    _duplicado(ctx.claves, ("Social", origen), "IdComment")
    _referencias(ctx, cliente, producto)
    return dict(origen=origen, cliente=cliente, producto=producto, fecha=fecha, comentario=comentario,
                extra=(canal,), fuente=ctx.fuente_de["social_comments.csv"])


def insertar_social(ctx, d):
    ctx.repo.llamar("sp_registrar_opinion_social",
                    [d["origen"], d["cliente"], d["producto"], d["fuente"], d["fecha"], d["comentario"], *d["extra"]])
    ctx.claves.add(("Social", d["origen"]))


def transformar_web(ctx, f):
    origen = V.patron(V.obligatorio(f, "IdReview"), "IdReview", r"W\d+", "W####")
    cliente = T.codigo_a_entero(V.obligatorio(f, "IdCliente"), "C", "IdCliente")
    producto = T.codigo_a_entero(V.obligatorio(f, "IdProducto"), "P", "IdProducto")
    fecha = V.fecha(V.obligatorio(f, "Fecha"), "Fecha", ctx.hoy)
    comentario = T.limpiar_texto(V.obligatorio(f, "Comentario"))
    rating = V.entero(V.obligatorio(f, "Rating"), "Rating", 1, 5)
    _duplicado(ctx.claves, ("Web", origen), "IdReview")
    _referencias(ctx, cliente, producto)
    return dict(origen=origen, cliente=cliente, producto=producto, fecha=fecha, comentario=comentario,
                extra=(rating,), fuente=ctx.fuente_de["web_reviews.csv"])


def insertar_web(ctx, d):
    ctx.repo.llamar("sp_registrar_opinion_web",
                    [d["origen"], d["cliente"], d["producto"], d["fuente"], d["fecha"], d["comentario"], *d["extra"]])
    ctx.claves.add(("Web", d["origen"]))


# ---------------------------------------------------------------- motor de carga
def _rechazar(ctx, stats, archivo, fila_n, fila, error):
    stats.rechazados += 1
    stats.motivos[f"{error.tipo} · {error.campo}"] += 1
    ctx.repo.registrar_rechazo(ctx.ejecucion, archivo, fila_n, error.tipo, error.campo, error.detalle, fila)


def procesar_archivo(ctx, archivo, transformar, insertar):
    stats = Estadisticas(archivo)
    try:
        filas = leer_csv(ctx.datos / archivo, COLUMNAS_REQUERIDAS[archivo])
    except EstructuraInvalidaError as e:
        stats.error_fatal = str(e)
        ctx.log.error(f"Estructura inválida: {e}")
        return stats
    ctx.log.info(f"Procesando {archivo}: {len(filas)} registros leídos")
    for n, fila in filas:
        stats.leidos += 1
        try:
            datos = transformar(ctx, fila)
            insertar(ctx, datos)
            ctx.repo.confirmar()
            stats.insertados += 1
        except ValidacionError as e:
            ctx.repo.deshacer()
            _rechazar(ctx, stats, archivo, n, fila, e)
        except pymysql.err.IntegrityError as e:
            ctx.repo.deshacer()
            detalle = str(e.args[1]) if len(e.args) > 1 else str(e)
            _rechazar(ctx, stats, archivo, n, fila, ValidacionError("Restricción de la BD", "BD", detalle))
        except pymysql.MySQLError as e:
            ctx.repo.deshacer()
            raise ErrorDeCarga(f"{archivo}, fila {n}: {e}") from e
    ctx.log.info(f"  -> {archivo}: insertados={stats.insertados} rechazados={stats.rechazados}")
    return stats


def ejecutar(ctx):
    """Orden obligatorio: primero los padres (maestros), después las opiniones."""
    resultados = [
        procesar_archivo(ctx, "fuente_datos.csv", transformar_fuente, insertar_fuente),
        procesar_archivo(ctx, "clients.csv", transformar_cliente, insertar_cliente),
        procesar_archivo(ctx, "products.csv", transformar_producto, insertar_producto),
    ]
    for archivo in TIPO_FUENTE_POR_ARCHIVO:
        ctx.asignar_fuente(archivo)
    resultados += [
        procesar_archivo(ctx, "surveys_part1.csv", transformar_encuesta, insertar_encuesta),
        procesar_archivo(ctx, "social_comments.csv", transformar_social, insertar_social),
        procesar_archivo(ctx, "web_reviews.csv", transformar_web, insertar_web),
    ]
    return resultados
