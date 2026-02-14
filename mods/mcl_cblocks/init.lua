-- mcl_cblocks: Colored Blocks for Mineclonia
-- ==============================
-- LISTA DE CORES
-- ==============================
local colors = {
	{name="white", desc="White", hex="#FFFFFF", dye="white"},
	{name="orange", desc="Orange", hex="#F9801D", dye="orange"},
	{name="magenta", desc="Magenta", hex="#C74EBD", dye="magenta"},
	{name="light_blue", desc="Light Blue", hex="#3AB3DA", dye="light_blue"},
	{name="yellow", desc="Yellow", hex="#FED83D", dye="yellow"},
	{name="lime", desc="Lime", hex="#80C71F", dye="lime"},
	{name="pink", desc="Pink", hex="#F38BAA", dye="pink"},
	{name="gray", desc="Gray", hex="#474F52", dye="gray"},
	{name="silver", desc="Silver", hex="#9D9D97", dye="silver"},
	{name="cyan", desc="Cyan", hex="#169C9C", dye="cyan"},
	{name="purple", desc="Purple", hex="#8932B8", dye="purple"},
	{name="blue", desc="Blue", hex="#3C44AA", dye="blue"},
	{name="brown", desc="Brown", hex="#835432", dye="brown"},
	{name="green", desc="Green", hex="#5E7C16", dye="green"},
	{name="red", desc="Red", hex="#B02E26", dye="red"},
	{name="black", desc="Black", hex="#1D1D21", dye="black"},
}

-- ==============================
-- LISTA DE NODES BASE
-- ==============================
local base_nodes = {
	"mcl_core:stonebrick",
	"mcl_trees:wood_oak",
	"mcl_core:cobble",
}

-- ==============================
-- FUNÇÃO PRINCIPAL
-- ==============================
local function register_colored_block(base_node)
	local base_def = minetest.registered_nodes[base_node]
	if not base_def then
		minetest.log("error", "[mcl_cblocks] Nó base não encontrado: " .. base_node)
		return
	end

	local id = base_node:match(":(.+)")
	local base_desc = base_def.description or id

	for _, color in ipairs(colors) do
		local node_name = "mcl_cblocks:" .. id .. "_" .. color.name
		local def = table.copy(base_def)

		def.groups = table.copy(base_def.groups or {})
		def.groups.colored_block = 1
		def.description = color.desc .. " " .. base_desc

		-- =================================================================
		-- SOLUÇÃO DEFINITIVA PARA TEXTURA: USANDO OVERLAY
		-- Em vez de 'colorize', que pode apagar a textura, usamos uma sobreposição.
		-- Isso mantém a textura original (ex: da madeira) e aplica a cor por cima.
		-- 'mcl_cblocks_overlay.png' é uma imagem 1x1 pixel da cor branca.
		-- =================================================================
		local new_tiles = {}
		local base_tiles = base_def.tiles or base_def.tile_images
		
		if type(base_tiles) == "table" then
			for _, tile in ipairs(base_tiles) do
				local tile_name = (type(tile) == "table") and tile.name or tile
				table.insert(new_tiles, {
					name = tile_name,
					color = color.hex,
				})
			end
		end
		
		def.tiles = new_tiles
		def.tile_images = nil -- Garante que a engine use a definição de 'tiles'

		minetest.register_node(":" .. node_name, def)

		-- =================================================================
		-- REGISTRO DE ESCADAS E LAJES (se o mod existir)
		-- =================================================================
		if minetest.get_modpath("mcl_stairs") then
			mcl_stairs.register_stair_and_slab(
				id .. "_" .. color.name,
				node_name,
				def.groups,
				def.tiles,
				color.desc .. " " .. base_desc .. " Stair",
				color.desc .. " " .. base_desc .. " Slab",
				def.sounds
			)
		end

		-- =================================================================
		-- CRAFTING SHAPELESS (qualquer posição)
		-- 8 blocos + 1 corante = 8 blocos coloridos.
		-- =================================================================
		minetest.register_craft({
			type = "shapeless",
			output = node_name .. " 1",
			recipe = {
               "mcl_dyes:" .. color.dye, base_node,

			}
		})
	end
end

-- ==============================
-- LOOP PARA REGISTRAR TUDO
-- ==============================
for _, node in ipairs(base_nodes) do
	register_colored_block(node)
end

minetest.log("action", "[mcl_cblocks] Blocos coloridos carregados com sucesso!")
