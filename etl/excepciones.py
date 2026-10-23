"""Excepciones propias del ETL."""


class ETLError(Exception):
    """Base de todos los errores del proceso."""


class EstructuraInvalidaError(ETLError):
    """El archivo no existe o no tiene las columnas esperadas: no se puede procesar."""


class ValidacionError(ETLError):
    """Un registro no cumple una regla. Se rechaza ese registro y el proceso continúa."""

    def __init__(self, tipo, campo, detalle):
        super().__init__(f"{tipo} [{campo}]: {detalle}")
        self.tipo, self.campo, self.detalle = tipo, campo, detalle


class ErrorDeCarga(ETLError):
    """Falla inesperada de base de datos (conexión caída, etc.). Detiene el proceso."""
