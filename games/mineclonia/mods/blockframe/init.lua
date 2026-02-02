--------------------------------------------------
-- TABELA PRINCIPAL
--------------------------------------------------
blockframe = {}
blockframe.active = {}
blockframe.memory = {} -- memoria por player

blockframe = blockframe or {}

function blockframe.help_text()
	return [[
📦 BlockFrame — Ajuda

Uso básico:
  /blockframe <args>
  /blockframe_set

O bloco usado é SEMPRE o que está na sua mão.

━━━━━━━━━━━━━━━━━━━━
ARGS DISPONÍVEIS
━━━━━━━━━━━━━━━━━━━━

size=x,y,z
  Define o tamanho do bloco
  Ex: size=1,1,1
      size=0.5,2,0.5

rotate=graus
  Rotação em Y (horizontal)
  Ex: rotate=45
      rotate=90

mirror=x|y|z
  Espelha o bloco em um eixo
  Ex: mirror=x
      mirror=y

pos=x,y,z
  Offset manual da posição
  Ex: pos=0,1,0
      pos=0,-0.1,0

step=valor
  Precisão da mira (snap)
  Ex: step=0.1
      step=0.25
      step=0 (livre)

━━━━━━━━━━━━━━━━━━━━
EXEMPLOS COMPLETOS
━━━━━━━━━━━━━━━━━━━━

/blockframe size=1,1,1 rotate=90
/blockframe pos=0,1,0 step=0.1
/blockframe size=0.5,0.5,0.5 mirror=x
/blockframe rotate=45 pos=0,-0.1,0 step=0.05

Confirmar colocação:
  /blockframe_set

Colocar novamente o último:
  /blockframe_set

Cancelar preview:
  /blockframe_cancel
]]
end


--------------------------------------------------
-- PARSER DE ARGS
--------------------------------------------------
function blockframe.parse_args(param)
	local args = {}
	for word in param:gmatch("%S+") do
		local k, v = word:match("([^=]+)=([^=]+)")
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
	local n = stack:get_name()
	if minetest.registered_nodes[n] then return n end
end

--------------------------------------------------
-- SPAWN / UPDATE PREVIEW
--------------------------------------------------
function blockframe.spawn_preview(player, args)
	local name = player:get_player_name()
	local node = blockframe.get_wielded_node(player)

	-- fallback para memória
	if not node and blockframe.memory[name] then
		node = blockframe.memory[name].node
	end
	if not node then return end

	if blockframe.active[name] then
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
	local ent = obj:get_luaentity()
	ent.player = player
	ent:set_node(node)
	ent:apply_args(args)

	blockframe.active[name] = { entity = ent }
end

--------------------------------------------------
-- /blockframe
--------------------------------------------------
minetest.register_chatcommand("blockframe", {
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		local args = blockframe.parse_args(param)
		blockframe.spawn_preview(player, args)
		return true
	end
})

--------------------------------------------------
-- /blockframe_set
--------------------------------------------------
minetest.register_chatcommand("blockframe_set", {
	func = function(name)
		local mem = blockframe.memory[name]
		local data = blockframe.active[name]

		if not data and not mem then
			return false, "Nenhum BlockFrame anterior"
		end

		local node, args, pos

		if data then
			local ent = data.entity
			if not ent.last_pos then return false, "Sem posição válida" end
			node = ent.node
			args = ent.args
			pos = ent.last_pos
			ent.object:remove()
			blockframe.active[name] = nil
		else
			node = mem.node
			args = mem.args
			pos = mem.pos
		end

		minetest.add_entity(
			pos,
			"blockframe:placed",
			minetest.serialize({ node = node, args = args })
		)

		blockframe.memory[name] = {
			node = node,
			args = table.copy(args),
			pos = pos
		}

		return true, "BlockFrame colocado"
	end
})

minetest.register_chatcommand("blockframe_help", {
	description = "Mostra a ajuda do BlockFrame",
	func = function(name)
		return true, blockframe.help_text()
	end
})


--------------------------------------------------
-- LIMPA AO SAIR
--------------------------------------------------
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	if blockframe.active[name] then
		blockframe.active[name].entity.object:remove()
		blockframe.active[name] = nil
	end
end)

--------------------------------------------------
-- CARREGA ENTIDADES
--------------------------------------------------
dofile(minetest.get_modpath("blockframe") .. "/entity.lua")
