--------------------------------------------------
-- INIT.LUA COMPLETO - BLOCKFRAME (UPDATED V11)
--------------------------------------------------

blockframe = {}
blockframe.active = {} -- [name] = { type="single"|"composite", entities={}, ... }
blockframe.memory = {}
blockframe.del_history = {}
blockframe.world_path = minetest.get_worldpath()

--load gizmos
dofile(minetest.get_modpath("blockframe") .. "/gizmo.lua")

--------------------------------------------------
-- HELP
-------------------------------------------------- 
function blockframe.help_text()
    return [[
📦 BlockFrame — Ajuda (Português)

━━━━━━━━━━━━━━━━━━━━
📌 COMANDOS
━━━━━━━━━━━━━━━━━━━━

/blockframe <args>
/blockframe_set
/blockframe_cancel
/blockframe_undo

/blockframe_del radius=N
/blockframe_del_undo

/blockframe_apply radius=N <args>
/blockframe_undo_apply

/blockframe_save <nome> radius=N
/blockframe_load <nome> <args>

/blockframe_help

━━━━━━━━━━━━━━━━━━━━
⚙ ARGS (Preview / Load / Apply)
━━━━━━━━━━━━━━━━━━━━

size=x,y,z        tamanho/escala (ex: 1,1,1 ou 0.5)
rotate=x,y,z      rotação XYZ em graus
mirror=x|y|z      espelhamento em eixo
pos=x,y,z         posição absoluta ou offset
step=valor        snap da mira (ex: 0.5)
collision=true    ativa colisão
glow=N            nível de brilho (0–14)
node=true/false   true = forma de node, false = item

━━━━━━━━━━━━━━━━━━━━
🧠 APPLY (Editar em Área)
━━━━━━━━━━━━━━━━━━━━

radius=N          raio ao redor do jogador

Exemplo:
 /blockframe_apply radius=10 size=2
 → altera todos blockframes próximos

 /blockframe_undo_apply
 → desfaz o último apply

━━━━━━━━━━━━━━━━━━━━
💡 EXEMPLOS
━━━━━━━━━━━━━━━━━━━━

/blockframe size=0.5 rotate=0,45,0
/blockframe_apply radius=5 glow=10
/blockframe_load minha_casa size=2 rotate=0,90,0

]]
end

--------------------------------------------------
-- PARSER
--------------------------------------------------
function blockframe.parse_args(param)
	local args = {}
	for w in param:gmatch("%S+") do
		local k,v = w:match("([^=]+)=([^=]+)")
		if k then 
			if v == "true" then v = true 
			elseif v == "false" then v = false 
			elseif tonumber(v) then v = tonumber(v)
			end
			args[k] = v 
		end
	end
	return args
end

--------------------------------------------------
-- FUNÇÕES AUXILIARES
--------------------------------------------------
local function parse_vec(str, def)
	if not str then return def end
	if type(str) == "table" then return str end
	local vals = {}
	for n in str:gmatch("([^,]+)") do
		table.insert(vals, tonumber(n))
	end
	if #vals == 1 then return {x=vals[1], y=vals[1], z=vals[1]} end
	if #vals == 2 then return {x=vals[1], y=vals[2], z=vals[2]} end
	if #vals >= 3 then return {x=vals[1], y=vals[2], z=vals[3]} end
	return def
end

local function snap(v, step)
	if not step or step <= 0 then return v end
	return {
		x = math.floor(v.x / step + 0.5) * step,
		y = math.floor(v.y / step + 0.5) * step,
		z = math.floor(v.z / step + 0.5) * step
	}
end

local function safe(v)
    return math.max(0.001, math.abs(v or 0))
end

local function get_wielded_item(player)
	local stack = player:get_wielded_item()
	if stack:is_empty() then return end
	return stack:get_name()
end

