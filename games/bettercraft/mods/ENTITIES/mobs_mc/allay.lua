local S = core.get_translator("mobs_mc")
local mob_class = mcl_mobs.mob_class

--------------------------------------------------------
-- ALLAY DEFINITION
--------------------------------------------------------

local allay = {
    description = S("Allay"),
    type = "animal",
    spawn_class = "passive",
    passive = true,
    glow = 5,
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

    lifetimer = -1,
    static_save = true,
    despawn = false,

    --------------------------------------------------------
    -- PERSISTÊNCIA
    --------------------------------------------------------

    on_activate = function(self, staticdata, dtime_s)
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                self._given_item = data._given_item
                self._given_stack = data._given_stack
                self._picked_up_item = data._picked_up_item
                self._player = data._player
            end
        end
    end,

    get_staticdata = function(self)
        return minetest.serialize({
            _given_item = self._given_item,
            _given_stack = self._given_stack,
            _picked_up_item = self._picked_up_item,
            _player = self._player,
        })
    end,
}

--------------------------------------------------------
-- SISTEMA DE ITENS
--------------------------------------------------------

function allay:_drop_items(only_picked_up)
    local pos = self.object:get_pos()
    if not pos then return end

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
        return
    end

    self:_drop_items()
end

--------------------------------------------------------
-- MOVIMENTO E IA
--------------------------------------------------------

function allay:motion_step(dtime, moveresult, self_pos)

    local target_pos = nil
    local player = self._player and minetest.get_player_by_name(self._player)

    --------------------------------------------------------
    -- BUSCAR ITEM NO CHÃO
    --------------------------------------------------------

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
                    else
                        target_pos = opos
                        break
                    end
                end
            end
        end
    end

    --------------------------------------------------------
    -- SEGUIR JOGADOR + TELEPORTE
    --------------------------------------------------------

    if player then
        local ppos = player:get_pos()
        ppos.y = ppos.y + 1.2
        local dist = vector.distance(self_pos, ppos)

        if dist > 20 then
            self.object:set_pos(vector.offset(ppos, math.random(-1,1), 0, math.random(-1,1)))
            return
        end

        if self._picked_up_item then
            if dist > 2.0 then
                target_pos = ppos
            end
        elseif self._given_item then
            if dist > 3.5 then
                target_pos = ppos
            end
        end
    end

    --------------------------------------------------------
    -- WANDER
    --------------------------------------------------------

    if not target_pos then
        if not self._wander_pos or vector.distance(self_pos, self._wander_pos) < 1.5 or math.random(100) == 1 then
            local base_pos = player and player:get_pos() or self_pos
            self._wander_pos = vector.offset(base_pos, math.random(-4, 4), math.random(1, 2), math.random(-4, 4))

            local node_at_pos = core.get_node(self._wander_pos)
            if core.registered_nodes[node_at_pos.name] and core.registered_nodes[node_at_pos.name].walkable then
                self._wander_pos = nil
            end
        end
        target_pos = self._wander_pos
    end

    --------------------------------------------------------
    -- MOVIMENTO SUAVE
    --------------------------------------------------------

    if target_pos then
        local dir = vector.direction(self_pos, target_pos)
        local target_vel = vector.multiply(dir, 3.0)
        local current_vel = self.object:get_velocity()

        local smooth = 0.08
        local new_vel = {
            x = current_vel.x + (target_vel.x - current_vel.x) * smooth,
            y = current_vel.y + (target_vel.y - current_vel.y) * smooth,
            z = current_vel.z + (target_vel.z - current_vel.z) * smooth,
        }

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
    self:_drop_items()
end

mcl_mobs.register_mob("mobs_mc:allay", allay)
mcl_mobs.register_egg("mobs_mc:allay", S("Allay"), "#38e0e5", "#f7f8f8", 0)