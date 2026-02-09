local S = core.get_translator("mcl_pale_oak")

core.register_craftitem("mcl_pale_oak:resin_clump", {
	description = S("Resin clump"),
	inventory_image = "mcl_pale_oak_resin_clump.png",
	groups = { craftitem = 1 },
	_mcl_crafting_output = {
		square3 = {output = "mcl_pale_oak:block_of_resin"}
	},
	_mcl_cooking_output = "mcl_pale_oak:resin_brick"
})

core.register_craftitem("mcl_pale_oak:resin_brick", {
	description = S("Resin brick"),
	inventory_image = "mcl_pale_oak_resin_brick.png",
	groups = { craftitem = 1 },
	_mcl_crafting_output = {
		square2 = {output = "mcl_pale_oak:resin_brick_block"}
	},
	_mcl_armor_trim_color = "#ff5315",
	_mcl_armor_trim_desc = "Resin Material"
})

core.register_node("mcl_pale_oak:block_of_resin", {
	description = S("Block of resin"),
	tiles = {"mcl_pale_oak_resin_block.png"},
	_mcl_hardness = 0,
	groups = { dig_immediate = 3 },
	_mcl_crafting_output = {
		single = {output = "mcl_pale_oak:resin_clump 9"}
	}
})

core.register_node("mcl_pale_oak:resin_brick_block", {
	description = S("Resin Bricks"),
	tiles = {"mcl_pale_oak_resin_brick_block.png"},
	_mcl_hardness = 1.5,
	_mcl_blast_resistance = 6,
	groups = { pickaxey = 1, material_stone = 1 },
})

core.register_node("mcl_pale_oak:chiseled_resin_brick", {
	description = S("Chiseled Resin Brick"),
	tiles = {"mcl_pale_oak_chiseled_resin_bricks.png"},
	_mcl_hardness = 1.5,
	_mcl_blast_resistance = 6,
	groups = { pickaxey = 1 },
})

mcl_stairs.register_stair_and_slab("resin_brick", {
    baseitem = "mcl_pale_oak:resin_brick_block",
    description_stair = "Resin Brick Stairs",
    description_slab = "Resin Brick Slab",
	groups = { pickaxey=1 },
	overrides = {
		_mcl_stonecutter_recipes = {"mcl_pale_oak:resin_brick_block"},
	}
})

mcl_walls.register_wall("mcl_pale_oak:resin_brick_wall", "Resin Brick Wall", "mcl_pale_oak:resin_brick", {"mcl_pale_oak_resin_brick_block.png"})

-- ABM: Seiva aparece nas árvores Pale Oak ao longo do tempo
minetest.register_abm({
	label = "Resin Growth on Creaking Heart",
	nodenames = {"mcl_pale_oak:creaking_heart"},
	interval = 300,
	chance = 50,
	action = function(pos)
		local dirs = {
			{x=1,y=0,z=0},{x=-1,y=0,z=0},
			{x=0,y=0,z=1},{x=0,y=0,z=-1},
		}

		for _, d in ipairs(dirs) do
			local p = vector.add(pos, d)
			if minetest.get_node(p).name == "air" then
				minetest.set_node(p, {
					name = "mcl_pale_oak:resin_clump_node",
					param2 = minetest.dir_to_wallmounted(d)
				})
				break
			end
		end
	end,
})


-- Registra seiva como nó (grudada na árvore)
-- Nó de seiva grudado na árvore (tipo vinha, mas sem escalar)
-- Nó de seiva grudado na árvore (plano tipo vinha, mas sem escalar)
minetest.register_node("mcl_pale_oak:resin_clump_node", {
    description = "Seiva",
    drawtype = "signlike", -- 🔥 plano, colado na superfície
    tiles = {"default_resin_clump_node.png"},
    inventory_image = "default_resin_clump_node.png",
    wield_image = "default_resin_clump_node.png",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    climbable = false, -- não é escalável como vinha
    use_texture_alpha = "clip", -- recorte limpo da textura
    orientation = "wall", -- garante orientação colada

    groups = {
        handy = 1,
        attached_node = 1, -- cai se o suporte for removido
        dig_immediate = 3,
        deco_block = 1,
    },

    drop = "mcl_pale_oak:resin_clump",
    sounds = mcl_sounds.node_sound_leaves_defaults(),
    _mcl_item_group = "materials",

    selection_box = {
        type = "fixed",
        fixed = {-0.5, -0.5, -0.05, 0.5, 0.5, 0.05}, -- seleção vertical fina
    },

    -- Garante que a seiva "grude" na parede corretamente
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        local under = pointed_thing.under
        local dir = vector.subtract(under, pos)
        local wall = minetest.dir_to_wallmounted(dir)
        local node = minetest.get_node(pos)
        node.param2 = wall
        minetest.swap_node(pos, node)
    end,

    -- Mantém apenas a lógica de cair se o suporte for destruído
    on_destruct = function(pos)
        -- nada extra, não remove outros nós adjacentes
    end,
})