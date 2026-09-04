local S = core.get_translator(core.get_current_modname())

mcl_mobspawners = {}

local default_mob = "mobs_mc:pig"

-- Mob spawner
--local spawner_default = default_mob.." 0 15 4 15"

local function get_mob_textures(mob)
	local list = core.registered_entities[mob].texture_list
	if type(list[1]) == "table" then
		return list[1]
	else
		return list
	end
end

local function find_doll(pos)
	for obj in core.objects_inside_radius(pos, 0.5) do
		if not obj:is_player() then
			if obj and obj:get_luaentity().name == "mcl_mobspawners:doll" then
				return obj
			end
		end
	end
end

local function spawn_doll(pos)
	return core.add_entity({x=pos.x, y=pos.y-0.3, z=pos.z}, "mcl_mobspawners:doll")
end

local function set_doll_properties(doll, mob)
	local mobinfo = core.registered_entities[mob]
	if not mobinfo then return end
	local xs, ys
	if mobinfo.doll_size_override then
		xs = mobinfo.doll_size_override.x
		ys = mobinfo.doll_size_override.y
	else
		xs = mobinfo.initial_properties.visual_size.x * 0.33333
		ys = mobinfo.initial_properties.visual_size.y * 0.33333
	end
	local prop = {
		mesh = mobinfo.initial_properties.mesh,
		textures = get_mob_textures(mob),
		visual_size = {
			x = xs,
			y = ys,
		}
	}
	doll:set_properties(prop)
	doll:get_luaentity()._mob = mob
end

local function respawn_doll(pos)
	local meta = core.get_meta(pos)
	local mob = meta:get_string("Mob")
	local doll
	if mob and mob ~= "" then
		doll = find_doll(pos)
		if not doll then
			doll = spawn_doll(pos)
			if doll and doll:get_pos() then
				set_doll_properties(doll, mob)
			end
		end
	end
	return doll
end

--[[ Public function: Setup the spawner at pos.
This function blindly assumes there's actually a spawner at pos.
If not, then the results are undefined.
All the arguments are optional!

* Mob: ID of mob to spawn (default: mobs_mc:pig)
* MinLight: Minimum light to spawn (default: 0)
* MaxLight: Maximum light to spawn (default: 15)
* MaxMobsInArea: How many mobs are allowed in the area around the spawner (default: 4)
* PlayerDistance: Spawn mobs only if a player is within this distance; 0 to disable (default: 15)
]]

function mcl_mobspawners.setup_spawner(pos, Mob, _, _, MaxMobsInArea, PlayerDistance, _)
	-- Activate mob spawner and disable editing functionality
	if Mob == nil then Mob = default_mob end
	if MaxMobsInArea == nil then MaxMobsInArea = 4  end
	if PlayerDistance == nil then PlayerDistance = 15 end
	local meta = core.get_meta(pos)
	meta:set_string("Mob", Mob)
	meta:set_int("MaxMobsInArea", MaxMobsInArea)
	meta:set_int("PlayerDistance", PlayerDistance)

	-- Create doll or replace existing doll
	local doll = find_doll(pos)
	if not doll then
		doll = spawn_doll(pos)
	end
	set_doll_properties(doll, Mob)


	-- Start spawning very soon
	local t = core.get_node_timer(pos)
	t:start(2)
end

local posns = {}

for i = 0, 242 do
	table.insert (posns, i)
end

local floor = math.floor

