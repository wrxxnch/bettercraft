mcl_bubble_column = {}

local WATER_VISC = 1

local liquid_tpl = {
	_doc_items_create_entry = false,
	sounds = mcl_sounds.node_sound_water_defaults(),
	is_ground_content = false,
	use_texture_alpha = "blend",
	paramtype = "light",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	drop = "",
	drowning = 0,
	liquid_viscosity = WATER_VISC,
	liquid_range = 7,
	waving = 3,
	post_effect_color = {a=60, r=0x03, g=0x3C, b=0x5C},
	groups = { water=3, liquid=3, puts_out_fire=1, not_in_creative_inventory=1, freezes=1, melt_around=1, dig_by_piston=1, unsticky = 1},
	_pathfinding_class = "WATER",
	_on_bottle_place = mcl_core.get_bottle_place_on_water("mcl_potions:water"),
	_mcl_blast_resistance = 100,
	_mcl_hardness = -1,
}

local liquid_flowing_tpl = table.merge(liquid_tpl, {
	wield_image = "default_water_flowing_animated.png^[verticalframe:64:0",
	drawtype = "flowingliquid",
	paramtype2 = "flowingliquid",
	liquidtype = "flowing",
	tiles = {"default_water_flowing_animated.png^[verticalframe:64:0"},
	special_tiles = {
		{
			name = "default_water_flowing_animated.png",
			backface_culling=false,
			animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=4.0}
		},
		{
			name = "default_water_flowing_animated.png",
			backface_culling=false,
			animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=4.0}
		},
	},
})

local liquid_source_tpl = table.merge(liquid_tpl, {
	wield_image = "default_water_flowing_animated.png^[verticalframe:64:0",
	drawtype = "liquid",
	liquidtype = "source",
	tiles = {
		{name="default_water_source_animated.png", animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=5.0}}
	},
	special_tiles = {{
		name = "default_water_source_animated.png",
		animation={type="vertical_frames", aspect_w=16, aspect_h=16, length=5.0},
		backface_culling = false,
	}},
})

core.register_node("mcl_bubble_column:bubbly_flowing", table.merge(liquid_flowing_tpl, {
	liquid_alternative_flowing = "mcl_bubble_column:bubbly_flowing",
	liquid_alternative_source = "mcl_bubble_column:bubbly",
	groups = table.merge(liquid_tpl.groups, {bubbly=1})
}))
core.register_node("mcl_bubble_column:bubbly", table.merge(liquid_source_tpl, {
	liquid_alternative_flowing = "mcl_bubble_column:bubbly_flowing",
	liquid_alternative_source = "mcl_bubble_column:bubbly",
	groups = table.merge(liquid_tpl.groups, {bubbly=1})
}))

core.register_node("mcl_bubble_column:whirly_flowing", table.merge(liquid_flowing_tpl, {
	liquid_alternative_flowing = "mcl_bubble_column:whirly_flowing",
	liquid_alternative_source = "mcl_bubble_column:whirly",
	groups = table.merge(liquid_tpl.groups, {whirly=1})
}))
core.register_node("mcl_bubble_column:whirly", table.merge(liquid_source_tpl, {
	liquid_alternative_flowing = "mcl_bubble_column:whirly_flowing",
	liquid_alternative_source = "mcl_bubble_column:whirly",
	groups = table.merge(liquid_tpl.groups, {whirly=1})
}))

mcl_bubble_column.on_enter_bubble_column = function (self)
	if mcl_serverplayer.is_csm_capable(self) then
		self:add_velocity({x = 0, y = 1, z = 0})
	else
		local velocity = self:get_velocity()
		self:add_velocity({x = 0, y = math.min(2.6, math.abs(velocity.y)+2), z = 0})
	end
end

mcl_bubble_column.on_enter_whirlpool = function (self)
	if mcl_serverplayer.is_csm_capable(self) then
		self:add_velocity({x = 0, y = -1, z = 0})
	else
		local velocity = self:get_velocity()
		self:add_velocity({x = 0, y = math.max(-1, (-math.abs(velocity.y))-1), z = 0})
	end
end

