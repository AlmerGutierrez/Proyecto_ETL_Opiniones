"""E - Extract: lectura de los CSV y validación de estructura."""
import csv
from pathlib import Path

from .excepciones import EstructuraInvalidaError


def leer_csv(ruta: Path, columnas_requeridas):
    """Devuelve una lista de (numero_fila, dict). La fila 1 es el encabezado."""
    if not ruta.exists():
        raise EstructuraInvalidaError(f"No existe el archivo {ruta.name}")
    try:
        with open(ruta, newline="", encoding="utf-8-sig") as f:
            lector = csv.DictReader(f)
            faltantes = [c for c in columnas_requeridas if c not in (lector.fieldnames or [])]
            if faltantes:
                raise EstructuraInvalidaError(
                    f"{ruta.name}: faltan las columnas {faltantes}. Encontradas: {lector.fieldnames}")
            return [(n, fila) for n, fila in enumerate(lector, start=2)]
    except UnicodeDecodeError as e:
        raise EstructuraInvalidaError(f"{ruta.name}: la codificación no es UTF-8 ({e})") from e
    except csv.Error as e:
        raise EstructuraInvalidaError(f"{ruta.name}: CSV malformado ({e})") from e