-- Aplica transformações (escala, rotação, espelho)
local function apply_transform(base_val, transform_val, is_rotation)
	if not transform_val then return base_val end
	if is_rotation then
		return {
			x = (base_val.x or 0) + (transform_val.x or 0),
			y = (base_val.y or 0) + (transform_val.y or 0),
			z = (base_val.z or 0) + (transform_val.z or 0)
		}
	else
		-- Escala multiplicativa
		return {
			x = (base_val.x or 1) * (transform_val.x or 1),
			y = (base_val.y or 1) * (transform_val.y or 1),
			z = (base_val.z or 1) * (transform_val.z or 1)
		}
	end
end

local function update_entity_properties(self)

    -- 🛠️ CORREÇÃO: sempre garantir vetor
    local base_size = self.args.size

    if type(base_size) == "number" then
        base_size = {x = base_size, y = base_size, z = base_size}

    elseif type(base_size) == "string" then
        base_size = parse_vec(base_size, {x=0.5,y=0.5,z=0.5})

    elseif type(base_size) ~= "table" then
        base_size = {x=0.5,y=0.5,z=0.5}
    end

    -- fallback de segurança
    base_size.x = base_size.x or 0.5
    base_size.y = base_size.y or 0.5
    base_size.z = base_size.z or 0.5

    local visual_v = table.copy(base_size)

    -- mirror
    if self.args.mirror=="x" then visual_v.x=-visual_v.x end
    if self.args.mirror=="y" then visual_v.y=-visual_v.y end
    if self.args.mirror=="z" then visual_v.z=-visual_v.z end

    local props = {
        visual_size = visual_v,
        physical = false,
        pointable = true,
        collisionbox = {0,0,0,0,0,0}
    }

    -- colisão
    if self.args.collision then
        props.physical = true

        local size = {
            x = math.abs(base_size.x),
            y = math.abs(base_size.y),
            z = math.abs(base_size.z)
        }

        props.collisionbox = {
            -size.x/2, -size.y/2, -size.z/2,
             size.x/2,  size.y/2,  size.z/2
        }
    end

    if self.args.glow then
        props.glow = tonumber(self.args.glow) or 0
    end

    self.object:set_properties(props)

    -- rotação
    if self.args.rotate then
        local rot = self.args.rotate

        if type(rot) == "number" then
            rot = {x=0,y=rot,z=0}
        elseif type(rot) == "string" then
            rot = parse_vec(rot, {x=0,y=0,z=0})
        elseif type(rot) ~= "table" then
            rot = {x=0,y=0,z=0}
        end

        self.object:set_rotation({
            x = math.rad(rot.x or 0),
            y = math.rad(rot.y or 0),
            z = math.rad(rot.z or 0)
        })
    end
end

-- Shared function to apply arguments to any blockframe entity
local function shared_apply_args(self, args, global_args)
	local final_args = table.copy(self.args or {})
	local new_args = table.copy(args or {})

	-- 🔴 CONVERSÕES IMPORTANTES
	if new_args.size then
		new_args.size = parse_vec(new_args.size, {x=0.5,y=0.5,z=0.5})
	end
	if new_args.rotate then
		new_args.rotate = parse_vec(new_args.rotate, {x=0,y=0,z=0})
	end

	-- Merge new_args into final_args
	for k, v in pairs(new_args) do
		final_args[k] = v
	end
		
	-- Merge with global_args (from /blockframe_load)
	if global_args then
		if global_args.size then 
			local scale = parse_vec(global_args.size, {x=1,y=1,z=1})
			final_args.size = apply_transform(final_args.size or {x=0.5,y=0.5,z=0.5}, scale, false)
		end
		if global_args.rotate then
			local rot_offset = parse_vec(global_args.rotate, {x=0,y=0,z=0})
			final_args.rotate = apply_transform(final_args.rotate or {x=0,y=0,z=0}, rot_offset, true)
		end
		if global_args.mirror then final_args.mirror = global_args.mirror end
		if global_args.collision ~= nil then final_args.collision = global_args.collision end
		if global_args.glow then final_args.glow = global_args.glow end
		if global_args.step then final_args.step = global_args.step end
	end

	self.args = final_args
	update_entity_properties(self)
