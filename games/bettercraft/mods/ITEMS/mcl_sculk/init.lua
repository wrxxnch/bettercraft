local S = core.get_translator(core.get_current_modname())
local modpath = core.get_modpath(core.get_current_modname())

mcl_sculk = mcl_sculk or {}
-- dofile(modpath .. "/shrieker.lua")


-- Configurações
local spread_to = {
	"mcl_core:stone","mcl_core:dirt","mcl_core:sand","mcl_core:dirt_with_grass",
	"group:grass_block","mcl_core:andesite","mcl_core:diorite","mcl_core:granite",
	"mcl_core:mycelium","group:dirt","mcl_end:end_stone","mcl_nether:netherrack",
	"mcl_blackstone:basalt","mcl_nether:soul_sand","mcl_blackstone:soul_soil",
	"mcl_crimson:warped_nylium","mcl_crimson:crimson_nylium","mcl_core:gravel",
	"mcl_deepslate:deepslate","mcl_deepslate:tuff"
}

local sounds = {
	footstep = {name = "mcl_sculk_block", gain = 0.2},
	dug      = {name = "mcl_sculk_block", gain = 0.2},
}

local SHRIEKER_COOLDOWN = 5
local SENSOR_COOLDOWN = 1
local MAX_FREQUENCY = 5

-- Configuração da detecção de movimento (vibração)
local DETECT_INTERVAL = 0.5     -- a cada quantos segundos o mod varre os jogadores
local SHRIEKER_RANGE  = 8       -- alcance em nodes (igual ao vanilla)
local SENSOR_RANGE    = 8
local MOVE_THRESHOLD  = 0.05    -- velocidade mínima (m/s) pra contar como "se movendo"

-- Regras de Redstone
local mesecon_rules = nil
if core.global_exists("mesecon") then
	mesecon_rules = mesecon.rules.default
end

-- Partícula de "eco"
local function spawn_echo_particles(pos)
	core.add_particlespawner({
		amount = 1,
		time = 0.5,
		minpos = {x = pos.x - 0.4, y = pos.y + 0.05, z = pos.z - 0.4},
		maxpos = {x = pos.x + 0.4, y = pos.y + 0.3,  z = pos.z + 0.4},
		minvel = {x = -0.2, y = 0.8, z = -0.2},
		maxvel = {x =  0.2, y = 1.5, z =  0.2},
		minacc = {x = 0, y = 0.3, z = 0},
		maxacc = {x = 0, y = 0.6, z = 0},
		minexptime = 0.6,
		maxexptime = 1.2,
		minsize = 5,
		maxsize = 5,
		texture = "echo.png",
		glow = 12,
	})
end

-- Globalstep para detecção de movimento
local detect_timer = 0
core.register_globalstep(function(dtime)
	detect_timer = detect_timer + dtime
	if detect_timer < DETECT_INTERVAL then return end
	detect_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		local vel = player:get_velocity()
		local speed = math.sqrt(vel.x * vel.x + vel.z * vel.z)
		if speed > MOVE_THRESHOLD then
			local ppos = player:get_pos()

			local shriekers = core.find_nodes_in_area(
				{x = ppos.x - SHRIEKER_RANGE, y = ppos.y - SHRIEKER_RANGE, z = ppos.z - SHRIEKER_RANGE},
				{x = ppos.x + SHRIEKER_RANGE, y = ppos.y + SHRIEKER_RANGE, z = ppos.z + SHRIEKER_RANGE},
				{"mcl_sculk:shrieker"}
			)
			for _, spos in ipairs(shriekers) do
				mcl_sculk.activate_shrieker(spos)
			end
		end
	end
end)

-- Vinhas de Sculk
core.register_node("mcl_sculk:vein", {
	description = S("Sculk Vein"),
	drawtype = "nodebox",
	tiles = {"mcl_sculk_vein.png"},
	inventory_image = "mcl_sculk_vein.png",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	use_texture_alpha = "clip",
	walkable = false,
	buildable_to = true,
	node_box = { type = "wallmounted" },
	groups = {handy = 1, axey = 1, shearsy = 1, deco_block = 1, sculk = 1, attached_node = 1},
	sounds = sounds,
	_mcl_hardness = 0.2,
})

