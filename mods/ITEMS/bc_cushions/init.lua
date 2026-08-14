local S = core.get_translator(core.get_current_modname())
local D = mcl_util.get_dynamic_translator()

-- Texture translation table (following mcl_wool)
local messy_textures = {
	["light_blue"] = "mcl_wool_light_blue",
	["grey"]       = "wool_dark_grey",
	["silver"]     = "wool_grey",
	["green"]      = "wool_dark_green",
	["lime"]       = "mcl_wool_lime",
	["purple"]     = "wool_violet",
}

local function get_texture(color)
	local texcolor = "wool_" .. color
	if messy_textures[color] then
		texcolor = messy_textures[color]
	end
	return texcolor .. ".png"
end

-- =========================================================
-- SITTING LOGIC (based on mcl_cozy)
-- =========================================================
-- Instead of attaching the player to an invisible entity, we follow
-- mcl_cozy's approach: the player stays "free", but with movement
-- physics locked and the sitting eye offset/animation applied.
-- They automatically stand up when they try to move.

local mod_mcl_player      = core.get_modpath("mcl_player") ~= nil
local mod_playerphysics   = core.get_modpath("playerphysics") ~= nil

local SIT_EYE_OFFSET = vector.new(0, -7, 2)
local VELOCITY_THRESHOLD = 0.125

cushions = cushions or {}
cushions.sitting = {} -- [player_name] = cushion_luaentity (or true, if none)

-- Marks the player as "attached" inside mcl_player itself. Without this,
-- mcl_player's own globalstep keeps overriding the sitting animation every
-- tick (e.g. reverting to "idle"/"walk"), exactly what mcl_cozy avoids by
-- setting mcl_player.players[player].attached = true/false.
local function set_mcl_player_attached(player, bool)
	if not (mod_mcl_player and mcl_player.players and player) then return end
	local pdata = mcl_player.players[player]
	if pdata then
		pdata.attached = bool
	end
end

local function stand_up(player, cushion_self)
	if not player then return end
	local name = player:get_player_name()

	player:set_eye_offset(vector.zero(), vector.zero())

	if mod_playerphysics then
		playerphysics.remove_physics_factor(player, "speed", "cushions:sit")
		playerphysics.remove_physics_factor(player, "jump", "cushions:sit")
	end

	set_mcl_player_attached(player, false)

	if mod_mcl_player then
		mcl_player.player_set_animation(player, "stand", 30)
	else
		player:set_animation({x = 0, y = 79}, 30, 0)
	end

	cushions.sitting[name] = nil
	if cushion_self then
		cushion_self.sitter = nil
	end
end

-- sit: toggles sitting/standing. cushion_self (optional) is the cushion's
-- luaentity, used to store who is sitting on it.
local function sit(pos, player, cushion_self)
	if not player or not player:is_player() then return end
	local name = player:get_player_name()

	-- If already sitting, stand up
	if cushions.sitting[name] then
		stand_up(player, cushions.sitting[name] ~= true and cushions.sitting[name] or cushion_self)
		return
	end

	-- Prevents sitting while moving too fast (same check as mcl_cozy)
	if vector.length(player:get_velocity()) > VELOCITY_THRESHOLD then
		return
	end

	player:move_to(pos)
	player:set_eye_offset(SIT_EYE_OFFSET, SIT_EYE_OFFSET)

	if mod_playerphysics then
		playerphysics.add_physics_factor(player, "speed", "cushions:sit", 0)
		playerphysics.add_physics_factor(player, "jump", "cushions:sit", 0)
	end

	set_mcl_player_attached(player, true)

	if mod_mcl_player then
		mcl_player.player_set_animation(player, "sit", 30)
		-- small delay, same as mcl_cozy's ACTION_APPLY_DELAY: avoids a race
		-- condition where the animation doesn't "stick" right after move_to
		core.after(0.05, function()
			if core.get_player_by_name(name) == player and cushions.sitting[name] then
				mcl_player.player_set_animation(player, "sit", 30)
			end
		end)
	else
		player:set_animation({x = 81, y = 160}, 30, 0)
	end

	cushions.sitting[name] = cushion_self or true
	if cushion_self then
		cushion_self.sitter = name
	end
end

-- Automatically stands up anyone who tries to move, like mcl_cozy does
core.register_globalstep(function(_)
	for name, cushion_self in pairs(cushions.sitting) do
		local player = core.get_player_by_name(name)
		if not player then
			cushions.sitting[name] = nil
		else
			local ctrl = player:get_player_control()
			if ctrl.up or ctrl.down or ctrl.left or ctrl.right or ctrl.jump or ctrl.sneak then
				stand_up(player, cushion_self ~= true and cushion_self or nil)
			end
		end
	end
end)

-- Stands up stuck players in case they leave the game while sitting
core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if cushions.sitting[name] then
		cushions.sitting[name] = nil
	end
end)

