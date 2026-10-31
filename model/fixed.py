"""Integer fixed-point helpers used by the model and later RTL comparison."""


def sign_extend(value: int, width: int) -> int:
    """Interpret ``value`` as a signed two's-complement integer."""

    mask = (1 << width) - 1
    value &= mask
    sign = 1 << (width - 1)
    return value - (1 << width) if value & sign else value


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def edge_function(ax: int, ay: int, bx: int, by: int, px: int, py: int) -> int:
    """Return the signed 2-D cross product for edge ``a -> b`` at ``p``."""

    return (bx - ax) * (py - ay) - (by - ay) * (px - ax)

