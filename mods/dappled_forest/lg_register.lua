-- Level-generation registration for the Dappled Forest (com grama laranja).
local modname = core.get_current_modname()

local ORANGE = "#df6827"
local ORANGE_GRASS = modname .. ":dirt_with_grass_orange"

---------------------------------------------------------------------------
-- Grama laranja: terra + overlay de grama pintado de laranja por cima
---------------------------------------------------------------------------
local function tex_name(t)
	if type(t) == "table" then
		return t.name
	end
	return t
end

local function register_orange_grass()
	local orig = core.registered_nodes["mcl_core:dirt_with_grass"]
	if not orig then
		core.log("warning", "[" .. modname .. "] mcl_core:dirt_with_grass nao encontrado")
		return
	end

	local def         = table.copy(orig)

	-- texturas do nó original
	local top_tex     = tex_name(orig.tiles[1])
	local dirt_tex    = tex_name(orig.tiles[2])
	local side_ov     = orig.overlay_tiles and tex_name(orig.overlay_tiles[3])

	-- remove o sistema de paleta; a cor fica fixa na textura
	def.palette       = nil
	def.color         = nil
	def.overlay_tiles = nil
	def.paramtype2    = "none"
	def.param2        = nil

	-- topo: grama (cinza) multiplicada pela cor laranja
	local top         = top_tex .. "^[multiply:" .. ORANGE

	-- lado: dirt ^ (overlay da grama pintado de laranja)
	local side        = dirt_tex
	if side_ov then
		side = dirt_tex .. "^(" .. side_ov .. "^[multiply:" .. ORANGE .. ")"
	end

	def.tiles = { top, dirt_tex, side }
	def.description = "Grass Block (Dappled Forest)"
	def.drop = "mcl_core:dirt"
	def._mcl_silk_touch_drop = { ORANGE_GRASS }
	def._doc_items_create_entry = false
	def.groups = table.copy(orig.groups)

	core.register_node(ORANGE_GRASS, def)
end

register_orange_grass()

local function is_grass(name)
	return name == "mcl_core:dirt_with_grass" or name == ORANGE_GRASS
end

---------------------------------------------------------------------------
-- Bioma
---------------------------------------------------------------------------
local core_biome = {
	name = "dappled_forest",
	node_top = core.registered_nodes[ORANGE_GRASS] and ORANGE_GRASS or "mcl_core:dirt_with_grass",
	node_filler = "mcl_core:dirt",
	depth_top = 1,
	depth_filler = 3,
	y_min = 1,
	y_max = 31000,
	heat_point = 0.45,
	humidity_point = 0.65,
	vertical_blend = 4,
	grass_color = "#df6827",
	-- foliage_color = "#df6827",
}

if core.register_biome then
	core.register_biome(core_biome)
end

local function dappled_biome_at(pos)
	if not core.get_biome_data or not core.get_biome_name then
		return false
	end
	local data = core.get_biome_data(pos)
	return data and core.get_biome_name(data.biome) == "dappled_forest"
end

---------------------------------------------------------------------------
-- Árvores e arbustos
---------------------------------------------------------------------------
local LEAVES_OPTIONS = {
	"mcl_trees:leaves_poplar",
	"mcl_trees:leaves_poplar_red",
	"mcl_trees:leaves_poplar_yellow",
}

