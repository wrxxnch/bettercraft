-- BIOME NAME
core.register_chatcommand("biome", {
    description = "Echoes the biome name you stand in.",
    privs = { shout = false, },
    func = function(name, param)
        local player = core.get_player_by_name(name);
        local biome_data = core.get_biome_data(player:get_pos());
        core.chat_send_player( name, 
            "You stand in: '"..core.get_biome_name(biome_data.biome).."' biome!"
        );
    end,
})

