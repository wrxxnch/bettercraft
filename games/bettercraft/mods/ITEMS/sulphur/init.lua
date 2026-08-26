-- SPDX-License-Identifier: MIT
local core = minetest
local S = core.get_translator("sulphur_update")

local modname = "sulphur_update"

-- Carrega o mapgen se existir
local mapgen_path = core.get_modpath(modname) .. "/mapgen.lua"
local f = io.open(mapgen_path, "r")
if f then
	f:close()
	dofile(mapgen_path)
end

-- Adjustable visual scales.
local SLIME_VISUAL_SIZE = { x = 9, y = 9 }
local SULFUR_BLOCK_VISUAL_SIZE = { x = 0.08, y = 0.08 }

local function tex(name)
	return name .. ".png"
end

local function register_full_block(name, description, texture, groups, sounds)
	core.register_node(modname .. ":" .. name, {
		description = S(description),
		tiles = { tex(texture) },
		is_ground_content = false,
		stack_max = 64,
		groups = groups or { pickaxey = 1, building_block = 1 },
		sounds = sounds or
			(mcl_sounds and mcl_sounds.node_sound_stone_defaults and mcl_sounds.node_sound_stone_defaults() or {}),
	})
end

local stone_groups = { pickaxey = 1, building_block = 1 }

