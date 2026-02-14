local MAX_SLEEP_INTERVAL = 3600
local S = minetest.get_translator(minetest.get_current_modname())

mcl_mobs.register_mob("mobs_mc:phantom", {
	description = S("Phantom"),
	type = "monster",
	spawn_class = "hostile",

	hp_min = 20,
	hp_max = 20,
	damage = 4,
	reach = 3,
	armor = 10,
	damage_groups = {fleshy = 100},
	view_range = 64,

	visual = "mesh",
	mesh = "mobs_mc_phantom.b3d",
	textures = {{"mobs_mc_phantom.png"}},
	visual_size = {x = 1, y = 1},
	collisionbox = {-0.6,-0.3,-0.6, 0.6,0.3,0.6},
	glow = 6,

	-- Real flight configuration
	fly = true,
	fly_in = {"air"},
	floats = 1,
	jump = false,
	stepheight = 0,
	pathfinding = false,
	fall_damage = false,
	fear_height = 0,

	walk_velocity = 6,
	pace_bonus = 0.3,
	run_velocity = 8,
	fly_velocity = 8,

	animation = {
		stand_start = 1, stand_end = 160, stand_speed = 20,
		walk_start = 1, walk_end = 160, speed_normal = 20,
		run_start = 1, run_end = 160, speed_run = 25,
	},

	drops = {
		{name = "mcl_mobitems:phantom_membrane", chance = 2, min = 0, max = 1},
	},

	-- Retreat logic when taking damage
	on_attack = function(self, hitter)
		if not hitter or not hitter:is_player() then return end

		self.phantom_state = "retreat"
		self.retreat_timer = 2.0
	end,

	--------------------------------------------------
	-- Custom AI
	--------------------------------------------------
	do_custom = function(self, dtime)
		if not self.object or not self.object:get_pos() then return end

		-- Remove gravity
		self.object:set_acceleration({x=0, y=0, z=0})

		local pos = self.object:get_pos()

		-- Detect if damage was taken
		if not self._last_health then
			self._last_health = self.health
		end

		if self.health < self._last_health then
			self.phantom_state = "retreat"
			self.retreat_timer = 2.0
		end

		self._last_health = self.health

		-- Sun burning logic
		local light = minetest.get_node_light(pos) or 0
		local time = minetest.get_timeofday()
		if time > 0.2 and time < 0.8 and light > 12 then
			local node_above = minetest.get_node_or_nil({x=pos.x, y=pos.y+1, z=pos.z})
			if node_above and node_above.name == "air" then
				self.health = self.health - (dtime * 2)
				  if self.health <= 0 then
                    self:check_for_death()
                    return false
                end
			end
		end

		-- Player search (ignores creative mode)
		local players = minetest.get_connected_players()
		local target = nil
		local min_dist = 64

		for _, player in ipairs(players) do
			local name = player:get_player_name()
			local is_creative = minetest.settings:get_bool("creative_mode") or minetest.check_player_privs(name, {creative=true})
			
			if not is_creative then
				local ppos = player:get_pos()
				if ppos then
					local dist = vector.distance(pos, ppos)
					if dist < min_dist then
						target = player
						min_dist = dist
					end
				end
			end
		end

		local tpos
		if not target then
			if not self.idle_center then self.idle_center = pos end
			tpos = self.idle_center
		else
			tpos = target:get_pos()
			self.idle_center = nil
		end

		-- Initialize state
		if not self.phantom_state then
			self.phantom_state = "circle"
			self.circle_angle = 0
		end

		-- State: RETREAT (fly upward when damaged)
		if self.phantom_state == "retreat" then
			self.retreat_timer = (self.retreat_timer or 2) - dtime
			
			-- Pure upward velocity
			self.object:set_velocity({x=0, y=8, z=0})
			
			if self.retreat_timer <= 0 then
				self.phantom_state = "circle"
			end
			return false
		end

		-- State: CIRCLE
		if self.phantom_state == "circle" then
			self.circle_angle = (self.circle_angle or 0) + dtime * 1.2

			local radius = 18
			local max_height = 20

			-- Height limited to 20 blocks above the target
			local desired_y = tpos.y + max_height

			local offset = {
				x = math.cos(self.circle_angle) * radius,
				y = desired_y - pos.y,
				z = math.sin(self.circle_angle) * radius
			}

			local goal = vector.add(pos, offset)
			local dir = vector.direction(pos, goal)
			local v = vector.multiply(dir, 9)

			self.object:set_velocity(v)
			self.object:set_yaw(minetest.dir_to_yaw(dir))

			if target and math.random(1, 160) == 1 then
				self.phantom_state = "dive"
			end
		end

		-- State: DIVE
		if self.phantom_state == "dive" and target then
			local dir = vector.direction(pos, tpos)
			local v = vector.multiply(dir, 13)

			self.object:set_velocity(v)
			self.object:set_yaw(minetest.dir_to_yaw(dir))

			if vector.distance(pos, tpos) < 2.5 then
				target:punch(self.object, 1.0, {
					full_punch_interval = 1.0,
					damage_groups = {fleshy = 6},
				})
				self.phantom_state = "circle"
			end

			if pos.y < tpos.y - 1 then
				self.phantom_state = "circle"
			end
		elseif self.phantom_state == "dive" and not target then
			self.phantom_state = "circle"
		end

		return false
	end,
})

mcl_mobs.register_egg("mobs_mc:phantom", "Phantom", "#162328", "#a078db", 0)
