--------------------------------------------------
-- INIT.LUA COMPLETO - BLOCKFRAME (UPDATED)
--------------------------------------------------

blockframe = {}
blockframe.active = {}
blockframe.memory = {}
blockframe.world_path = minetest.get_worldpath()

--------------------------------------------------
-- HELP
--------------------------------------------------
function blockframe.help_text()
	return [[
📦 BlockFrame — Ajuda

Uso:
/blockframe <args>
/blockframe_set
/blockframe_cancel
/blockframe_undo
/blockframe_del radius=N
/blockframe_save <nome> radius=N
/blockframe_load <nome> collision=true|false
/blockframe_help

ARGS:
 size=x,y,z        tamanho (1 valor = x=y=z)
 rotate=x,y,z      rotação XYZ
 mirror=x|y|z      espelho
 pos=x,y,z         posição absoluta
 step=valor        snap da mira
 collision=true    ativa colisão (apenas no set/load)

Exemplos:
/blockframe size=0.1
/blockframe_save meu_mapa radius=10
/blockframe_load meu_mapa collision=true
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
			-- Converter booleanos
			if v == "true" then v = true 
			elseif v == "false" then v = false 
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

local function get_wielded_item(player)
	local stack = player:get_wielded_item()
	if stack:is_empty() then return end
	return stack:get_name()
end

-- Função para atualizar colisão e visual
local function update_entity_properties(self)
	local base = self.args.size or {x=0.5,y=0.5,z=0.5}
	local v = table.copy(base)
	
	-- Mirror
	if self.args.mirror=="x" then v.x=-v.x end
	if self.args.mirror=="y" then v.y=-v.y end
	if self.args.mirror=="z" then v.z=-v.z end
	
	local props = {visual_size = v}
	
	-- Collision
local is_preview = (self.name == "blockframe:preview")

if self.args.collision and not is_preview then
	props.physical = true
	local sx, sy, sz = math.abs(v.x), math.abs(v.y), math.abs(v.z)
	props.collisionbox = {-sx, -sy, -sz, sx, sy, sz}
	props.pointable = true
else
	props.physical = false
	props.collisionbox = {0,0,0,0,0,0}
	props.pointable = not is_preview
end

	
	self.object:set_properties(props)
	
	-- Rotation
	if self.args.rotate then
		local rot = self.args.rotate
		if type(rot) == "table" then
			self.object:set_rotation({
				x = math.rad(rot.x or 0),
				y = math.rad(rot.y or 0),
				z = math.rad(rot.z or 0)
			})
		end
	end
end

--------------------------------------------------
-- ENTIDADES
--------------------------------------------------
-- PREVIEW
minetest.register_entity("blockframe:preview", {
	initial_properties = {
		visual = "wielditem",
		physical = false,
		pointable = false,
		glow = 5,
		visual_size = {x=0.5,y=0.5},
		collisionbox = {0,0,0,0,0,0},
		static_save = false,
	},
	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata) or {}
		self.node = data.node or "default:stone"
		self.args = {}
		self.step = 0
		self.player = nil
		self.last_pos = nil
		self.offset = {x=0,y=0,z=0}
		self.object:set_properties({wield_item=self.node, opacity=120})
	end,
	set_node = function(self,node)
		self.node = node
		self.object:set_properties({wield_item=node})
	end,
	apply_args = function(self,args)
		if args.size then self.args.size = parse_vec(args.size,{x=0.5,y=0.5,z=0.5}) end
		if args.mirror=="x" or args.mirror=="y" or args.mirror=="z" then self.args.mirror = args.mirror end
		if args.step then self.step = tonumber(args.step) or 0 end
		if args.collision ~= nil then self.args.collision = args.collision end
		if args.pos then
			local p = parse_vec(args.pos,{x=0,y=0,z=0})
			self.offset = p
			self.args.pos = p
		end
		if args.rotate then
			if type(args.rotate) == "string" then
				local rx,ry,rz = args.rotate:match("([^,]+),([^,]+),([^,]+)")
				if rx and ry and rz then
					self.args.rotate = {x=tonumber(rx) or 0, y=tonumber(ry) or 0, z=tonumber(rz) or 0}
				else
					local r = tonumber(args.rotate)
					self.args.rotate = r and {x=0,y=r,z=0} or {x=0,y=0,z=0}
				end
			else
				self.args.rotate = args.rotate
			end
		end
		update_entity_properties(self)
	end,
	on_step = function(self)
		if not self.player or not self.player:is_player() then return end
		local eye = vector.add(self.player:get_pos(),
			self.player:get_properties().eye_height and {x=0,y=self.player:get_properties().eye_height,z=0} or {x=0,y=1.6,z=0})
		local dir = self.player:get_look_dir()
		local start = vector.add(eye, vector.multiply(dir,0.2))
		local finish = vector.add(start, vector.multiply(dir,6))
		local ray = minetest.raycast(start, finish, true, true)
		for hit in ray do
			if hit.type=="object" and hit.ref==self.player then goto continue end
			local p = hit.intersection_point or hit.above
			if p then
				p = snap(p,self.step)
				p = vector.add(p,self.offset)
				self.object:set_pos(p)
				self.last_pos = p
				return
			end
			::continue::
		end
	end
})

-- PLACED
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
		if self.args.pos then self.object:set_pos(self.args.pos) end
	end,
	get_staticdata=function(self)
		return minetest.serialize({node=self.node,args=self.args})
	end
})

