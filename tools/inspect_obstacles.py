import gzip
import json
import sys

sys.stdout.reconfigure(encoding="utf-8")

with gzip.open(r"D:\game\tool\editor_map\export\map_525dc16b\chunks\0_0.json.gz", "rt", encoding="utf-8") as f:
    raw_src = json.load(f)["r"]

r = raw_src.get("27,27", {})
print("Objects in 27,27:")
for obj in r.get("objects", []):
    print(" ", obj)

print("\nCovers in 27,27:")
for cov in r.get("covers", []):
    print(" ", cov)

print("\nNPCs in 27,27:")
for n in r.get("npcs", []):
    print(" ", n)
