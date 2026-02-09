mcl_bows = {}

--Bow
dofile(core.get_modpath("mcl_bows") .. "/arrow.lua")
dofile(core.get_modpath("mcl_bows") .. "/bow.lua")

--Crossbow
dofile(core.get_modpath("mcl_bows") .. "/crossbow.lua")

--Compatiblility with older MineClone worlds
core.register_alias("mcl_throwing:bow", "mcl_bows:bow")
core.register_alias("mcl_throwing:arrow", "mcl_bows:arrow")
