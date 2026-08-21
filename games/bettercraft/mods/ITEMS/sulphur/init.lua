-- SPDX-License-Identifier: MIT
local core = minetest
local S = core.get_translator("sulphur_update")

local modname = "sulphur_update"

-- Escalas visuais configuráveis.
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

-- Official Sulfur/Cinnabar family names from the Minecraft Wiki.
register_full_block("cinnabar", "Cinábrio", "cinnabar", { pickaxey = 1, building_block = 1, material_rock = 1 })
register_full_block("chiseled_cinnabar", "Cinábrio talhado", "chiseled_cinnabar", stone_groups)
register_full_block("polished_cinnabar", "Cinábrio polido", "polished_cinnabar", stone_groups)
register_full_block("cinnabar_bricks", "Tijolos de cinábrio", "cinnabar_bricks", stone_groups)
register_full_block("potent_sulfur", "Enxofre potente", "potent_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur", "Enxofre", "sulfur", { pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("chiseled_sulfur", "Enxofre talhado", "chiseled_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("polished_sulfur", "Enxofre polido", "polished_sulfur",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })
register_full_block("sulfur_bricks", "Tijolos de enxofre", "sulfur_bricks",
	{ pickaxey = 1, building_block = 1, material_sulphur = 1 })

local spike_groups = { pickaxey = 1, attached_node = 1, material_sulphur = 1 }
local spike_box = { type = "fixed", fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 } }

local function register_spike_texture(name, description, texture)
	core.register_node(modname .. ":" .. name, {
		description = S(description),
		drawtype = "plantlike",
		tiles = { tex(texture) },
		paramtype = "light",
		use_texture_alpha = true,
		sunlight_propagates = true,
		walkable = false,
		selection_box = spike_box,
		collision_box = spike_box,
		groups = spike_groups,
		drop = modname .. ":sulphur_stalactite",
	})
end

core.register_alias(modname .. ":cinnabar_block_wiki", modname .. ":cinnabar")
core.register_alias(modname .. ":sulfur_block_wiki", modname .. ":sulfur")
core.register_alias(modname .. ":sulphur_block_wiki", modname .. ":sulphur")

-- Espeleotemas: cinco estágios, duas direções e os mesmos nomes usados pelo dripstone.
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
	local other_pos = vector.offset(pos, 0, -direction, 0)
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
	-- CORREÇÃO: o sinal estava invertido. "above" é onde o novo nó vai ser colocado;
	-- se "above" fica ACIMA de "under" (chão), o espeleotema deve crescer para CIMA (stalagmite = "up").
	-- se "above" fica ABAIXO de "under" (teto), o espeleotema deve crescer para BAIXO (stalactite = "down").
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
			description = S("Espeleotema de enxofre (@1/@2)", i, #sulfur_spike_stages),
			_doc_items_hidden = true,
			drawtype = "plantlike",
			tiles = { "sulfur_spike_" .. label .. "_" .. stage .. ".png" },
			paramtype = "light",
			use_texture_alpha = true,
			sunlight_propagates = true,
			is_ground_content = false,
			walkable = false,
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
	description = S("Espeleotema de enxofre"),
	inventory_image = tex("sulfur_spike_up_tip"),
	on_place = place_sulfur_spike,
	on_secondary_use = place_sulfur_spike,
})

core.register_lbm({
	label = "Preservar espeleotemas de enxofre",
	name = modname .. ":keep_sulfur_spikes",
	nodenames = {
		modname .. ":sulfur_spike_up_tip_merge", modname .. ":sulfur_spike_up_tip",
		modname .. ":sulfur_spike_up_frustum", modname .. ":sulfur_spike_up_middle", modname .. ":sulfur_spike_up_base",
		modname .. ":sulfur_spike_down_tip_merge", modname .. ":sulfur_spike_down_tip",
		modname .. ":sulfur_spike_down_frustum", modname .. ":sulfur_spike_down_middle", modname .. ":sulfur_spike_down_base",
	},
	run_at_every_load = true,
	action = function(pos) end,
	})

-- Crescimento simples baseado no ABM do mcl_dripstone. Os nós permanecem no mapa
-- porque são nós normais, e não entidades temporárias.
core.register_abm({
	label = "Crescimento dos espeleotemas de enxofre",
	nodenames = { modname .. ":sulfur_spike_up_tip" },
	interval = 69,
	chance = 88,
	action = function(pos)
		local stalactite_length = sulfur_spike_length(pos, 1)
		local water_pos = vector.offset(pos, 0, stalactite_length + 1, 0)
		if core.get_item_group(core.get_node(water_pos).name, "water") == 0 then return end
		if core.get_node(vector.offset(pos, 0, stalactite_length, 0)).name ~= modname .. ":sulfur" then return end

		if math.random(2) == 1 then
			for i = 1, 10 do
				local candidate = vector.offset(pos, 0, -i, 0)
				local node = core.get_node(candidate)
				local groups = core.registered_nodes[node.name] and core.registered_nodes[node.name].groups or {}
				if (groups.solid or 0) > 0 or (groups.sulfur_spike_stage or 0) > 0 then
					if i <= 7 then
						core.set_node(vector.offset(pos, 0, -i + 1, 0), { name = sulfur_spike_node(2, -1) })
						sulfur_spike_update(vector.offset(pos, 0, -i + 1, 0), -1)
					end
					return
				elseif node.name ~= "air" then
					return
				end
			end
		else
			if stalactite_length > 7 then return end
			local target = vector.offset(pos, 0, -1, 0)
			if core.get_node(target).name == "air" then
				core.set_node(target, { name = sulfur_spike_node(2, 1) })
				sulfur_spike_update(target, 1)
			end
		end
	end,
})

core.register_craftitem(modname .. ":bucket_of_sulfur_cube", {
	description = S("Balde com cubo de enxofre"),
	inventory_image = tex("bucket_of_sulfur_cube"),
	stack_max = 1,
	on_place = function(itemstack, placer, pointed_thing)
		if not pointed_thing or pointed_thing.type ~= "node" then return itemstack end
		local pos = pointed_thing.above
		local obj = core.add_entity(pos, modname .. ":sulfur_slime")
		if obj then
			if not core.is_creative_enabled(placer:get_player_name()) then
				itemstack:replace(ItemStack("mcl_buckets:bucket_empty"))
			end
			return itemstack
		end
		return itemstack
	end,
})

if mcl_jukebox and mcl_jukebox.register_record then
	mcl_jukebox.register_record({
		title = "Bounce",
		author = "fingerspit",
		id = "bounce",
		texture = tex(
			"music_disc_bounce"),
		sound = "mcl_jukebox_track_7",
		exclude_from_creeperdrop = true,
		comparator_signal = 8
	})
	core.register_alias(modname .. ":music_disc_bounce", "mcl_jukebox:record_bounce")
else
	core.register_craftitem(modname .. ":music_disc_bounce",
		{ description = S("Disco musical — Bounce"), inventory_image = tex("music_disc_bounce"), stack_max = 1, groups = { music_record = 1 } })
end


core.register_node(modname .. ":sulphur_smoke", {
	description = S("Fumaça de enxofre na água"),
	drawtype = "plantlike",
	tiles = { tex("sulphur_smoke") },
	paramtype = "light",
	walkable = false,
	pointable = true,
	use_texture_alpha = true,
	sunlight_propagates = true,
	groups = { not_in_creative_inventory = 1, attached_node = 1 },
	drop = "",
})

local function craft(output, recipe)
	core.register_craft({ output = modname .. ":" .. output, recipe = recipe })
end
craft("sulphur",
	{ { modname .. ":sulphur_stalactite", modname .. ":sulphur_stalactite" }, { modname .. ":sulphur_stalactite", modname .. ":sulphur_stalactite" } })
craft("cinnabar",
	{ { modname .. ":cinnabar", modname .. ":cinnabar", modname .. ":cinnabar" }, { modname .. ":cinnabar", modname .. ":cinnabar", modname .. ":cinnabar" }, { modname .. ":cinnabar", modname .. ":cinnabar", modname .. ":cinnabar" } })
craft("sulphur_bricks",
	{ { modname .. ":sulphur", modname .. ":sulphur" }, { modname .. ":sulphur", modname .. ":sulphur" } })
craft("cinnabar_bricks",
	{ { modname .. ":cinnabar", modname .. ":cinnabar" }, { modname .. ":cinnabar", modname .. ":cinnabar" } })
core.register_craft({ output = modname .. ":sulphur_stalactite 4", recipe = { { modname .. ":sulphur" }, { modname .. ":sulphur" } } })
core.register_craft({ output = modname .. ":polished_cinnabar 4", recipe = { { modname .. ":cinnabar" }, { modname .. ":cinnabar" } } })
core.register_craft({ output = modname .. ":polished_sulfur 4", recipe = { { modname .. ":sulfur" }, { modname .. ":sulfur" } } })
core.register_craft({ output = modname .. ":potent_sulfur", recipe = { { modname .. ":sulfur", modname .. ":sulfur" }, { modname .. ":sulfur", modname .. ":sulfur" } } })
core.register_craft({ output = modname .. ":chiseled_cinnabar", recipe = { { modname .. ":cinnabar" }, { modname .. ":cinnabar" } } })
core.register_craft({ output = modname .. ":chiseled_sulfur", recipe = { { modname .. ":sulfur" }, { modname .. ":sulfur" } } })
core.register_craft({ output = modname .. ":cinnabar_bricks 4", recipe = { { modname .. ":cinnabar", modname .. ":cinnabar" }, { modname .. ":cinnabar", modname .. ":cinnabar" } } })
core.register_craft({ output = modname .. ":sulfur_bricks 4", recipe = { { modname .. ":sulfur", modname .. ":sulfur" }, { modname .. ":sulfur", modname .. ":sulfur" } } })
core.register_craft({ output = modname .. ":bucket_of_sulfur_cube", recipe = { { "mcl_buckets:bucket_empty", modname .. ":sulfur" } } })
core.register_craft({ output = modname .. ":sulphur_smoke 2", recipe = { { modname .. ":sulphur_dust" }, { "mcl_core:water_source" } } })


local function item_is_block(name)
	return name and name ~= "" and core.registered_nodes[name] and core.registered_nodes[name].walkable
end

local material_rules = {
	wood = { speed = 0.78, gravity = 0.92, jump = 1.0, label = "madeira" },
	stone = { speed = 0.52, gravity = 1.55, jump = 0.72, label = "rocha" },
	ice = { speed = 1.65, gravity = 0.88, jump = 1.10, label = "gelo" },
	default = { speed = 1.0, gravity = 1.0, jump = 1.0, label = "enxofre" },
}

local function classify_material(name)
	if core.get_item_group(name, "wood") > 0 or core.get_item_group(name, "material_wood") > 0 then
		return material_rules
			.wood
	end
	if core.get_item_group(name, "ice") > 0 or core.get_item_group(name, "snowy") > 0 then return material_rules.ice end
	if core.get_item_group(name, "stone") > 0 or core.get_item_group(name, "rock") > 0 or core.get_item_group(name, "pickaxey") > 0 then
		return
			material_rules.stone
	end
	if name == modname .. ":sulphur_block" or core.get_item_group(name, "material_sulphur") > 0 then
		return
			material_rules.default
	end
	return nil
end

local function give_nausea(obj, duration)
	if mcl_potions and mcl_potions.give_effect then
		mcl_potions.give_effect("nausea", obj, 1, duration, false)
	end
end


-- Environmental effects.
core.register_abm({
	label = "Sulphur geyser pulse",
	nodenames = { modname .. ":potent_sulfur" },
	interval = 3,
	chance = 2,
	action = function(pos)
		core.add_particlespawner({
			amount = 18,
			time = 0.7,
			minpos = vector.offset(pos, -0.25, 0.3, -0.25),
			maxpos =
				vector.offset(pos, 0.25, 2.0, 0.25),
			minvel = { x = -0.3, y = 2, z = -0.3 },
			maxvel = { x = 0.3, y = 4, z = 0.3 },
			minacc = { x = 0, y = -2, z = 0 },
			maxacc = { x = 0, y = -1, z = 0 },
			minexptime = 0.5,
			maxexptime = 1.8,
			minsize = 2,
			maxsize = 5,
			texture =
			"sulphur_smoke_particle.png",
			glow = 3
		})
		core.sound_play("fire_large", { pos = pos, gain = 0.15, max_hear_distance = 16 })
	end
})

core.register_abm({
	label = "Sulphur water nausea",
	nodenames = { modname .. ":sulphur_smoke" },
	interval = 2,
	chance = 1,
	action = function(pos)
		for _, obj in ipairs(core.get_objects_inside_radius(pos, 3.5)) do
			if obj:is_player() then give_nausea(obj, 5) end
		end
	end
})

core.register_lbm({
	label = "Sulphur smoke over water",
	name = modname .. ":convert_smoke",
	nodenames = { modname .. ":sulphur_smoke" },
	run_at_every_load = true,
	action = function(pos)
		local below = core.get_node(vector.offset(pos, 0, -1, 0)).name
		if core.get_item_group(below, "water") == 0 and below ~= "mcl_core:water_source" then core.remove_node(pos) end
	end
})

-- Movimento do slime baseado em slime_do_go_pos, slime_turn e slime_jump_continuously da BetterCraft.
local function sulfur_slime_do_go_pos(self, dtime, moveresult)
	local rule = self.sulphur_rule or material_rules.default
	local speed = (self.movement_velocity or self.movement_speed or 10) * rule.speed
	if not self._next_jump then self._next_jump = 0 end

	local delay = math.max(0, self._next_jump - dtime)
	if delay == 0 or self._in_water or not moveresult
		or not (moveresult.touching_ground or moveresult.standing_on_object) then
		if delay == 0 then
			self._jump = true
			delay = (math.random(60) + 40) / 20 * (self.jump_delay_multiplier or 1)
		end
		self.acc_dir.z = speed / 20
		self.acc_speed = speed
	else
		self.acc_dir.z = 0
		self.acc_speed = 0
	end
	self._next_jump = delay
end

local function sulfur_slime_turn(self, dtime, self_pos)
	local remaining = self._next_turn or 0
	if remaining == 0 then remaining = (math.random(60) + 40) / 20 end
	local standing_on = core.registered_nodes[self.standing_on]
	if standing_on and (standing_on.walkable or standing_on.liquidtype ~= "none") then
		remaining = math.max(0, remaining - dtime)
		if remaining == 0 then self:set_yaw(math.random() * 2 * math.pi) end
	end
	self._next_turn = remaining
end

local function sulfur_slime_ai(self, dtime)
	if self.dead or not self.object:get_luaentity() then return end
	local self_pos = self.object:get_pos()
	local rule = self.sulphur_rule or material_rules.default

	-- Sem bloco, o slime usa movimento contínuo e salto automático da BetterCraft.
	if not self.sulphur_block then
		self.movement_goal = "go_pos"
		self.movement_velocity = (self.movement_speed or 10) * rule.speed
		sulfur_slime_turn(self, dtime, self_pos)
	else
		-- Com bloco, mantém a velocidade e a gravidade alteradas pelo material.
		self.movement_goal = "go_pos"
		self.movement_velocity = (self.movement_speed or 10) * rule.speed
	end
end

-- Visual auxiliar do bloco absorvido, exibido como wielditem dentro do slime.
core.register_entity(modname .. ":sulfur_cube_contents", {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "wielditem",
		visual_size = SULFUR_BLOCK_VISUAL_SIZE,
		wield_item = "air",
	},
	on_step = function(self)
		if not self.parent or not self.parent:get_pos() then
			self.object:remove()
		end
	end,
})

