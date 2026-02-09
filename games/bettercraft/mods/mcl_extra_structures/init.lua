--||||||||||||||||||||||||||||||
--|||| mcl_extra_structures ||||
--||||||||||||||||||||||||||||||

local mod = minetest.get_modpath("mcl_extra_structures")

if not core.global_exists ("mcl_levelgen")
	or (not mcl_levelgen.levelgen_enabled
	    and not mcl_levelgen.enable_ersatz) then
	-- Load Structure Files
	dofile(mod .. "/desert_oasis.lua") -- Load Desert Oasis
	dofile(mod .. "/birch_forest_ruins.lua") -- Load Birch Forest Ruins
	dofile(mod .. "/brick_pyramid.lua") -- Load Brick Pyramid
	dofile(mod .. "/graveyard.lua") -- Load Graveyards
	dofile(mod .. "/loggers_camp.lua") -- Load Loggers Camp
	dofile(mod .. "/sandstone_obelisk.lua") -- Load Sandstone Obelisks
	dofile(mod .. "/ice_tower.lua") -- Load Ice Tower
else
	-- Load map generator script.
	mcl_levelgen.register_levelgen_script (mod .. "/lg_register.lua", true)
	dofile (mod .. "/lg_register.lua")
end
