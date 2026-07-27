local S = core.get_translator(core.get_current_modname());

natural_habitat.register_multinode("natural_habitat:stick", {
    shared = {
        description = S("Stick"),
        drawtype = "mesh",
        tiles = { "default_tree.png", "default_tree_top.png" },
        paramtype = "light",
        paramtype2 = "facedir",
        walkable = false,
        groups = {
            dig_immediate=3, stick=1, falling_node=1, not_in_creative_inventory=1,
            deco_block=1, dig_by_water=1, attached_node=1,
        },
        on_place = natural_habitat.place_item,
        sounds = natural_habitat.sound_wood(),
    },
    nodes = {
        [""] = {
            mesh = "nbt_stick.obj",
            drop = natural_habitat.stick,
            node_box = { type="fixed", fixed={{-0.4, -0.5, -0.2, 0.4, -0.3, 0.2}} },
            selection_box = { type="fixed", fixed={{-0.4, -0.5, -0.2, 0.4, -0.3, 0.2}} },
        },
        ["_2"] = {
            mesh = "nbt_stick_2.obj";
            drop = natural_habitat.stick.." 2";
            node_box = { type="fixed", fixed={{-0.4, -0.5, -0.4, 0.4, -0.2, 0.4}} };
            selection_box = { type="fixed", fixed={{-0.4, -0.5, -0.4, 0.4, -0.2, 0.4}} };
        },
        ["_3"] = {
            mesh = "nbt_stick_3.obj";
            drop = natural_habitat.stick.." 3";
            node_box = { type="fixed", fixed={{-0.4, -0.5, -0.4, 0.4, -0.2, 0.4}} };
            selection_box = { type="fixed", fixed={{-0.4, -0.5, -0.4, 0.4, -0.2, 0.4}} };
        },
    },
});

natural_habitat.register_multideco("natural_habitat:deco_stick", {
    shared = {
        deco_type = "simple",
        fill_ratio = 0.005,
        spawn_by = "air",
        num_spawn_by = 1,
        rotation = "random",
        decos = {
            { decoration="natural_habitat:stick", },
            { decoration="natural_habitat:stick_2", },
            { decoration="natural_habitat:stick_3", },
        },
        use_map_generator = true,
    },
    minetest = {
        place_on = {
            "default:dirt_with_grass", "default:dry_dirt_with_dry_grass", 
            "default:permafrost", "default:dirt_with_snow",
            "default:dirt_with_coniferous_litter",
            "default:dirt_with_rainforest_litter", 
        },
        biomes = {
            "grassland", "deciduous_forest", "tundra", "taiga",
            "snowy_grassland", "coniferous_forest", "rainforest",
        },
    },
    mineclonia = {
        place_on = {
            "mcl_core:dirt_with_grass", "mcl_core:mycelium",
            "mcl_core:podzol", "mcl_core:coarse_dirt",
        },
        biomes = {
            "Forest", "FlowerForest", "Plains", "BirchForest", "Meadow",
            "Taiga", "MegaTaiga", "MegaSpruceTaiga", "SunflowerPlains",
            "BirchForest", "BirchForestM", "RoofedForest", "Jungle",
            "JungleM", "JungleEdge", "BambooJungle", "Savanna", 
            "PaleGarden"
        },
    },
});


-- OVERRIDE STICK ITEM
core.override_item(natural_habitat.stick, {
    on_place = function(itemstack, placer, pointed_thing)
        -- Proteção básica
        if not pointed_thing or pointed_thing.type ~= "node" then
            return itemstack
        end

        local pos = pointed_thing.under
        local node = core.get_node(pos)
        local node_def = core.registered_nodes[node.name]

        -- Se o jogador NÃO estiver agachado (sneak), tentamos interagir com o bloco (ex: Sweet Berries)
        if placer and not placer:get_player_control().sneak then
            -- Se o bloco sob o graveto tiver uma função de clique (como colher frutas)
            if node_def and node_def.on_rightclick then
                -- Chamamos diretamente passando TODOS os parâmetros que o MineClone exige
                return node_def.on_rightclick(pos, node, placer, itemstack, pointed_thing) or itemstack
            end
            
            -- Fallback para a API do mod, mas agora passando o pointed_thing
            local rc = natural_habitat.check_on_rightclick(pos, itemstack, placer, pointed_thing)
            if rc then return rc end
        end

        -- Lógica de empilhamento de gravetos (stick, stick_2, stick_3)
        if node.name == "natural_habitat:stick" then
            core.set_node(pos, { name="natural_habitat:stick_2", param2=node.param2 })
            natural_habitat.take_item(placer, itemstack)
            return itemstack
        elseif node.name == "natural_habitat:stick_2" then
            core.set_node(pos, { name="natural_habitat:stick_3", param2=node.param2 })
            natural_habitat.take_item(placer, itemstack)
            return itemstack
        end
        
        -- Se não for graveto e não for interação, tenta colocar um graveto novo
        -- (usando pointed_thing.above para não substituir o bloco de baixo)
        if not string.find(node.name, "natural_habitat:stick") then
            return natural_habitat.place_item(
                itemstack, placer, pointed_thing, 
                "natural_habitat:stick"
            )
        end
        
        return itemstack
    end,
})