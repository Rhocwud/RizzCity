# scripts/normalize_newlines.py
# Normalize line endings for all .luau files under Explorer/ to LF and rewrite files in place.
import os, sys

ROOT = "Explorer"
count = 0
for dirpath, _, filenames in os.walk(ROOT):
    for fname in filenames:
        if not fname.lower().endswith(".luau"):
            continue
        path = os.path.join(dirpath, fname)
        with open(path, "rb") as f:
            raw = f.read()
        # replace CRLF with LF, also replace lone CR with LF
        normalized = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        if normalized != raw:
            with open(path, "wb") as f:
                f.write(normalized)
            count += 1
            print("Normalized:", path)
print("Total files normalized:", count)