-- Texturas base por face do slime.
local SLIME_FRONT_TEXTURE = "sulfur_cube_entity.png^[opacity:237"
local SLIME_SIDE_TEXTURES = {
	"sulfur_cube_entity.png^[opacity:237",
	"sulfur_cube_entity.png^[opacity:237",
	"sulfur_cube_entity.png^[opacity:237",
	"sulfur_cube_entity.png^[opacity:237",
	"sulfur_cube_entity.png^[opacity:237",
}

local function get_block_texture(itemname)
	local def = core.registered_items[itemname] or core.registered_nodes[itemname]
	if not def then return "blank.png" end
	if def.inventory_image and def.inventory_image ~= "" then return def.inventory_image end
	if def.tiles and def.tiles[1] then
		local tile = def.tiles[1]
		if type(tile) == "string" then return tile end
	end
	return "blank.png"
end

local function compose_face_texture(base_texture, itemname)
	local block_texture = get_block_texture(itemname) .. "^[resize:32x32"
	-- O bloco ocupa 32x32 no atlas 128x64 e fica centralizado, menor que o slime.
	return base_texture .. "^[combine:128x64:48,16=" .. block_texture
end

local function slime_texture_list(itemname)
	local textures = {}
	if itemname then
		textures[1] = compose_face_texture(SLIME_FRONT_TEXTURE, itemname)
		for i = 1, 5 do
			textures[i + 1] = compose_face_texture(SLIME_SIDE_TEXTURES[i], itemname)
		end
	else
		textures[1] = SLIME_FRONT_TEXTURE
		for i = 1, 5 do
			textures[i + 1] = SLIME_SIDE_TEXTURES[i]
		end
	end
	return textures