-- Spawn mobs around pos
-- NOTE: The node is timer-based, rather than ABM-based.
local function spawn_mobs(pos)

	-- get meta
	local meta = core.get_meta(pos)

	-- get settings
	local mob = meta:get_string("Mob")
	local num = meta:get_int("MaxMobsInArea")
	local pla = meta:get_int("PlayerDistance")

	-- if amount is 0 then do nothing
	if num == 0 then
		return
	end

	-- are we spawning a registered mob?
	if not mcl_mobs.spawning_mobs[mob] then
		core.log("error", "[mcl_mobspawners] Mob Spawner: Mob doesn't exist: "..mob)
		return
	end

	-- check objects inside 8×8 area around spawner
	local count = 0
	local ent

	local timer = core.get_node_timer(pos)

	-- spawn mob if player detected and in range
	if pla > 0 then
		local in_range = 0

		for oir in core.objects_inside_radius(pos, pla) do
			if oir:is_player() then
				in_range = 1
				break
			end
		end

		-- player not found
		if in_range == 0 then
			-- Try again quickly
			timer:start(2)
			return
		end
	end

	--[[ HACK!
	The doll may not stay spawned if the mob spawner is placed far away from
	players, so we will check for its existance periodically when a player is nearby.
	This would happen almost always when the mob spawner is placed by the mapgen.
	This is probably caused by a Minetest bug:
	https://github.com/minetest/minetest/issues/4759
	FIXME: Fix this horrible hack.
	]]
	local doll = find_doll(pos)
	if not doll then
		doll = spawn_doll(pos)
		set_doll_properties(doll, mob)
	end

	-- count mob objects of same type in area
	for obj in core.objects_inside_radius(pos, 8) do
		ent = obj:get_luaentity()

		if ent and ent.name and ent.name == mob then
			count = count + 1
		end
	end

	-- Are there too many of same type? then fail
	if count >= num then
		timer:start(math.random(5, 20))
		return
	end

	table.shuffle (posns)
	local spawned = 0
	local v1 = vector.new ()
	for _, posn in ipairs (posns) do
		local dx = posn % 9
		local dy = floor (posn / 9) % 3
		local dz = floor (posn / 27) % 9
		v1.x = pos.x + dx - 4
		v1.y = pos.y + dy
		v1.z = pos.z + dz - 4

		if mcl_mobs.spawn_abnormally (v1, mob, {}, "spawner") then
			spawned = spawned + 1
			if spawned == 4 then
				break
			end
		end
	end

	-- Spawn attempt done. Next spawn attempt much later
	timer:start (mcl_util.float_random(10, 39.95))
end

-- The mob spawner node.
-- PLACEMENT INSTRUCTIONS:
-- If this node is placed by a player, core.item_place, etc. default settings are applied
-- automatially.
-- IF this node is placed by ANY other method (e.g. core.set_node, LuaVoxelManip), you
-- MUST call mcl_mobspawners.setup_spawner right after the spawner has been placed.


