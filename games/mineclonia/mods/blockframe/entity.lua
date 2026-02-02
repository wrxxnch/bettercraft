--------------------------------------------------
-- UTIL
--------------------------------------------------
local function parse_vec(str, def)
	if not str then return def end
	local x,y,z = str:match("([^,]+),([^,]+),([^,]+)")
	return {
		x = tonumber(x) or def.x,
		y = tonumber(y) or def.y,
		z = tonumber(z) or def.z
	}
end

local function snap(v, step)
	if not step or step <= 0 then return v end
	return {
		x = math.floor(v.x / step + 0.5) * step,
		y = math.floor(v.y / step + 0.5) * step,
		z = math.floor(v.z / step + 0.5) * step
	}
end

--------------------------------------------------
-- PREVIEW ENTITY
--------------------------------------------------
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
		self.offset = {x=0,y=0,z=0}
		self.step = 0
		self.player = nil
		self.last_pos = nil

		self.object:set_properties({
			wield_item = self.node,
			opacity = 120
		})
	end,

	set_node = function(self, node)
		self.node = node
		self.object:set_properties({ wield_item = node })
	end,

	apply_args = function(self, args)
		if args.size then
			self.args.size = parse_vec(args.size, {x=0.5,y=0.5,z=0.5})
		end

		if args.rotate then
			local r = tonumber(args.rotate)
			if r then self.args.rotate = r end
		end

		if args.mirror == "x" or args.mirror == "y" or args.mirror == "z" then
			self.args.mirror = args.mirror
		end

		if args.step then
			local s = tonumber(args.step)
			if s then self.step = s end
		end

		if args.pos then
			self.offset = parse_vec(args.pos, {x=0,y=0,z=0})
			self.args.pos = self.offset
		end

		local base = self.args.size or {x=0.5,y=0.5,z=0.5}
		local v = table.copy(base)

		if self.args.mirror == "x" then v.x = -v.x end
		if self.args.mirror == "y" then v.y = -v.y end
		if self.args.mirror == "z" then v.z = -v.z end

		self.object:set_properties({ visual_size = v })

		if self.args.rotate then
			self.object:set_rotation({x=0,y=math.rad(self.args.rotate),z=0})
		end
	end,

	on_step = function(self)
	if not self.player or not self.player:is_player() then return end

	-- 📷 posição REAL da câmera
	local eye = vector.add(
		self.player:get_pos(),
		self.player:get_properties().eye_height and
		{x=0, y=self.player:get_properties().eye_height, z=0}
		or {x=0,y=1.6,z=0}
	)

	local dir = self.player:get_look_dir()

	-- começa o raio um pouco à frente da câmera (evita bater no player)
	local start = vector.add(eye, vector.multiply(dir, 0.2))
	local finish = vector.add(start, vector.multiply(dir, 6))

	local ray = minetest.raycast(start, finish, true, true)

	for hit in ray do
		-- ignora o próprio player
		if hit.type == "object" and hit.ref == self.player then
			goto continue
		end

		local p = hit.intersection_point or hit.above
		if p then
			p = snap(p, self.step)
			p = vector.add(p, self.offset)

			self.object:set_pos(p)
			self.last_pos = p
			return
		end

		::continue::
	end
end

})

--------------------------------------------------
-- ENTIDADE FINAL
--------------------------------------------------
minetest.register_entity("blockframe:placed", {
	initial_properties = {
		visual = "wielditem",
		physical = false,
		pointable = true,
		static_save = true,
		visual_size = {x=0.5,y=0.5},
		collisionbox = {0,0,0,0,0,0},
	},

	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata) or {}

		self.node = data.node or "default:stone"
		self.args = data.args or {}

		-- 🔑 DEFINE ANTES DE QUALQUER COISA
		self.object:set_properties({
			wield_item = self.node
		})

		-- SIZE + MIRROR
		local base = self.args.size or {x=0.5,y=0.5,z=0.5}
		local v = table.copy(base)

		if self.args.mirror == "x" then v.x = -v.x end
		if self.args.mirror == "y" then v.y = -v.y end
		if self.args.mirror == "z" then v.z = -v.z end

		self.object:set_properties({ visual_size = v })

		-- ROTATE
		if type(self.args.rotate) == "number" then
			self.object:set_rotation({
				x = 0,
				y = math.rad(self.args.rotate),
				z = 0
			})
		end

		-- OFFSET POS
		if self.args.pos then
			local p = vector.add(self.object:get_pos(), self.args.pos)
			self.object:set_pos(p)
		end
	end,

	get_staticdata = function(self)
		return minetest.serialize({
			node = self.node,
			args = self.args
		})
	end
})

