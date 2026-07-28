local S = core.get_translator(core.get_current_modname())

-------------------------------------------------------
-- CONFIG
-------------------------------------------------------
local BEE_SPEED = 4.5
local EXPLORE_SPEED = 2.5
local SEARCH_RADIUS = 16
local HIVE_TIME = 20
local BREED_COOLDOWN = 60
local ANGER_TIME = 12

-------------------------------------------------------
-- AUX
-------------------------------------------------------

local function safe_vec(v)
	return {
		x = v.x or 0,
		y = v.y or 0,
		z = v.z or 0
	}
end

-- Função para transformar a abelha em "Brava"
local function make_bee_angry(bee_obj, player)
	if not bee_obj or not player then return end
	
	local lua_ent = bee_obj:get_luaentity()
	if lua_ent then
		-- 1. Mudar Textura para Brava
		bee_obj:set_properties({
			textures = {"mobs_mc_bee_angry.png"},
		})
		
		-- 2. Definir o Player como alvo (Lógica mobs_mc / mobs_redo)
		lua_ent.attack = player
		lua_ent.state = "attack"
		
		-- 3. Sobrescrever a função de ataque da abelha específica
		-- Para que ao picar, ela aplique veneno e agende a morte
		local old_custom_attack = lua_ent.custom_attack
		lua_ent.do_custom_attack = function(self, target)
			if target:is_player() then
				-- Aplica veneno (mcl_status_effects do MineClone)
				if mcl_status_effects then
					mcl_status_effects.add_effect(target, "poison", 10, 0)
				end
				
				-- 4. Morrer 10 segundos depois de picar
				minetest.chat_send_all("A abelha te picou e morrerá em breve!")
				minetest.after(10, function()
					if bee_obj:get_pos() then
						bee_obj:remove() -- Remove a abelha do jogo
					end
				end)
				
				-- Desativa o ataque para ela não picar de novo enquanto espera a morte
				self.attack = nil
				self.state = "stand"
			end
		end
	end
end

-- Sobrescrever a colmeia para reagir a mãos/itens errados
local hives = {"mcl_bees:beehive_5", "mcl_bees:bee_nest_5"}

for _, hive_name in ipairs(hives) do
	local old_node = minetest.registered_nodes[hive_name]
	if old_node then
		minetest.override_item(hive_name, {
			on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
				local tool = itemstack:get_name()
				
				-- Se não for tesoura, as abelhas atacam!
				if tool ~= "mcl_tools:shears" then
					local meta = minetest.get_meta(pos)
					local bee_count = meta:get_int("bees_count") or 3
					
					for i = 1, bee_count do
						minetest.after(i * 0.2, function()
							local obj = minetest.add_entity(pos, "mcl_bees:bee")
							if obj then
								make_bee_angry(obj, clicker)
							end
						end)
					end
					
					-- Esvazia a colmeia (opcional, elas saíram pra atacar)
					meta:set_int("bees_count", 0)
				end
				
				-- Executa a lógica original (se houver)
				if old_node.on_rightclick then
					return old_node.on_rightclick(pos, node, clicker, itemstack, pointed_thing)
				end
			end,
		})
	end
end

local function add_honey(pos)
    local node = minetest.get_node(pos)
    
    -- ADICIONE ESTA VERIFICAÇÃO:
    -- Verifica se o nome do bloco contém "beehive" ou "bee_nest" 
    -- antes de tentar concatenar o nível de mel.
    if not node.name:find("beehive") and not node.name:find("bee_nest") then
        return -- Sai da função se não for uma colmeia válida
    end

    -- Se o código original for algo como:
    -- minetest.swap_node(pos, {name = node.name .. "_1"})
    -- Garanta que ele só rode se o node.name for o esperado.
    
    -- Exemplo de correção mais robusta:
    local new_name = node.name .. "_1"
    if minetest.registered_nodes[new_name] then
        minetest.swap_node(pos, {name = new_name})
    else
        minetest.log("warning", "[bee_custom] Tentativa de criar node inexistente: " .. new_name)
    end
end

local function obstructed(a, b)
	local dir = vector.direction(a, b)
	local p = vector.add(a, vector.multiply(dir, 0.8))
	local n = minetest.get_node_or_nil(p)
	if not n then return false end
	local def = minetest.registered_nodes[n.name]
	return def and def.walkable