end

local function remove_contents_visual(self)
	if self.sulphur_contents and self.sulphur_contents:get_pos() then
		self.sulphur_contents:remove()
	end
	self.sulphur_contents = nil
	self.object:set_properties({ textures = { slime_texture_list() } })
end

local function set_contents_visual(self, itemname)
	remove_contents_visual(self)
	local obj = core.add_entity(self.object:get_pos(), modname .. ":sulfur_cube_contents")
	if obj then
		obj:set_properties({ wield_item = itemname, visual_size = SULFUR_BLOCK_VISUAL_SIZE })
		local child = obj:get_luaentity()
		if child then child.parent = self.object end
		obj:set_attach(self.object, "", { x = 0, y = 0.8, z = 0 }, { x = 0, y = 0, z = 0 })
		self.sulphur_contents = obj
	end
end

local function make_slime_immortal(self)
	self.sulphur_immortal = true
	self.object:set_armor_groups({ immortal = 1 })
end

local function make_slime_vulnerable(self)
	self.sulphur_immortal = false
	self.object:set_armor_groups({ fleshy = 80 })
end

local function remove_absorbed_block(self, clicker, toolstack)
	if not self.sulphur_block then return false end
	core.add_item(self.object:get_pos(), self.sulphur_block)
	self.sulphur_block = nil
	self.sulphur_material = nil
	self.sulphur_rule = nil
	remove_contents_visual(self)
	make_slime_vulnerable(self)
	self.object:set_properties({ textures = { slime_texture_list() }, nametag = S("Cubo de enxofre") })
	if toolstack and toolstack:get_name() == "mcl_tools:shears" and not core.is_creative_enabled(clicker:get_player_name()) then
		toolstack:add_wear(6553)
		clicker:set_wielded_item(toolstack)
	end
	return true
