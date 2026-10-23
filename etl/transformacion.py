"""T - Transform: limpieza y normalización de valores."""
from .validacion import patron


def limpiar_texto(valor: str) -> str:
    """Quita espacios sobrantes (inicio, fin y repetidos dentro del texto)."""
    return " ".join(valor.split())


def codigo_a_entero(valor: str, prefijo: str, campo: str) -> int:
    """'C007' -> 7 ; 'P016' -> 16. Unifica el formato de IDs con las tablas maestras."""
    patron(valor, campo, rf"{prefijo}\d+", f"{prefijo}###")
    return int(valor[len(prefijo):])
