"""Reglas de validación. Cada función devuelve el valor ya limpio o lanza ValidacionError."""
import re
from datetime import datetime

from .excepciones import ValidacionError

EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def obligatorio(fila, campo):
    valor = (fila.get(campo) or "").strip()
    if valor == "":
        raise ValidacionError("Campo obligatorio vacío", campo, "valor vacío o nulo")
    return valor


def longitud(valor, campo, maximo):
    if len(valor) > maximo:
        raise ValidacionError("Longitud excedida", campo, f"{len(valor)} caracteres (máximo {maximo})")
    return valor


def entero(valor, campo, minimo=None, maximo=None):
    try:
        n = int(str(valor).strip())
    except (TypeError, ValueError):
        raise ValidacionError("Tipo de dato inválido", campo, f"'{valor}' no es un entero")
    if (minimo is not None and n < minimo) or (maximo is not None and n > maximo):
        raise ValidacionError("Valor fuera de rango", campo, f"{n} no está entre {minimo} y {maximo}")
    return n


def fecha(valor, campo, hoy):
    try:
        f = datetime.strptime(valor, "%Y-%m-%d").date()
    except ValueError:
        raise ValidacionError("Formato inválido", campo, f"'{valor}' no cumple AAAA-MM-DD")
    if f > hoy:
        raise ValidacionError("Valor fuera de rango", campo, f"fecha futura {f}")
    return f


def patron(valor, campo, regex, ejemplo):
    if not re.fullmatch(regex, valor):
        raise ValidacionError("Formato inválido", campo, f"'{valor}' no cumple el formato {ejemplo}")
    return valor


def en_catalogo(valor, campo, catalogo):
    if valor not in catalogo:
        raise ValidacionError("Valor fuera de catálogo", campo, f"'{valor}' no está en {sorted(catalogo)}")
    return valor


def email(valor, campo="Email"):
    if not EMAIL_RE.match(valor):
        raise ValidacionError("Formato inválido", campo, f"'{valor}' no es un correo válido")
    return valor
