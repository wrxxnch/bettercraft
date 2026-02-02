--------------------------------------------------
-- TABELA PRINCIPAL
--------------------------------------------------
blockframe = {}
blockframe.active = {}

--------------------------------------------------
-- PARSER DE ARGS
--------------------------------------------------
function blockframe.parse_args(param)
	local args = {}
	for word in param:gmatch("%S+") do
		local k,v = word:match("([^=]+)=([^=]+)")
		if k then args[k] = v end
	end
	return args
end

--------------------------------------------------
-- BLOCO NA MÃO
--------------------------------------------------
function blockframe.get_wielded_node(player)
	local stack = player:get_wielded_item()
	if stack:is_empty() then return end

	local name = stack:get_name()
	if minetest.registered_nodes[name] then
		return name
	end
end

--------------------------------------------------
-- SPAWN / UPDATE PREVIEW
--------------------------------------------------
function blockframe.spawn_preview(player, args)
	local name = player:get_player_name()
	local node = blockframe.get_wielded_node(player)

	if not node then
		return false, "Segure um bloco válido"
	end

	if blockframe.active[name] then
		local ent = blockframe.active[name].entity
		ent.node = node
		ent.object:set_properties({ wield_item = node })
		ent:apply_args(args)
		return true
	end

	local obj = minetest.add_entity(
		player:get_pos(),
		"blockframe:preview",
		minetest.serialize({ node = node })
	)

	if not obj then return end

	local ent = obj:get_luaentity()
	ent.player = player
	ent:apply_args(args)

	blockframe.active[name] = {
		entity = ent
	}

	return true
end

--------------------------------------------------
-- /blockframe
--------------------------------------------------
minetest.register_chatcommand("blockframe", {
	description = "Cria preview do bloco na mão",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return end

		local args = blockframe.parse_args(param)
		return blockframe.spawn_preview(player, args)
	end
})

--------------------------------------------------
-- /blockframe_set
--------------------------------------------------
minetest.register_chatcommand("blockframe_set", {
	description = "Confirma BlockFrame",
	func = function(name)
		local data = blockframe.active[name]
		if not data then return false, "Nenhum preview ativo" end

		local ent = data.entity
		if not ent.last_pos then return false, "Sem posição válida" end

		minetest.add_entity(
			ent.last_pos,
			"blockframe:placed",
			minetest.serialize({
				node = ent.node,
				args = ent.args
			})
		)

		ent.object:remove()
		blockframe.active[name] = nil

		return true, "BlockFrame criado"
	end
})

--------------------------------------------------
-- /blockframe_cancel
--------------------------------------------------
minetest.register_chatcommand("blockframe_cancel", {
	func = function(name)
		if blockframe.active[name] then
			blockframe.active[name].entity.object:remove()
			blockframe.active[name] = nil
		end
	end
})

--------------------------------------------------
-- REMOVE AO SAIR
--------------------------------------------------
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if blockframe.active[name] then
		blockframe.active[name].entity.object:remove()
		blockframe.active[name] = nil
	end
end)

--------------------------------------------------
-- TOOL REMOVE
--------------------------------------------------
minetest.register_tool("blockframe:removeblockframe", {
	description = "Remove BlockFrame",
	inventory_image = "default_stick.png^[colorize:#ff0000:180",

	on_use = function(_, user, pointed)
		if pointed.type ~= "object" then return end
		local obj = pointed.ref
		if obj and obj:get_luaentity()
		and obj:get_luaentity().name == "blockframe:placed" then
			obj:remove()
		end
	end
})

--------------------------------------------------
-- ENTIDADES
--------------------------------------------------
dofile(minetest.get_modpath("blockframe") .. "/entity.lua")