end

--------------------------------------------------
-- ENTIDADES
--------------------------------------------------
minetest.register_entity("blockframe:preview", {
	initial_properties = {
		visual = "wielditem", physical = false, pointable = false, glow = 5,
		visual_size = {x=0.5,y=0.5}, collisionbox = {0,0,0,0,0,0}, static_save = false,
	},
	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata) or {}
		self.node = data.node or "default:stone"
		self.args = {}
		self.player_name = data.player_name
		self.rel_pos = data.rel_pos or {x=0,y=0,z=0}
		self.object:set_properties({wield_item=self.node, opacity=120})
	end,
	apply_args = shared_apply_args,
	on_step = function(self)
		local player = minetest.get_player_by_name(self.player_name)
		if not player then return end
		local active = blockframe.active[self.player_name]
		if not active then return end
	end
})

minetest.register_entity("blockframe:placed", {
	initial_properties = {
		visual="wielditem", physical=false, pointable=true, static_save=true,
		visual_size={x=0.5,y=0.5}, collisionbox={0,0,0,0,0,0},
	},
	on_activate=function(self,staticdata)
		local data = minetest.deserialize(staticdata) or {}
		self.node = data.node or "default:stone"
		self.args = data.args or {}
		self.object:set_properties({wield_item=self.node})
		update_entity_properties(self)
		if self.args.pos then 
			local p = parse_vec(self.args.pos)
			if p then self.object:set_pos(p) end
		end
	end,
	apply_args = shared_apply_args,
	get_staticdata=function(self)
		-- Sincronizar propriedades visuais antes de salvar
		local props = self.object:get_properties()
		local rot = self.object:get_rotation()
		self.args.size = props.visual_size
		self.args.rotate = {x=math.deg(rot.x), y=math.deg(rot.y), z=math.deg(rot.z)}
		self.args.pos = self.object:get_pos()
		self.args.glow = props.glow
		return minetest.serialize({node=self.node, args=self.args})
	end
})

--------------------------------------------------
-- CENTRAL PREVIEW LOGIC
--------------------------------------------------
minetest.register_globalstep(function(dtime)
	for name, data in pairs(blockframe.active) do
		local player = minetest.get_player_by_name(name)
		if player then
			local eye = vector.add(player:get_pos(), {x=0, y=player:get_properties().eye_height or 1.6, z=0})
			local dir = player:get_look_dir()
			local ray = minetest.raycast(vector.add(eye, vector.multiply(dir, 0.2)), vector.add(eye, vector.multiply(dir, 6)), true, true)
			
			local hit_pos
			for hit in ray do
				if hit.type ~= "object" or hit.ref ~= player then
					hit_pos = hit.intersection_point or hit.above
					break
				end
			end
			
			if hit_pos then
				hit_pos = snap(hit_pos, data.step or 0)
				hit_pos = vector.add(hit_pos, data.offset or {x=0,y=0,z=0})
				data.last_pos = hit_pos
				
				for _, ent_obj in ipairs(data.entities) do
					local ent = ent_obj:get_luaentity()
					if ent then
						local final_pos = vector.add(hit_pos, ent.rel_pos or {x=0,y=0,z=0})
						ent_obj:set_pos(final_pos)
					end
				end
			end
		end
	end
end)

--------------------------------------------------
-- SPAWN HELPERS
--------------------------------------------------
function blockframe.clear_active(name)
	if blockframe.active[name] then
		for _, obj in ipairs(blockframe.active[name].entities) do
			if obj:get_luaentity() then obj:remove() end
		end
		blockframe.active[name] = nil
	end
end

