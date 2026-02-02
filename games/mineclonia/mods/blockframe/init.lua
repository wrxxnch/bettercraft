-- ==================================================
-- TABELA PRINCIPAL (SÓ AQUI)
-- ==================================================
blockframe = {}
blockframe.active = {}
blockframe.players = {} -- ⬅️ NOVO


----------------------------------------------------
-- SPAWN PREVIEW (fica no init.lua!)
----------------------------------------------------
function blockframe.spawn_preview(player, node)
	local name = player:get_player_name()

	-- remove preview anterior
	if blockframe.active[name] then
		blockframe.active[name].entity.object:remove()
	end

	local obj = minetest.add_entity(
		player:get_pos(),
		"blockframe:preview",
		minetest.serialize({ node = node })
	)

	if not obj then return end

	local ent = obj:get_luaentity()
	ent.player = player

	blockframe.active[name] = {
		entity = ent,
		node = node
	}
end

----------------------------------------------------
-- CARREGA ENTIDADES (NÃO REDEFINE blockframe)
----------------------------------------------------
dofile(minetest.get_modpath("blockframe") .. "/entity.lua")

----------------------------------------------------
-- /blockframe  (COM ou SEM args)
----------------------------------------------------
minetest.register_chatcommand("blockframe", {
	description = "Preview de bloco (usa item na mão se vazio)",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return end

		local node = param

		-- sem argumento → usa item da mão
		if node == "" then
			local stack = player:get_wielded_item()
			if stack:is_empty() then
				return false, "Segure um bloco ou use /blockframe <node>"
			end
			node = stack:get_name()
		end

		if not minetest.registered_nodes[node] then
			return false, "Item não é um bloco colocável: " .. node
		end

		blockframe.spawn_preview(player, node)
		return true, "Preview ativo"
	end
})

----------------------------------------------------
-- /blockframe_set  (CONFIRMA COMO ENTIDADE)
----------------------------------------------------
minetest.register_chatcommand("blockframe_set", {
	description = "Confirma e cria BlockFrame (entidade)",
	func = function(name)
		local data = blockframe.active[name]
		if not data or not data.entity then
			return false, "Nenhum BlockFrame ativo"
		end

		local ent = data.entity
		if not ent.last_pos then
			return false, "Sem posição válida"
		end

		minetest.add_entity(
			ent.last_pos,
			"blockframe:placed",
			minetest.serialize({
				node = data.node
			})
		)

		ent.object:remove()
		blockframe.active[name] = nil

		return true, "BlockFrame criado (ENTIDADE)"
	end
})

----------------------------------------------------
-- /blockframe_cancel
----------------------------------------------------
minetest.register_chatcommand("blockframe_cancel", {
	func = function(name)
		if blockframe.active[name] then
			blockframe.active[name].entity.object:remove()
			blockframe.active[name] = nil
		end
	end
})
