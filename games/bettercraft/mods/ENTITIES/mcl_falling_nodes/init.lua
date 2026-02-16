local function get_falling_depth(self)

    if not self
    or not self.object then
        return 0
    end

    local pos = self.object:get_pos()

    if not pos then
        return 0
    end

    if not self._startpos then

        self._startpos = vector.round({

            x = pos.x or 0,
            y = pos.y or 0,
            z = pos.z or 0

        })

    end

    local sy = self._startpos.y or pos.y or 0
    local py = pos.y or sy

    return sy - py

end

local old_spawn = core.spawn_falling_node

function core.spawn_falling_node(pos)

    if not pos
    or pos.x == nil
    or pos.y == nil
    or pos.z == nil then
        return false
    end

    local node = core.get_node_or_nil(pos)

    if not node
    or not node.name
    or node.name == "ignore"
    or node.name == "air" then
        return false
    end

    -- se node não existe no registry, ainda permite
    if not core.registered_nodes[node.name] then

        -- cria entity manual segura
        local obj = core.add_entity(pos, "__builtin:falling_node")

        if obj then

            local ent = obj:get_luaentity()

            if ent then

                ent:set_node(node)

                ent._startpos = vector.round({
                    x = pos.x,
                    y = pos.y,
                    z = pos.z
                })

            end

        end

        core.remove_node(pos)

        return true

    end

    return old_spawn(pos)

end


local function deal_falling_damage(self, dtime)

    -- proteção total
    if not self or not self.object then
        return
    end

    if not self.node or not self.node.name then
        return
    end

    if core.get_item_group(self.node.name, "falling_node_damage") == 0 then
        return
    end

    local pos = self.object:get_pos()

    if not pos then
        return
    end

    if not self._startpos then
        self._startpos = vector.round(pos)
    end

    self._hit = self._hit or {}

    for obj in core.objects_inside_radius(pos, 1) do

        if obj and obj:get_pos() then

            local entity = obj:get_luaentity()

            if entity and entity.name == "__builtin:item" then

                obj:remove()

            elseif mcl_util.get_hp(obj) > 0 and not self._hit[obj] then

                self._hit[obj] = true

                local fall_distance = (self._startpos.y or pos.y) - pos.y

                local damage = (fall_distance - 1) * 2

                damage = math.max(0, math.min(40, damage))

                if damage >= 1 then

                    local inv = mcl_util.get_inventory(obj)

                    if inv then

                        local helmet = inv:get_stack("armor", 2)

                        if not helmet:is_empty() and core.get_item_group(helmet:get_name(), "combat_armor") > 0 then

                            damage = damage * 0.75

                            mcl_util.use_item_durability(helmet, 1)

                            inv:set_stack("armor", 2, helmet)

                        end

                    end

                    local dmg_type = "falling_node"

                    if core.get_item_group(self.node.name, "anvil") ~= 0 then
                        dmg_type = "anvil"
                    end

                    mcl_util.deal_damage(obj, damage, {
                        type = dmg_type
                    })

                end

            end

        end

    end

end

core.register_entity(":__builtin:falling_node", {

    initial_properties = {

        visual = "wielditem",

        visual_size = {
            x = 0.667,
            y = 0.667
        },

        textures = {"air"},

        physical = true,

        is_visible = false,

        collide_with_objects = false,

        collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}

    },

    node = {
        name = "air"
    },

    meta = {},

    _mcl_fishing_hookable = true,

    _mcl_fishing_reelable = true,

    set_node = function(self, node, meta)

        -- fallback seguro
        if not node or not node.name then
            node = {
                name = "air"
            }
        end

        local def = core.registered_nodes[self.node.name]

        -- se node não existe, usar fallback visual mas manter nome original
        local visual_name = node.name
        local glow = 0

        if not def then
            visual_name = "unknown" -- textura fallback
        else

            if def._mcl_falling_node_alternative then
                node.name = def._mcl_falling_node_alternative
                visual_name = node.name
                def = core.registered_nodes[node.name]
            end

            if node.param2 and node.param2 ~= 0 then

                if def.paramtype2 == "facedir" or def.paramtype2 == "colorfacedir" then

                    self.object:set_yaw(core.dir_to_yaw(core.facedir_to_dir(node.param2)))

                elseif def.paramtype2 == "wallmounted" or def.paramtype2 == "colorwallmounted" then

                    self.object:set_yaw(core.dir_to_yaw(core.wallmounted_to_dir(node.param2)))

                end

            end

            glow = def.light_source or 0

        end

        self.node = node
        self.meta = meta or {}

        self.object:set_properties({

            is_visible = true,
            textures = {visual_name},
            glow = glow

        })

    end,

   get_staticdata = function(self)

    local inv

    if self.meta then

        inv = self.meta.inv
        self.meta.inventory = nil

    end

    return core.serialize({

        node = self.node or {name="air"},
        meta = self.meta or {},
        _inv = inv,

        -- FIX
        _startpos = self._startpos or {x=0,y=0,z=0},

    })

end,


on_activate = function(self, staticdata)

    self.object:set_armor_groups({immortal=1})

    local ds

    if staticdata and staticdata ~= "" then
        ds = core.deserialize(staticdata)
    end

    if ds and type(ds) == "table" then

        if ds.node then

            local meta = ds.meta or {}
            meta.inventory = ds._inv

            self:set_node(ds.node, meta)

        else

            self:set_node(ds)

        end

        -- FIX CRÍTICO
        if ds._startpos
        and ds._startpos.x
        and ds._startpos.y
        and ds._startpos.z then

            self._startpos = vector.round(ds._startpos)

        end

    else

        self:set_node({name="air"})

    end


    -- GARANTIA ABSOLUTA
    local pos = self.object:get_pos()

    if pos then

        self._startpos = vector.round({

            x = pos.x or 0,
            y = pos.y or 0,
            z = pos.z or 0

        })

    else

        self._startpos = {x=0,y=0,z=0}

    end

end,


    on_step = function(self, dtime)

        if not self.node or not self.node.name then
            self:set_node({
                name = "air"
            })
            return
        end

        local pos = self.object:get_pos()

        if not pos then
            return
        end

        local accel = self.object:get_acceleration()

        if not accel or accel.y ~= -10 then

            self.object:set_acceleration({
                x = 0,
                y = -10,
                z = 0
            })

        end

        local np = {
            x = pos.x,
            y = pos.y + 0.3,
            z = pos.z
        }

        local n2 = core.get_node(np)

        if n2 and n2.name == "mcl_portals:portal_end" then

            self.object:remove()

            return

        end

        local bcp = {
            x = pos.x,
            y = pos.y - 0.7,
            z = pos.z
        }

        local bcn = core.get_node_or_nil(bcp)

        if not bcn then
            return
        end

        local bcd = core.registered_nodes[bcn.name]

        if bcd and bcd.walkable then

            local def = core.registered_nodes[self.node.name]

            if def then

                core.set_node(np, self.node)

                if def._mcl_after_falling then

                    def._mcl_after_falling(np, get_falling_depth(self))

                end

            end

            deal_falling_damage(self, dtime)

            self.object:remove()

            core.check_for_falling(np)

            return

        end

        deal_falling_damage(self, dtime)

    end

})
