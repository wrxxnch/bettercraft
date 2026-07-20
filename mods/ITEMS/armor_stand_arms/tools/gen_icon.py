#!/usr/bin/env python3
"""Generate textures/armor_stand_arms_item.png from the vanilla icon.

Copies mcl_armor_stand's 16x16 inventory icon and draws two hanging arm
columns (x=5 and x=11, rows 4..8) below the shoulder bar in matching wood
colors. Re-run after a Mineclonia update if the vanilla icon changes:
    python3 tools/gen_icon.py
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
VANILLA = os.path.expanduser(
    "~/.var/app/org.luanti.luanti/.minetest/games/mineclonia/"
    "mods/ITEMS/mcl_armor_stand/textures/3d_armor_stand_item.png"
)
OUT = os.path.join(HERE, "..", "textures", "armor_stand_arms_item.png")

# wood palette sampled from the vanilla icon; arms hang from the shoulder
# bar ends and step one pixel outward halfway down (angled arms)
ARM_PIXELS = [
    # (dx from bar end, y, color) — mirrored for both sides
    (0, 4, (124, 95, 76, 255)),
    (0, 5, (137, 106, 78, 255)),
    (1, 6, (145, 112, 82, 255)),
    (1, 7, (124, 95, 76, 255)),
]

im = Image.open(VANILLA).convert("RGBA")
px = im.load()
for dx, y, color in ARM_PIXELS:
    px[5 - dx, y] = color
    px[11 + dx, y] = color
im.save(OUT, optimize=True)
print("wrote", OUT)
