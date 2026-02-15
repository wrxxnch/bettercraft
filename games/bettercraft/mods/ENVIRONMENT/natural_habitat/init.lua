local S = core.get_translator(core.get_current_modname());
local modpath = core.get_modpath(core.get_current_modname());

natural_habitat = {};

-- IMPORTS
dofile(modpath.."/utils/api.lua");

dofile(modpath.."/biomes/list.lua");
dofile(modpath.."/items/list.lua");
dofile(modpath.."/decorations/list.lua");