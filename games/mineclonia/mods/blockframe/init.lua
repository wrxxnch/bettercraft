--------------------------------------------------
-- TABELA PRINCIPAL
--------------------------------------------------
blockframe = {}
blockframe.active = {}
blockframe.memory = {}

--------------------------------------------------
-- HELP
--------------------------------------------------
function blockframe.help_text()
	return [[
📦 BlockFrame — Ajuda

Uso:
/blockframe <args>
/blockframe_set

O bloco usado é SEMPRE o que está na sua mão.

ARGS:
 size=x,y,z        tamanho
 rotate=graus      rotação Y
 mirror=x|y|z      espelho
 pos=x,y,z         offset livre
 step=valor        snap da mira

Exemplos:
/blockframe size=1,1,1 rotate=90
/blockframe pos=0,1,0 step=0.1
/blockframe size=0.5,0.5,0.5 mirror=x
/blockframe rotate=45 pos=0,-0.1,0 step=0.05

Confirmar:
/blockframe_set
]]
end

--------------------------------------------------
-- PARSER
--------------------------------------------------
function blockframe.parse_args(param)
	local args = {}
	for w in param:gmatch("%S+") do
		local k,v = w:match("([^=]+)=([^=]+)")
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

	-- fallback memória
	if not node and blockframe.memory[name] then
		node = blockframe.memory[name].node
	end
	if not node then return end

	-- update
	if blockframe.active[name] and blockframe.active[name].entity then
		local ent = blockframe.active[name].entity
		ent:set_node(node)
		ent:apply_args(args)
		return
	end

	local obj = minetest.add_entity(
		player:get_pos(),
		"blockframe:preview",
		minetest.serialize({ node = node })
	)
	if not obj then return end

	blockframe.active[name] = {
		object = obj,
		entity = nil
	}

	minetest.after(0, function()
		if not blockframe.active[name] then return end
		if not obj or not obj:get_luaentity() then return end

		local ent = obj:get_luaentity()
		if not ent then return end

		ent.player = player
		ent:set_node(node)
		ent:apply_args(args)

		blockframe.active[name].entity = ent
	end)
end

--------------------------------------------------
-- /blockframe
--------------------------------------------------
minetest.register_chatcommand("blockframe", {
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		blockframe.spawn_preview(player, blockframe.parse_args(param))
		return true
	end
})

--------------------------------------------------
-- /blockframe_set
--------------------------------------------------
minetest.register_chatcommand("blockframe_set", {
	func = function(name)
		local data = blockframe.active[name]
		local mem  = blockframe.memory[name]

		if not data and not mem then
			return false, "Nenhum BlockFrame anterior"
		end

		local node, args, pos

		if data and data.entity and data.entity.last_pos then
			local ent = data.entity
			node = ent.node
			args = table.copy(ent.args or {})
			pos  = vector.new(ent.last_pos)
			ent.object:remove()
			blockframe.active[name] = nil
		else
			node = mem.node
			args = table.copy(mem.args or {})
			pos  = vector.new(mem.pos)
		end

		minetest.add_entity(
			pos,
			"blockframe:placed",
			minetest.serialize({ node = node, args = args })
		)

		blockframe.memory[name] = {
			node = node,
			args = table.copy(args),
			pos  = vector.new(pos)
		}

		return true, "BlockFrame colocado"
	end
})

--------------------------------------------------
-- /blockframe_help
--------------------------------------------------
minetest.register_chatcommand("blockframe_help", {
	func = function()
		return true, blockframe.help_text()
	end
})

--------------------------------------------------
-- SALVA AO SAIR
--------------------------------------------------
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local data = blockframe.active[name]
	if not data or not data.entity then return end
	local ent = data.entity
	if not ent.last_pos then return end

	blockframe.memory[name] = {
		node = ent.node,
		args = table.copy(ent.args or {}),
		pos  = vector.new(ent.last_pos)
	}

	ent.object:remove()
	blockframe.active[name] = nil
end)

--------------------------------------------------
-- LOAD ENTITIES
--------------------------------------------------
dofile(minetest.get_modpath("blockframe") .. "/entity.lua")
