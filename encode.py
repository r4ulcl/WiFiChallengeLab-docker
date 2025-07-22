#!/usr/bin/env python3
"""
encode.py   –   Encode plaintext with a repeating‑key XOR
Usage:
    python encode.py "Text you want to protect" "mySuperSecret"
If you omit the secret, the script will prompt for it.
"""

import sys
import base64
import getpass


def encode(plaintext: str, secret: str) -> str:
    p_bytes = plaintext.encode("utf‑8")
    k_bytes = secret.encode("utf‑8")
    xored   = bytes(b ^ k_bytes[i % len(k_bytes)] for i, b in enumerate(p_bytes))
    return base64.urlsafe_b64encode(xored).decode("ascii")


def main() -> None:
    # ── arg 1 = text to cipher ──────────────────────────────────────────────
    if len(sys.argv) < 2:
        sys.exit("Usage: python encode.py \"plaintext\" [secret]")

    plaintext = sys.argv[1]

    # ── arg 2 = secret (optional) ──────────────────────────────────────────
    if len(sys.argv) >= 3:
        secret = sys.argv[2]
    else:
        # Hide typing if the user prefers not to expose the key in shell history
        secret = getpass.getpass("Secret key: ")

    cipher = encode(plaintext, secret)
    print(cipher)


if __name__ == "__main__":
    main()
