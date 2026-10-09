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

	local def = table.copy(orig)

	-- texturas do nó original
	local top_tex  = tex_name(orig.tiles[1])
	local dirt_tex = tex_name(orig.tiles[2])
	local side_ov  = orig.overlay_tiles and tex_name(orig.overlay_tiles[3])

	-- remove o sistema de paleta; a cor fica fixa na textura
	def.palette = nil
	def.color = nil
	def.overlay_tiles = nil
	def.paramtype2 = "none"
	def.param2 = nil

	-- topo: grama (cinza) multiplicada pela cor laranja
	local top = top_tex .. "^[multiply:" .. ORANGE

	-- lado: dirt ^ (overlay da grama pintado de laranja)
	local side = dirt_tex
	if side_ov then
		side = dirt_tex .. "^(" .. side_ov .. "^[multiply:" .. ORANGE .. ")"
	end

	def.tiles = { top, dirt_tex, side }
	def.description = "Grass Block (Dappled Forest)"
	def.drop = "mcl_core:dirt"
	def._mcl_silk_touch_drop = { ORANGE_GRASS }
	def._doc_items_create_entry = false
	def.groups = table.copy(orig.groups)
	def.groups.not_in_creative_inventory = 1

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
	foliage_color = "#df6827",
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
local function place_poplar_tree(x, y, z, rng)
	local leaves_options = {
		"mcl_trees:leaves_poplar",
		"mcl_trees:leaves_poplar_red",
		"mcl_trees:leaves_poplar_yellow",
	}

	local leaves = nil
	for _, leaf_name in ipairs(leaves_options) do
		if core.registered_items[leaf_name] then
			leaves = leaf_name
			break
		end
	end

	if not leaves then
		return false
	end

	local trunk = "mcl_trees:tree_poplar"
	if not core.registered_items[trunk] then
		return false
	end

	for dy = 0, 4 do
		if core.get_node({x = x, y = y + dy, z = z}).name ~= "air" then
			return false
		end
	end

	for dy = 0, 4 do
		core.set_node({x = x, y = y + dy, z = z}, {name = trunk})
	end

	for dx = -2, 2 do
		for dz = -2, 2 do
			for dy = 3, 5 do
				if math.abs(dx) + math.abs(dz) <= (dy == 5 and 1 or 2) then
					local p = {x = x + dx, y = y + dy, z = z + dz}
					if core.get_node(p).name == "air" then
						core.set_node(p, {name = leaves})
					end
				end
			end
		end
	end
	return true
end

local function try_red_shrub(x, y, z)
	local target = {x = x, y = y, z = z}
	local below = {x = x, y = y - 1, z = z}
	local target_name = core.get_node(target).name
	local below_name = core.get_node(below).name

	if target_name == "air" and (is_grass(below_name) or below_name == "mcl_core:dirt") then
		local shrub_name = modname .. ":red_shrub"
		if core.registered_items[shrub_name] then
			core.set_node(target, {name = shrub_name})
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

	-- 1) troca a grama do bioma pela grama laranja
	if core.registered_nodes[ORANGE_GRASS] then
		local grass = core.find_nodes_in_area_under_air(minp, maxp, {"mcl_core:dirt_with_grass"})
		for _, p in ipairs(grass) do
			if dappled_biome_at({x = p.x, y = p.y + 1, z = p.z}) then
				core.swap_node(p, {name = ORANGE_GRASS})
			end
		end
	end

	-- 2) árvores
	for attempt = 15, 25 do
		local x = rng:next(minp.x + 2, maxp.x - 2)
		local z = rng:next(minp.z + 2, maxp.z - 2)
		local surface_y

		for y = maxp.y - 1, minp.y + 1, -1 do
			if is_grass(core.get_node({x = x, y = y, z = z}).name) then
				surface_y = y + 1
				break
			end
		end

		if surface_y and dappled_biome_at({x = x, y = surface_y, z = z}) then
			if place_poplar_tree(x, surface_y, z, rng) then
				trees = trees + 1
			end
		end
	end

	-- 3) arbustos vermelhos
	for attempt = 1, 10 + trees * 3 do
		local x = rng:next(minp.x, maxp.x)
		local z = rng:next(minp.z, maxp.z)

		for y = maxp.y - 1, minp.y + 1, -1 do
			if is_grass(core.get_node({x = x, y = y, z = z}).name) then
				if dappled_biome_at({x = x, y = y + 1, z = z}) then
					try_red_shrub(x, y + 1, z)
				end
				break
			end
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
			{}, {"mcl_levelgen:freeze_top_layer"},
		},
		has_precipitation = true,
		temperature = 0.5,
		grass_palette_index = 19,
		groups = {is_forest = true, is_overworld = true},
		fog_color = "#c0d8ff",
		sky_color = "#7ba4ff",
	})
end