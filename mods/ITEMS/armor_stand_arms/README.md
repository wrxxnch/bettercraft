# Armor Stand with Arms

An armor stand that has **arms** — so it can show off your armor **and** hold
a **weapon** in one hand and a **shield** in the other. One mod that works on
[Mineclonia](https://content.luanti.org/packages/ryvnf/mineclonia/),
[VoxeLibre](https://content.luanti.org/packages/Wuzzy/mineclone2/) (formerly
MineClone2), and **Minetest Game** (with the
[3d_armor](https://content.luanti.org/packages/stu/3d_armor/) mod).

It works just like the normal armor stand you already know, but now your
gear has somewhere to pose. Set up a knight by the door, show off your best
sword, or build a little armory room where every stand holds a different
weapon.

## How to craft it

Put **8 sticks** around a **stone slab** in the crafting grid:

```
Stick   Stick   Stick
Stick   Stick   Stick
Stick   Slab    Stick
```

The slab is the same one used to craft each game's normal armor stand — the
"Smooth Stone Slab" in Mineclonia, the "Polished Stone Slab" in VoxeLibre,
or the "Stone Slab" in Minetest Game. In short: the normal armor stand
recipe, plus extra sticks down the sides to make the arms.

## How to use it — Mineclonia / VoxeLibre

- **Put armor on it** — hold a helmet, chestplate, leggings, or boots and
  use them on the stand, exactly like the normal armor stand.
- **Give it a weapon** — hold a melee weapon (sword, mace, or trident in MCL;
  sword, hammer, or trident in VL) and use it on the stand. The weapon
  appears in its right hand.
- **Give it a shield** — hold a shield and use it on the stand. The shield
  appears on its other arm. (Only regular shield supported. Planned update:
  support for shields customized with banners)
- **Take things back** — with an empty hand, use the place key on the stand.
  Aim at the weapon or the shield to take it, or at a piece of armor to
  take that piece.
- **Turn it** — use a screwdriver to rotate the stand; the weapon and shield
  turn with it.
- Break the stand and everything it was holding drops on the ground.

## How to use it — Minetest Game

- **Right-click the stand** to open it, like a chest.
- **Armor** goes in the four middle slots — helmet, chestplate, leggings,
  boots. Pieces snap to their proper slot automatically.
- **Weapon** (sword, axe) goes in the left slot and appears in the stand's
  right hand; a **shield** goes in the right slot and appears on its other
  arm.
- Take anything back out through the same menu.
- Rotate the stand with a screwdriver; the weapon and shield turn with it.
- The stand can't be dug while it's holding something — empty it first.
  Explosions drop everything on the ground.

## Requirements

- On **Mineclonia** or **VoxeLibre**: nothing extra to install. The mod uses
  the game's own armor stand mod (`mcl_armor_stand`) for the body model,
  which both games include by default.
- On **Minetest Game**: the
  [3d_armor](https://content.luanti.org/packages/stu/3d_armor/) modpack —
  the mod that adds wearable armor (and its armor stand). Its `shields`
  part is needed if you want the stand to hold shields. If 3d_armor is
  missing, your world still loads fine — the stand just stays inactive and
  a chat message tells you what to install.

The mod detects the game by itself and loads the matching version; the
stand is named `armor_stand_arms:armor_stand` everywhere.

## Credits & license

This mod is based on the armor stands by **Stuart Jones** (stujones11): the
one that ships with Mineclonia and VoxeLibre, and the one from the 3d_armor
modpack for Minetest Game. The stand models and icon are extended versions
of those originals.

- Code: **LGPL 2.1 or later**
- Models & textures: **CC BY-SA 3.0**

See [LICENSE.txt](https://github.com/nandologia/Armor-Stand-with-Arms/blob/main/LICENSE.txt) for the full details.

---

### For modders

`init.lua` only picks the right code path for the running game: `mcl.lua`
(Mineclonia/VoxeLibre, right-click equip flow) or `minetest_game.lua`
(Minetest Game, 3d_armor's chest-style formspec). The arm geometry and the
hand-display entities work the same way in both.

The arms on the models and the inventory icon are generated from each
game's own armor stand art by the scripts in `tools/`, so they always match
it:

- `tools/gen_mesh.py` — adds the two arms to Mineclonia's armor stand model
  (`models/armor_stand_arms.obj`; the model is the same in Mineclonia and
  VoxeLibre).
- `tools/gen_mesh_minetest.py` — same, for 3d_armor_stand's model
  (`models/armor_stand_arms_minetest.obj`), with the arm faces reusing UVs
  from existing faces so they land on the right part of the texture atlas.
- `tools/gen_icon.py` — adds the arms to Mineclonia's stand icon.
- `tools/gen_shield_texture.py` — copies Mineclonia's flat shield icon,
  used in place of VoxeLibre's own shield icon (which is drawn at an angle
  and looks skewed when shown flat on the stand's arm).
- `tools/test_load.py` / `tools/test_load_minetest.py` — load the mod under
  a stub API (via `lupa`), one per game family, and check the
  placing/taking/rotating/dropping logic without launching the game.

Re-run the `gen_*` scripts after a game/modpack update if the armor stand
model, icon, or shield icon ever changes. The weapon and shield positions
live in the `HANDS` table at the top of `mcl.lua` and `minetest_game.lua`.
