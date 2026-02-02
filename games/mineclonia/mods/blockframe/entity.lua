--------------------------------------------------
-- UTIL
--------------------------------------------------
local function parse_vec(str, def)
	if not str then return def end
	local x,y,z = str:match("([^,]+),([^,]+),([^,]+)")
	return {x=tonumber(x),y=tonumber(y),z=tonumber(z)}
end

--------------------------------------------------
-- PREVIEW
--------------------------------------------------
minetest.register_entity("blockframe:preview", {
	visual = "wielditem",
	visual_size = {x=0.5,y=0.5},
	collisionbox = {0,0,0,0,0,0},
	physical = false,
	pointable = false,
	glow = 5,

	on_activate = function(self, staticdata)
		local data = {}
		if staticdata and staticdata ~= "" then
			local ok, res = pcall(minetest.deserialize, staticdata)
			if ok and type(res) == "table" then data = res end
		end

		self.node = data.node
		self.args = {}
		self.player = nil
		self.last_pos = nil

		self.object:set_properties({
			wield_item = self.node,
			opacity = 120
		})
	end,

	apply_args = function(self, args)
		self.args = self.args or {}

		if args.size then
			self.args.size = parse_vec(args.size, {x=0.5,y=0.5,z=0.5})
			self.object:set_properties({visual_size = self.args.size})
		end

		if args.rotate then
			self.args.rotate = tonumber(args.rotate)
			self.object:set_rotation({x=0,y=math.rad(self.args.rotate),z=0})
		end

		if args.mirror then
			local v = self.object:get_properties().visual_size
			if args.mirror == "x" then v.x = -v.x end
			if args.mirror == "y" then v.y = -v.y end
			if args.mirror == "z" then v.z = -v.z end
			self.object:set_properties({visual_size = v})
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
			if hit.type == "node" then
				self.object:set_pos(hit.above)
				self.last_pos = hit.above
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
		local data = {}
		if staticdata and staticdata ~= "" then
			local ok, res = pcall(minetest.deserialize, staticdata)
			if ok and type(res) == "table" then data = res end
		end

		self.args = data.args or {}
		self.object:set_properties({
			wield_item = data.node,
			visual_size = self.args.size or {x=0.5,y=0.5,z=0.5}
		})

		if self.args.rotate then
			self.object:set_rotation({x=0,y=math.rad(self.args.rotate),z=0})
		end
	end
})
