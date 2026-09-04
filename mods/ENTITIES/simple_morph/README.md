> [!WARNING]  
> **Work in Progress:** This mod is currently under active development. Features, mob abilities, and API methods may change between updates, and you may encounter minor visual bugs or balance changes.

# Simple Morph for Mineclonia

A lightweight, feature-packed morphing mod designed specifically for Mineclonia. Transform into any registered mob with dynamically scaled hitboxes, camera alignment, status effects, and passive abilities.

## Features

* **Dynamic Scaling:** Bounding boxes and visual meshes automatically scale to match target mob heights.
* **Camera Offsets:** First-person and third-person camera origins automatically adjust to match the mob's eye level.
* **Passive Mob Abilities:**
  * **Creeper:** Left-click/punch nodes to trigger native explosions (`mcl_explosions`).
  * **Bat / Phantom:** Flying physics (jump boost up) and continuous Night Vision potion effects (`mcl_potions`).
  * **Spider / Cave Spider:** Higher jump height and Night Vision.
  * **Fish / Squid / Dolphin / Guardian:** Infinite water breathing.
* **Clean Cleanup:** Reverting via `/unmorph` automatically strips morph-applied status effects and restores player skins (`mcl_skins`).

---

## Commands

* `/morph list` — Displays a list of all available morphable entities loaded in the world.
* `/morph <mob_name>` — Morph into a specific mob (e.g., `/morph creeper`, `/morph bat`, `/morph cow`).
* `/unmorph` — Revert back to standard player form.

---

## Installation

1. Download or clone this repository into your Luanti/Minetest `mods/` directory:
   * **Windows:** `%APPDATA%\Luanti\mods\simple_morph`
   * **Linux:** `~/.luanti/mods/simple_morph`
2. Enable `simple_morph` in your world configuration menu.

## Dependencies

* **Required:** `mcl_player`, `mcl_skins`, `mcl_potions`
* **Optional:** `mcl_mobs`, `mobs_mc`, `mcl_explosions`

## License

* **Code:** MIT License
* **Media / Textures:** CC BY-SA 4.0