mcl_bubble_column.check_water = function(pos)
	local node = core.get_node(pos)
	local node_above = core.get_node(vector.offset(pos,0,1,0))
	local node_below = core.get_node(vector.offset(pos,0,-1,0))
	local above_is_water = core.get_item_group(node_above.name, "water") == 3

	-- base node
	if node.name == "mcl_nether:magma" then
		if above_is_water and core.get_item_group(node_above.name, "whirly") ~= 1 then
			core.swap_node(vector.offset(pos,0,1,0),{name="mcl_bubble_column:whirly"})
		end
	elseif node.name == "mcl_nether:soul_sand" then
		if above_is_water and core.get_item_group(node_above.name, "bubbly") ~= 1 then
			core.swap_node(vector.offset(pos,0,1,0),{name="mcl_bubble_column:bubbly"})
		end
	-- whirlpool
	elseif node.name == "mcl_bubble_column:whirly" then
		if core.get_item_group(node_above.name, "whirly") ~= 1 then
			if above_is_water then
				core.swap_node(vector.offset(pos,0,1,0),{name="mcl_bubble_column:whirly"})
			end
		end
		if core.get_item_group(node_below.name, "whirly") ~= 1 then
			if node_below.name ~= "mcl_nether:magma" then
				core.swap_node(pos,{name="mcl_core:water_source"})
			end
		end
	-- bubble column
	elseif node.name == "mcl_bubble_column:bubbly" then
		if core.get_item_group(node_above.name, "bubbly") ~= 1 then
			if above_is_water then
				core.swap_node(vector.offset(pos,0,1,0),{name="mcl_bubble_column:bubbly"})
			end
		end
		if core.get_item_group(node_below.name, "bubbly") ~= 1 then
			if node_below.name ~= "mcl_nether:soul_sand" then
				core.swap_node(pos,{name="mcl_core:water_source"})
			end
		end
	end
end

core.register_abm({
	label = "Bubble column/Whirlpool particles & water transform",
	nodenames = {
		"mcl_nether:magma",
		"mcl_nether:soul_sand",
		"group:whirly",
		"group:bubbly",
	},
	interval = 1,
	chance = 1,
	action = function(pos)
		local node = core.get_node(pos)
		mcl_bubble_column.check_water(pos)
		if core.get_item_group(node.name, "bubbly") == 1 then
			core.add_particlespawner({
				amount = 10,
				time = 1,
				minpos = {x=pos.x-0.5, y=pos.y, z=pos.z-0.5},
				maxpos = {x=pos.x+0.5, y=pos.y, z=pos.z+0.5},
				minvel = {x=0, y=0.5, z=0},
				maxvel = {x=0, y=1.0, z=0},
				minacc = {x=0, y=0, z=0},
				maxacc = {x=0, y=0.5, z=0},
				minexptime = 1,
				maxexptime = 1,
				minsize = 0.5,
				maxsize = 2.4,
				texture = "mcl_particles_bubble.png"
			})
		else
			core.add_particlespawner({
				amount = 10,
				time = 1,
				minpos = {x=pos.x-0.5, y=pos.y, z=pos.z-0.5},
				maxpos = {x=pos.x+0.5, y=pos.y, z=pos.z+0.5},
				minvel = {x=0, y=-1.0, z=0},
				maxvel = {x=0, y=-1.5, z=0},
				minacc = {x=0, y=0, z=0},
				maxacc = {x=0, y=-0.5, z=0},
				minexptime = 1,
				maxexptime = 1,
				minsize = 0.5,
				maxsize = 2.4,
				texture = "mcl_particles_bubble.png"
			})
		end
	end,
})

core.register_globalstep(function()
	for _,player in pairs(core.get_connected_players()) do
		local pos = player:get_pos()
		local feet_node = core.get_node(pos)
		local eye_pos = vector.offset(pos,0,player:get_properties().eye_height,0)
		local eye_node = core.get_node(eye_pos)
		if core.get_item_group(feet_node.name, "bubbly") == 1
			or core.get_item_group(eye_node.name, "bubbly") == 1 then
			mcl_bubble_column.on_enter_bubble_column(player)
		elseif core.get_item_group(feet_node.name, "whirly") == 1
			or core.get_item_group(eye_node.name, "whirly") == 1 then
			mcl_bubble_column.on_enter_whirlpool(player)
		end
	end
end)
