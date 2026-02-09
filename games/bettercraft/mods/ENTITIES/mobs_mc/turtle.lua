local S = core.get_translator("mobs_mc")

local mob_class = mcl_mobs.mob_class

mcl_mobs.register_mob("mobs_mc:turtle", {
	description = S("Turtle"),
	type = "animal",
	spawn_class = "passive",
	attack_type = "dogfight",
	attacks_monsters = true,
	specific_attack = {
		"mobs_mc:slime_small",
		"mobs_mc:magma_cube_small"
	},
	damage = 8,
	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 3,
	double_melee_attack = false,
	reach = 2,
	armor = 5,
	collisionbox = { -0.6, -0.05, -0.6, 0.6, 0.5, 0.6 },
	visual = "mesh",
	mesh = "mobs_mc_turtle.b3d",
	visual_size = { x = 1, y = 1},
	texture_list = {
		{"mobs_mc_turtle.png"},
	},
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 4,
	view_range = 16,
	stepheight = 1.1,
	jump = true,
	jump_height = 10,
	--suffocation = true,
	fear_height = 4,
	---
	swims = true,
	spawn_in_group = 5,
	-- turtle doesn't take drowning damage
	breath_max = -1,
	follow = { "mcl_ocean:seagrass" },
	sounds = {
	   -- random = "",
	},

	drops = {
	   -- {name = "turtle:turtle", min = 1, max = 2},
	},

	animation = {
		-- swing = 145,165
		-- idling underwater = 175,250
		stand_start = 1, stand_end = 20, stand_speed = 10,
		walk_start = 30, walk_end =85, speed_normal = 10,
		--run_start = 0, run_end = 0, run_speed = 15,
		--punch_start = 0, punch_end = 0, punch_speed =15,
		-- = 145,fly_end = 165,fly_speed = 10,
		--die_start = 0, die_end = 0, die_speed = 0,--die_loop = 0,
	},

	on_rightclick = function(self, clicker)
		local it = clicker:get_wielded_item()
		if it:get_name() == "mcl_ocean:seagrass" then
			self:feed_tame(clicker, 4, true, false, true)
			if not core.is_creative_enabled(clicker:get_player_name()) then
				it:take_item()
				clicker:set_wielded_item(it)
			end
		end
	end,
	on_breed = function(self, _)
		self._has_egg = true
		self:go_home()
		return false
	end,
	go_home = function(self)
		if not self._home then return end
		if vector.distance(self.object:get_pos() < 25) then
			return true
		end
		self:go_to_pos(self._home)
	end,
	lay_egg = function(self)
		local pos = self.object:get_pos()
		local nn = core.find_nodes_in_area_under_air(vector.offset(pos, -32, -5, -32), vector.offset(pos, 32, 5, 32), { "mcl_core:sand", "mcl_core:red_sand" } )
		if nn and #nn > 0 then
			local p = nn[math.random(#nn)]
			self:gopath(p, function()
				core.set_node(vector.offset(p, 0, 1, 0), { name = "mcl_mobitems:turtle_egg" })
			end)
		end
	end,

	on_grown = function(self)
		mcl_util.drop_item_stack(self.object:get_pos(), ItemStack("mcl_mobitems:scute"))
	end,

	post_load_staticdata = function(self)
		mob_class.post_load_staticdata(self)
		if not self._turtle_initialized then
			self._home = self.object:get_pos():copy()
			if not self.child and math.random(10) == 1 then
				self.child = true
			end
			self._turtle_initialized = true
		end
	end,
})

local function start_egg_timer(pos)
	core.get_node_timer(pos):start(math.random(3600,24000))
end

core.override_item("mcl_mobitems:turtle_egg", {
	on_timer = function(pos)
		local tod = core.get_timeofday()
		if tod > 0.14 and tod < 0.18 then
			mcl_mobs.spawn_child(pos, "mobs_mc:turtle")
			core.remove_node(pos)
		else
			-- wait 15 minutes of game time until early morning;
			-- check time_speed setting, because the hatching time
			-- window is rather small
			local time_speed = tonumber(core.settings:get("time_speed")) or 72
			core.get_node_timer(pos):start(900 / time_speed)
		end
		return false
	end,
	on_construct = start_egg_timer,
})

local tspawn = {
	name = "mobs_mc:turtle",
	type_of_spawning = "ground",
	dimension = "overworld",
	min_height = mobs_mc.water_level-4,
	max_height = mobs_mc.water_level+3,
	min_light = 0,
	max_light = core.LIGHT_MAX + 1,
	aoc = 7,
	chance = 100,
	biomes = {
		"Plains_beach",
		"ExtremeHills_beach",
		"MangroveSwamp_shore",
		"ColdTaiga_beach",
		"ColdTaiga_beach_water",
		"Swampland_shore",
		"Taiga_beach",
		"Forest_beach",
		"FlowerForest_beach",
		"Savanna_beach",
		"Jungle_shore",
		"JungleM_shore",
	},
}
mcl_mobs.spawn_setup(tspawn)
mcl_mobs.spawn_setup(table.merge(tspawn, {
	type_of_spawning = "water",
}))

mcl_mobs.register_egg("mobs_mc:turtle", "turtle", "#516720", "#ded88f", 0)