-- Shrieker (Inativo)
-- Ordem dos materiais no .obj (mcl_sculk_shrieker.obj): side, inner_top, bottom, top.
-- IMPORTANTE: "tiles" precisa ter as 4 entradas nessa mesma ordem. Com só 3, o Luanti não sabe
-- que textura usar para o material "inner_top" e o topo volta a aparecer errado/vazio — é o
-- mesmo bug do "buraco no centro" que já tínhamos corrigido antes.
-- comparator_signal = 0: sinal fixo emitido para comparadores enquanto inativo.
core.register_node("mcl_sculk:shrieker", {
	description = S("Sculk Shrieker"),
	drawtype = "mesh",
	mesh = "mcl_sculk_shrieker.obj",
	tiles = {
		"mcl_sculk_shrieker_side.png",
		"mcl_sculk_shrieker_bottom.png",
		"mcl_sculk_shrieker_top.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	use_texture_alpha = "opaque",
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_off = 1, comparator_signal = 0},
	sounds = sounds,
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.4375, 0.5},
	},
	collision_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.4375, 0.5},
	},
	mesecons = {receptor = {state = "off", rules = mesecon_rules}},
	_mcl_hardness = 3,
})

-- Função de Ativação do Shrieker
function mcl_sculk.activate_shrieker(pos)
	local node = core.get_node(pos)
	if node.name ~= "mcl_sculk:shrieker" then return end

	local meta = core.get_meta(pos)
	local last = meta:get_int("last_shriek")
	local now = os.time()
	if now - last <= SHRIEKER_COOLDOWN then return end

	-- Troca o nó para o estado Ativo (que tem comparator_signal = 15 no grupo,
	-- então qualquer comparador apontado pra cá já lê o novo valor sozinho)
	core.swap_node(pos, {name = "mcl_sculk:shrieker_active", param2 = node.param2})

	core.sound_play("mcl_sculk_shrieker_shriek", {pos = pos, gain = 2.0, max_hear_distance = 32})
	spawn_echo_particles(pos)

	if core.global_exists("mesecon") then
		mesecon.receptor_on(pos, mesecon_rules)
	end

	local new_meta = core.get_meta(pos)
	new_meta:set_int("last_shriek", now)
	core.get_node_timer(pos):start(2.0)
end

-- Shrieker (Ativo)
-- comparator_signal = 15: sinal fixo (força máxima) emitido para comparadores enquanto ativo.
core.register_node("mcl_sculk:shrieker_active", {
	description = S("Sculk Shrieker Active"),
	drawtype = "mesh",
	mesh = "mcl_sculk_shrieker.obj",
	tiles = {
		"mcl_sculk_shrieker_side.png",
		"mcl_sculk_shrieker_bottom.png",
		"mcl_sculk_shrieker_top.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	use_texture_alpha = "opaque",
	light_source = 7,
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_on = 1, not_in_creative_inventory = 1, comparator_signal = 15},
	drop = "mcl_sculk:shrieker",
	sounds = sounds,
	selection_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.4375, 0.5},
	},
	collision_box = {
		type = "fixed",
		fixed = {-0.5, -0.5, -0.5, 0.5, 0.4375, 0.5},
	},
	mesecons = {receptor = {state = "on", rules = mesecon_rules}},
	on_timer = function(pos, elapsed)
		core.swap_node(pos, {name = "mcl_sculk:shrieker"})

		if core.global_exists("mesecon") then
			mesecon.receptor_off(pos, mesecon_rules)
		end
		return false
	end,
	_mcl_hardness = 3,
})

-- Blocos Sólidos
core.register_node("mcl_sculk:sculk", {
	description = S("Sculk"),
	tiles = {{ name = "mcl_sculk_sculk.png", animation = {type = "vertical_frames", aspect_w = 16, aspect_h = 16, length = 3.0}}},
	groups = {handy = 1, hoey = 1, building_block=1, sculk = 1, unmovable_by_piston = 1},
	sounds = sounds,
	_mcl_hardness = 0.6,
	_mcl_silk_touch_drop = true,
})

core.register_node("mcl_sculk:catalyst", {
	description = S("Sculk Catalyst"),
	tiles = {"mcl_sculk_catalyst_top.png", "mcl_sculk_catalyst_bottom.png", "mcl_sculk_catalyst_side.png"},
	groups = {handy = 1, hoey = 1, building_block=1, sculk = 1},
	light_source = 6,
	sounds = sounds,
	_mcl_hardness = 3,
})

-- =========================================================
-- COMPARADORES
-- =========================================================
-- Removido o antigo "mcl_comparators.register_comparator_handler" / "update_comparators":
-- essas funções não existem na API real do mcl_comparators (VoxeLibre/MineClone2), por isso
-- nunca faziam nada (a condição com "and" falhava silenciosamente, sem erro no log).
--
-- O jeito real e oficial de um node emitir um sinal fixo pro comparador é o grupo
-- "comparator_signal = X" (ver GROUPS.md do VoxeLibre). Por isso: mcl_sculk:shrieker tem
-- comparator_signal = 0 e mcl_sculk:shrieker_active tem comparator_signal = 15, lá em cima
-- na definição de cada node. Nenhuma chamada extra é necessária — o comparador lê o grupo
-- do node à sua frente quando é atualizado (o próprio mesecon.receptor_on/off já dispara essa
-- atualização de redstone na vizinhança).