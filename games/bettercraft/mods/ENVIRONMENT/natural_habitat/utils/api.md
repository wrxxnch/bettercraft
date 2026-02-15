# Natural Habitat (API)

## Utilities
- ```natural_habitat.is_minetest()```: 
  - returns true if game is "Minetest Game".
- ```natural_habitat.is_mineclonia()```:
  - returns true if game is "MineClonia".
- ```natural_habitat.schempath(spfc)```:
  - if (spfc) is nil returns "Natural Habitat" mod schempath with current game folder.
  - if (spfc) is true returns default "Natural Habitat" mod schempath.
- ```natural_habitat.check_on_rightclick(pos, itemstack, placer)```:
  - returns "node.on_rightclick" function if "sneak" button not pressed.
- ```natural_habitat.place_item(itemstack, user, pointed_thing, replacement) ```: 
  - use in ```on_place = function(itemstack, placer, pointed_thing)```.
  - similar to ```core.place_node(pos, node[, placer])```, but with some changes:
    - checking "node.on_rightclick" before place.
    - use ```core.check_for_falling(pos)```.
    - have "replacement" node: you can make craftitem place another node. (for example I use this to to make sticks placeble).
- ```natural_habitat.game_impact(minetest, mineclonia)```:
  - return variable depends which game is playing.
- ```natural_habitat.get_item(minetest_item, mineclonia_item)```:
  - returns item depends which game is playing.
- ```natural_habitat.take_item(player, itemstack)```:
  - similar to ```itemstack:take_item();``` but it take item only if player not in creative mode.
- ```natural_habitat.register_decoration(def)```:
  - same as ```core.register_decoration(def);``` but filtering unnecessary stuff in definition.
- ```natural_habitat.find_biomes_in_area(pos, biomes, radius, height)```: returns array of found biomes positions.

## Table
- ```table.len(tbl, start_count)```: returns table length;

## MultiPack
- ```natural_habitat.register_multinode(name, multidef)```:
  - register a multiple nodes with its definition.
  - definition table:
  ```
  natural_habitat.register_multinode("mod:node_name", {
      shared = {
          ..., -- standard shared node definition.
      },
      nodes = {
          [""] = {
              description = S("Node"),
              ..., -- standard node definition.
          },
          ["_with_something"] = {
              description = S("Node with something"),
              ..., -- standard node definition.
          },
      },
  });```

- ```natural_habitat.register_multideco(name, multidef)```:
  - register a multiple decoration with its definition.
  - definition table:
  ```
  {
      shared = {
      	... -- standard decoration definition.
      	decos = {
      		... -- standard decoration definition.
      	},
      	use_map_generator = true,
      	
      	biome_min_radius = 3,
      	-- If (nil) will be ignored.
      	biome_min_height = 1,
      	-- If (nil) will be the same as biome_min_radius.
      	
      	avoid_nodes = { "node:name", ... },
      	avoid_radius = 3,
      	
      	pursue_nodes = { "node:name", ... },
      	pursue_radius = 3,
      }, 
      minetest = {}, -- standard decoration definition.
      mineclonia = {}, -- standard decoration definition.
  }
  ```
- ```natural_habitat.deco_smart_place(pos, def)```:
  - smart placing decoration