core.register_node("mcl_mobspawners:spawner", {
	tiles = {"mob_spawner.png"},
	drawtype = "glasslike",
	paramtype = "light",
	description = S("Mob Spawner"),
	_tt_help = S("Makes mobs appear"),
	_doc_items_longdesc = S("A mob spawner regularily causes mobs to appear around it while a player is nearby. Some mob spawners are disabled while in light."),
	_doc_items_usagehelp = S("If you have a spawn egg, you can use it to change the mob to spawn. Just place the item on the mob spawner. Player-set mob spawners always spawn mobs regardless of the light level."),
	groups = {pickaxey=1, material_stone=1, deco_block=1, unmovable_by_piston = 1, features_cannot_replace = 1, jigsaw_preserve_meta = 1, jigsaw_construct = 1},
	is_ground_content = false,
	drop = "",

	-- If placed by player, setup spawner with default settings
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" or not placer or not placer:is_player() then
			return itemstack
		end

		local rc = mcl_util.call_on_rightclick(itemstack, placer, pointed_thing)
		if rc then return rc end

		local name = placer:get_player_name()
		local privs = core.get_player_privs(name)
		if not privs.maphack then
			core.chat_send_player(name, "Placement denied. You need the “maphack” privilege to place mob spawners.")
			return itemstack
		end
		local node_under = core.get_node(pointed_thing.under)
		local new_itemstack, success = core.item_place_node(itemstack, placer, pointed_thing)
		if success then
			local placepos
			local def = core.registered_nodes[node_under.name]
			if def and def.buildable_to then
				placepos = pointed_thing.under
			else
				placepos = pointed_thing.above
			end
			mcl_mobspawners.setup_spawner(placepos)
		end
		return new_itemstack
	end,

	on_rightclick = function(pos, _, clicker, itemstack, _)
		if not clicker:is_player() then return itemstack end
		if core.get_item_group(itemstack:get_name(),"spawn_egg") == 0 then return itemstack end
		local name = clicker:get_player_name()
		local privs = core.get_player_privs(name)
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return itemstack
		end
		if not privs.maphack then
			core.chat_send_player(name, S("You need the “maphack” privilege to change the mob spawner."))
			return itemstack
		end

		mcl_mobspawners.setup_spawner(pos, itemstack:get_name())

		if not core.is_creative_enabled(name) then
			itemstack:take_item()
		end
		return itemstack
	end,

	on_destruct = function(pos)
		-- Remove doll (if any)
		local obj = find_doll(pos)
		if obj then
			obj:remove()
		end
		mcl_experience.throw_xp(pos, math.random(15, 43))
	end,

	on_construct = function (pos)
		local meta = core.get_meta (pos)
		local mob = meta:get_string ("Mob")

		if mob and mob ~= "" then
			-- Create doll or replace existing doll
			local doll = find_doll (pos)
			if not doll then
				doll = spawn_doll (pos)
			end
			set_doll_properties (doll, mob)

			-- Start spawning very soon
			local t = core.get_node_timer (pos)
			t:start (2)
		end
	end,

	on_punch = function(pos)
		respawn_doll(pos)
	end,

	on_timer = spawn_mobs,

	sounds = mcl_sounds.node_sound_metal_defaults(),

	_mcl_hardness = 5,
})

-- Definição da Entidade Doll com suporte a persistência e rotação 3D
local doll_def = {
	initial_properties = {
		hp_max = 1,
		physical = false,
		pointable = false,
		visual = "mesh",
		makes_footstep_sound = false,
		automatic_rotate = math.pi * 2.9,
	},
	timer = 0,
	_mob = default_mob,
	_custom = false,
	_duration = -1,
	_mcl_pistons_unmovable = true,
}

-- Salva os dados para que a doll não mude ou suma ao reiniciar o servidor
doll_def.get_staticdata = function(self)
	local data = { 
		mob = self._mob, 
		custom = self._custom, 
		duration = self._duration,
		rot = self.object:get_rotation(),
		prop = self.object:get_properties()
	}
	return core.serialize(data)
end

doll_def.on_activate = function(self, staticdata)
	local data = core.deserialize(staticdata)
	if data then
		self._mob = data.mob or default_mob
		self._custom = data.custom
		self._duration = data.duration or -1
		if data.prop then self.object:set_properties(data.prop) end
		if data.rot then self.object:set_rotation(data.rot) end
	end
	set_doll_properties(self.object, self._mob)
	self.object:set_armor_groups({immortal=1})
end

doll_def.on_step = function(self, dtime)
	if self._duration ~= -1 then
		self._duration = self._duration - dtime
		if self._duration <= 0 then self.object:remove() return end
	end
	
	if self._custom then return end

	self.timer = self.timer + dtime
	if self.timer > 1 then
		local n = core.get_node_or_nil(self.object:get_pos())
		if n and n.name and n.name ~= "mcl_mobspawners:spawner" then 
			self.object:remove() 
		end
		self.timer = 0
	end
end

core.register_entity("mcl_mobspawners:doll", doll_def)

-- Utilitários de busca e parse
local function get_mob_full_name(name)
	if not name then return nil end
	if core.registered_entities[name] then return name end
	if core.registered_entities["mobs_mc:" .. name] then return "mobs_mc:" .. name end
	if core.registered_entities["mcl_mobs:" .. name] then return "mcl_mobs:" .. name end
	return nil
