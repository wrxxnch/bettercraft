-- SPDX-License-Identifier: MIT
local core = minetest
local S = core.get_translator("sulphur_update")

local modname = "sulphur_update"

-- Carrega a geração de mapa (certifique-se de que o arquivo mapgen.lua existe)
dofile(core.get_modpath(modname) .. "/mapgen.lua")

-- Escalas visuais configuráveis.
local SLIME_VISUAL_SIZE = { x = 9, y = 9 }
local SULFUR_BLOCK_VISUAL_SIZE = { x = 0.08, y = 0.08 }

local function tex(name)
	return name .. ".png"
end

-- Aliases para compatibilidade com Wiki
core.register_alias(modname .. ":cinnabar_block_wiki", modname .. ":cinnabar")
core.register_alias(modname .. ":sulfur_block_wiki", modname .. ":sulfur")
core.register_alias(modname .. ":sulphur_block_wiki", modname .. ":sulphur")

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

-- Registro de blocos
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

-------------------------------------------------------
-- SISTEMA DE ESPELEOTEMAS (A LÓGICA SOLICITADA)
-------------------------------------------------------

local sulfur_spike_directions = { [-1] = "down", [1] = "up" }
local sulfur_spike_stages = { "tip_merge", "tip", "frustum", "middle", "base" }

local function sulfur_spike_node(stage, direction)
	return modname .. ":sulfur_spike_" .. sulfur_spike_directions[direction] .. "_" .. sulfur_spike_stages[stage]
end

local function sulfur_spike_direction(name)
	return string.find(name, ":sulfur_spike_down_", 1, true) and -1 or 1
end

local function sulfur_spike_length(pos, direction)
	local offset_pos = vector.copy(pos)
	local length = 0
	repeat
		length = length + 1
		offset_pos = vector.offset(offset_pos, 0, direction, 0)
	until core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage") == 0
	return length
end

local function sulfur_spike_break_column(pos, direction)
	local offset_pos = vector.copy(pos)
	while true do
		offset_pos = vector.offset(offset_pos, 0, -direction, 0)
		local node = core.get_node(offset_pos)
		local stage = core.get_item_group(node.name, "sulfur_spike_stage")
		if stage == 1 and sulfur_spike_direction(node.name) == -direction then
			core.swap_node(offset_pos, { name = sulfur_spike_node(2, -direction) })
			break
		elseif stage == 0 then
			break
		else
			core.add_item(offset_pos, ItemStack(modname .. ":sulphur_stalactite"))
			core.swap_node(offset_pos, { name = "air" })
		end
	end
end

local function sulfur_spike_update(pos, direction)
	local other_pos = vector.offset(pos, 0, direction, 0)
	local other_name = core.get_node(other_pos).name
	if core.get_item_group(other_name, "sulfur_spike_stage") ~= 0 then
		core.swap_node(pos, { name = sulfur_spike_node(1, direction) })
		core.swap_node(other_pos, { name = sulfur_spike_node(1, -direction) })
	end

	local stage
	local previous_stage
	while true do
		pos = vector.offset(pos, 0, direction, 0)
		previous_stage = stage
		stage = core.get_item_group(core.get_node(pos).name, "sulfur_spike_stage")
		if stage == 4 or stage == 5 then
			break
		elseif stage == 0 then
			if previous_stage == 3 then
				core.swap_node(vector.offset(pos, 0, -direction, 0), { name = sulfur_spike_node(5, direction) })
			end
			break
		end
		core.swap_node(pos, { name = sulfur_spike_node(stage + 1, direction) })
	end
end