--------------------------------------------------
-- COMANDOS
--------------------------------------------------
minetest.register_chatcommand("blockframe",{
	func=function(name,param)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		local args = blockframe.parse_args(param)
		
		blockframe.clear_active(name)
		
		local node = get_wielded_item(player)
		if not node and blockframe.memory[name] then node=blockframe.memory[name].node end
		if not node then return false, "Segure um bloco ou use um anterior." end
		
		local obj = minetest.add_entity(player:get_pos(), "blockframe:preview", minetest.serialize({node=node, player_name=name}))
		if obj then
			local ent = obj:get_luaentity()
			ent:apply_args(args)
			blockframe.active[name] = {
				type = "single",
				entities = {obj},
				step = tonumber(args.step) or 0,
				offset = parse_vec(args.pos, {x=0,y=0,z=0})
			}
		end
		return true
	end
})

minetest.register_chatcommand("blockframe_load", {
	params = "<nome> [args]",
	func = function(name, param)
		local filename, args_str = param:match("^(%S+)%s*(.*)$")
		if not filename then return false, "Uso: /blockframe_load <nome> [args]" end
		
		local filepath = blockframe.world_path .. "/" .. filename .. ".bf"
		local file = io.open(filepath, "r")
		if not file then return false, "Arquivo não encontrado." end
		local data = minetest.deserialize(file:read("*all"))
		file:close()
		
		if not data or not data.entities then return false, "Arquivo inválido." end
		
		blockframe.clear_active(name)
		local global_args = blockframe.parse_args(args_str)
		local preview_objs = {}
		
		-- CALCULAR CENTRO PARA CENTRALIZAÇÃO
		local min_p, max_p = {x=0,y=0,z=0}, {x=0,y=0,z=0}
		if #data.entities > 0 then
			min_p = table.copy(data.entities[1].rel_pos)
			max_p = table.copy(data.entities[1].rel_pos)
			for i=2, #data.entities do
				local p = data.entities[i].rel_pos
				min_p.x, max_p.x = math.min(min_p.x, p.x), math.max(max_p.x, p.x)
				min_p.y, max_p.y = math.min(min_p.y, p.y), math.max(max_p.y, p.y)
				min_p.z, max_p.z = math.min(min_p.z, p.z), math.max(max_p.z, p.z)
			end
		end
		local center_offset = {
			x = (min_p.x + max_p.x) / 2,
			y = (min_p.y + max_p.y) / 2,
			z = (min_p.z + max_p.z) / 2
		}

		local player = minetest.get_player_by_name(name)
		for _, e in ipairs(data.entities) do
			local adjusted_rel = vector.subtract(e.rel_pos, center_offset)
			local obj = minetest.add_entity(player:get_pos(), "blockframe:preview", 
				minetest.serialize({node=e.node, player_name=name, rel_pos=adjusted_rel}))
			if obj then
				local ent = obj:get_luaentity()
				ent:apply_args(e.args, global_args)
				table.insert(preview_objs, obj)
			end
		end
		
		blockframe.active[name] = {
			type = "composite",
			entities = preview_objs,
			step = tonumber(global_args.step) or tonumber(data.entities[1] and data.entities[1].args.step) or 0,
			offset = parse_vec(global_args.pos, {x=0,y=0,z=0})
		}
		
		return true, "Preview carregado (centralizado). Use /blockframe_set para confirmar."
	end
})

minetest.register_chatcommand("blockframe_set",{
	func=function(name)
		local data = blockframe.active[name]
		if not data then return false, "Nenhum preview ativo." end
		
		local count = 0
		for _, obj in ipairs(data.entities) do
			local ent = obj:get_luaentity()
			if ent then
				local pos = obj:get_pos()
				local final_args = table.copy(ent.args)
				final_args.pos = pos
				minetest.add_entity(pos, "blockframe:placed", minetest.serialize({node=ent.node, args=final_args}))
				
				blockframe.memory[name] = {node=ent.node, args=final_args, pos=pos}
				count = count + 1
			end
		end
		
		blockframe.clear_active(name)
		return true, "Confirmado: " .. count .. " bloco(s) colocado(s)."
	end
})

