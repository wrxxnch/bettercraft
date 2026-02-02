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
-- PREVIEW
--------------------------------------------------
minetest.register_entity("blockframe:preview", {
	visual = "wielditem",
	physical = false,
	pointable = false,
	glow = 5,

	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata) or {}
		self.node = data.node
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
		-- SIZE
		if args.size then
			self.args.size = parse_vec(args.size, {x=0.5,y=0.5,z=0.5})
		end

		-- ROTATE
		if args.rotate then
			local r = tonumber(args.rotate)
			if r then self.args.rotate = r end
		end

		-- MIRROR
		if args.mirror == "x" or args.mirror == "y" or args.mirror == "z" then
			self.args.mirror = args.mirror
		end

		-- STEP (SNAP)
		if args.step then
			local s = tonumber(args.step)
			if s and s > 0 then self.step = s end
		end

		-- POS OFFSET  ⭐ NOVO ⭐
		if args.pos then
			self.args.pos = parse_vec(args.pos, {x=0,y=0,z=0})
			self.offset = self.args.pos
		end

		-- aplica visual
		local base = self.args.size or {x=0.5,y=0.5,z=0.5}
		local v = table.copy(base)

		if self.args.mirror == "x" then v.x = -v.x end
		if self.args.mirror == "y" then v.y = -v.y end
		if self.args.mirror == "z" then v.z = -v.z end

		self.object:set_properties({ visual_size = v })

		if type(self.args.rotate) == "number" then
			self.object:set_rotation({
				x = 0,
				y = math.rad(self.args.rotate),
				z = 0
			})
		end
	end,

	on_step = function(self)
		if not self.player then return end

		local eye = vector.add(self.player:get_pos(), {x=0,y=1.6,z=0})
		local dir = self.player:get_look_dir()

		local ray = minetest.raycast(
			eye,
			vector.add(eye, vector.multiply(dir, 6)),
			false,
			true
		)

		for hit in ray do
			if hit.intersection_point then
				-- posição livre
				local p = hit.intersection_point

				-- snap
				p = snap(p, self.step)

				-- offset manual (args.pos)
				p = vector.add(p, self.offset)

				self.object:set_pos(p)
				self.last_pos = p
				return
			end
		end
	end
})

--------------------------------------------------
-- ENTIDADE FINAL
--------------------------------------------------
minetest.register_entity("blockframe:placed", {
	visual = "wielditem",
	physical = false,
	pointable = true,

	on_activate = function(self, staticdata)
		local data = minetest.deserialize(staticdata) or {}
		self.node = data.node
		self.args = data.args or {}

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

		-- POS OFFSET (aplicado no spawn)
		if self.args.pos then
			local off = self.args.pos
			local p = vector.add(self.object:get_pos(), off)
			self.object:set_pos(p)
		end
	end
})
