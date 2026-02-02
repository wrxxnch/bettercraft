--------------------------------------------------
-- INIT.LUA COMPLETO - BLOCKFRAME
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
/blockframe_cancel
/blockframe_undo
/blockframe_del
/blockframe_help

ARGS:
 size=x,y,z        tamanho (1 valor = x=y=z)
 rotate=x,y,z      rotação XYZ
 mirror=x|y|z      espelho
 pos=x,y,z         posição absoluta
 step=valor        snap da mira

Exemplos:
/blockframe size=0.1
/blockframe size=1,0.5
/blockframe size=1,2,0.5 rotate=0,90,0
/blockframe pos=0,1,0 step=0.1
/blockframe mirror=x rotate=45,0,90

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
-- FUNÇÕES AUXILIARES
--------------------------------------------------
local function parse_vec(str, def)
	if not str then return def end
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
		static_save = true,
	},
	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata) or {}
		self.node = data.node or "default:stone"
		self.args = {}
		self.step = 0
		self.player = nil
		self.last_pos = nil
		self.offset = {x=0,y=0,z=0} -- offset relativo
		self.object:set_properties({wield_item=self.node, opacity=120})
	end,
	set_node = function(self,node)
		self.node = node
		self.object:set_properties({wield_item=node})
	end,
	apply_args = function(self,args)
		-- SIZE
		if args.size then
			self.args.size = parse_vec(args.size,{x=0.5,y=0.5,z=0.5})
		end
		-- MIRROR
		if args.mirror=="x" or args.mirror=="y" or args.mirror=="z" then
			self.args.mirror = args.mirror
		end
		-- STEP
		if args.step then
			local s = tonumber(args.step)
			if s then self.step = s end
		end
		-- POS
		if args.pos then
			local p = parse_vec(args.pos,{x=0,y=0,z=0})
			self.offset = p -- offset relativo
			self.args.pos = p -- para placed
		end
		-- ROTATE
		if args.rotate then
			local rx,ry,rz = args.rotate:match("([^,]+),([^,]+),([^,]+)")
			if rx and ry and rz then
				self.args.rotate = {x=tonumber(rx) or 0, y=tonumber(ry) or 0, z=tonumber(rz) or 0}
			else
				local r = tonumber(args.rotate)
				if r then self.args.rotate = {x=0,y=r,z=0} else self.args.rotate={x=0,y=0,z=0} end
			end
		end
		-- VISUAL SIZE + MIRROR
		local base = self.args.size or {x=0.5,y=0.5,z=0.5}
		local v = table.copy(base)
		if self.args.mirror=="x" then v.x=-v.x end
		if self.args.mirror=="y" then v.y=-v.y end
		if self.args.mirror=="z" then v.z=-v.z end
		self.object:set_properties({visual_size=v})
		-- ROTATION
		if self.args.rotate then
			self.object:set_rotation({
				x = math.rad(self.args.rotate.x or 0),
				y = math.rad(self.args.rotate.y or 0),
				z = math.rad(self.args.rotate.z or 0)
			})
		end
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
				p = vector.add(p,self.offset) -- aplica offset se definido
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
		-- SIZE + MIRROR
		local base = self.args.size or {x=0.5,y=0.5,z=0.5}
		local v = table.copy(base)
		if self.args.mirror=="x" then v.x=-v.x end
		if self.args.mirror=="y" then v.y=-v.y end
		if self.args.mirror=="z" then v.z=-v.z end
		self.object:set_properties({visual_size=v})
		-- ROTATE
		if type(self.args.rotate)=="table" then
			self.object:set_rotation({
				x=math.rad(self.args.rotate.x or 0),
				y=math.rad(self.args.rotate.y or 0),
				z=math.rad(self.args.rotate.z or 0)
			})
		end
		-- POSIÇÃO ABSOLUTA
		if self.args.pos then
			self.object:set_pos(self.args.pos)
		end
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
		if not obj or not obj:get_luaentity() then return end
		local ent = obj:get_luaentity()
		ent.player = player
		ent:set_node(node)
		ent:apply_args(args)
		blockframe.active[name].entity = ent
	end)
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

minetest.register_chatcommand("blockframe_del",{
	func=function(name)
		local player = minetest.get_player_by_name(name)
		if not player then return false,"Player não encontrado." end
		local eye = vector.add(player:get_pos(),
			player:get_properties().eye_height and {x=0,y=player:get_properties().eye_height,z=0} or {x=0,y=1.6,z=0})
		local dir = player:get_look_dir()
		local start = vector.add(eye,vector.multiply(dir,0.2))
		local finish = vector.add(start,vector.multiply(dir,6))
		local ray = minetest.raycast(start,finish,true,true)
		for hit in ray do
			if hit.type=="object" then
				local obj = hit.ref
				local luaent = obj:get_luaentity()
				if luaent and luaent.name=="blockframe:placed" then
					if luaent.node then
						local stack = ItemStack(luaent.node)
						local inv = player:get_inventory()
						if inv:room_for_item("main",stack) then inv:add_item("main",stack)
						else minetest.add_item(player:get_pos(),stack) end
					end
					obj:remove()
					return true,"BlockFrame removido e item devolvido."
				end
			end
		end
		return false,"Nenhum BlockFrame encontrado para deletar."
	end
})

minetest.register_chatcommand("blockframe_help",{
	func=function()
		return true,blockframe.help_text()
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
	blockframe.memory[name]={node=ent.node,args=table.copy(ent.args or {}),pos=vector.new(ent.last_pos)}
	ent.object:remove()
	blockframe.active[name]=nil
end)