--------------------------------------------------
-- SPAWN / UPDATE PREVIEW
--------------------------------------------------
function blockframe.spawn_preview(player,args)
	local name = player:get_player_name()
	local node = get_wielded_item(player)
	if not node and blockframe.memory[name] then node=blockframe.memory[name].node end
	if not node then return end
	
	if blockframe.active[name] and blockframe.active[name].entity then
		local ent = blockframe.active[name].entity
		ent:set_node(node)
		ent:apply_args(args)
		return
	end
	
	local obj = minetest.add_entity(player:get_pos(),"blockframe:preview",minetest.serialize({node=node}))
	if not obj then return end
	blockframe.active[name]={object=obj, entity=nil}
	minetest.after(0,function()
		if not blockframe.active[name] then return end
		local ent = obj:get_luaentity()
		if not ent then return end
		ent.player = player
		ent:set_node(node)
		ent:apply_args(args)
		blockframe.active[name].entity = ent
	end)
end

--------------------------------------------------
-- SAVE / LOAD SYSTEM
--------------------------------------------------
function blockframe.save_map(filename, center_pos, radius)
	local objs = minetest.get_objects_inside_radius(center_pos, radius)
	local data = {
		version = 1,
		entities = {}
	}
	
	for _, obj in ipairs(objs) do
		local ent = obj:get_luaentity()
		if ent and ent.name == "blockframe:placed" then
			local rel_pos = vector.subtract(obj:get_pos(), center_pos)
			table.insert(data.entities, {
				node = ent.node,
				rel_pos = rel_pos,
				args = ent.args
			})
		end
	end
	
	local filepath = blockframe.world_path .. "/" .. filename .. ".bf"
	local file = io.open(filepath, "w")
	if file then
		file:write(minetest.serialize(data))
		file:close()
		return true, #data.entities
	end
	return false, "Erro ao abrir arquivo para escrita"
end

function blockframe.load_map(filename, center_pos, extra_args)
	local filepath = blockframe.world_path .. "/" .. filename .. ".bf"
	local file = io.open(filepath, "r")
	if not file then return false, "Arquivo não encontrado" end
	
	local content = file:read("*all")
	file:close()
	
	local data = minetest.deserialize(content)
	if not data or not data.entities then return false, "Arquivo corrompido ou inválido" end
	
	for _, e in ipairs(data.entities) do
		local pos = vector.add(center_pos, e.rel_pos)
		local args = table.copy(e.args)
		
		-- Sobrescrever argumentos se passados no comando (ex: collision)
		for k, v in pairs(extra_args) do
			args[k] = v
		end
		
		args.pos = pos
		minetest.add_entity(pos, "blockframe:placed", minetest.serialize({node=e.node, args=args}))
	end
	
	return true, #data.entities
end

--------------------------------------------------
-- COMANDOS
--------------------------------------------------
minetest.register_chatcommand("blockframe",{
	func=function(name,param)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		blockframe.spawn_preview(player,blockframe.parse_args(param))
		return true
	end
})

minetest.register_chatcommand("blockframe_set",{
	func=function(name)
		local data = blockframe.active[name]
		local mem = blockframe.memory[name]
		if not data and not mem then return false,"Nenhum BlockFrame anterior" end
		local node,args,pos
		if data and data.entity and data.entity.last_pos then
			local ent = data.entity
			node = ent.node
			args = table.copy(ent.args or {})
			pos = vector.new(ent.last_pos)
			args.pos = pos
			ent.object:remove()
			blockframe.active[name]=nil
		else
			node = mem.node
			args = table.copy(mem.args or {})
			pos = vector.new(mem.pos)
			args.pos = pos
		end
		minetest.add_entity(pos,"blockframe:placed",minetest.serialize({node=node,args=args}))
		blockframe.memory[name]={node=node,args=table.copy(args),pos=vector.new(pos)}
		return true,"BlockFrame colocado"
	end
})

