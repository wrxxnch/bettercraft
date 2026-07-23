-- mcl_bees/init.lua
-- Mod de abelhas para Mineclonia/MineClone2
-- Baseado no PR 2129 do Mineclonia
--
-- Melhorias adicionadas nesta versão:
--   1) Abelhas ficam BRAVAS ao ter mel/favo retirado da colmeia/ninho sem fumaça de fogueira embaixo
--   2) Tesoura (shears) retira 3 Honeycomb da colmeia/ninho quando o mel está maduro
--   3) Reprodução das abelhas usando flores (modo "apaixonado" -> gera abelha bebê)

mcl_bees = {}

-- =========================================================
-- CONFIGURAÇÕES GERAIS
-- =========================================================

local HONEY_MAX_LEVEL   = 5     -- nível de mel necessário para colher
local ANGRY_RADIUS      = 6     -- raio (nodes) em que as abelhas ficam bravas
local ANGRY_TIME        = 30    -- segundos que a abelha fica brava
local ATTACK_COOLDOWN   = 1      -- segundos entre picadas
local ATTACK_DAMAGE     = 2      -- dano por picada (em corações = damage/2)
local LOVE_TIME         = 30     -- segundos que a abelha fica no "modo apaixonado"
local BREED_COOLDOWN    = 300    -- segundos até poder se reproduzir de novo
local BABY_GROW_TIME    = 1200   -- segundos até o bebê virar adulto (20 min)

-- Nomes de itens (ajuste conforme os nomes reais usados no seu jogo)
local ITEM_GLASS_BOTTLE = "mcl_core:glass_bottle"
local ITEM_SHEARS       = "mcl_tools:shears"
local ITEM_FLOWER_GROUP = "group:flower"

-- =========================================================
-- FUNÇÕES AUXILIARES
-- =========================================================

-- Verifica se existe uma fogueira acesa produzindo fumaça logo abaixo da colmeia/ninho
-- (na Mineclonia, isso evita que as abelhas fiquem bravas ao colher o mel)
local function has_campfire_smoke_below(pos)
    if not minetest.get_modpath("mcl_campfire") then
        return false
    end
    for dy = 1, 5 do
        local check_pos = { x = pos.x, y = pos.y - dy, z = pos.z }
        local node = minetest.get_node(check_pos)
        if node and node.name == "mcl_campfire:campfire_lit" then
            return true
        end
    end
    return false
end

-- Deixa todas as abelhas próximas bravas, e faz com que elas ataquem o jogador responsável
local function anger_nearby_bees(pos, player)
    local objects = minetest.get_objects_inside_radius(pos, ANGRY_RADIUS)
    for _, obj in ipairs(objects) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "mcl_bees:bee" then
            ent.angry = true
            ent.angry_timer = ANGRY_TIME
            ent.attack_target = player
            -- interrompe qualquer outra ação (namoro, seguir flor, etc.)
            ent.in_love = false
        end
    end
end

-- Cria uma abelha bebê próxima de uma posição
local function spawn_baby_bee(pos)
    local obj = minetest.add_entity(pos, "mcl_bees:bee")
    if obj then
        local ent = obj:get_luaentity()
        if ent then
            ent.baby = true
            ent.age = 0
            obj:set_properties({
                visual_size = { x = 0.5, y = 0.5 },
                collisionbox = { -0.1, -0.05, -0.1, 0.1, 0.35, 0.1 },
            })
        end
    end
    return obj
end

-- =========================================================
-- ENTIDADE: ABELHA
-- =========================================================

