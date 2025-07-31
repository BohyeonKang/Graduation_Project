import random

def generate_random_nchw():
    # Generate a random 32-bit integer
    random_int = random.getrandbits(32)

    # Convert the integer to its hexadecimal representation
    hex_representation = hex(random_int)

    print(f"Random 32-bit Hexadecimal Integer: {hex_representation}")

    # For N, C, H, W format, we need to decide how to split the 32 bits.
    # A common way to interpret this for a 32-bit integer might be to
    # divide the bits, e.g., 8 bits for each (N, C, H, W).
    # This is an arbitrary interpretation since NCHW usually refers to
    # the dimensions of a tensor, not a direct bit-level breakdown of a single integer.
    # If you have a specific mapping in mind (e.g., how many bits for N, C, H, W respectively),
    # please let me know.

    # Here's one possible interpretation:
    # We can view the 32-bit integer as a concatenation of four 8-bit values.
    # Extracting these values:
    N = (random_int >> 24) & 0xFF  # Most significant 8 bits
    C = (random_int >> 16) & 0xFF  # Next 8 bits
    H = (random_int >> 8) & 0xFF   # Next 8 bits
    W = random_int & 0xFF          # Least significant 8 bits

    print(f"N: {N} (0x{N:02x})")
    print(f"C: {C} (0x{C:02x})")
    print(f"H: {H} (0x{H:02x})")
    print(f"W: {W} (0x{W:02x})")

    # If you meant that N, C, H, W should be individual random 8-bit integers,
    # then the approach would be slightly different:
    # N = random.randint(0, 255)
    # C = random.randint(0, 255)
    # H = random.randint(0, 255)
    # W = random.randint(0, 255)
    # print(f"\nAlternatively, individual random 8-bit values for N, C, H, W:")
    # print(f"N: {N} (0x{N:02x})")
    # print(f"C: {C} (0x{C:02x})")
    # print(f"H: {H} (0x{H:02x})")
    # print(f"W: {W} (0x{W:02x})")

# Run the function
generate_random_nchw()