minetest.register_chatcommand("blockframe_save", {
	params = "<nome> [radius=N]",
	description = "Salva BlockFrames em um arquivo .bf",
	func = function(name, param)
		local filename, args_str = param:match("^(%S+)%s*(.*)$")
		if not filename then return false, "Uso: /blockframe_save <nome> [radius=N]" end
		
		local args = blockframe.parse_args(args_str)
		local radius = tonumber(args.radius) or 10
		local player = minetest.get_player_by_name(name)
		if not player then return end
		
		local success, count = blockframe.save_map(filename, player:get_pos(), radius)
		if success then
			return true, "Salvo: " .. count .. " blocos no arquivo " .. filename .. ".bf"
		else
			return false, count
		end
	end
})

minetest.register_chatcommand("blockframe_load", {
	params = "<nome> [collision=true|false]",
	description = "Carrega BlockFrames de um arquivo .bf",
	func = function(name, param)
		local filename, args_str = param:match("^(%S+)%s*(.*)$")
		if not filename then return false, "Uso: /blockframe_load <nome> [collision=true]" end
		
		local args = blockframe.parse_args(args_str)
		local player = minetest.get_player_by_name(name)
		if not player then return end
		
		local success, count = blockframe.load_map(filename, player:get_pos(), args)
		if success then
			return true, "Carregado: " .. count .. " blocos do arquivo " .. filename .. ".bf"
		else
			return false, count
		end
	end
})

minetest.register_chatcommand("blockframe_cancel",{
	func=function(name)
		local data = blockframe.active[name]
		if not data or not data.entity then return false,"Nenhum BlockFrame ativo para cancelar." end
		local ent = data.entity
		if ent.object then ent.object:remove() end
		blockframe.active[name]=nil
		return true,"BlockFrame preview cancelado."
	end
})

minetest.register_chatcommand("blockframe_undo",{
	func=function(name)
		local mem = blockframe.memory[name]
		if not mem then return false,"Nenhum bloco para desfazer." end
		local pos = mem.pos
		if pos then
			local objs = minetest.get_objects_inside_radius(pos,0.5)
			for _,obj in ipairs(objs) do
				local luaent = obj:get_luaentity()
				if luaent and luaent.name=="blockframe:placed" then obj:remove(); break end
			end
		end
		local player = minetest.get_player_by_name(name)
		if player and mem.node then
			local stack = ItemStack(mem.node)
			local inv = player:get_inventory()
			if inv:room_for_item("main",stack) then inv:add_item("main",stack)
			else minetest.add_item(player:get_pos(),stack) end
		end
		blockframe.memory[name]=nil
		return true,"Último BlockFrame removido e item devolvido."
	end
})

minetest.register_chatcommand("blockframe_del", {
	description = "Deleta BlockFrames ao redor. Opcional: radius=<numero>",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then return false, "Player não encontrado." end
		local args = blockframe.parse_args(param)
		local radius = tonumber(args.radius) or 2
		local pos = player:get_pos()
		local objs = minetest.get_objects_inside_radius(pos, radius)
		local removed = 0
		local inv = player:get_inventory()
		for _, obj in ipairs(objs) do
			if obj ~= player then
				local ent = obj:get_luaentity()
				if ent and ent.name == "blockframe:placed" then
					if ent.node then
						local stack = ItemStack(ent.node)
						if inv and inv:room_for_item("main", stack) then inv:add_item("main", stack)
						else minetest.add_item(pos, stack) end
					end
					obj:remove()
					removed = removed + 1
				end
			end
		end
		if removed == 0 then return false, "Nenhum BlockFrame encontrado no raio " .. radius end
		return true, "Removido " .. removed .. " BlockFrame(s) no raio " .. radius
	end
})

minetest.register_chatcommand("blockframe_help",{
	func=function()
		return true,blockframe.help_text()
	end
})

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	local data = blockframe.active[name]
	if not data or not data.entity then return end
	local ent = data.entity
	if not ent.last_pos then return end
	blockframe.memory[name]={node=ent.node,args=table.copy(ent.args or {}),pos=vector.new(ent.last_pos)}
	ent.object:remove()
	blockframe.active[name]=nil
end)