local function pick_leaves(rng)
	local available = {}
	for _, leaf_name in ipairs(LEAVES_OPTIONS) do
		if core.registered_items[leaf_name] then
			available[#available + 1] = leaf_name
		end
	end
	if #available == 0 then
		return nil
	end
	return available[rng:next(1, #available)]
end

local function place_poplar_tree(x, y, z, rng)
	local leaves = pick_leaves(rng)
	if not leaves then
		return false
	end

	local trunk = "mcl_trees:tree_poplar"
	if not core.registered_items[trunk] then
		return false
	end

	for dy = 0, 4 do
		if core.get_node({ x = x, y = y + dy, z = z }).name ~= "air" then
			return false
		end
	end

	for dy = 0, 4 do
		core.set_node({ x = x, y = y + dy, z = z }, { name = trunk })
	end

	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = 3, 5 do
				if math.abs(dx) + math.abs(dz) <= (dy == 5 and 1 or 2) then
					local p = { x = x + dx, y = y + dy, z = z + dz }
					if core.get_node(p).name == "air" then
						core.set_node(p, { name = leaves })
					end
				end
			end
		end
	end
	return true
end

local function try_red_shrub(x, y, z)
	local target = { x = x, y = y, z = z }
	local below = { x = x, y = y - 1, z = z }
	local target_name = core.get_node(target).name
	local below_name = core.get_node(below).name

	if target_name == "air" and (is_grass(below_name) or below_name == "mcl_core:dirt") then
		local shrub_name = modname .. ":red_shrub"
		if core.registered_items[shrub_name] then
			core.set_node(target, { name = shrub_name })
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Geração
---------------------------------------------------------------------------
core.register_on_generated(function(minp, maxp, blockseed)
	local rng = PseudoRandom((blockseed or 0) + 41317)
	local trees = 0
	local base_grass = "mcl_core:dirt_with_grass"
	local surface_y_by_x = {}

	local grass = core.find_nodes_in_area_under_air(minp, maxp, { base_grass, ORANGE_GRASS })
	for _, p in ipairs(grass) do
		if p.y > minp.y and p.y < maxp.y then
			local surface_y_by_z = surface_y_by_x[p.x]
			if not surface_y_by_z then
				surface_y_by_z = {}
				surface_y_by_x[p.x] = surface_y_by_z
			end
			if not surface_y_by_z[p.z] or p.y > surface_y_by_z[p.z] then
				surface_y_by_z[p.z] = p.y
			end
		end

		if core.registered_nodes[ORANGE_GRASS] and core.get_node(p).name == base_grass
				and dappled_biome_at({ x = p.x, y = p.y + 1, z = p.z }) then
			core.swap_node(p, { name = ORANGE_GRASS })
		end
	end

	-- 2) árvores
	for attempt = 1, 25 do
		local x = rng:next(minp.x + 2, maxp.x - 2)
		local z = rng:next(minp.z + 2, maxp.z - 2)
		local surface_y_by_z = surface_y_by_x[x]
		local surface_y = surface_y_by_z and surface_y_by_z[z]

		if surface_y and dappled_biome_at({ x = x, y = surface_y + 1, z = z }) then
			if place_poplar_tree(x, surface_y + 1, z, rng) then
				trees = trees + 1
			end
		end
	end

	-- 3) arbustos vermelhos
	for attempt = 1, 10 + trees * 3 do
		local x = rng:next(minp.x, maxp.x)
		local z = rng:next(minp.z, maxp.z)
		local surface_y_by_z = surface_y_by_x[x]
		local surface_y = surface_y_by_z and surface_y_by_z[z]

		if surface_y and dappled_biome_at({ x = x, y = surface_y + 1, z = z }) then
			try_red_shrub(x, surface_y + 1, z)
		end
	end
end)

---------------------------------------------------------------------------
-- mcl_levelgen
---------------------------------------------------------------------------
if mcl_levelgen then
	mcl_levelgen.register_biome("DappledForest", {
		carvers = {
			air = {
				"mcl_levelgen:cave_carver",
				"mcl_levelgen:cave_extra_underground_carver",
				"mcl_levelgen:ravine_carver",
			},
		},
		downfall = 0.8,
		features = {
			{}, {}, {}, {}, {}, {}, {}, {}, {},
			{}, { "mcl_levelgen:freeze_top_layer" },
		},
		has_precipitation = true,
		temperature = 0.5,
		grass_palette_index = 19,
		groups = { is_forest = true, is_overworld = true },
		fog_color = "#c0d8ff",
		sky_color = "#7ba4ff",
	})
end