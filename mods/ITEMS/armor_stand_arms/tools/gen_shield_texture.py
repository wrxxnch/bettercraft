#!/usr/bin/env python3
"""Generate textures/armor_stand_arms_shield.png: a copy of Mineclonia's
flat shield inventory icon, used as a stand-in for the shield displayed on
the stand's off arm.

Why: VoxeLibre's own shield icon (mcl_shield.png) is drawn at a stylized
angle (not a plain rectangle), which looks skewed when shown flat on the
stand's arm. Mineclonia's icon (mcl_shield_48.png) is a plain frontal
rectangle. Both are CC BY-SA 3.0 from the same mcl_shields lineage, so this
mod bundles the flat one and displays it in place of the actual equipped
shield's icon specifically when running on VoxeLibre (see init.lua).

Re-run after a Mineclonia update if its shield icon ever changes:
    python3 tools/gen_shield_texture.py
"""
import os
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.expanduser(
    "~/.var/app/org.luanti.luanti/.minetest/games/mineclonia/"
    "mods/ITEMS/mcl_shields/textures/mcl_shield_48.png"
)
OUT = os.path.join(HERE, "..", "textures", "armor_stand_arms_shield.png")


def main():
    shutil.copyfile(SOURCE, OUT)
    print("wrote %s (copied from %s)" % (OUT, SOURCE))


if __name__ == "__main__":
    main()
