-- SOUND STONE
function natural_habitat.sound_stone()
    if natural_habitat.is_minetest and core.get_modpath("default") then
        return default.node_sound_stone_defaults();
    elseif natural_habitat.is_mineclonia and core.get_modpath("mcl_sounds") then
        return mcl_sounds.node_sound_stone_defaults();
    end;
end;

-- SOUND WOOD
function natural_habitat.sound_wood()
    if natural_habitat.is_minetest and core.get_modpath("default") then
        return default.node_sound_wood_defaults();
    elseif natural_habitat.is_mineclonia and core.get_modpath("mcl_sounds") then
        return mcl_sounds.node_sound_wood_defaults();
    end;
end;

-- SOUND LEAVES
function natural_habitat.sound_leaves()
    if natural_habitat.is_minetest and core.get_modpath("default") then
        return default.node_sound_leaves_defaults();
    elseif natural_habitat.is_mineclonia and core.get_modpath("mcl_sounds") then
        return mcl_sounds.node_sound_leaves_defaults();
    end;
end;

-- SOUND WOOL
function natural_habitat.sound_wool()
    if natural_habitat.is_minetest and core.get_modpath("default") then
        return default.node_sound_defaults();
    elseif natural_habitat.is_mineclonia and core.get_modpath("mcl_sounds") then
        return mcl_sounds.node_sound_wool_defaults();
    end;
end;