end

-------------------------------------------------------
-- BEE MOB
-------------------------------------------------------

mcl_mobs.register_mob("bee_custom:bee", {
	description = "Bee",
	type = "animal",
	spawn_class = "passive",
	passive = true,

	hp_min = 10,
	hp_max = 10,

	visual = "mesh",
	mesh = "mobs_mc_bee.b3d",
	textures = {"mobs_mc_bee.png"},
	visual_size = {x=1,y=1},

	collisionbox = {-0.25,-0.25,-0.25,0.25,0.25,0.25},
	fly = true,
	fly_in = "air",

	walk_velocity = 4,
	run_velocity = 6,

	follow = {"group:flower"},

	animation = {
		stand_start = 1,
		stand_end = 40,
		walk_start = 1,
		walk_end = 40,
		speed_normal = 30,
	},

	---------------------------------------------------
	on_activate = function(self, staticdata, dtime)
		if self.mob_activate then
			self:mob_activate(staticdata, mcl_mobs.registered_mobs[self.name], dtime)
		end

		self.has_nectar = self.has_nectar or false
		self.in_hive = self.in_hive or false
		self.hive_timer = self.hive_timer or 0
		self.breed_timer = self.breed_timer or 0
		self.explore_timer = self.explore_timer or 0
		self.explore_dir = self.explore_dir or {x=1,y=0,z=0}
		self.angry = self.angry or false
		self.angry_timer = self.angry_timer or 0
	end,

	---------------------------------------------------
	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then return end

		-- segurança absoluta
		self.breed_timer = self.breed_timer or 0
		self.explore_timer = self.explore_timer or 0
		self.hive_timer = self.hive_timer or 0
		self.angry_timer = self.angry_timer or 0

		---------------------------------------------------
		-- ANGRY MODE
		---------------------------------------------------
		if self.angry then
			self.angry_timer = self.angry_timer - dtime
			if self.angry_timer <= 0 then
				self.angry = false
				self.object:set_properties({textures={"mobs_mc_bee.png"}})
			end
		end

		---------------------------------------------------
		-- DENTRO DA COLMEIA
		---------------------------------------------------
		if self.in_hive then
			self.hive_timer = self.hive_timer - dtime
			self.object:set_velocity({x=0,y=0,z=0})

			if self.hive_timer <= 0 then
				add_honey(self.hive_pos)
				self.in_hive = false
				self.has_nectar = false
				self.object:set_properties({
					visual_size={x=1,y=1},
					textures={"mobs_mc_bee.png"},
					pointable=true
				})
				self.object:set_velocity({x=0,y=2,z=0})
			end
			return
		end
		
        ---------------------------------------------------
		-- ATAQUE SE IRRITADA (CORRIGIDO)
		---------------------------------------------------
		if self.angry then
			-- Se ela já picou, ela não ataca mais e apenas espera a morte
			if self.has_stung then
				self.attack = nil
			else
				for _, p in ipairs(minetest.get_connected_players()) do
					local ppos = p:get_pos()
					if ppos and vector.distance(pos, ppos) < 1.5 then
						-- 1. Aplica o Dano (Punch)
						p:punch(self.object, 1.0, {
							full_punch_interval = 1.0,
							damage_groups = {fleshy = 2}
						})

						-- 2. Aplica Veneno por 10 segundos
						if mcl_potions and mcl_potions.give_effect_by_level then
							mcl_potions.give_effect_by_level("poison", p, 1, 10)
						elseif mcl_status_effects then
							mcl_status_effects.add_effect(p, "poison", 10, 0)
						end

						-- 3. Marca que picou e agenda a morte
						self.has_stung = true
						minetest.chat_send_player(p:get_player_name(), "A abelha te picou e morrerá em breve!")
						
						minetest.after(10, function()
							if self.object and self.object:get_pos() then
								self.object:remove()
							end
						end)
						
						break -- Sai do loop para não picar múltiplos jogadores ao mesmo tempo
					end
				end
			end
		end

		-- Ativar estado bravo e mudar textura
		if self.attack and not self.angry then
			self.angry = true
			self.angry_timer = ANGER_TIME
			self.object:set_properties({textures = {"mobs_mc_bee_angry.png"}})
		end


		---------------------------------------------------
		-- FOLLOW FLOWER
		---------------------------------------------------
		for _,p in ipairs(minetest.get_connected_players()) do
			local ppos = p:get_pos()
			if vector.distance(pos, ppos) < 8 then
				if core.get_item_group(p:get_wielded_item():get_name(), "flower") > 0 then
					local dir = vector.direction(pos, ppos)
					self.object:set_yaw(math.atan2(dir.z, dir.x)-math.pi/2)
					self.object:set_velocity(vector.multiply(dir, BEE_SPEED))
					return
				end
			end
		end

		---------------------------------------------------
		-- BUSCA FLOR / COLMEIA
		---------------------------------------------------
		local target, is_hive = nil, false

		if not self.has_nectar then
			target = minetest.find_node_near(pos, SEARCH_RADIUS, "group:flower")
		else
			target = minetest.find_node_near(pos, SEARCH_RADIUS, {"group:beehive", "group:bee_nest"})
			is_hive = true
		end

		if target then
			local dir = vector.direction(pos, target)
			if obstructed(pos, target) then
				dir = vector.add(dir, {x=dir.z, y=0.3, z=-dir.x})
			end

			self.object:set_yaw(math.atan2(dir.z, dir.x)-math.pi/2)
			self.object:set_velocity(vector.multiply(vector.normalize(dir), BEE_SPEED))

			if vector.distance(pos, target) < 1.2 then
				if is_hive then
					self.in_hive = true
					self.hive_pos = vector.new(target)
					self.hive_timer = HIVE_TIME
					self.object:set_properties({visual_size={x=0,y=0}, pointable=false})
				else
					self.has_nectar = true
					self.object:set_properties({textures={"mobs_mc_bee_nectar.png"}})
				end
			end
			return
		end

		---------------------------------------------------
		-- EXPLORAÇÃO
		---------------------------------------------------
		self.explore_timer = self.explore_timer - dtime
		if self.explore_timer <= 0 then
			local a = math.random() * math.pi * 2
			self.explore_dir = {x=math.cos(a), y=0, z=math.sin(a)}
			self.explore_timer = math.random(3,6)
		end

		local vel = {
			x = self.explore_dir.x * EXPLORE_SPEED,
			y = 0,
			z = self.explore_dir.z * EXPLORE_SPEED
		}

		if pos.y < 5 then vel.y = 0.3 end
		if pos.y > 120 then vel.y = -0.3 end

		self.object:set_yaw(math.atan2(self.explore_dir.z, self.explore_dir.x)-math.pi/2)
		self.object:set_velocity(vel)
	end,

	---------------------------------------------------
	-- BREED
	---------------------------------------------------
	on_rightclick = function(self, clicker)
		if self.breed_timer > 0 then return end
		local item = clicker:get_wielded_item()

		if core.get_item_group(item:get_name(), "flower") > 0 then
			if not minetest.is_creative_enabled(clicker:get_player_name()) then
				item:take_item()
				clicker:set_wielded_item(item)
			end

			self.breed_timer = BREED_COOLDOWN
			self.angry = false

			minetest.add_particlespawner({
				amount = 10,
				time = 0.4,
				minpos = self.object:get_pos(),
				maxpos = self.object:get_pos(),
				minvel = {x=-1,y=1,z=-1},
				maxvel = {x=1,y=2,z=1},
				texture = "heart.png"
			})

			mcl_mobs.spawn_child(self.object:get_pos(), "bee_custom:bee")
		end
	end,
})

-------------------------------------------------------
-- SPAWN + EGG
-------------------------------------------------------

mcl_mobs.spawn({
    name = "mcl_bees:bee",
    nodes = {"mcl_core:dirt_with_grass", "group:beehive", "group:bee_nest"},
    neighbors = {"air"},
    min_light = 10,
    max_light = 15,
    interval = 60,
    chance = 8000,
    active_object_count = 2,
    min_height = 1,
    max_height = 31000,
    biomes = {
        "plains",
        "sunflower_plains",
        "forest",
        "flower_forest",
        "birch_forest"
    }
})

mcl_mobs.register_egg("bee_custom:bee", S("Bee"), "#f6c343", "#000000")