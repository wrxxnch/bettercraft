local S = core.get_translator(core.get_current_modname())

local mcl_comparators = core.get_modpath("mcl_comparators")

mcl_sculk = {}

local sounds = {
	footstep = {name = "mcl_sculk_block", gain = 0.2},
	dug      = {name = "mcl_sculk_block", gain = 0.2},
}

local SHRIEKER_COOLDOWN = 5
local DETECT_INTERVAL = 0.5
local SHRIEKER_RANGE  = 8
local MOVE_THRESHOLD  = 0.05

local mesecon_rules = nil
if core.global_exists("mesecon") then
	mesecon_rules = mesecon.rules.default
end

-- Função vital: Notifica comparadores e redstone ao redor
local function notify_redstone(pos)
	if core.get_modpath("mcl_comparators") then
		mcl_comparators.update_comparators(pos)
	end
	-- Se usar mesecons, isso ajuda a forçar a atualização da rede
	if core.global_exists("mesecon") then
		mesecon.update_queries(pos)
	end
end

local function spawn_echo_particles(pos)
	core.add_particlespawner({
		amount = 1,
		time = 0.5,
		minpos = {x = pos.x - 0.4, y = pos.y + 0.05, z = pos.z - 0.4},
		maxpos = {x = pos.x + 0.4, y = pos.y + 0.3,  z = pos.z + 0.4},
		minvel = {x = -0.2, y = 0.8, z = -0.2},
		maxvel = {x =  0.2, y = 1.5, z =  0.2},
		minexptime = 0.6,
		maxexptime = 1.2,
		minsize = 5,
		maxsize = 5,
		texture = "echo.png",
		glow = 12,
	})
end

-- Registro do Handler do Comparador (Lê o valor dos nós)
if core.get_modpath("mcl_comparators") then
	mcl_comparators.register_comparator_handler({"mcl_sculk:shrieker", "mcl_sculk:shrieker_active"}, function(pos, node)
		if node.name == "mcl_sculk:shrieker_active" then
			return 15
		end
		return 0
	end)
end

-- Detecção de movimento
local detect_timer = 0
core.register_globalstep(function(dtime)
	detect_timer = detect_timer + dtime
	if detect_timer < DETECT_INTERVAL then return end
	detect_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		local vel = player:get_velocity()
		if vector.length(vel) > MOVE_THRESHOLD then
			local ppos = player:get_pos()
			local shriekers = core.find_nodes_in_area(
				vector.subtract(ppos, SHRIEKER_RANGE),
				vector.add(ppos, SHRIEKER_RANGE),
				{"mcl_sculk:shrieker"}
			)
			for _, spos in ipairs(shriekers) do
				mcl_sculk.activate_shrieker(spos)
			end
		end
	end
end)

-- Shrieker Inativo
core.register_node("mcl_sculk:shrieker", {
	description = S("Sculk Shrieker"),
	drawtype = "mesh",
	mesh = "mcl_sculk_shrieker.obj",
	tiles = {"mcl_sculk_shrieker_side.png", "mcl_sculk_shrieker_bottom.png", "mcl_sculk_shrieker_top.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_off = 1},
	sounds = sounds,
	mesecons = {receptor = {state = "off", rules = mesecon_rules}},
	_mcl_hardness = 3,
})

-- Função de ativação
function mcl_sculk.activate_shrieker(pos)
	local node = core.get_node(pos)
	local meta = core.get_meta(pos)
	
	-- Usamos gametime para evitar problemas com relógio do sistema
	local last = meta:get_int("last_shriek")
	local now = core.get_gametime()
	if now - last <= SHRIEKER_COOLDOWN then return end

	-- 1. Troca o nó
	core.set_node(pos, {name = "mcl_sculk:shrieker_active", param2 = node.param2})
	
	-- 2. Atualiza a Redstone IMEDIATAMENTE
	notify_redstone(pos)

	-- 3. Efeitos
	core.sound_play("mcl_sculk_shrieker_shriek", {pos = pos, gain = 2.0, max_hear_distance = 32})
	spawn_echo_particles(pos)

	if core.global_exists("mesecon") then
		mesecon.receptor_on(pos, mesecon_rules)
	end

	-- 4. Salva o cooldown no novo meta (set_node limpa o meta anterior)
	local new_meta = core.get_meta(pos)
	new_meta:set_int("last_shriek", now)
	core.get_node_timer(pos):start(2.0)
end

-- Shrieker Ativo
core.register_node("mcl_sculk:shrieker_active", {
	description = S("Sculk Shrieker Active"),
	drawtype = "mesh",
	mesh = "mcl_sculk_shrieker.obj",
	tiles = {"mcl_sculk_shrieker_side.png", "mcl_sculk_shrieker_bottom.png", "mcl_sculk_shrieker_top.png"},
	paramtype = "light",
	paramtype2 = "facedir",
	light_source = 7,
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_on = 1, not_in_creative_inventory = 1},
	drop = "mcl_sculk:shrieker",
	sounds = sounds,
	mesecons = {receptor = {state = "on", rules = mesecon_rules}},
	on_timer = function(pos, elapsed)
		local node = core.get_node(pos)
		local meta = core.get_meta(pos)
		local last_val = meta:get_int("last_shriek")

		-- Volta para o inativo
		core.set_node(pos, {name = "mcl_sculk:shrieker", param2 = node.param2})
		
		-- Salva o cooldown no meta do bloco inativo
		local m = core.get_meta(pos)
		m:set_int("last_shriek", last_val)

		-- Notifica que desligou
		notify_redstone(pos)
		
		if core.global_exists("mesecon") then
			mesecon.receptor_off(pos, mesecon_rules)
		end
		return false
	end,
	_mcl_hardness = 3,
})