-- Block registry
register_full_block("cinnabar", "Cinnabar", "cinnabar", { pickaxey = 1, building_block = 1, material_rock = 1 })
register_full_block("chiseled_cinnabar", "Chiseled Cinnabar", "chiseled_cinnabar", stone_groups)
register_full_block("polished_cinnabar", "Polished Cinnabar", "polished_cinnabar", stone_groups)
register_full_block("cinnabar_bricks", "Cinnabar Bricks", "cinnabar_bricks", stone_groups)
register_full_block("potent_sulfur", "Potent Sulfur", "potent_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur", "Sulfur", "sulfur", { pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("chiseled_sulfur", "Chiseled Sulfur", "chiseled_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("polished_sulfur", "Polished Sulfur", "polished_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur_bricks", "Sulfur Bricks", "sulfur_bricks",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })

-- Speleothem system (stalactites/stalagmites)
local sulfur_spike_directions = { [-1] = "down", [1] = "up" }
local sulfur_spike_stages = { "tip_merge", "tip", "frustum", "middle", "base" }

local function sulfur_spike_node(stage, direction)
	return modname .. ":sulfur_spike_" .. sulfur_spike_directions[direction] .. "_" .. sulfur_spike_stages[stage]
end

local function sulfur_spike_update(pos, direction)
	local stage
	local previous_stage
	while true do
		pos = vector.offset(pos, 0, direction, 0)
		previous_stage = stage
		stage = core.get_item_group(core.get_node(pos).name, "sulfur_spike_stage")
		if stage == 4 or stage == 5 then break
		elseif stage == 0 then
			if previous_stage == 3 then core.swap_node(vector.offset(pos, 0, -direction, 0), { name = sulfur_spike_node(5, direction) }) end
			break
		end
		core.swap_node(pos, { name = sulfur_spike_node(stage + 1, direction) })
	end
end

for i, stage in ipairs(sulfur_spike_stages) do
	core.register_node(sulfur_spike_node(i, 1), {
		description = S("Sulfur speleothem"),
		drawtype = "plantlike",
		tiles = { "sulfur_spike_up_" .. stage .. ".png" },
		paramtype = "light",
		use_texture_alpha = true,
		walkable = true,
		groups = { pickaxey = 1, attached_node = 1, sulfur_spike_stage = i, not_in_creative_inventory = 1 },
		drop = modname .. ":sulphur_stalactite",
	})
	core.register_node(sulfur_spike_node(i, -1), {
		description = S("Sulfur speleothem"),
		drawtype = "plantlike",
		tiles = { "sulfur_spike_down_" .. stage .. ".png" },
		paramtype = "light",
		use_texture_alpha = true,
		walkable = true,
		groups = { pickaxey = 1, attached_node = 1, sulfur_spike_stage = i, not_in_creative_inventory = 1 },
		drop = modname .. ":sulphur_stalactite",
	})
end

core.register_craftitem(modname .. ":sulphur_stalactite", {
	description = S("Sulfur speleothem"),
	inventory_image = tex("sulfur_spike_up_tip"),
	on_place = function(itemstack, player, pointed_thing)
		if not pointed_thing then return end
		local direction = pointed_thing.above.y - pointed_thing.under.y
		if direction == 0 then return end
		core.set_node(pointed_thing.above, { name = sulfur_spike_node(2, direction) })
		sulfur_spike_update(pointed_thing.above, direction)
		if not core.is_creative_enabled(player:get_player_name()) then itemstack:take_item() end
		return itemstack
	end,
})

-------------------------------------------------------
-- GEYSER LOGIC (EJECTION AND PARTICLES)
-------------------------------------------------------

local function get_water_column_height(pos)
	local height = 0
	for i = 1, 15 do
		local check_pos = {x = pos.x, y = pos.y + i, z = pos.z}
		local node = core.get_node(check_pos).name
		if core.get_item_group(node, "water") ~= 0 then
			height = i
		else
			break
		end
	end
	return height
end

-- 1. Passive bubble effect (indicates the geyser is ready)
core.register_abm({
	label = "Sulphur Passive Bubbles",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 2,
	chance = 1,
	action = function(pos)
		local above = core.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name
		if core.get_item_group(above, "water") ~= 0 then
			core.add_particlespawner({
				amount = 2,
				time = 1,
				minpos = vector.offset(pos, -0.2, 0.5, -0.2),
				maxpos = vector.offset(pos, 0.2, 1.0, 0.2),
				minvel = {x=-0.1, y=1, z=-0.1},
				maxvel = {x=0.1, y=2, z=0.1},
				minexptime = 1, maxexptime = 1.5,
				texture = "sulphur_smoke_particle.png",
				glow = 5
			})
		end
	end
})

-- 2. The geyser pulse (strong ejection and smoke)
core.register_abm({
	label = "Sulphur Geyser Pulse",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 10,
	chance = 1,
	action = function(pos)
		local node_below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
		if node_below ~= "mcl_nether:magma" then return end
		
		local water_h = get_water_column_height(pos)
		if water_h == 0 then return end

		-- Fast-rising smoke particles
		core.add_particlespawner({
			amount = 60,
			time = 2.0,
			minpos = {x = pos.x - 0.3, y = pos.y + 0.5, z = pos.z - 0.3},
			maxpos = {x = pos.x + 0.3, y = pos.y + 1.2, z = pos.z + 0.3},
			minvel = {x = -0.4, y = 18, z = -0.4},
			maxvel = {x = 0.4, y = 25, z = 0.4},
			minexptime = 0.8, maxexptime = 1.5,
			minsize = 6, maxsize = 12,
			texture = {
				name = "mcl_particles_smoke_anim.png",
				animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8 },
			},
			glow = 14
		})

		core.sound_play("fire_large", { pos = pos, gain = 0.6, max_hear_distance = 32 })

		-- PHYSICAL EJECTION
		local upward_force = 14 + (water_h * 1.5) 
		
		local objs = core.get_objects_in_area(
			{x = pos.x - 0.8, y = pos.y, z = pos.z - 0.8},
			{x = pos.x + 0.8, y = pos.y + water_h + 1, z = pos.z + 0.8}
		)

		for _, obj in ipairs(objs) do
			if obj:is_player() then
				obj:add_velocity({x = 0, y = upward_force, z = 0})
			else
				local v = obj:get_velocity()
				if v then
					obj:set_velocity({x = v.x, y = upward_force, z = v.z})
				end
			end
		end
	end
})

-- 3. Constant nausea effect for players in the geyser column

core.register_abm({
	label = "Sulphur Constant Nausea",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 1, -- Verifica a cada segundo
	chance = 1,
	action = function(pos)
		local water_h = get_water_column_height(pos)
		if water_h == 0 then return end

		-- Detecta jogadores na coluna de água
		local objs = core.get_objects_in_area(
			{x = pos.x - 0.7, y = pos.y + 0.5, z = pos.z - 0.7},
			{x = pos.x + 0.7, y = pos.y + water_h + 0.5, z = pos.z + 0.7}
		)

		for _, obj in ipairs(objs) do
			if obj:is_player() and mcl_potions and mcl_potions.give_effect then
				-- Aplica náusea por 2 segundos (se renova a cada segundo)
				mcl_potions.give_effect("nausea", obj, 1, 2, false)
			end
		end
	end
})


-------------------------------------------------------
-- SULFUR SLIME LOGIC
-------------------------------------------------------

local material_rules = {
	wood = { speed = 0.78, gravity = 0.92, jump = 1.0, label = "wood" },
	stone = { speed = 0.52, gravity = 1.55, jump = 0.72, label = "stone" },
	ice = { speed = 1.65, gravity = 0.88, jump = 1.10, label = "ice" },
	default = { speed = 1.0, gravity = 1.0, jump = 1.0, label = "sulfur" },
}

local function classify_material(name)
	if core.get_item_group(name, "wood") > 0 or core.get_item_group(name, "material_wood") > 0 then return material_rules.wood end
	if core.get_item_group(name, "ice") > 0 or core.get_item_group(name, "snowy") > 0 then return material_rules.ice end
	if core.get_item_group(name, "stone") > 0 or core.get_item_group(name, "rock") > 0 or core.get_item_group(name, "pickaxey") > 0 then return material_rules.stone end
	if name == modname .. ":sulphur_block" or core.get_item_group(name, "material_sulphur") > 0 then return material_rules.default end
	return nil
end

if mcl_mobs and mcl_mobs.register_mob then
	mcl_mobs.register_mob(modname .. ":sulfur_slime", {
		description = S("Sulfur slime"),
		type = "animal", 
		spawn_class = "passive",
		hp_min = 16, hp_max = 16, armor = 80,
		collisionbox = { -0.75, -0.01, -0.75, 0.75, 1.5, 0.75 },
		visual = "mesh", mesh = "mobs_mc_slime.b3d",
		visual_size = SLIME_VISUAL_SIZE,
		textures = { "sulfur_cube_entity.png^[opacity:237" },
		on_rightclick = function(self, clicker)
			local stack = clicker:get_wielded_item()
			local name = stack:get_name()
			if name == "mcl_buckets:bucket_empty" then
				clicker:set_wielded_item(ItemStack(modname .. ":bucket_of_sulfur_cube"))
				self.object:remove()
				return
			end
			local rule = classify_material(name)
			if rule then
				self.sulphur_rule = rule
				self.object:set_properties({ nametag = S("Sulfur cube: @1", rule.label) })
				stack:take_item()
				clicker:set_wielded_item(stack)
			end
		end,
	})
	mcl_mobs.register_egg(modname .. ":sulfur_slime", S("Sulfur slime"), "#f4d35e", "#7a6a2f", true)
end

core.register_craftitem(modname .. ":bucket_of_sulfur_cube", {
	description = S("Bucket with sulfur cube"),
	inventory_image = tex("bucket_of_sulfur_cube"),
	stack_max = 1,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type == "node" then
			core.add_entity(pointed_thing.above, modname .. ":sulfur_slime")
			return ItemStack("mcl_buckets:bucket_empty")
		end
	end,
})

-- Crafting
core.register_craft({ output = modname .. ":potent_sulfur", recipe = { { modname .. ":sulfur", modname .. ":sulfur" }, { modname .. ":sulfur", modname .. ":sulfur" } } })