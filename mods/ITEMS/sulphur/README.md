# Sulphur Update

Mod for **BetterCraft**, the Mineclonia-based game for Luanti. It adds a volcanic and chemical layer to the underground, with sulfur, cinnabar, geysers, sulfurous smoke, and a slime whose behavior changes depending on the block placed inside it.

Author: wrxxnch instagram:jeanpseven

## Installation

Copy the `sulphur_update` folder to `games/bettercraft/mods/` inside the BetterCraft installation. Since this mod uses the `mcl_core`, `mcl_mobs`, and `mcl_potions` APIs, it should be enabled in a BetterCraft world, not in a world created with the default Minetest Game.

## Content

This version uses as reference the sprites from [Sulfur](https://minecraft.wiki/w/Sulfur), [Cinnabar](https://minecraft.wiki/w/Cinnabar), [Sulfur Cube](https://minecraft.wiki/w/Sulfur_Cube), [Bucket of Sulfur Cube](https://minecraft.wiki/w/Bucket_of_Sulfur_Cube), and [Music Disc Bounce](https://minecraft.wiki/w/Music_Disc_Bounce). The texture files for the requested assets were included in the package. **Slabs, stairs, and walls were deliberately ignored at this stage and will be added later.**

## OBJ/MTL Models for the Sulfur Spike

The nodes use the exact names of the provided models. Place the OBJ/MTL pairs in the mod's `models/` folder without renaming the files. The registered models are `sulfur_spike.obj`/`.mtl`, `sulfur_spike_down_base.obj`/`.mtl`, `sulfur_spike_down_frustum.obj`/`.mtl`, `sulfur_spike_down_middle.obj`/`.mtl`, `sulfur_spike_down_tip_merge.obj`/`.mtl`, `sulfur_spike_down_tip.obj`/`.mtl`, `sulfur_spike_up_base.obj`/`.mtl`, `sulfur_spike_up_frustum.obj`/`.mtl`, `sulfur_spike_up_middle.obj`/`.mtl`, `sulfur_spike_up_tip_merge.obj`/`.mtl`, and `sulfur_spike_up_tip.obj`/`.mtl`. Each OBJ file must keep its `mtllib` reference to the corresponding MTL.

| Content | Behavior |
|---|---|
| Sulfur block | Yellow building block, construction material, and ingredient for bricks. |
| Sulfur ore | Underground generation in stone and deepslate; drops sulfur powder. |
| Sulfur stalactite | Decorative non-walkable node, suitable for caves. |
| Cinnabar | Red building block with wiki-based texture. |
| Cut cinnabar | Cut variant of cinnabar. |
| Polished cinnabar | Polished variant of cinnabar. |
| Cinnabar bricks | Decorative cinnabar variant. |
| Potent sulfur | Concentrated sulfur variant. |
| Sulfur | Yellow building block with wiki-based texture. |
| Cut sulfur | Cut variant of sulfur. |
| Polished sulfur | Polished variant of sulfur. |
| Sulfur bricks | Decorative sulfur variant. |
| Sulfur spike | Decorative pointed node. |
| Sulfur geyser | Emits hot particles, weak light, and periodic sound pulses. |
| Sulfur smoke in water | Must be placed above a water source; the area causes nausea periodically. |
| Sulfur cube | Can be summoned by the Spawn Egg, receive blocks via right-click, and be collected in a bucket. |
| Bucket of Sulfur Cube | Stores and relocates a large sulfur cube. |
| Music Disc Bounce | Disc integrated into the jukebox; uses the sound registry available in the base when the original audio is not present. |
| Sulfur Cube Spawn Egg | Spawn egg with a wiki sprite. |

## Mutable slime

Hold a block and right-click the **sulfur slime**. The block is consumed, except in creative mode, and the slime starts displaying the name of the stored material.

| Inserted material | Applied effect |
|---|---|
| Wood | Lower speed, lower gravity, and bouncier jumps, like a plastic ball. |
| Stone or block with a pickaxe group | Higher gravity, lower speed, and reduced jump; the slime becomes heavy. |
| Ice or block with the `ice` group | Much higher speed and slippery/fast movement. |
| Sulfur | Default behavior, keeping the balanced profile. |

The sorting uses node groups, so compatible Mineclonia woods, rocks, and ices also work, not just the blocks added by this mod.

## Quick test

After enabling the mod, use the creative inventory or the base grant commands to obtain the items. To test the slime, obtain the spawn egg `sulphur_update:sulphur_slime_spawn_egg`, place a geyser, and observe the particle pulses. To test the smoke, place `sulphur_update:sulphur_smoke` directly above a water source and stay nearby for a few seconds.

## Compatibility

The implementation was written for the `wrxxnch/luanti-bettercraft` tree and uses the node naming conventions and Mineclonia APIs present in that base. The Lua syntax was validated before packaging; in-game validation should be done in a test copy of the world.

## License

The new code in this mod is distributed under MIT. The BetterCraft/Mineclonia base and its assets remain subject to their own licenses.
