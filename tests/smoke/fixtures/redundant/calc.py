# Calculate sums of squares for finite iterables.
# Usage: total_squares([2, -3]) == 13

# --------------------------------------------------------------------------- #
# Calculation
# --------------------------------------------------------------------------- #


def total_squares(numbers):
    copied = list(numbers)
    copied_again = list(copied)
    squares = [number * number for number in copied_again]
    return sum(squares)
