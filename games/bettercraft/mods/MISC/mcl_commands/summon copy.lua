minetest.register_chatcommand("summon", {
	params = "<mob> [args]",
	description = "Invoca um mob com parâmetros (ex: /summon creeper hp=100,name=Boss,glow=10)",
	privs = { server = true },

	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Jogador não encontrado"
		end

		if param == "" then
			return false, "Uso: /summon <mob> [args]"
		end

		-- separa nome do mob e argumentos
		local mobname, argstr = param:match("^(%S+)%s*(.*)$")

		-- normaliza nome (igual minecraft)
		if not mobname:find(":") then
			mobname = "mobs_mc:" .. mobname
		end

		local pos = vector.round(player:get_pos())
		pos.y = pos.y + 1

		local obj = minetest.add_entity(pos, mobname)
		if not obj then
			return false, "Falha ao spawnar mob: " .. mobname
		end

		local mob = obj:get_luaentity()
		if not mob then
			obj:remove()
			return false, "Entidade não é um mob válido"
		end

		-- =========================
		-- Parse dos argumentos
		-- =========================
		local args = {}
		if argstr and argstr ~= "" then
			for token in argstr:gmatch("[^,]+") do
				local k, v = token:match("^([^=]+)=?(.*)$")
				if k then
					k = k:trim()
					v = v:trim()
					if v == "" or v == "true" then v = true
					elseif v == "false" then v = false
					elseif tonumber(v) then v = tonumber(v)
					end
					args[k] = v
				end
			end
		end

		-- =========================
		-- APLICAR FLAGS E ATRIBUTOS
		-- =========================

		-- Vida e Respiração
		if args.hp then
			mob.health = math.min(args.hp, mob.hp_max or args.hp)
			obj:set_hp(mob.health)
		end
		if args.hp_max then mob.hp_max = args.hp_max end
		if args.breath then mob.breath = args.breath end
		if args.breath_max then mob.breath_max = args.breath_max end

		-- Nome e Visual
		if args.name then
			mob.nametag = args.name
			obj:set_properties({nametag = args.name})
		end
		if args.glow then
			obj:set_properties({ glow = args.glow })
		end
		
		-- Tamanho e Child
		if args.child ~= nil then
			mob.child = (args.child == true)
			if mob.child and mob.base_visual_size then
				obj:set_properties({
					visual_size = {
						x = mob.base_visual_size.x * 0.5,
						y = mob.base_visual_size.y * 0.5
					}
				})
			end
		end
		if args.scale then
			local s = args.scale
			obj:set_properties({ visual_size = {x=s, y=s} })
		end

		-- Comportamento Base
		if args.passive ~= nil then mob.passive = args.passive end
		if args.retaliates ~= nil then mob.retaliates = args.retaliates end
		if args.docile_by_day ~= nil then mob.docile_by_day = args.docile_by_day end
		if args.day_docile ~= nil then mob.docile_by_day = args.day_docile end -- Alias do usuário
		if args.persistent ~= nil then mob.persistent = args.persistent end
		if args.persist_in_peaceful ~= nil then mob.persist_in_peaceful = args.persist_in_peaceful end

		-- Combate
		if args.damage then mob.damage = args.damage end
		if args.reach then mob.reach = args.reach end
		if args.knock_back ~= nil then mob.knock_back = args.knock_back end
		if args.armor then mob.armor = args.armor end

		-- Movimentação
		if args.walk_velocity then mob.walk_velocity = args.walk_velocity end
		if args.run_velocity then mob.run_velocity = args.run_velocity end
		if args.jump ~= nil then mob.jump = args.jump end
		if args.jump_height then mob.jump_height = args.jump_height end
		if args.stepheight then mob.stepheight = args.stepheight end
		if args.fly ~= nil then mob.fly = args.fly end
		if args.swims ~= nil then mob.swims = args.swims end
		if args.floats ~= nil then mob.floats = args.floats end
		if args.view_range then mob.view_range = args.view_range end

		-- Danos Ambientais
		if args.water_damage then mob.water_damage = args.water_damage end
		if args.lava_damage then mob.lava_damage = args.lava_damage end
		if args.fire_damage then mob.fire_damage = args.fire_damage end
		if args.light_damage then mob.light_damage = args.light_damage end
		if args.suffocation ~= nil then mob.suffocation = args.suffocation end
		if args.fall_damage ~= nil then mob.fall_damage = args.fall_damage end
		if args.fear_height then mob.fear_height = args.fear_height end

		-- Luz Solar (Específico para mortos-vivos)
		if args.ignited_by_sunlight == false then
			mob.ignited_by_sunlight = false
			mob.sunlight_damage = 0
			if mob.extinguish then mob:extinguish() end
		end

		-- Posse e Domesticação
		if args.owner then
			mob.owner = args.owner
			mob.tamed = true
		end
		if args.tamed ~= nil then mob.tamed = args.tamed end
		if args.order then mob.order = args.order end -- "follow" ou "stand"

		-- Força aplicar propriedades e inicialização
		if mob.on_spawn then
			mob:on_spawn()
		end

		return true, "Mob spawnado: " .. mobname .. " com argumentos aplicados."
	end
})
