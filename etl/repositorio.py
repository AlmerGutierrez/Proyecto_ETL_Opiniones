"""Acceso a base de datos (única capa que habla SQL). Compatible con MySQL y MariaDB."""
import json

import pymysql

from .excepciones import ErrorDeCarga


def _sentencias(texto):
    """Separa un script SQL en sentencias, respetando las directivas DELIMITER."""
    delim, buf = ";", []
    for linea in texto.splitlines():
        s = linea.strip()
        if s.upper().startswith("DELIMITER "):
            delim = s.split(None, 1)[1]
            continue
        if not buf and (s == "" or s.startswith("--")):
            continue
        buf.append(linea)
        if s.endswith(delim):
            sentencia = "\n".join(buf).rstrip()
            yield sentencia[: -len(delim)]
            buf = []


def _explicar(error, script):
    """Traduce errores típicos de creación de la BD a un mensaje que diga qué hacer."""
    codigo = error.args[0] if error.args else 0
    if codigo == 3121:
        return (f"{script}: MySQL rechazó la carpeta del archivo de datos (error 3121). Hay dos causas posibles: "
                "(1) las carpetas Primary y Secondary NO EXISTEN (MySQL no las crea), o (2) no están declaradas en "
                "'innodb_directories' en my.ini / el servicio no se reinició (ver config/my.ini.ejemplo).")
    if codigo in (1030, 1005, 3119, 3120, 3122):
        return (f"{script}: no se pudo crear el archivo de datos ({error}). Verifica que las carpetas "
                "Primary y Secondary EXISTAN y que el servicio de MySQL tenga permiso de escritura.")
    return f"{script}: {error}"


class Repositorio:
    def __init__(self, cfg, con_bd=True):
        try:
            self.conn = pymysql.connect(
                host=cfg.host, port=cfg.port, user=cfg.usuario, password=cfg.clave,
                database=cfg.nombre if con_bd else None, charset="utf8mb4", autocommit=False)
        except pymysql.MySQLError as e:
            raise ErrorDeCarga(f"No se pudo conectar a la base de datos: {e}") from e

    # ---- administración ----
    def reiniciar_bd(self, nombre):
        with self.conn.cursor() as cur:
            cur.execute(f"DROP DATABASE IF EXISTS `{nombre}`")
        self.conn.commit()

    def existen_tablespaces(self, nombres):
        with self.conn.cursor() as cur:
            marcas = ",".join(["%s"] * len(nombres))
            cur.execute(f"SELECT COUNT(*) FROM information_schema.INNODB_TABLESPACES WHERE NAME IN ({marcas})", list(nombres))
            return cur.fetchone()[0] == len(nombres)

    def eliminar_tablespaces(self, nombres):
        """DROP DATABASE no elimina los tablespaces generales: hay que quitarlos aparte."""
        with self.conn.cursor() as cur:
            marcas = ",".join(["%s"] * len(nombres))
            cur.execute(f"SELECT NAME FROM information_schema.INNODB_TABLESPACES WHERE NAME IN ({marcas})", list(nombres))
            for (nombre,) in cur.fetchall():
                cur.execute(f"DROP TABLESPACE `{nombre}`")
        self.conn.commit()

    def ejecutar_script(self, ruta, reemplazos=None):
        try:
            with self.conn.cursor() as cur, open(ruta, encoding="utf-8") as f:
                texto = f.read()
                for viejo, nuevo in (reemplazos or {}).items():
                    texto = texto.replace(viejo, nuevo)
                for sentencia in _sentencias(texto):
                    cur.execute(sentencia)
            self.conn.commit()
        except pymysql.MySQLError as e:
            raise ErrorDeCarga(_explicar(e, getattr(ruta, "name", str(ruta)))) from e

    # ---- consultas de apoyo para validar -----
    def _columna(self, sql):
        with self.conn.cursor() as cur:
            cur.execute(sql)
            return {fila[0] if len(fila) == 1 else tuple(fila) for fila in cur.fetchall()}

    def ids(self, tabla, columna):
        return self._columna(f"SELECT {columna} FROM {tabla}")

    def emails(self):
        return {e.lower() for e in self._columna("SELECT Email FROM cliente")}

    def claves_opinion(self):
        return self._columna("SELECT TipoOrigen, IdOrigen FROM opinion")

    def fuente_por_tipo(self, tipo):
        with self.conn.cursor() as cur:
            cur.execute("SELECT IdFuente FROM fuente_datos WHERE TipoFuente=%s ORDER BY IdFuente LIMIT 1", (tipo,))
            fila = cur.fetchone()
            return fila[0] if fila else None

    # ---------- inserciones ----------
    def _ejecutar(self, sql, params):
        with self.conn.cursor() as cur:
            cur.execute(sql, params)

    def insertar_fuente(self, id_, tipo, fecha):
        self._ejecutar("INSERT INTO fuente_datos (IdFuente, TipoFuente, FechaCarga) VALUES (%s,%s,%s)", (id_, tipo, fecha))

    def insertar_cliente(self, id_, nombre, email):
        self._ejecutar("INSERT INTO cliente (IdCliente, Nombre, Email) VALUES (%s,%s,%s)", (id_, nombre, email))

    def insertar_producto(self, id_, nombre, categoria):
        self._ejecutar("INSERT INTO producto (IdProducto, Nombre, Categoria) VALUES (%s,%s,%s)", (id_, nombre, categoria))

    def llamar(self, procedimiento, argumentos):
        with self.conn.cursor() as cur:
            cur.callproc(procedimiento, argumentos)

    def registrar_rechazo(self, ejecucion, archivo, fila, tipo, campo, detalle, registro):
        self._ejecutar(
            "INSERT INTO etl_rechazo (IdEjecucion, Archivo, Fila, TipoError, Campo, Detalle, Registro) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s)",
            (ejecucion, archivo, fila, tipo, campo, detalle[:255], json.dumps(registro, ensure_ascii=False)))
        self.conn.commit()

    # ------ transacciones -----
    def confirmar(self):
        self.conn.commit()

    def deshacer(self):
        self.conn.rollback()

    def cerrar(self):
        self.conn.close()
