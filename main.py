"""Punto de entrada del ETL (aplicación monolítica: un solo proceso, módulos internos por capa).

Uso:
    python main.py --reiniciar          # borra y recrea la BD y su estructura física, luego carga
    python main.py --crear-bd           # crea la BD si no existe, luego carga
    python main.py                      # solo carga (la BD ya existe)
Conexión por variables de entorno: DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, DB_NAME
"""
import argparse
import logging
import sys
import time
from datetime import datetime
from pathlib import Path

from etl import procesos, reporte
from etl.config import RAIZ, RUTA_EN_SCRIPT, RUTA_FISICA_DEFECTO, TABLESPACES, ConfigBD
from etl.excepciones import ETLError
from etl.repositorio import Repositorio


def configurar_log(ejecucion):
    log = logging.getLogger("etl")
    log.setLevel(logging.INFO)
    formato = logging.Formatter("%(asctime)s | %(levelname)-7s | %(message)s", "%H:%M:%S")
    consola = logging.StreamHandler(sys.stdout)
    consola.setFormatter(formato)
    log.addHandler(consola)
    (RAIZ / "logs").mkdir(exist_ok=True)
    archivo = logging.FileHandler(RAIZ / "logs" / f"etl_{ejecucion}.log", encoding="utf-8")
    archivo.setFormatter(formato)
    log.addHandler(archivo)
    return log


def main():
    ap = argparse.ArgumentParser(description="ETL - Sistema de Análisis de Opiniones de Clientes")
    ap.add_argument("--datos", default=str(RAIZ / "data"), help="carpeta con los CSV")
    ap.add_argument("--ruta-fisica", default=RUTA_FISICA_DEFECTO,
                    help="carpeta base con Primary/, Secondary/ y Log/ (por defecto %(default)s)")
    ap.add_argument("--crear-bd", action="store_true", help="ejecuta los scripts SQL de /sql antes de cargar")
    ap.add_argument("--reiniciar", action="store_true", help="elimina la BD y la vuelve a crear (implica --crear-bd)")
    args = ap.parse_args()

    ejecucion = datetime.now().strftime("%Y%m%d%H%M%S")
    log = configurar_log(ejecucion)
    cfg = ConfigBD.desde_entorno()
    inicio = time.time()
    repo = None
    try:
        log.info(f"Inicio del ETL (ejecución {ejecucion}) -> {cfg.usuario}@{cfg.host}:{cfg.port}/{cfg.nombre}")
        if args.crear_bd or args.reiniciar:
            admin = Repositorio(cfg, con_bd=False)
            if args.reiniciar:
                admin.reiniciar_bd(cfg.nombre)
                admin.eliminar_tablespaces(TABLESPACES)
                log.info(f"Base de datos '{cfg.nombre}' y tablespaces {list(TABLESPACES)} eliminados")
            for script in sorted((RAIZ / "sql").glob("0[0-3]_*.sql")):
                if script.name.startswith("00_") and admin.existen_tablespaces(TABLESPACES):
                    log.info(f"Script omitido: {script.name} (los tablespaces ya existen)")
                    continue
                admin.ejecutar_script(script, {RUTA_EN_SCRIPT: args.ruta_fisica})
                log.info(f"Script ejecutado: {script.name}")
            admin.cerrar()
        repo = Repositorio(cfg)
        ctx = procesos.Contexto(repo, Path(args.datos), ejecucion, log)
        estadisticas = procesos.ejecutar(ctx)
        reporte.imprimir_resumen(log, ejecucion, estadisticas, time.time() - inicio)
        return 2 if any(e.error_fatal for e in estadisticas) else 0
    except ETLError as e:
        log.error(f"El proceso se detuvo: {e}")
        return 1
    finally:
        if repo:
            repo.cerrar()


if __name__ == "__main__":
    sys.exit(main())
