local S = core.get_translator("mobs_mc")
local mob_class = mcl_mobs.mob_class

--------------------------------------------------------
-- Entidade Visual para o Item na Mão
--------------------------------------------------------

minetest.register_entity("mobs_mc:visual_item", {
    initial_properties = {
        visual = "wielditem",
        textures = {"air"},
        visual_size = {x = 0.2, y = 0.2},
        collisionbox = {0, 0, 0, 0, 0, 0},
        pointable = false,
        static_save = false,
    },
    on_step = function(self, dtime)
        if not self.object:get_attach() then
            self.object:remove()
        end
    end,
})

--------------------------------------------------------
-- ALLAY DEFINITION
--------------------------------------------------------

local allay = {
    description = S("Allay"),
    type = "animal",
    spawn_class = "passive",
    passive = true,

    hp_min = 20,
    hp_max = 20,

    collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.6, 0.2},
    head_eye_height = 0.4,

    visual = "mesh",
    mesh = "mobs_mc_allay.b3d",
    textures = {
        {"mobs_mc_allay.png"},
    },

    fly = true,
    fall_damage = 0,
    pushable = false,
    makes_footstep_sound = false,

    gravity_drag = 0,
    _apply_gravity_drag_on_ground = false,
    movement_speed = 3.0,
    view_range = 16,
}

--------------------------------------------------------
-- SISTEMA DE ITENS
--------------------------------------------------------

function allay:_update_hand_item()
    if self._wielded_item_entity then
        self._wielded_item_entity:remove()
        self._wielded_item_entity = nil
    end

    local item_to_show = self._picked_up_item or self._given_stack
    if item_to_show then
        local pos = self.object:get_pos()
        local ent = minetest.add_entity(pos, "mobs_mc:visual_item")
        if ent then
            ent:set_properties({
                textures = {ItemStack(item_to_show):get_name()},
            })
            ent:set_attach(self.object, "Arm_R", {x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
            self._wielded_item_entity = ent
        end
    end
end

function allay:_drop_items(only_picked_up)
    local pos = self.object:get_pos()
    if self._picked_up_item then
        local item_obj = minetest.add_item(pos, self._picked_up_item)
        if item_obj then
            item_obj:set_velocity({x = math.random(-1, 1), y = 2, z = math.random(-1, 1)})
        end
        self._picked_up_item = nil
    end
    
    if not only_picked_up and self._given_stack then
        minetest.add_item(pos, self._given_stack)
        self._given_stack = nil
        self._given_item = nil
        self._player = nil
    end
    self:_update_hand_item()
end

function allay:on_rightclick(clicker)
    local wi = clicker:get_wielded_item()
    if not self._given_item and not wi:is_empty() then
        self._player = clicker:get_player_name()
        self._given_item = wi:get_name()
        self._given_stack = wi:to_string()
        if not minetest.settings:get_bool("creative_mode") then
            wi:take_item()
            clicker:set_wielded_item(wi)
        end
        self:_update_hand_item()
        return
    end
    self:_drop_items()
end

--------------------------------------------------------
-- MOVIMENTO E IA
--------------------------------------------------------

function allay:motion_step(dtime, moveresult, self_pos)
    -- Manter item na mão se necessário
    if (self._given_item or self._picked_up_item) and 
       (not self._wielded_item_entity or not self._wielded_item_entity:get_luaentity()) then
        self:_update_hand_item()
    end

    local target_pos = nil
    local player = self._player and minetest.get_player_by_name(self._player)

    -- 1. BUSCAR ITEM NO CHÃO
    if self._given_item and not self._picked_up_item then
        local items = minetest.get_objects_inside_radius(self_pos, self.view_range)
        for _, o in ipairs(items) do
            local entity = o:get_luaentity()
            if entity and entity.name == "__builtin:item" then
                local itemstack = ItemStack(entity.itemstring)
                if itemstack:get_name() == self._given_item then
                    local opos = o:get_pos()
                    if vector.distance(self_pos, opos) < 1.5 then
                        self._picked_up_item = entity.itemstring
                        o:remove()
                        self:_update_hand_item()
                    else
                        target_pos = opos
                        break
                    end
                end
            end
        end
    end

    -- 2. SEGUIR JOGADOR (Se tiver item coletado OU apenas o item dado)
    if not target_pos and player then
        local ppos = player:get_pos()
        ppos.y = ppos.y + 1.2 -- Altura do peito/cabeça do jogador
        local dist = vector.distance(self_pos, ppos)
        
        if self._picked_up_item then
            -- Se coletou item, segue bem de perto (para entregar ou apenas acompanhar)
            if dist > 2.0 then
                target_pos = ppos
            end
        elseif self._given_item then
            -- Se apenas tem o item de referência, segue a uma distância amigável
            if dist > 3.5 then
                target_pos = ppos
            end
        end
    end

    -- 3. MOVIMENTO ALEATÓRIO (Wander)
    if not target_pos then
        if not self._wander_pos or vector.distance(self_pos, self._wander_pos) < 1.5 or math.random(100) == 1 then
            -- Wander limitado perto do jogador se ele existir
            local base_pos = player and player:get_pos() or self_pos
            self._wander_pos = vector.offset(base_pos, math.random(-4, 4), math.random(1, 2), math.random(-4, 4))
            
            -- Verificar se o local é válido
            local node = core.get_node(self._wander_pos)
            if core.registered_nodes[node.name] and core.registered_nodes[node.name].walkable then
                self._wander_pos = nil
            end
        end
        target_pos = self._wander_pos
    end

    -- CÁLCULO DE VELOCIDADE E LIMITES
    if target_pos then
        -- 🔥 LIMITE DE ALTURA: Não subir mais que 4 blocos acima do chão
        local check_pos = {x=self_pos.x, y=self_pos.y, z=self_pos.z}
        local dist_to_ground = 0
        for i=1, 5 do
            local n = core.get_node({x=check_pos.x, y=check_pos.y-i, z=check_pos.z})
            if core.registered_nodes[n.name] and core.registered_nodes[n.name].walkable then
                dist_to_ground = i
                break
            end
        end
        
        -- Se estiver muito alto, força o alvo para baixo
        if dist_to_ground == 0 or dist_to_ground > 4 then
             target_pos.y = self_pos.y - 1
        end

        local dir = vector.direction(self_pos, target_pos)
        local target_speed = 3.0
        local target_vel = vector.multiply(dir, target_speed)
        local current_vel = self.object:get_velocity()
        
        local smooth = 0.08
        local new_vel = {
            x = current_vel.x + (target_vel.x - current_vel.x) * smooth,
            y = current_vel.y + (target_vel.y - current_vel.y) * smooth,
            z = current_vel.z + (target_vel.z - current_vel.z) * smooth,
        }

        -- Altura mínima (não encostar no chão)
        if dist_to_ground <= 1 and new_vel.y < 0 then
            new_vel.y = 0.5
        end

        self.object:set_velocity(new_vel)
        
        if vector.length(new_vel) > 0.1 then
            local yaw = math.atan2(new_vel.z, new_vel.x) - math.pi / 2
            self:set_yaw(yaw)
        end
    else
        local current_vel = self.object:get_velocity()
        self.object:set_velocity(vector.multiply(current_vel, 0.9))
    end
end

function allay:run_ai(dtime, moveresult)
    return 
end

function allay:on_die(pos)
    if self._wield_item_entity then
        self._wield_item_entity:remove()
    end
    self:_drop_items()
end

mcl_mobs.register_mob("mobs_mc:allay", allay)
mcl_mobs.register_egg("mobs_mc:allay", S("Allay"), "#38e0e5", "#f7f8f8", 0)
