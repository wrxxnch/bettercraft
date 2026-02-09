-- ===============================
-- PARTICLE COMMAND (ISOLADO)
-- ===============================

local function normalize_texture(name)
	if not name or name == "" then return nil end
	if not name:find("%.png$") then
		name = name .. ".png"
	end
	return name
end

-- Parse de posição com suporte a ~ e ^
local function parse_pos(args, player)
	local base = vector.round(player:get_pos())
	base.y = base.y + 1.5

	local function parse_axis(v, axis)
		if v == "~" then return base[axis] end
		if v:sub(1,1) == "~" then
			return base[axis] + (tonumber(v:sub(2)) or 0)
		end
		if v == "^" then return base[axis] end
		if v:sub(1,1) == "^" then
			return base[axis] + (tonumber(v:sub(2)) or 0)
		end
		return tonumber(v)
	end

	if args[1] and (tonumber(args[1]) or args[1]:match("^[~^]")) then
		return {
			x = parse_axis(table.remove(args,1), "x"),
			y = parse_axis(table.remove(args,1), "y"),
			z = parse_axis(table.remove(args,1), "z"),
		}
	end

	return base
end

minetest.register_chatcommand("particle", {
	params = "<textura> [args...]",
	description = "Cria partículas (static, floating, falling, sphere, hollow)",
	privs = {server = true},

	func = function(name, param)
		local args = param:split(" ")
		if #args == 0 then
			return false, "Uso: /particle <textura> [args]"
		end

		local player = minetest.get_player_by_name(name)
		if not player then return false end

		-- TEXTURA
		local texture = normalize_texture(table.remove(args, 1))
		if not texture then
			return false, "Textura inválida"
		end

		-- CONFIG PADRÃO
		local cfg = {
			mode   = "static", -- static | floating | falling
			shape  = "point",  -- point | sphere
			hollow = false,
			radius = 3,
			size   = 4,
			count  = 30,
			spread = 0.3,
			seed   = os.time(),
		}

		-- PARSE DE FLAGS
		local i = 1
		while i <= #args do
			local a = args[i]:lower()

			if a == "floating" or a == "falling" or a == "static" then
				cfg.mode = a
				table.remove(args,i)

			elseif a == "hollow" then
				cfg.hollow = true
				table.remove(args,i)

			elseif a == "sphere" then
				cfg.shape = "sphere"
				table.remove(args,i)

			elseif a:match("^sphere=") then
				cfg.shape = "sphere"
				cfg.radius = tonumber(a:match("sphere=(.+)")) or cfg.radius
				table.remove(args,i)

			elseif a:match("^size=") then
				cfg.size = tonumber(a:match("size=(.+)")) or cfg.size
				table.remove(args,i)

			elseif a:match("^count=") then
				cfg.count = tonumber(a:match("count=(.+)")) or cfg.count
				table.remove(args,i)

			elseif a:match("^spread=") then
				cfg.spread = tonumber(a:match("spread=(.+)")) or cfg.spread
				table.remove(args,i)

			elseif a:match("^seed=") then
				cfg.seed = tonumber(a:match("seed=(.+)")) or cfg.seed
				table.remove(args,i)

			else
				i = i + 1
			end
		end

		-- POSIÇÃO
		local pos = parse_pos(args, player)

		math.randomseed(cfg.seed)

		-- MOVIMENTO
		local vel, acc, collision = vector.zero(), vector.zero(), false

		if cfg.mode == "falling" then
			vel = {x=0,y=1,z=0}
			acc = {x=0,y=-9.8,z=0}
			collision = true

		elseif cfg.mode == "floating" then
			vel = {x=0,y=1,z=0}
			acc = {x=0,y=0.3,z=0}
		end

		-- SPAWN
		if cfg.shape == "sphere" then
			for x=-cfg.radius,cfg.radius do
				for y=-cfg.radius,cfg.radius do
					for z=-cfg.radius,cfg.radius do
						local d = math.sqrt(x*x+y*y+z*z)
						if d <= cfg.radius and (not cfg.hollow or d >= cfg.radius-1) then
							minetest.add_particle({
								pos = vector.add(pos,{x=x,y=y,z=z}),
								velocity = vel,
								acceleration = acc,
								expirationtime = 4,
								size = cfg.size,
								texture = texture,
								collisiondetection = collision,
								glow = 10,
							})
						end
					end
				end
			end
		else
			minetest.add_particlespawner({
				amount = cfg.count,
				time = 0.1,
				minpos = vector.subtract(pos, cfg.spread),
				maxpos = vector.add(pos, cfg.spread),
				minvel = vel,
				maxvel = vel,
				minacc = acc,
				maxacc = acc,
				minsize = cfg.size,
				maxsize = cfg.size,
				texture = texture,
				collisiondetection = collision,
				glow = 10,
			})
		end

		return true, " Particle criado: "..texture
	end,
})