-- =========================================================
-- HELPER FUNCTION: finds the real top of the pointed node
-- =========================================================
local function get_node_top(pos)
	local node = core.get_node(pos)
	local ndef = core.registered_nodes[node.name]
	local top = 0.5

	if ndef then
		local box = ndef.collision_box or ndef.node_box
		if box and box.type == "fixed" and box.fixed then
			local fixed = box.fixed
			if type(fixed[1]) == "table" then
				top = -0.5
				for _, b in ipairs(fixed) do
					if b[5] and b[5] > top then
						top = b[5]
					end
				end
			elseif type(fixed[1]) == "number" then
				top = fixed[5]
			end
		end

		if ndef.paramtype2 == "leveled" and ndef.leveled then
			local level = node.param2 or 0
			if level == 0 then level = ndef.leveled end
			top = -0.5 + (level / 64)
		end
	end

	return top
end

-- =========================================================
-- CUSHION ENTITY
-- =========================================================
local function make_staticdata(color, invisible)
	return core.serialize({color = color, invisible = invisible or false})
end

core.register_entity("cushions:cushion_entity", {
	visual = "cube",
	visual_size = {x = 0.7, y = 0.19, z = 0.7},
	collisionbox = {-0.35, -0.095, -0.35, 0.35, 0.095, 0.35},
	selectionbox = {-0.35, -0.095, -0.35, 0.35, 0.095, 0.35},
	pointable = true,
	physical = false,
	static_save = true,
	textures = {"blank.png","blank.png","blank.png","blank.png","blank.png","blank.png"},

	on_activate = function(self, staticdata)
		local data = (staticdata ~= "" and staticdata ~= nil) and core.deserialize(staticdata) or nil
		self.color = (data and data.color) or "white"
		self.invisible = (data and data.invisible) or false
		self.sitter = nil -- name of the player sitting on this cushion (not persisted)
		self.object:set_armor_groups({immortal = 1})
		self:update_textures()
	end,

	get_staticdata = function(self)
		return make_staticdata(self.color, self.invisible)
	end,

	update_textures = function(self)
		if self.invisible then
			self.object:set_properties({
				textures = {"blank.png","blank.png","blank.png","blank.png","blank.png","blank.png"},
			})
		else
			local tex = get_texture(self.color)
			self.object:set_properties({textures = {tex, tex, tex, tex, tex, tex}})
		end
	end,

	-- Stands up the player sitting on this cushion, if any
	stand_up = function(self)
		if not self.sitter then return end
		local player = core.get_player_by_name(self.sitter)
		if player then
			stand_up(player, self)
		else
			self.sitter = nil
		end
	end,

	-- Right-click: Removes the cushion, stands up whoever is sitting and drops the item
	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then return end
		local pos = self.object:get_pos()

		-- Stand up the sitting player (if any) before removing the cushion
		self:stand_up()

		-- If not in creative mode, drop the item of the matching color
		if not core.is_creative_enabled(clicker:get_player_name()) then
			core.add_item(pos, "cushions:cushion_" .. self.color)
		end

		self.object:remove()
	end,

	-- Punch (Left-click): Sit or Toggle Visibility
	on_punch = function(self, puncher)
		if not puncher or not puncher:is_player() then return end

		-- If sneaking + Punch = Toggle visible/invisible
		if puncher:get_player_control().sneak then
			self.invisible = not self.invisible
			self:update_textures()
			return
		end

		-- Normal punch = Sit/Stand (mcl_cozy-style logic)
		sit(self.object:get_pos(), puncher, self)
	end,
})

-- =========================================================
-- PLACEABLE ITEMS
-- =========================================================
for color, colordef in pairs(mcl_dyes.colors) do
	local item_name = "cushions:cushion_" .. color

	core.register_craftitem(item_name, {
		description = D(colordef.readable_name .. " Cushion"),
		inventory_image = get_texture(color),
		groups = {cushion_item = 1, flammable = 1, miscellaneous = 1},

		on_place = function(itemstack, placer, pointed_thing)
			if pointed_thing.type ~= "node" then
				return itemstack
			end

			local under = pointed_thing.under
			local top = get_node_top(under)
			local spawn_pos = {
				x = under.x,
				y = under.y + top + 0.01,
				z = under.z,
			}

			local objs = core.get_objects_inside_radius(spawn_pos, 0.3)
			for _, obj in ipairs(objs) do
				local ent = obj:get_luaentity()
				if ent and ent.name == "cushions:cushion_entity" then
					return itemstack
				end
			end

			local ent = core.add_entity(spawn_pos, "cushions:cushion_entity", make_staticdata(color, false))
			if ent then
				if placer and placer:is_player() then
					ent:set_yaw(placer:get_look_horizontal())
				end
				if not (placer and core.is_creative_enabled(placer:get_player_name())) then
					itemstack:take_item()
				end
			end

			return itemstack
		end,
	})

	core.register_craft({
		output = item_name,
		recipe = {
			{"mcl_wool:" .. color, "mcl_wool:slab_" .. color, "mcl_wool:" .. color},
		}
	})
end