end

-- Definição do Mob
if mcl_mobs and mcl_mobs.register_mob then

	local slime_def = {
		description = S("Slime de enxofre"),
		type = "animal", 
		spawn_class = "passive",
		hp_min = 16,
		hp_max = 16,
		armor = 80,
		damage = 2,
		collisionbox = { -0.75, -0.01, -0.75, 0.75, 1.5, 0.75 },
		visual = "mesh",
		mesh = "mobs_mc_slime.b3d",
		visual_size = SLIME_VISUAL_SIZE,
		use_texture_alpha = true,
		textures = { slime_texture_list() },

		movement_speed = 10,
		jump_height = 7,
		fall_damage = 0,
		passive = true,
		makes_footstep_sound = false,
		
		sounds = {
			death = "green_slime_death",
			damage = "green_slime_damage",
		},

		drops = { { name = modname .. ":sulphur_dust", chance = 1, min = 1, max = 2 } },
		
		animation = { 
			jump_start = 1, jump_end = 20, jump_speed = 24, jump_loop = false, 
			stand_start = 1, stand_end = 1,
		},
		
			do_go_pos = sulfur_slime_do_go_pos,
			run_ai = sulfur_slime_ai,
			jump_delay_multiplier = 1,

		on_punch = function(self)
			if self.sulphur_immortal then return true end
		end,

		on_die = function(self)
			remove_contents_visual(self)
		end,

		on_rightclick = function(self, clicker)
			local stack = clicker:get_wielded_item()
			local name = stack:get_name()

			-- Um bloco absorvido só pode ser removido com tesoura.
			if self.sulphur_block then
				if name ~= "mcl_tools:shears" then return end
				remove_absorbed_block(self, clicker, stack)
				return
			end

			-- Coleta no balde somente quando o cubo está vazio.
			if name == "mcl_buckets:bucket_empty" then
				if not core.is_creative_enabled(clicker:get_player_name()) then
					clicker:set_wielded_item(ItemStack(modname .. ":bucket_of_sulfur_cube"))
				end
				self.object:remove()
				return
			end

			if not item_is_block(name) or name == modname .. ":sulfur_slime_spawn_egg" then return end
			local rule = classify_material(name)
			if not rule then return end

			self.sulphur_material = rule.label
			self.sulphur_block = name
			self.sulphur_rule = rule
			self.movement_speed = 10 * rule.speed
			self.jump_height = 7 * rule.jump
				set_contents_visual(self, name)
				make_slime_immortal(self)
				self.object:set_acceleration({ x = 0, y = -9.8 * rule.gravity, z = 0 })
				self.object:set_properties({
					textures = { slime_texture_list(name) },
					nametag = S("Cubo de enxofre: @1", rule.label),
					nametag_color = "#f4d35e"
				})
			if not core.is_creative_enabled(clicker:get_player_name()) then
				stack:take_item()
				clicker:set_wielded_item(stack)
			end
			core.sound_play("default_place_node", { pos = self.object:get_pos(), gain = 0.5, max_hear_distance = 12 })
		end,

		do_custom = function(self, dtime, moveresult)
			-- Salto extra se for madeira
			if self.sulphur_rule and self.sulphur_rule.label == "madeira" and moveresult and moveresult.touching_ground then
				local v = self.object:get_velocity()
				if math.abs(v.y) < 0.2 then 
					self.object:set_velocity({ x = v.x, y = 8.5, z = v.z }) 
				end
			end
		end,
	}

	-- Registro do Mob e do Ovo (APENAS AQUI DENTRO)
	mcl_mobs.register_mob(modname .. ":sulfur_slime", slime_def)
	mcl_mobs.register_egg(modname .. ":sulfur_slime", S("Slime de enxofre"), "#f4d35e", "#7a6a2f", true)
end