mcl_mobs.register_mob("mcl_bees:bee", {

    -- Interação por clique direito:
    --  - Flor na mão -> entra em modo de reprodução ("apaixonada")
    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then
            return
        end

        local item = clicker:get_wielded_item()

        if minetest.get_item_group(item:get_name(), "flower") > 0 or item:get_name() == "mcl_flowers:flower_all" then
            -- Bebês e abelhas já apaixonadas/bravas não entram em modo de reprodução
            if self.baby or self.angry or self.in_love then
                return
            end
            if (self.breed_cooldown or 0) > 0 then
                minetest.chat_send_player(clicker:get_player_name(), "Esta abelha ainda não pode se reproduzir de novo.")
                return
            end

            self.in_love = true
            self.love_timer = LOVE_TIME

            -- consome a flor (exceto em modo criativo)
            if not minetest.is_creative_enabled(clicker:get_player_name()) then
                item:take_item()
                clicker:set_wielded_item(item)
            end

            -- efeito visual de "apaixonada"
            local pos = self.object:get_pos()
            if pos then
                minetest.add_particlespawner({
                    amount = 6,
                    time = 1,
                    minpos = { x = pos.x - 0.3, y = pos.y + 0.5, z = pos.z - 0.3 },
                    maxpos = { x = pos.x + 0.3, y = pos.y + 1, z = pos.z + 0.3 },
                    minvel = { x = 0, y = 0.5, z = 0 },
                    maxvel = { x = 0, y = 1, z = 0 },
                    minexptime = 1,
                    maxexptime = 1.5,
                    minsize = 1,
                    maxsize = 2,
                    texture = "heart.png",
                })
            end
        end
    end,

    do_custom = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end

        -- inicializa campos usados pela lógica nova, se ainda não existirem
        self.angry          = self.angry or false
        self.angry_timer    = self.angry_timer or 0
        self.in_love        = self.in_love or false
        self.love_timer     = self.love_timer or 0
        self.breed_cooldown = self.breed_cooldown or 0
        self.attack_wait    = self.attack_wait or 0
        self.baby           = self.baby or false
        self.age            = self.age or 0

        -- reduz temporizadores gerais
        if self.breed_cooldown > 0 then
            self.breed_cooldown = self.breed_cooldown - dtime
        end

        -- ---------------------------------------------------
        -- Crescimento de bebês
        -- ---------------------------------------------------
        if self.baby then
            self.age = self.age + dtime
            if self.age >= BABY_GROW_TIME then
                self.baby = false
                self.object:set_properties({
                    visual_size = { x = 1, y = 1 },
                    collisionbox = { -0.2, -0.1, -0.2, 0.2, 0.7, 0.2 },
                })
            end
        end

        -- ---------------------------------------------------
        -- Estado: BRAVA (ataca o jogador que tirou o mel)
        -- ---------------------------------------------------
        if self.angry then
            self.angry_timer = self.angry_timer - dtime

            local target = self.attack_target
            local target_pos = target and target:get_pos()

            if self.angry_timer <= 0 or not target or not target_pos then
                self.angry = false
                self.attack_target = nil
                self.order = "stand"
                return
            end

            -- persegue o alvo
            local dir = vector.direction(pos, target_pos)
            self.object:set_velocity({
                x = dir.x * (self.fly_velocity or 4),
                y = dir.y * (self.fly_velocity or 4),
                z = dir.z * (self.fly_velocity or 4),
            })

            -- se estiver perto o suficiente, ataca
            local dist = vector.distance(pos, target_pos)
            if dist <= 1.2 then
                self.attack_wait = self.attack_wait - dtime
                if self.attack_wait <= 0 then
                    target:punch(self.object, 1.0, {
                        full_punch_interval = ATTACK_COOLDOWN,
                        damage_groups = { fleshy = ATTACK_DAMAGE },
                    }, dir)
                    self.attack_wait = ATTACK_COOLDOWN
                end
            end
            return -- enquanto brava, ignora namoro/procura de flores
        end

        -- ---------------------------------------------------
        -- Estado: APAIXONADA (procurando parceiro para reproduzir)
        -- ---------------------------------------------------
        if self.in_love then
            self.love_timer = self.love_timer - dtime
            if self.love_timer <= 0 then
                self.in_love = false
                return
            end

            -- procura outra abelha também apaixonada nas redondezas
            local objects = minetest.get_objects_inside_radius(pos, 4)
            for _, obj in ipairs(objects) do
                if obj ~= self.object then
                    local other = obj:get_luaentity()
                    if other and other.name == "mcl_bees:bee" and other.in_love
                        and not other.baby and (other.breed_cooldown or 0) <= 0 then

                        -- reproduz: gera bebê e reinicia os dois pais
                        spawn_baby_bee(pos)

                        self.in_love = false
                        self.breed_cooldown = BREED_COOLDOWN
                        other.in_love = false
                        other.breed_cooldown = BREED_COOLDOWN

                        minetest.add_particlespawner({
                            amount = 10,
                            time = 1,
                            minpos = { x = pos.x - 0.5, y = pos.y, z = pos.z - 0.5 },
                            maxpos = { x = pos.x + 0.5, y = pos.y + 1, z = pos.z + 0.5 },
                            minvel = { x = -0.5, y = 0.5, z = -0.5 },
                            maxvel = { x = 0.5, y = 1, z = 0.5 },
                            minexptime = 1,
                            maxexptime = 2,
                            minsize = 1,
                            maxsize = 2,
                            texture = "heart.png",
                        })
                        return
                    end
                end
            end
            -- continua "andando" normalmente enquanto não acha parceiro
        end

        -- ---------------------------------------------------
        -- Comportamento normal: procurar flores próximas
        -- ---------------------------------------------------
        if math.random(1, 100) == 1 then
            local nodes = minetest.find_nodes_in_area(
                { x = pos.x - 5, y = pos.y - 2, z = pos.z - 5 },
                { x = pos.x + 5, y = pos.y + 2, z = pos.z + 5 },
                { "group:flower" }
            )
            if #nodes > 0 then
                self.order = "follow"
                self.follow = nodes[math.random(1, #nodes)]
            end
        end
    end,

    type = "animal",
    spawn_class = "passive",
    hp_min = 20,
    hp_max = 20,
    xp_min = 5,
    xp_max = 5,
    reach = 3,
    armor = 10,
    collisionbox = { -0.2, -0.1, -0.2, 0.2, 0.7, 0.2 },
    visual = "mesh",
    mesh = "mobs_mc_bee.b3d",
    visual_size = { x = 1, y = 1 },
    textures = {
        { "mobs_mc_bee.png" },
    },
    glow = 4,
    fly = true,
    fly_in = { "air" },
    fly_velocity = 4,
    sounds = {
        random = "mcl_bees_bee_idle",
        hurt = "mcl_bees_bee_hurt",
        death = "mcl_bees_bee_death",
    },
    drops = {},
    view_range = 16,
    stepheight = 1.1,
    fall_damage = false,
    animation = {
        stand_start = 1, stand_end = 40, stand_speed = 10,
        walk_start = 1, walk_end = 40, speed_normal = 10,
        run_start = 1, run_end = 40, speed_run = 15,
        punch_start = 1, punch_end = 40, punch_speed = 15,
    },
})

mcl_mobs.register_egg("mcl_bees:bee", "Bee", "#6f4833", "#daa047", 0)

-- =========================================================
-- FUNÇÃO COMPARTILHADA: colheita de mel/favo da colmeia e do ninho
-- =========================================================

local function on_rightclick_hive(pos, node, clicker, itemstack)
    if not clicker or not clicker:is_player() then
        return itemstack
    end

    local meta = minetest.get_meta(pos)
    local honey_level = meta:get_int("honey_level")

    if honey_level < HONEY_MAX_LEVEL then
        -- minetest.chat_send_player(clicker:get_player_name(), "A colmeia ainda não tem mel suficiente.")
        return itemstack
    end

    local item_name = itemstack:get_name()
    local harvested = false

    if item_name == ITEM_GLASS_BOTTLE then
        -- Retira 1 Honey Bottle, consome 1 vidro
        itemstack:take_item()
        local inv = clicker:get_inventory()
        local honey_bottle = ItemStack("mcl_bees:honey_bottle")
        if inv:room_for_item("main", honey_bottle) then
            inv:add_item("main", honey_bottle)
        else
            minetest.item_drop(honey_bottle, clicker, pos)
        end
        harvested = true

    elseif item_name == ITEM_SHEARS then
        -- Retira 3 Honeycomb e desgasta a tesoura
        local inv = clicker:get_inventory()
        local honeycomb = ItemStack("mcl_bees:honeycomb 3")
        if inv:room_for_item("main", honeycomb) then
            inv:add_item("main", honeycomb)
        else
            minetest.item_drop(honeycomb, clicker, pos)
        end

        if not minetest.is_creative_enabled(clicker:get_player_name()) then
            itemstack:add_wear_by_uses(238) -- durabilidade padrão de tesoura
        end
        harvested = true
    end

    if harvested then
        meta:set_int("honey_level", 0)
        minetest.sound_play("mcl_bees_honey_extract", { pos = pos, gain = 1.0, max_hear_distance = 16 }, true)

        -- Só deixa as abelhas bravas se NÃO houver fumaça de fogueira embaixo
        if not has_campfire_smoke_below(pos) then
            anger_nearby_bees(pos, clicker)
        end
    end

    return itemstack
end

-- =========================================================
-- NÓS: COLMEIA (Beehive) e NINHO DE ABELHA (Bee Nest)
-- =========================================================

minetest.register_node("mcl_bees:beehive", {
    description = "Beehive",
    tiles = {
        "mcl_bees_beehive_top.png", "mcl_bees_beehive_top.png",
        "mcl_bees_beehive_side.png", "mcl_bees_beehive_side.png",
        "mcl_bees_beehive_side.png", "mcl_bees_beehive_front.png"
    },
    groups = { pickaxey = 1, axey = 1, handy = 1, deco_block = 1 },
    sounds = mcl_sounds.node_sound_wood_defaults(),
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("honey_level", 0)
        meta:set_int("bee_count", 0)
    end,
    on_rightclick = function(pos, node, clicker, itemstack)
        return on_rightclick_hive(pos, node, clicker, itemstack)
    end,
})

minetest.register_node("mcl_bees:bee_nest", {
    description = "Bee Nest",
    tiles = {
        "mcl_bees_bee_nest_top.png", "mcl_bees_bee_nest_bottom.png",
        "mcl_bees_bee_nest_side.png", "mcl_bees_bee_nest_side.png",
        "mcl_bees_bee_nest_side.png", "mcl_bees_bee_nest_front.png"
    },
    groups = { pickaxey = 1, axey = 1, handy = 1, deco_block = 1 },
    sounds = mcl_sounds.node_sound_wood_defaults(),
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_int("honey_level", 0)
        meta:set_int("bee_count", 0)
    end,
    on_rightclick = function(pos, node, clicker, itemstack)
        return on_rightclick_hive(pos, node, clicker, itemstack)
    end,
})

-- =========================================================
-- PRODUÇÃO DE MEL AO LONGO DO TEMPO
-- =========================================================
-- A cada intervalo, existe uma chance de o nível de mel subir 1,
-- simulando as abelhas polinizando flores e voltando para casa.

minetest.register_abm({
    label = "mcl_bees: produção de mel",
    nodenames = { "mcl_bees:beehive", "mcl_bees:bee_nest" },
    interval = 60,
    chance = 20,
    action = function(pos, node)
        local meta = minetest.get_meta(pos)
        local honey_level = meta:get_int("honey_level")
        if honey_level < HONEY_MAX_LEVEL then
            -- só produz mel se houver flores por perto (incentiva jardins de flores)
            local flowers = minetest.find_node_near(pos, 8, { "group:flower" })
            if flowers then
                meta:set_int("honey_level", honey_level + 1)
            end
        end
    end,
})

-- =========================================================
-- ITENS: Mel e Favo de Mel
-- =========================================================

minetest.register_craftitem("mcl_bees:honey_bottle", {
    description = "Honey Bottle",
    inventory_image = "mcl_bees_honey_bottle.png",
    on_use = minetest.item_eat(6, "mcl_core:glass_bottle"),
})

minetest.register_craftitem("mcl_bees:honeycomb", {
    description = "Honeycomb",
    inventory_image = "mcl_bees_honeycomb.png",
})

-- =========================================================
-- RECEITAS DE CRAFTING
-- =========================================================

minetest.register_craft({
    output = "mcl_bees:beehive",
    recipe = {
        { "mcl_core:wood", "mcl_core:wood", "mcl_core:wood" },
        { "mcl_bees:honeycomb", "mcl_bees:honeycomb", "mcl_bees:honeycomb" },
        { "mcl_core:wood", "mcl_core:wood", "mcl_core:wood" },
    }
})

-- =========================================================
-- SPAWN DAS ABELHAS
-- =========================================================

mcl_mobs.spawn({
    name = "mcl_bees:bee",
    nodes = { "mcl_core:dirt_with_grass" },
    min_light = 10,
    max_light = 15,
    interval = 60,
    chance = 8000,
    active_object_count = 2,
    min_height = 1,
    max_height = 31000,
})

-- Adicionar abelhas aos biomas específicos (Planícies, Florestas, etc.)
if minetest.get_modpath("mcl_biomes") then
    mcl_mobs.spawn({
        name = "mcl_bees:bee",
        nodes = { "mcl_core:dirt_with_grass" },
        neighbors = { "air" },
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
end
