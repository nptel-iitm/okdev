"""Order pricing rules for the storefront."""

FREE_SHIPPING_THRESHOLD = 50.0
SHIPPING_FLAT_RATE = 4.99


def subtotal(items):
    """Sum line totals. Each item is a dict with 'price' and 'quantity'."""
    total = 0.0
    for item in items:
        total += item["price"] * item["quantity"]
    return total


def apply_discount(amount, percent):
    """Reduce amount by a percentage. percent is 0-100."""
    if percent < 0 or percent > 100:
        raise ValueError("percent must be between 0 and 100")
    return amount - (amount * percent / 100)


def shipping_cost(subtotal_amount):
    """Flat rate below the threshold, free at or above it."""
    if subtotal_amount > FREE_SHIPPING_THRESHOLD:
        return 0.0
    return SHIPPING_FLAT_RATE


def order_total(items, discount_percent=0):
    """Subtotal, then discount, then shipping on the discounted amount."""
    sub = subtotal(items)
    discounted = apply_discount(sub, discount_percent)
    return discounted + shipping_cost(discounted)
