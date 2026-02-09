local S = core.get_translator(core.get_current_modname())

-------------------------------------------------------
-- CONFIG
-------------------------------------------------------
local BEE_SPEED = 4.5
local SEARCH_RADIUS = 16
local EXPLORE_SPEED = 2.5
local HIVE_TIME = 20
local BREED_COOLDOWN = 60
local ANGER_TIME = 15

-------------------------------------------------------
-- AUX
-------------------------------------------------------

local function add_honey(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node then return end
	if not node.name:find("_") then return end

	local lvl = tonumber(node.name:match("_(%d)$")) or 0
	if lvl < 5 then
		local base = node.name:gsub("_%d$", "")
		minetest.swap_node(pos, {name = base .. "_" .. (lvl + 1), param2 = node.param2})
	end
end

local function obstructed(a, b)
	local dir = vector.direction(a, b)
	local p = vector.add(a, vector.multiply(dir, 0.7))
	local n = minetest.get_node_or_nil(p)
	if not n then return false end
	local def = minetest.registered_nodes[n.name]
	return def and def.walkable
end

-------------------------------------------------------
-- BEE
-------------------------------------------------------

mcl_mobs.register_mob("bee_custom:bee", {
	description = "Bee",
	type = "animal",
	spawn_class = "passive",
	passive = true,
	hp_min = 10,
	hp_max = 10,

	visual = "mesh",
	mesh = "mobs_mc_bee.b3d",
	textures = {"mobs_mc_bee.png"},
	visual_size = {x=1,y=1},

	collisionbox = {-0.25,-0.25,-0.25,0.25,0.25,0.25},
	fly = true,
	fly_in = "air",

	walk_velocity = 4,
	run_velocity = 6,

	follow = {"group:flower"},

	animation = {
		stand_start = 1,
		stand_end = 40,
		walk_start = 1,
		walk_end = 40,
		speed_normal = 30,
	},

	---------------------------------------------------
	-- ACTIVATE
	---------------------------------------------------
	on_activate = function(self, staticdata, dtime)
		if self.mob_activate then
			self:mob_activate(staticdata, mcl_mobs.registered_mobs[self.name], dtime)
		end

		self.has_nectar = self.has_nectar or false
		self.in_hive = self.in_hive or false
		self.hive_timer = self.hive_timer or 0
		self.breed_timer = self.breed_timer or 0
		self.explore_timer = self.explore_timer or 0
		self.explore_dir = self.explore_dir or nil
		self.angry = self.angry or false
		self.angry_timer = self.angry_timer or 0
	end,

	---------------------------------------------------
	-- STEP
	---------------------------------------------------
	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		self.breed_timer = math.max(0, (self.breed_timer or 0) - dtime)
		self.explore_timer = self.explore_timer or 0

		---------------------------------------------------
		-- ANGRY MODE
		---------------------------------------------------
		if self.angry then
			self.angry_timer = self.angry_timer - dtime
			if self.angry_timer <= 0 then
				self.angry = false
				self.object:set_properties({textures={"mobs_mc_bee.png"}})
			end
		end

		---------------------------------------------------
		-- INSIDE HIVE
		---------------------------------------------------
		if self.in_hive then
			self.hive_timer = self.hive_timer - dtime
			self.object:set_velocity({x=0,y=0,z=0})

			if self.hive_timer <= 0 then
				add_honey(self.hive_pos)
				self.in_hive = false
				self.has_nectar = false
				self.object:set_properties({
					visual_size = {x=1,y=1},
					textures = {"mobs_mc_bee.png"},
					pointable = true
				})
				self.object:set_velocity({x=0,y=2,z=0})
			end
			return
		end

		---------------------------------------------------
		-- FOLLOW PLAYER WITH FLOWER
		---------------------------------------------------
		for _, p in ipairs(core.get_connected_players()) do
			local ppos = p:get_pos()
			if vector.distance(pos, ppos) < 8 then
				if core.get_item_group(p:get_wielded_item():get_name(), "flower") > 0 then
					local dir = vector.direction(pos, ppos)
					self.object:set_yaw(math.atan2(dir.z, dir.x) - math.pi/2)
					self.object:set_velocity(vector.multiply(dir, BEE_SPEED))
					return
				end
			end
		end

		---------------------------------------------------
		-- TARGET FLOWER OR HIVE
		---------------------------------------------------
		local target, hive = nil, false

		if not self.has_nectar then
			target = minetest.find_node_near(pos, SEARCH_RADIUS, "group:flower")
		else
			target = minetest.find_node_near(pos, SEARCH_RADIUS + 5, {"group:beehive", "group:bee_nest"})
			hive = true
		end

		if target then
			local dir = vector.direction(pos, target)

			if obstructed(pos, target) then
				dir = vector.add(dir, {x=dir.z, y=0.4, z=-dir.x})
			end

			self.object:set_yaw(math.atan2(dir.z, dir.x) - math.pi/2)
			self.object:set_velocity(vector.multiply(vector.normalize(dir), BEE_SPEED))

			if vector.distance(pos, target) < 1.2 then
				if hive then
					self.object:set_properties({visual_size={x=0,y=0}, pointable=false})
					self.in_hive = true
					self.hive_pos = vector.new(target)
					self.hive_timer = HIVE_TIME
				else
					self.has_nectar = true
					self.object:set_properties({textures={"mobs_mc_bee_nectar.png"}})
				end
			end
			return
		end

	---------------------------------------------------
-- EXPLORAÇÃO (CORRIGIDA)
---------------------------------------------------
self.explore_timer = self.explore_timer - dtime

if self.explore_timer <= 0 or not self.explore_dir then
	local angle = math.random() * math.pi * 2

	-- direção apenas horizontal
	self.explore_dir = {
		x = math.cos(angle),
		z = math.sin(angle),
		y = 0
	}

	-- leve ajuste vertical separado
	self.explore_y = (math.random() - 0.5) * 0.3

	self.explore_timer = math.random(3, 6)
end

-- Ajuste suave de altura (sem inclinar)
local vel = {
	x = self.explore_dir.x * EXPLORE_SPEED,
	z = self.explore_dir.z * EXPLORE_SPEED,
	y = self.explore_y
}

-- Limites de altura
if pos.y > 120 then vel.y = -0.3 end
if pos.y < 5 then vel.y = 0.3 end

-- Define rotação apenas no plano XZ
local yaw = math.atan2(self.explore_dir.z, self.explore_dir.x) - math.pi / 2
self.object:set_yaw(yaw)
self.object:set_velocity(vel)
	end,

	---------------------------------------------------
	-- RIGHT CLICK (BREED)
	---------------------------------------------------
	on_rightclick = function(self, clicker)
		if self.in_hive then return end

		local item = clicker:get_wielded_item()
		if core.get_item_group(item:get_name(), "flower") > 0 then
			if self.breed_timer > 0 then return end

			if not minetest.is_creative_enabled(clicker:get_player_name()) then
				item:take_item()
				clicker:set_wielded_item(item)
			end

			self.breed_timer = BREED_COOLDOWN

			minetest.add_particlespawner({
				amount = 10,
				time = 0.3,
				minpos = self.object:get_pos(),
				maxpos = self.object:get_pos(),
				minvel = {x=-1,y=1,z=-1},
				maxvel = {x=1,y=2,z=1},
				texture = "heart.png"
			})

			mcl_mobs.spawn_child(self.object:get_pos(), "bee_custom:bee")
		end
	end,
})

-------------------------------------------------------
-- SPAWN + EGG
-------------------------------------------------------

mcl_mobs.spawn({
	name = "bee_custom:bee",
	nodes = {"group:flower"},
	chance = 8000,
	active_object_count = 3,
	min_height = 1,
	max_height = 200,
})

mcl_mobs.register_egg("bee_custom:bee", S("Bee"), "#f6c343", "#000000")
