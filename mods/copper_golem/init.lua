local S = core.get_translator(minetest.get_current_modname())
local mob_class = mcl_mobs.mob_class

--------------------------------------------------------
-- COPPER GOLEM
--------------------------------------------------------

local copper_golem = {
    description = S("Copper Golem"),
    type = "animal",
    spawn_class = "passive",
    passive = true,

    hp_min = 20,
    hp_max = 20,

    collisionbox = {-0.4, 0, -0.4, 0.4, 1.4, 0.4},
    head_eye_height = 0.7,

    visual = "mesh",
    mesh = "mcl_mobs_copper_golem.obj",

    textures = {
        {"mcl_mobs_copper_golem.png"}
    },

    visual_size = {x = 20, y = 20},

    makes_footstep_sound = true,
    movement_speed = 1.2,
    view_range = 12,

    jump = true,
    fall_damage = 1,

    gravity = 1,
    gravity_drag = 0,

    lifetimer = -1,
    static_save = true,
    despawn = false
}

--------------------------------------------------------
-- PERSISTÊNCIA
--------------------------------------------------------

function copper_golem:on_activate(staticdata, dtime_s)
    if staticdata and staticdata ~= "" then
        local data = minetest.deserialize(staticdata)
        if data then
            self._wander_pos = data._wander_pos
        end
    end
end

function copper_golem:get_staticdata()
    return minetest.serialize({
        _wander_pos = self._wander_pos
    })
end

--------------------------------------------------------
-- BOTÃO
--------------------------------------------------------

local function press_button(pos)

    local node = minetest.get_node(pos)

    if minetest.get_item_group(node.name, "button") > 0 then
        minetest.sound_play("mesecons_button_push", {
            pos = pos,
            gain = 1
        })
    end

end

--------------------------------------------------------
-- IA
--------------------------------------------------------

function copper_golem:motion_step(dtime, moveresult, self_pos)

    local target_pos = nil

    --------------------------------------------------------
    -- PROCURAR BOTÃO
    --------------------------------------------------------

    local nodes = minetest.find_nodes_in_area(
        vector.subtract(self_pos, 6),
        vector.add(self_pos, 6),
        {"group:button"}
    )

    if #nodes > 0 then

        target_pos = nodes[math.random(#nodes)]

        if vector.distance(self_pos, target_pos) < 1.5 then
            press_button(target_pos)
        end

    end

    --------------------------------------------------------
    -- WANDER
    --------------------------------------------------------

    if not target_pos then

        if not self._wander_pos
        or vector.distance(self_pos, self._wander_pos) < 1
        or math.random(80) == 1 then

            self._wander_pos = vector.offset(
                self_pos,
                math.random(-5,5),
                0,
                math.random(-5,5)
            )

        end

        target_pos = self._wander_pos

    end

    --------------------------------------------------------
    -- MOVIMENTO + GRAVIDADE
    --------------------------------------------------------

    local vel = self.object:get_velocity()

    -- aplicar gravidade
    vel.y = vel.y - (9.81 * dtime)

    if target_pos then

        local dir = vector.direction(self_pos, target_pos)

        vel.x = dir.x * self.movement_speed
        vel.z = dir.z * self.movement_speed

        local yaw = math.atan2(dir.z, dir.x) - math.pi / 2
        self:set_yaw(yaw)

    else

        vel.x = vel.x * 0.8
        vel.z = vel.z * 0.8

    end

    self.object:set_velocity(vel)

end

function copper_golem:run_ai(dtime, moveresult)
    return
end

--------------------------------------------------------
-- MORTE
--------------------------------------------------------

function copper_golem:on_die(pos)

    minetest.add_item(pos, "mcl_copper:copper_ingot")

end

--------------------------------------------------------
-- REGISTRO DO MOB
--------------------------------------------------------

mcl_mobs.register_mob("copper_golem:copper_golem", copper_golem)

mcl_mobs.register_egg(
    "copper_golem:copper_golem",
    S("Copper Golem"),
    "#d77f2f",
    "#9b5c24",
    0
)