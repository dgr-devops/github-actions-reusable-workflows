"""Función de saludo mínima."""


def greet(name: str = "mundo") -> str:
    """Devuelve un saludo; falla si el nombre está vacío."""
    cleaned = name.strip()
    if not cleaned:
        raise ValueError("name must not be empty")
    return f"Hola, {cleaned}"
