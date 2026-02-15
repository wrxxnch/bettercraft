local mod_path = core.get_modpath(core.get_current_modname());
local biomes, decos = {}, {};

for key, def in pairs(core.registered_biomes) do biomes[key] = def; end
core.clear_registered_biomes();
for key, def in pairs(biomes) do core.register_biome(def); end

for key, def in pairs(core.registered_decorations) do decos[key] = def; end
core.clear_registered_decorations();
for key, def in pairs(decos) do core.register_decoration(def); end

dofile(mod_path.."/biomes/data/mellow_meadow.lua");
dofile(mod_path.."/biomes/data/dead_forest.lua");