end

local function parse_pos(pos_str, p_pos)
	local c = pos_str:split(",")
	if #c ~= 3 then return p_pos end
	local function axis(v, a)
		if v:sub(1,1) == "~" then return a + (tonumber(v:sub(2)) or 0) end
		return tonumber(v) or a
	end
	return {x=axis(c[1], p_pos.x), y=axis(c[2], p_pos.y), z=axis(c[3], p_pos.z)}
end

-- Parser de Rotação (suporta X ou X,Y,Z)
local function parse_rotate(rot_str)
	local c = rot_str:split(",")
	if #c == 3 then
		return { x=math.rad(tonumber(c[1]) or 0), y=math.rad(tonumber(c[2]) or 0), z=math.rad(tonumber(c[3]) or 0) }
	elseif #c == 1 then
		return { x=0, y=math.rad(tonumber(c[1]) or 0), z=0 }
	end
	return {x=0, y=0, z=0}
end

-- COMANDO: /summondoll
core.register_chatcommand("summondoll", {
	params = "<mob> [pos:x,y,z] [rotate:y ou x,y,z] [size:N] [static:bool] [spin:N] [duration:N]",
	description = "Invoca doll customizada com sistema de chaves",
	privs = {server = true},
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return end

		local args = param:split(" ")
		if #args < 1 then return false, "Uso: /summondoll <mob> pos:~,~,~ size:2 rotate:0,90,0" end

		local mob_name = get_mob_full_name(args[1])
		if not mob_name then return false, "Mob não encontrado: " .. args[1] end

		-- Padrões
		local vals = {
			pos = player:get_pos(),
			rotate = {x=0, y=0, z=0},
			size = 1.0,
			static = false,
			spin = 9.1,
			duration = -1
		}

		-- Processar chaves
		for i=2, #args do
			local kv = args[i]:split(":")
			if #kv == 2 then
				local k, v = kv[1], kv[2]
				if k == "pos" then vals.pos = parse_pos(v, vals.pos)
				elseif k == "rotate" then vals.rotate = parse_rotate(v)
				elseif k == "size" then vals.size = tonumber(v) or vals.size
				elseif k == "static" then vals.static = (v == "true")
				elseif k == "spin" then vals.spin = tonumber(v) or vals.spin
				elseif k == "duration" then 
					local d = tonumber(v) or 0
					vals.duration = (d > 0) and d or -1
				end
			end
		end

		local doll = core.add_entity(vals.pos, "mcl_mobspawners:doll")
		if not doll then return false, "Erro ao criar entidade." end

		local ent = doll:get_luaentity()
		ent._custom = true
		ent._mob = mob_name
		ent._duration = vals.duration
		set_doll_properties(doll, mob_name)

		local prop = doll:get_properties()
		prop.visual_size = { x = prop.visual_size.x * vals.size, y = prop.visual_size.y * vals.size }
		prop.automatic_rotate = vals.static and 0 or vals.spin
		if vals.static then prop.physical = true end

		doll:set_properties(prop)
		doll:set_rotation(vals.rotate)

		return true, "Doll " .. mob_name .. " invocada com sucesso."
	end
})

-- COMANDO: /killdoll
core.register_chatcommand("killdoll", {
	params = "[raio]",
	description = "Remove dolls próximas",
	privs = {server = true},
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then return end
		local radius = tonumber(param) or 5
		local count = 0
		for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), radius)) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "mcl_mobspawners:doll" then
				obj:remove()
				count = count + 1
			end
		end
		return true, count .. " dolls removidas."
	end
})

-- FIXME: Doll can get destroyed by /clearobjects
core.register_lbm({
	label = "Respawn mob spawner dolls",
	name = "mcl_mobspawners:respawn_entities",
	nodenames = { "mcl_mobspawners:spawner" },
	run_at_every_load = true,
	action = function(pos)
		respawn_doll(pos)
	end,
})