function blockframe.save_map(filename, center_pos, radius)
	local objs = minetest.get_objects_inside_radius(center_pos, radius)
	local data = { version = 1, entities = {} }
	for _, obj in ipairs(objs) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "blockframe:placed" then
			-- Capturar estado atual completo
			local props = obj:get_properties()
			local rot = obj:get_rotation()
			ent.args.size = props.visual_size
			ent.args.rotate = {x=math.deg(rot.x), y=math.deg(rot.y), z=math.deg(rot.z)}
			ent.args.pos = obj:get_pos()
			ent.args.glow = props.glow

			table.insert(data.entities, {
				node = ent.node,
				rel_pos = vector.subtract(obj:get_pos(), center_pos),
				args = table.copy(ent.args)
			})
		end
	end
	local file = io.open(blockframe.world_path .. "/" .. filename .. ".bf", "w")
	if file then file:write(minetest.serialize(data)); file:close(); return true, #data.entities end
	return false, "Erro ao salvar."
end

minetest.register_chatcommand("blockframe_save", {
	params = "<nome> [radius=N]",
	func = function(name, param)
		local filename, args_str = param:match("^(%S+)%s*(.*)$")
		if not filename then return false, "Uso: /blockframe_save <nome> [radius=N]" end
		local args = blockframe.parse_args(args_str)
		local radius = tonumber(args.radius) or 10
		local player = minetest.get_player_by_name(name)
		local success, count = blockframe.save_map(filename, player:get_pos(), radius)
		if success then return true, "Salvo: " .. count .. " blocos." else return false, count end
	end
})

minetest.register_chatcommand("blockframe_cancel",{
	func=function(name)
		if not blockframe.active[name] then return false, "Nenhum preview para cancelar." end
		blockframe.clear_active(name)
		return true, "Preview cancelado."
	end
})

minetest.register_chatcommand("blockframe_undo",{
	func=function(name)
		local mem = blockframe.memory[name]
		if not mem then return false,"Nenhum bloco para desfazer." end
		local objs = minetest.get_objects_inside_radius(mem.pos, 0.5)
		for _,obj in ipairs(objs) do
			local luaent = obj:get_luaentity()
			if luaent and luaent.name=="blockframe:placed" then obj:remove(); break end
		end
		blockframe.memory[name]=nil
		return true,"Desfeito."
	end
})

minetest.register_chatcommand("blockframe_del", {
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local args = blockframe.parse_args(param)
		local radius = tonumber(args.radius) or 2
		local objs = minetest.get_objects_inside_radius(player:get_pos(), radius)
		local removed_list = {}
		for _, obj in ipairs(objs) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "blockframe:placed" then
				table.insert(removed_list, {node = ent.node, pos = obj:get_pos(), args = table.copy(ent.args)})
				obj:remove()
			end
		end
		blockframe.del_history[name] = removed_list
		return true, "Removido " .. #removed_list .. " blocos."
	end
})

minetest.register_chatcommand("blockframe_del_undo", {
	func = function(name)
		local history = blockframe.del_history[name]
		if not history then return false, "Nada para desfazer." end
		for _, item in ipairs(history) do
			minetest.add_entity(item.pos, "blockframe:placed", minetest.serialize({node=item.node, args=item.args}))
		end
		blockframe.del_history[name] = nil
		return true, "Restaurado."
	end
})

minetest.register_chatcommand("blockframe_apply", {
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		local args = blockframe.parse_args(param)
		local radius = tonumber(args.radius) or 5
		local objs = minetest.get_objects_inside_radius(player:get_pos(), radius)
		local count = 0
		for _, obj in ipairs(objs) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "blockframe:placed" then
				if ent.apply_args then
					ent:apply_args(args)
					count = count + 1
				end
			end
		end
		return true, "Aplicado a " .. count .. " blocos."
	end
})

minetest.register_chatcommand("blockframe_help", { func = function() return true, blockframe.help_text() end })

minetest.register_on_leaveplayer(function(player) 
	local name = player:get_player_name()
	blockframe.clear_active(name)
end)