local function place_sulfur_spike(itemstack, player, pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
	local under_node = core.get_node(pointed_thing.under)
	if core.get_item_group(under_node.name, "solid") == 0
		and core.get_item_group(under_node.name, "sulfur_spike_stage") == 0 then
		return itemstack
	end
	if pointed_thing.above.x ~= pointed_thing.under.x or pointed_thing.above.z ~= pointed_thing.under.z then
		return itemstack
	end
	
	local direction = pointed_thing.above.y - pointed_thing.under.y
	if direction == 0 then return itemstack end
	
	if not core.is_creative_enabled(player:get_player_name()) then itemstack:take_item() end
	core.set_node(pointed_thing.above, { name = sulfur_spike_node(2, direction) })
	sulfur_spike_update(pointed_thing.above, direction)
	return itemstack
end

local function sulfur_spike_destruct(pos)
	local direction = sulfur_spike_direction(core.get_node(pos).name)
	sulfur_spike_break_column(pos, direction)

	local offset_pos = vector.offset(pos, 0, direction, 0)
	if core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage") ~= 0 then
		core.swap_node(offset_pos, { name = sulfur_spike_node(2, direction) })
		while true do
			offset_pos = vector.offset(offset_pos, 0, direction, 0)
			local stage = core.get_item_group(core.get_node(offset_pos).name, "sulfur_spike_stage")
			if stage == 3 then
				core.swap_node(offset_pos, { name = sulfur_spike_node(2, direction) })
			elseif stage == 4 or stage == 5 then
				core.swap_node(offset_pos, { name = sulfur_spike_node(3, direction) })
				break
			else
				break
			end
		end
	end
end

for i, stage in ipairs(sulfur_spike_stages) do
	local add = (i - 1) / 16
	local box = { type = "fixed", fixed = {
		math.max(-0.5, -3 / 16 - add), -0.5,
		math.max(-0.5, -3 / 16 - add),
		math.min(0.5, 3 / 16 + add), 0.5,
		math.min(0.5, 3 / 16 + add)
	} }
	for direction, label in pairs(sulfur_spike_directions) do
		core.register_node(sulfur_spike_node(i, direction), {
			description = S("Sulfur speleothem (@1/@2)", i, #sulfur_spike_stages),
			_doc_items_hidden = true,
			drawtype = "plantlike",
			tiles = { "sulfur_spike_" .. label .. "_" .. stage .. ".png" },
			paramtype = "light",
			use_texture_alpha = true,
			sunlight_propagates = true,
			is_ground_content = false,
			walkable = true,
			climbable = false,
			selection_box = box,
			collision_box = box,
			groups = {
				pickaxey = 1, attached_node = 1, material_sulphur = 1,
				not_in_creative_inventory = 1, sulfur_spike_stage = i, pathfinder_partial = 2,
			},
			drop = modname .. ":sulphur_stalactite",
			on_destruct = sulfur_spike_destruct,
			sounds = mcl_sounds and mcl_sounds.node_sound_stone_defaults and mcl_sounds.node_sound_stone_defaults() or {},
		})
	end
end

core.register_craftitem(modname .. ":sulphur_stalactite", {
	description = S("Sulfur speleothem"),
	inventory_image = tex("sulfur_spike_up_tip"),
	on_place = place_sulfur_spike,
})

-------------------------------------------------------
-- LÓGICA DO GEYSER E TOXICIDADE
-------------------------------------------------------

-- ABM: Fumaça amarela passiva (Água em cima, SEM magma embaixo)
core.register_abm({
	label = "Sulphur Passive Bubbles",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 3, chance = 2,
	action = function(pos)
		local above = core.get_node(vector.offset(pos, 0, 1, 0)).name
		local below = core.get_node(vector.offset(pos, 0, -1, 0)).name
		if core.get_item_group(above, "water") ~= 0 and below ~= "mcl_nether:magma" then
			core.add_particlespawner({
				amount = 5, time = 1,
				minpos = vector.offset(pos, -0.2, 0.5, -0.2), maxpos = vector.offset(pos, 0.2, 0.8, 0.2),
				minvel = {x = -0.1, y = 1, z = -0.1}, maxvel = {x = 0.1, y = 2, z = 0.1},
				minexptime = 1, maxexptime = 2, minsize = 1, maxsize = 3,
				texture = "sulphur_smoke_particle.png", glow = 5
			})
		end
	end
})

-- ABM: Pulso do Geyser (Ejeção Forte e Fumaça Animada)
core.register_abm({
	label = "Sulphur Geyser Pulse",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 12, chance = 1,
	action = function(pos)
		local node_below = core.get_node({x = pos.x, y = pos.y - 1, z = pos.z}).name
		if node_below ~= "mcl_nether:magma" then return end
		
		local height = 0
		for h = 1, 15 do
			if core.get_item_group(core.get_node({x=pos.x, y=pos.y+h, z=pos.z}).name, "water") ~= 0 then
				height = h
			else break end
		end
		if height == 0 then return end

		core.add_particlespawner({
			amount = 50, time = 2.0,
			minpos = {x = pos.x - 0.3, y = pos.y + 0.5, z = pos.z - 0.3},
			maxpos = {x = pos.x + 0.3, y = pos.y + 1.2, z = pos.z + 0.3},
			minvel = {x = -0.3, y = 15, z = -0.3}, maxvel = {x = 0.3, y = 22, z = 0.3},
			texture = { name = "mcl_particles_smoke_anim.png", animation = { type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 0.8 } },
			glow = 14
		})

		local force = 12 + (height * 2) 
		local objs = core.get_objects_in_area({x=pos.x-0.7, y=pos.y, z=pos.z-0.7}, {x=pos.x+0.7, y=pos.y+height+1, z=pos.z+0.7})
		for _, obj in ipairs(objs) do
			if obj:is_player() then obj:add_velocity({x=0, y=force, z=0})
			elseif obj:get_velocity() then obj:set_velocity({x=0, y=force, z=0}) end
		end
	end
})

-- ABM: Náusea Dinâmica
core.register_abm({
	label = "Sulphur Toxicity Check",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 1, chance = 1,
	action = function(pos)
		local objs = core.get_objects_inside_radius(pos, 2.5)
		for _, obj in ipairs(objs) do
			if obj:is_player() and mcl_potions then
				mcl_potions.give_effect("nausea", obj, 1, 2, false)
			end
		end
	end
})

-------------------------------------------------------
-- LÓGICA DO SULFUR SLIME
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

core.register_craft({ output = modname .. ":potent_sulfur", recipe = { { modname .. ":sulfur", modname .. ":sulfur" }, { modname .. ":sulfur", modname .. ":sulfur" } } })