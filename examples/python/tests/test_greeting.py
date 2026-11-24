import pytest

from demo_pkg import greet


def test_greet_default() -> None:
    assert greet() == "Hola, mundo"


def test_greet_strips_whitespace() -> None:
    assert greet("  Ana ") == "Hola, Ana"


def test_greet_rejects_empty_name() -> None:
    with pytest.raises(ValueError):
        greet("   ")
