-- Level-generation registration for the Dappled Forest.
local modname = core.get_current_modname()

local core_biome = {
	name = "dappled_forest",
	node_top = "mcl_core:dirt_with_grass",
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

-- Safe fallback tree generator. It avoids core.read_schematic so the mod
-- also works with Windows builds whose MTS reader rejects custom MTS files.
local function dappled_biome_at(pos)
	if not core.get_biome_data or not core.get_biome_name then
		return false
	end
	local data = core.get_biome_data(pos)
	return data and core.get_biome_name(data.biome) == "dappled_forest"
end

local function place_poplar_tree(x, y, z, rng)
	local trunk = "mcl_trees:tree_poplar"
	local leaves = ({
		"mcl_trees:leaves_poplar",
		"mcl_trees:leaves_poplar_red",
		"mcl_trees:leaves_poplar_yellow",
	})[1 + rng:next(1, 3)]
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
	if target_name == "air" and (below_name == "mcl_core:dirt_with_grass" or below_name == "mcl_core:dirt") then
		core.set_node(target, {name = modname .. ":red_shrub"})
		return true
	end
	return false
end

core.register_on_generated(function(minp, maxp, blockseed)
	local rng = PseudoRandom((blockseed or 0) + 41317)
	local trees = 0
	for attempt = 1, 3 do
		local x = rng:next(minp.x + 2, maxp.x - 2)
		local z = rng:next(minp.z + 2, maxp.z - 2)
		local surface_y
		for y = maxp.y - 1, minp.y + 1, -1 do
			if core.get_node({x = x, y = y, z = z}).name == "mcl_core:dirt_with_grass" then
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
	for attempt = 1, 10 + trees * 3 do
		local x = rng:next(minp.x, maxp.x)
		local z = rng:next(minp.z, maxp.z)
		for y = maxp.y - 1, minp.y + 1, -1 do
			if core.get_node({x = x, y = y, z = z}).name == "mcl_core:dirt_with_grass" then
				if dappled_biome_at({x = x, y = y + 1, z = z}) then
					try_red_shrub(x, y + 1, z)
				end
				break
			end
		end
	end
end)

-- Keep the complete biome definition available to BetterCraft's levelgen.
-- Tree and shrub placement above is deliberately engine-native and does not
-- depend on register_portable_schematic/core.read_schematic.
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
