local function ensure_startpos(self)

    if self._startpos
    and self._startpos.x
    and self._startpos.y
    and self._startpos.z then
        return
    end

    local pos = self.object:get_pos()

    if pos then

        self._startpos = {
            x = pos.x or 0,
            y = pos.y or 0,
            z = pos.z or 0
        }

    else

        self._startpos = {x=0,y=0,z=0}

    end

end



local function get_falling_depth(self)

    if not self or not self.object then
        return 0
    end

    ensure_startpos(self)

    local pos = self.object:get_pos()

    if not pos then
        return 0
    end

    local sy = self._startpos.y or pos.y or 0
    local py = pos.y or sy

    return sy - py

end



local function deal_falling_damage(self)

    if not self
    or not self.object
    or not self.node
    or not self.node.name then
        return
    end


    local def = core.registered_nodes[self.node.name]

    if not def then
        return
    end


    if core.get_item_group(self.node.name, "falling_node_damage") == 0 then
        return
    end


    ensure_startpos(self)


    local pos = self.object:get_pos()

    if not pos then
        return
    end


    self._hit = self._hit or {}


    for obj in core.objects_inside_radius(pos, 1) do

        if obj and obj:get_pos() then

            local entity = obj:get_luaentity()

            if entity and entity.name == "__builtin:item" then

                obj:remove()

            elseif mcl_util.get_hp(obj) > 0 and not self._hit[obj] then

                self._hit[obj] = true

                local fall_distance = get_falling_depth(self)

                local damage = (fall_distance - 1) * 2

                damage = math.max(0, math.min(40, damage))


                if damage >= 1 then

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
        visual_size = {x = 0.667, y = 0.667},

        textures = {"air"},

        physical = true,
        collide_with_objects = false,

        collisionbox = {-0.5,-0.5,-0.5, 0.5,0.5,0.5},

        is_visible = false,

    },


    node = {name="air"},
    meta = {},


    set_node = function(self, node, meta)

        if not node or not node.name then
            node = {name="air"}
        end

        local def = core.registered_nodes[node.name]

        local visual = node.name
        local glow = 0


        if not def then

            visual = "unknown"

        else

            if def._mcl_falling_node_alternative then

                node.name = def._mcl_falling_node_alternative
                visual = node.name

                def = core.registered_nodes[node.name]

            end


            if node.param2 and node.param2 ~= 0 then

                if def.paramtype2 == "facedir"
                or def.paramtype2 == "colorfacedir" then

                    self.object:set_yaw(
                        core.dir_to_yaw(
                            core.facedir_to_dir(node.param2)
                        )
                    )

                elseif def.paramtype2 == "wallmounted"
                or def.paramtype2 == "colorwallmounted" then

                    self.object:set_yaw(
                        core.dir_to_yaw(
                            core.wallmounted_to_dir(node.param2)
                        )
                    )

                end

            end

            glow = def.light_source or 0

        end


        self.node = node
        self.meta = meta or {}

        self.object:set_properties({

            textures = {visual},
            is_visible = true,
            glow = glow

        })

    end,



    get_staticdata = function(self)

        ensure_startpos(self)

        return core.serialize({

            node = self.node or {name="air"},
            meta = self.meta or {},

            _startpos = {
                x = self._startpos.x or 0,
                y = self._startpos.y or 0,
                z = self._startpos.z or 0
            }

        })

    end,



    on_activate = function(self, staticdata)

        self.object:set_armor_groups({immortal=1})

        ensure_startpos(self)


        if staticdata and staticdata ~= "" then

            local ds = core.deserialize(staticdata)

            if ds then

                if ds.node then
                    self:set_node(ds.node, ds.meta)
                end

                if ds._startpos
                and ds._startpos.x
                and ds._startpos.y
                and ds._startpos.z then

                    self._startpos = {
                        x = ds._startpos.x,
                        y = ds._startpos.y,
                        z = ds._startpos.z
                    }

                end

            end

        end

    end,



    on_step = function(self, dtime)

        ensure_startpos(self)

        if not self.node or not self.node.name then
            self.object:remove()
            return
        end


        local pos = self.object:get_pos()

        if not pos then return end


        self.object:set_acceleration({x=0,y=-10,z=0})


        local below = {
            x = pos.x,
            y = pos.y - 0.7,
            z = pos.z
        }


        local node_below = core.get_node_or_nil(below)

        if not node_below then return end


        local def_below = core.registered_nodes[node_below.name]


        if def_below and def_below.walkable then

            local place_pos = vector.round(pos)

            core.set_node(place_pos, self.node)

            local def = core.registered_nodes[self.node.name]

            if def and def._mcl_after_falling then

                def._mcl_after_falling(
                    place_pos,
                    get_falling_depth(self)
                )

            end


            deal_falling_damage(self)

            self.object:remove()

            core.check_for_falling(place_pos)

            return

        end


        deal_falling_damage(self)

    end

})
