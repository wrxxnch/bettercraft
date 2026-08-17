local S = core.get_translator(core.get_current_modname())
mcl_sculk = {}

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
local SENSOR_COOLDOWN = 4
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

-- Partícula de "eco" (ondas de vibração), disparada quando o shrieker/sensor detecta movimento.
-- Coloque o arquivo em textures/echo.png (16x16, pode ser uma tira/anel simples).
local function spawn_echo_particles(pos)
	core.add_particlespawner({
		amount = 12,
		time = 0.5,
		minpos = {x = pos.x - 0.4, y = pos.y + 0.05, z = pos.z - 0.4},
		maxpos = {x = pos.x + 0.4, y = pos.y + 0.3,  z = pos.z + 0.4},
		minvel = {x = -0.2, y = 0.8, z = -0.2},
		maxvel = {x =  0.2, y = 1.5, z =  0.2},
		minacc = {x = 0, y = 0.3, z = 0}, -- acelera pra cima em vez de cair
		maxacc = {x = 0, y = 0.6, z = 0},
		minexptime = 0.6,
		maxexptime = 1.2,
		minsize = 1.5,
		maxsize = 3,
		texture = "echo.png",
		glow = 12,
	})
end

-- Varre jogadores conectados; se algum estiver se movendo, procura shriekers/sensores
-- por perto e os ativa (respeitando o cooldown de cada um, guardado nos metadados do node).
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

			local sensors = core.find_nodes_in_area(
				{x = ppos.x - SENSOR_RANGE, y = ppos.y - SENSOR_RANGE, z = ppos.z - SENSOR_RANGE},
				{x = ppos.x + SENSOR_RANGE, y = ppos.y + SENSOR_RANGE, z = ppos.z + SENSOR_RANGE},
				{"mcl_sculk:calibrated_sensor"}
			)
			for _, spos in ipairs(sensors) do
				mcl_sculk.activate_sensor(spos)
			end
		end
	end
end)

-- Vinhas de Sculk (CORRIGIDO: Transparência)
core.register_node("mcl_sculk:vein", {
	description = S("Sculk Vein"),
	drawtype = "nodebox",
	tiles = {"mcl_sculk_vein.png"},
	inventory_image = "mcl_sculk_vein.png",
	paramtype = "light", -- Essencial para não ficar preto
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	use_texture_alpha = "clip", -- Aqui o "clip" é correto: é uma decal fina, precisa mesmo de buracos transparentes
	walkable = false,
	buildable_to = true,
	node_box = { type = "wallmounted" },
	groups = {handy = 1, axey = 1, shearsy = 1, deco_block = 1, sculk = 1, attached_node = 1},
	sounds = sounds,
	_mcl_hardness = 0.2,
})

-- Shrieker (Inativo)
-- Convertido a partir do modelo oficial (blockbench/JSON com ~262 quads) para um MESH real,
-- em vez de um nodebox simples. Isso é o que resolve de vez o "buraco vazio" no centro: o topo
-- do modelo oficial tem uma textura própria (inner_top) visível entre os espinhos, que a versão
-- em nodebox simplesmente não tinha como desenhar (nodebox só aceita 6 tiles no total, não uma
-- textura por elemento). Ordem dos materiais no .obj: side, inner_top, bottom, top — a lista de
-- "tiles" abaixo TEM que seguir essa mesma ordem.
core.register_node("mcl_sculk:shrieker", {
	description = S("Sculk Shrieker"),
	drawtype = "mesh",
	mesh = "mcl_sculk_shrieker.obj",
	tiles = {
		"mcl_sculk_shrieker_side.png",
		"mcl_sculk_shrieker_inner_top.png^[verticalframe:7:0", -- estático: só o frame 0 da tira de 7
		"mcl_sculk_shrieker_bottom.png",
		"mcl_sculk_shrieker_top.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	use_texture_alpha = "opaque",
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_off = 1},
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

-- Ativa o shrieker: chamado pelo globalstep de detecção de movimento (não mais um "on_step"
-- morto — register_node não tem esse callback, então antes isso nunca disparava de verdade).
function mcl_sculk.activate_shrieker(pos)
	local node = core.get_node(pos)
	if node.name ~= "mcl_sculk:shrieker" then return end -- já está ativo ou não é mais um shrieker

	local meta = core.get_meta(pos)
	local last = meta:get_int("last_shriek")
	local now = os.time()
	if now - last <= SHRIEKER_COOLDOWN then return end

	core.swap_node(pos, {name = "mcl_sculk:shrieker_active", param2 = node.param2})
	core.sound_play("mcl_sculk_shrieker_shriek", {pos = pos, gain = 2.0, max_hear_distance = 32})
	spawn_echo_particles(pos)

	if core.global_exists("mesecon") then
		mesecon.receptor_on(pos, mesecon_rules)
	end

	local new_meta = core.get_meta(pos)
	new_meta:set_int("last_shriek", now)
	core.get_node_timer(pos):start(2.0) -- Tempo que fica ligado
end

-- Shrieker (Ativo) - Para enviar sinal ao comparador
core.register_node("mcl_sculk:shrieker_active", {
	description = S("Sculk Shrieker Active"),
	drawtype = "mesh",
	mesh = "mcl_sculk_shrieker.obj",
	tiles = {
		"mcl_sculk_shrieker_side.png",
		{
			name = "mcl_sculk_shrieker_inner_top.png",
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 2.0, -- duração de um ciclo completo (7 frames), casa com o tempo do timer do shriek
			},
		},
		"mcl_sculk_shrieker_bottom.png",
		"mcl_sculk_shrieker_top.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	use_texture_alpha = "opaque",
	light_source = 7,
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_on = 1, not_in_creative_inventory = 1},
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

-- Outros blocos (Sculk, Catalisador, Sensor...)
-- Certifique-se de adicionar use_texture_alpha = "clip" apenas em blocos que realmente tenham
-- partes vazadas/transparentes (como a vein). Para blocos sólidos, prefira "opaque".

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

--------------------------------------------------------------------------
-- Sculk Sensor Calibrado (Calibrated Sculk Sensor)
--------------------------------------------------------------------------
-- Diferente do sensor comum: só detecta uma frequência específica de
-- vibração (ajustável clicando no bloco com o botão direito), e precisa
-- de um pulso de redstone na "cara" dele pra ficar "escutando". Aqui a
-- calibração é simplificada: clique direito cicla a frequência (1 a 5),
-- e ele funciona como receptor de mesecons emitindo pulso ao detectar.

local function get_frequency(pos)
	local meta = core.get_meta(pos)
	local freq = meta:get_int("frequency")
	if freq < 1 then freq = 1 end
	return freq
end

-- core.register_node("mcl_sculk:calibrated_sensor", {
-- 	description = S("Calibrated Sculk Sensor"),
-- 	drawtype = "nodebox",
-- 	tiles = {
-- 		"mcl_sculk_calibrated_sensor_top.png",
-- 		"mcl_sculk_calibrated_sensor_bottom.png",
-- 		"mcl_sculk_calibrated_sensor_side.png",
-- 		"mcl_sculk_calibrated_sensor_side.png",
-- 		"mcl_sculk_calibrated_sensor_side.png",
-- 		"mcl_sculk_calibrated_sensor_side.png",
-- 	},
-- 	paramtype = "light",
-- 	paramtype2 = "facedir",
-- 	sunlight_propagates = true,
-- 	use_texture_alpha = "opaque", -- bloco sólido, evita o mesmo bug do shrieker
-- 	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_off = 1},
-- 	sounds = sounds,
-- 	node_box = {
-- 		type = "fixed",
-- 		fixed = {
-- 			{-0.5, -0.5, -0.5, 0.5, -0.125, 0.5},      -- base do bloco
-- 			{-0.1875, -0.125, -0.1875, 0.1875, 0.1875, 0.1875}, -- "cristal" central (sensor)
-- 		},
-- 	},
-- 	mesecons = {receptor = {state = "off", rules = mesecon_rules}},
-- 	after_place_node = function(pos, placer)
-- 		local meta = core.get_meta(pos)
-- 		meta:set_int("frequency", 1)
-- 		meta:set_string("infotext", S("Frequency: @1", 1))
-- 	end,
-- 	on_rightclick = function(pos, node, clicker)
-- 		if not clicker or not clicker:is_player() then return end
-- 		local meta = core.get_meta(pos)
-- 		local freq = get_frequency(pos) % MAX_FREQUENCY + 1
-- 		meta:set_int("frequency", freq)
-- 		meta:set_string("infotext", S("Frequency: @1", freq))
-- 		core.sound_play("mcl_sculk_sensor_click", {pos = pos, gain = 0.6, max_hear_distance = 8})
-- 		core.chat_send_player(clicker:get_player_name(), S("Sculk sensor frequency set to @1", freq))
-- 	end,
-- 	_mcl_hardness = 1.5,
-- })

-- Ativa o sensor calibrado: chamado pelo globalstep de detecção de movimento, mesma razão
-- do shrieker (o antigo "on_step" no register_node nunca era executado pelo engine).
function mcl_sculk.activate_sensor(pos)
	local node = core.get_node(pos)
	if node.name ~= "mcl_sculk:calibrated_sensor" then return end

	local meta = core.get_meta(pos)
	local last = meta:get_int("last_pulse")
	local now = os.time()
	if now - last <= SENSOR_COOLDOWN then return end

	local freq = get_frequency(pos)
	core.swap_node(pos, {name = "mcl_sculk:calibrated_sensor_active", param2 = node.param2})
	core.sound_play("mcl_sculk_sensor_click", {pos = pos, gain = 1.0, max_hear_distance = 16})
	spawn_echo_particles(pos)

	if core.global_exists("mesecon") then
		mesecon.receptor_on(pos, mesecon_rules)
	end

	local new_meta = core.get_meta(pos)
	new_meta:set_int("frequency", freq)
	new_meta:set_int("last_pulse", now)
	new_meta:set_string("infotext", S("Frequency: @1", freq))
	core.get_node_timer(pos):start(1.5)
end

core.register_node("mcl_sculk:calibrated_sensor_active", {
	description = S("Calibrated Sculk Sensor Active"),
	drawtype = "nodebox",
	tiles = {
		"mcl_sculk_calibrated_sensor_top.png",
		"mcl_sculk_calibrated_sensor_bottom.png",
		"mcl_sculk_calibrated_sensor_side.png",
		"mcl_sculk_calibrated_sensor_side.png",
		"mcl_sculk_calibrated_sensor_side.png",
		"mcl_sculk_calibrated_sensor_side.png",
	},
	paramtype = "light",
	paramtype2 = "facedir",
	sunlight_propagates = true,
	use_texture_alpha = "opaque",
	light_source = 6,
	groups = {handy = 1, hoey = 1, sculk = 1, mesecon_receptor_on = 1, not_in_creative_inventory = 1},
	drop = "mcl_sculk:calibrated_sensor",
	sounds = sounds,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.5, -0.5, -0.5, 0.5, -0.125, 0.5},
			{-0.1875, -0.125, -0.1875, 0.1875, 0.1875, 0.1875},
		},
	},
	mesecons = {receptor = {state = "on", rules = mesecon_rules}},
	on_timer = function(pos, elapsed)
		core.swap_node(pos, {name = "mcl_sculk:calibrated_sensor"})
		if core.global_exists("mesecon") then
			mesecon.receptor_off(pos, mesecon_rules)
		end
		return false
	end,
	_mcl_hardness = 1.5,
})