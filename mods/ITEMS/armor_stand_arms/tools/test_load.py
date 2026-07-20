#!/usr/bin/env python3
"""Stub-execute init.lua under lupa (no lua on PATH; Luanti not launched).

Stubs enough of the Luanti + Mineclonia API to load the mod and exercise:
place, put weapon in hand, take weapon back, armor routing, screwdriver
rotate, dig drops, and the LBM respawn. Run: python3 tools/test_load.py
"""
import os
from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
INIT = os.path.join(HERE, "..", "init.lua")

HARNESS = r"""
local checks = {}
local function check(name, cond)
    checks[#checks+1] = {name, cond and true or false}
    if not cond then error("CHECK FAILED: " .. name, 2) end
end

-- ========== vector ==========
local vmeta
local function vnew(x, y, z)
    return setmetatable({x=x, y=y, z=z}, vmeta)
end
vmeta = {
    __add = function(a, b) return vnew(a.x+b.x, a.y+b.y, a.z+b.z) end,
    __sub = function(a, b) return vnew(a.x-b.x, a.y-b.y, a.z-b.z) end,
    __mul = function(a, s) return vnew(a.x*s, a.y*s, a.z*s) end,
    __index = {},
}
vector = {
    new = function(x, y, z)
        if type(x) == "table" then return vnew(x.x, x.y, x.z) end
        return vnew(x or 0, y or 0, z or 0)
    end,
    add = function(a, b) return vnew(a.x+b.x, a.y+b.y, a.z+b.z) end,
    subtract = function(a, b) return vnew(a.x-b.x, a.y-b.y, a.z-b.z) end,
    offset = function(v, x, y, z) return vnew(v.x+x, v.y+y, v.z+z) end,
    round = function(v)
        return vnew(math.floor(v.x+0.5), math.floor(v.y+0.5), math.floor(v.z+0.5))
    end,
    equals = function(a, b) return a.x==b.x and a.y==b.y and a.z==b.z end,
    distance = function(a, b)
        local dx, dy, dz = a.x-b.x, a.y-b.y, a.z-b.z
        return math.sqrt(dx*dx + dy*dy + dz*dz)
    end,
    rotate = function(v, rot)
        -- y-rotation only (all the mod uses)
        local c, s = math.cos(rot.y), math.sin(rot.y)
        return vnew(v.x*c - v.z*s, v.y, v.x*s + v.z*c)
    end,
}

-- ========== ItemStack ==========
local registered_items = {
    ["mcl_tools:sword_iron"] = {groups = {weapon = 1, sword = 1}},
    ["mcl_shields:shield"] = {groups = {shield = 1, weapon = 2}},
    ["mcl_armor:helmet_iron"] = {_mcl_armor_element = "head"},
    ["mcl_core:apple"] = {groups = {food = 2}},
    -- ranged/charge weapons must be REJECTED: they use
    -- controls.register_on_hold/on_release to track a right-mouse charge
    -- on the player's wielded item, which taking it away mid-click desyncs
    ["mcl_bows:bow"] = {groups = {weapon = 1, weapon_ranged = 1, bow = 1}},
    ["vl_weaponry:spear_iron"] = {groups = {weapon = 1, weapon_ranged = 1, spear = 1}},
    -- a plain melee weapon like VoxeLibre's hammer: weapon group, no
    -- shield/weapon_ranged -- should be ACCEPTED like a sword
    ["vl_weaponry:hammer_iron"] = {groups = {weapon = 1, hammer = 1}},
    -- tridents: allowed even with weapon_ranged. VoxeLibre's carries
    -- weapon_ranged (+ spear); Mineclonia's does not.
    ["vl_tridents:trident"] = {groups = {weapon = 1, weapon_ranged = 1, trident = 1, spear = 2}},
    ["mcl_tridents:trident"] = {groups = {weapon = 1, trident = 1}},
}
local StackMeta
local function ItemStack(init)
    local name, count = "", 0
    if type(init) == "table" then
        name, count = init.name or "", init.count or 0
    elseif type(init) == "string" and init ~= "" then
        name = init:match("^(%S+)")
        count = tonumber(init:match("%s(%d+)")) or 1
    end
    return setmetatable({_name = name, _count = count}, StackMeta)
end
StackMeta = {__index = {
    get_name = function(self) return self._name end,
    get_count = function(self) return self._count end,
    is_empty = function(self) return self._name == "" or self._count == 0 end,
    get_definition = function(self) return registered_items[self._name] end,
    take_item = function(self, n)
        n = math.min(n or 1, self._count)
        self._count = self._count - n
        local taken = ItemStack({name = self._name, count = n})
        if self._count == 0 then self._name = "" end
        return taken
    end,
    copy = function(self) return ItemStack({name = self._name, count = self._count}) end,
}}
_G.ItemStack = ItemStack

-- ========== inventory / meta ==========
local function Inventory()
    local lists = {}
    return {
        set_size = function(_, listname, size)
            lists[listname] = lists[listname] or {}
            for i = 1, size do
                lists[listname][i] = lists[listname][i] or ItemStack()
            end
        end,
        get_size = function(_, listname)
            return lists[listname] and #lists[listname] or 0
        end,
        get_stack = function(_, listname, i)
            return (lists[listname] and lists[listname][i] or ItemStack()):copy()
        end,
        set_stack = function(_, listname, i, stack)
            if type(stack) ~= "table" then stack = ItemStack(stack) end
            lists[listname][i] = stack:copy()
        end,
        get_list = function(_, listname) return lists[listname] end,
        get_lists = function(_) return lists end,
    }
end

-- ========== world state ==========
local nodes = {}       -- "x,y,z" -> node table
local metas = {}       -- "x,y,z" -> meta
local objects = {}     -- live entity objects
local drops = {}       -- itemstrings dropped via core.add_item
local function poskey(p) return p.x .. "," .. p.y .. "," .. p.z end

local registered_nodes, registered_entities, registered_lbms, registered_crafts = {}, {}, {}, {}

-- what pointed_thing_to_face_pos reports (test-tunable): y is the height
-- band, x is the sideways offset from the node center (world frame)
local face_pos_y = 0.5
local face_pos_x = 0

-- This harness simulates running under VoxeLibre: vl_weaponry (spears) is
-- present, matching how the mod detects IS_VOXELIBRE at load time.
-- mcl_armor_stand routes init.lua's game dispatch to the mcl.lua path.
local INSTALLED_MODS = {vl_weaponry = true, mcl_armor_stand = true}

core = {
    get_current_modname = function() return "armor_stand_arms" end,
    get_translator = function() return function(s) return s end end,
    get_modpath = function(name)
        -- the mod's own path must be real: init.lua dofiles mcl.lua from it
        if name == "armor_stand_arms" then return MOD_ROOT end
        return INSTALLED_MODS[name] and ("/mods/" .. name) or nil
    end,
    register_node = function(name, def) registered_nodes[name] = def end,
    register_entity = function(name, def) registered_entities[name] = def end,
    register_craftitem = function(name, def) registered_items[name] = def end,
    register_lbm = function(def) registered_lbms[#registered_lbms+1] = def end,
    register_craft = function(def) registered_crafts[#registered_crafts+1] = def end,
    get_node = function(pos)
        return nodes[poskey(vector.round(pos))] or {name = "air", param2 = 0}
    end,
    swap_node = function(pos, node) nodes[poskey(vector.round(pos))] = node end,
    get_meta = function(pos)
        local k = poskey(vector.round(pos))
        if not metas[k] then metas[k] = {inv = Inventory()} end
        local m = metas[k]
        return {get_inventory = function() return m.inv end}
    end,
    is_protected = function() return false end,
    record_protection_violation = function() end,
    facedir_to_dir = function(fd)
        local dirs = {
            [0] = vnew(0, 0, 1), [1] = vnew(1, 0, 0),
            [2] = vnew(0, 0, -1), [3] = vnew(-1, 0, 0),
        }
        return dirs[fd % 4]
    end,
    dir_to_yaw = function(dir) return math.atan(-dir.x, dir.z) end,
    pointed_thing_to_face_pos = function(clicker, pt)
        return vnew(pt.above.x + face_pos_x, pt.under.y + face_pos_y, pt.above.z)
    end,
    pos_to_string = function(p) return "(" .. p.x .. "," .. p.y .. "," .. p.z .. ")" end,
    string_to_pos = function(s)
        local x, y, z = s:match("%((%-?%d+),(%-?%d+),(%-?%d+)%)")
        if x then return vnew(tonumber(x), tonumber(y), tonumber(z)) end
    end,
    objects_inside_radius = function(pos, radius)
        local found, i = {}, 0
        for _, obj in ipairs(objects) do
            if not obj._removed and vector.distance(obj._pos, pos) <= radius + 1e-9 then
                found[#found+1] = obj
            end
        end
        return function()
            i = i + 1
            return found[i]
        end
    end,
    add_entity = function(pos, name, staticdata)
        local def = registered_entities[name]
        if not def then error("no such entity " .. name) end
        local obj
        obj = {
            _pos = vnew(pos.x, pos.y, pos.z),
            _removed = false,
            _properties = {},
            _rotation = vnew(0, 0, 0),
            is_player = function() return false end,
            get_pos = function(self) return self._pos end,
            set_pos = function(self, p) self._pos = vnew(p.x, p.y, p.z) end,
            set_yaw = function(self, yaw) self._rotation = vnew(0, yaw, 0) end,
            set_rotation = function(self, r) self._rotation = vnew(r.x, r.y, r.z) end,
            set_properties = function(self, props)
                for k, v in pairs(props) do self._properties[k] = v end
            end,
            set_armor_groups = function() end,
            remove = function(self) self._removed = true end,
        }
        local luaentity = setmetatable({object = obj, name = name}, {__index = def})
        obj.get_luaentity = function() return luaentity end
        objects[#objects+1] = obj
        if def.on_activate then luaentity:on_activate(staticdata or "") end
        return obj
    end,
    add_item = function(pos, stack)
        if type(stack) == "string" then stack = ItemStack(stack) end
        if stack and not stack:is_empty() then
            drops[#drops+1] = stack:get_name() .. " " .. stack:get_count()
        end
    end,
    log = function() end,
}

-- ========== game stubs (VoxeLibre-minimal surface) ==========
-- NOTE: this mock exposes only the SMALLER (VoxeLibre) mcl_armor / mcl_util
-- surface -- no has_piece, unequip, head_entity_equip/unequip,
-- drop_item_stack or float_random. If init.lua loads and every scenario
-- passes against this, it is compatible with both VoxeLibre and Mineclonia
-- (whose API is a superset).
local armor_calls = {}
mcl_armor = {
    elements = {
        head = {index = 2}, torso = {index = 3},
        legs = {index = 4}, feet = {index = 5},
    },
    equip = function(itemstack, obj, swap)
        armor_calls[#armor_calls+1] = "equip:" .. itemstack:get_name()
        return ItemStack()
    end,
    on_unequip = function(itemstack, obj)
        armor_calls[#armor_calls+1] = "unequip:" .. itemstack:get_name()
    end,
    update = function() end,
}
mcl_util = {}
mcl_sounds = {node_sound_wood_defaults = function() return {} end}
screwdriver = {ROTATE_FACE = 1, ROTATE_AXIS = 2}

-- ========== load the mod ==========
dofile(INIT_PATH)

local NODE = "armor_stand_arms:armor_stand"
local nodedef = registered_nodes[NODE]
check("node registered", nodedef ~= nil)
check("armor entity registered", registered_entities["armor_stand_arms:armor_entity"] ~= nil)
check("item entity registered", registered_entities["armor_stand_arms:item_entity"] ~= nil)
check("shield display craftitem registered", registered_items["armor_stand_arms:shield_display"] ~= nil)
check("craft registered", #registered_crafts == 1)
check("recipe is 7 sticks + slab", (function()
    local r = registered_crafts[1].recipe
    local sticks, slabs = 0, 0
    for _, row in ipairs(r) do
        for _, it in ipairs(row) do
            if it == "mcl_core:stick" then sticks = sticks + 1 end
            if it == "mcl_stairs:slab_stone" then slabs = slabs + 1 end
        end
    end
    return sticks == 8 and slabs == 1
end)())
check("mesh is armor_stand_arms.obj", nodedef.mesh == "armor_stand_arms.obj")

-- place the stand at (10, 5, 10), facing param2 = 0
local pos = vnew(10, 5, 10)
nodes[poskey(pos)] = {name = NODE, param2 = 0}
nodedef.on_construct(pos)
local function live(name)
    local n = 0
    for _, o in ipairs(objects) do
        if not o._removed and o:get_luaentity().name == name then n = n + 1 end
    end
    return n
end
check("stand entity spawned on construct", live("armor_stand_arms:armor_entity") == 1)
check("no item entity while hands empty", live("armor_stand_arms:item_entity") == 0)

local player = {
    is_player = function() return true end,
    get_player_name = function() return "nando" end,
    _wielded = ItemStack(),
    get_wielded_item = function(self) return self._wielded:copy() end,
}
local node = nodes[poskey(pos)]
local pt = {type = "node", under = pos, above = vnew(10, 5, 11)} -- side face

local function item_entity_for(slot)
    for _, o in ipairs(objects) do
        local le = o:get_luaentity()
        if not o._removed and le.name == "armor_stand_arms:item_entity" and le.slot == slot then
            return o
        end
    end
end

-- 1. right-click with a sword -> goes into the main hand
player._wielded = ItemStack("mcl_tools:sword_iron")
local ret = nodedef.on_rightclick(pos, node, player, ItemStack("mcl_tools:sword_iron"), pt)
local inv = core.get_meta(pos):get_inventory()
check("sword stored in hand slot", inv:get_stack("hand", 1):get_name() == "mcl_tools:sword_iron")
check("empty stack returned", ret:is_empty())
check("one item entity spawned", live("armor_stand_arms:item_entity") == 1)
local sword_obj = item_entity_for("main")
check("weapon entity is in the main slot", sword_obj ~= nil)
check("item entity shows the sword", sword_obj._properties.textures[1] == "mcl_tools:sword_iron")
check("item entity off node center", vector.distance(sword_obj._pos, pos) > 0.2)
check("item entity x offset rounds home", math.abs(sword_obj._pos.x - pos.x) < 0.5)
check("item entity z offset rounds home", math.abs(sword_obj._pos.z - pos.z) < 0.5)
-- simulate an activation without staticdata at the item's current position
local orphan = core.add_entity(sword_obj._pos, "armor_stand_arms:item_entity")
check("staticdata-less activation finds its node",
    vector.equals(orphan:get_luaentity().node_pos, pos))
orphan:remove()

-- 2. non-weapon (apple) is REJECTED: hand keeps the sword, apple returned
player._wielded = ItemStack("mcl_core:apple")
ret = nodedef.on_rightclick(pos, node, player, ItemStack("mcl_core:apple"), pt)
check("apple rejected (returned unchanged)", ret:get_name() == "mcl_core:apple")
check("hand still holds the sword", inv:get_stack("hand", 1):get_name() == "mcl_tools:sword_iron")

-- 2b. ranged/charge weapons (bow, spear) are REJECTED too, even though
-- they carry the weapon group -- taking them mid-click would desync their
-- own RMB charge-and-release tracking (this was a real in-game crash)
player._wielded = ItemStack("mcl_bows:bow")
ret = nodedef.on_rightclick(pos, node, player, ItemStack("mcl_bows:bow"), pt)
check("bow rejected (returned unchanged)", ret:get_name() == "mcl_bows:bow")
check("hand still holds the sword after bow attempt",
    inv:get_stack("hand", 1):get_name() == "mcl_tools:sword_iron")
check("no second item entity spawned for the bow", live("armor_stand_arms:item_entity") == 1)

player._wielded = ItemStack("vl_weaponry:spear_iron")
ret = nodedef.on_rightclick(pos, node, player, ItemStack("vl_weaponry:spear_iron"), pt)
check("spear rejected (returned unchanged)", ret:get_name() == "vl_weaponry:spear_iron")
check("hand still holds the sword after spear attempt",
    inv:get_stack("hand", 1):get_name() == "mcl_tools:sword_iron")

-- 2c. a trident IS accepted even though it carries weapon_ranged, and it
-- displays with its own item art (no substitution -- VoxeLibre's own blue
-- trident, at the normal weapon size)
inv:set_stack("hand", 1, "")
update_all_displays_via_lbm = registered_lbms[1]
update_all_displays_via_lbm.action(pos, node)
player._wielded = ItemStack("vl_tridents:trident")
ret = nodedef.on_rightclick(pos, node, player, ItemStack("vl_tridents:trident"), pt)
check("VoxeLibre trident accepted into the weapon hand",
    inv:get_stack("hand", 1):get_name() == "vl_tridents:trident")
check("trident returns empty (swap of an empty hand)", ret:is_empty())
local trident_obj = item_entity_for("main")
check("trident shows its own item art, not a substitute",
    trident_obj._properties.textures[1] == "vl_tridents:trident")
check("trident rendered at the normal weapon size (no VoxeLibre boost)",
    math.abs(trident_obj._properties.visual_size.x - 0.27) < 1e-9)
-- reset the hand back to the sword for the scenarios that follow
inv:set_stack("hand", 1, ItemStack("mcl_tools:sword_iron"))
update_all_displays_via_lbm.action(pos, node)
sword_obj = item_entity_for("main")

-- 3. shield -> goes into the OFF hand, second entity spawns
player._wielded = ItemStack("mcl_shields:shield")
ret = nodedef.on_rightclick(pos, node, player, ItemStack("mcl_shields:shield"), pt)
check("shield stored in offhand slot", inv:get_stack("offhand", 1):get_name() == "mcl_shields:shield")
check("shield returns empty", ret:is_empty())
check("two item entities now", live("armor_stand_arms:item_entity") == 2)
local shield_obj = item_entity_for("off")
check("shield entity is in the off slot", shield_obj ~= nil)
-- the actual item is stored in the inventory (checked above), but under
-- VoxeLibre the DISPLAYED texture is the bundled rectangular icon instead
-- of the real shield's own (skewed) icon -- see IS_VOXELIBRE in init.lua
check("shield entity shows the VoxeLibre display icon, not the raw shield",
    shield_obj._properties.textures[1] == "armor_stand_arms:shield_display")
check("VoxeLibre shield rendered 50% bigger than its base scale",
    math.abs(shield_obj._properties.visual_size.x - 0.34 * 1.5) < 1e-9)
check("weapon size unaffected by the VoxeLibre shield boost",
    math.abs(sword_obj._properties.visual_size.x - 0.27) < 1e-9)
check("weapon and shield on opposite arms (mirrored x)",
    (sword_obj._pos.x - pos.x) * (shield_obj._pos.x - pos.x) < 0)

-- 4. positional takes (stand still facing param2 = 0, so the harness's
-- face_pos_x maps 1:1 onto the stand-local sideways coordinate).
-- 4a. center click over an EMPTY torso slot with both hands full: armor
-- path only, hands must be left alone (regression: the old "empty piece
-- takes the weapon" fallback is gone)
player._wielded = ItemStack()
face_pos_y = 0.5
face_pos_x = 0
ret = nodedef.on_rightclick(pos, node, player, ItemStack(), pt)
check("center click over empty torso returns nothing", ret == nil or ret:is_empty())
check("center click leaves the weapon in place", inv:get_stack("hand", 1):get_name() == "mcl_tools:sword_iron")
check("center click leaves the shield in place", inv:get_stack("offhand", 1):get_name() == "mcl_shields:shield")

-- 4b. center click over an equipped torso piece with both hands full:
-- takes the ARMOR, not a held item (the reported annoyance, inverted)
inv:set_stack("armor", 3, ItemStack("mcl_armor:helmet_iron")) -- torso index = 3
armor_calls = {}
ret = nodedef.on_rightclick(pos, node, player, ItemStack(), pt)
check("center click takes the armor piece", ret:get_name() == "mcl_armor:helmet_iron")
check("armor slot cleared", inv:get_stack("armor", 3):is_empty())
check("on_unequip fired", armor_calls[1] == "unequip:mcl_armor:helmet_iron")
check("armor take leaves the weapon in place", inv:get_stack("hand", 1):get_name() == "mcl_tools:sword_iron")

-- 4c. click on the weapon side -> takes the weapon directly
face_pos_x = -0.3
ret = nodedef.on_rightclick(pos, node, player, ItemStack(), pt)
check("weapon-side click takes the weapon", ret:get_name() == "mcl_tools:sword_iron")
check("hand slot empty after weapon take", inv:get_stack("hand", 1):is_empty())
check("weapon entity removed, shield remains", live("armor_stand_arms:item_entity") == 1)

-- 4d. weapon side again while that hand is empty: falls through to the
-- armor logic without touching the shield
ret = nodedef.on_rightclick(pos, node, player, ItemStack(), pt)
check("empty weapon-side click leaves the shield alone",
    inv:get_stack("offhand", 1):get_name() == "mcl_shields:shield")

-- 4e. click on the shield side -> takes the shield directly
face_pos_x = 0.3
ret = nodedef.on_rightclick(pos, node, player, ItemStack(), pt)
check("shield-side click takes the shield", ret:get_name() == "mcl_shields:shield")
check("offhand slot empty after shield take", inv:get_stack("offhand", 1):is_empty())
check("all item entities removed", live("armor_stand_arms:item_entity") == 0)
face_pos_x = 0

-- 5. re-equip both hands, then screwdriver rotate moves BOTH item entities
player._wielded = ItemStack("mcl_tools:sword_iron")
nodedef.on_rightclick(pos, node, player, ItemStack("mcl_tools:sword_iron"), pt)
player._wielded = ItemStack("mcl_shields:shield")
nodedef.on_rightclick(pos, node, player, ItemStack("mcl_shields:shield"), pt)
sword_obj = item_entity_for("main")
shield_obj = item_entity_for("off")
local old_sword = vnew(sword_obj._pos.x, sword_obj._pos.y, sword_obj._pos.z)
local old_shield = vnew(shield_obj._pos.x, shield_obj._pos.y, shield_obj._pos.z)
check("on_rotate handled", nodedef.on_rotate(pos, {name = NODE, param2 = 0}, nil, screwdriver.ROTATE_FACE) == true)
node = nodes[poskey(pos)]
check("param2 rotated", node.param2 == 1)
check("weapon moved with rotation", not vector.equals(sword_obj._pos, old_sword))
check("shield moved with rotation", not vector.equals(shield_obj._pos, old_shield))
-- empty the hands again for the following scenarios (zone math against
-- the mocked face position is only meaningful at param2 = 0)
inv:set_stack("hand", 1, "")
inv:set_stack("offhand", 1, "")
update_all_displays_via_lbm = registered_lbms[1]
update_all_displays_via_lbm.action(pos, node)
check("hands emptied for later scenarios", live("armor_stand_arms:item_entity") == 0)

-- 8. helmet routes to mcl_armor.equip
armor_calls = {}
player._wielded = ItemStack("mcl_armor:helmet_iron")
ret = nodedef.on_rightclick(pos, node, player, ItemStack("mcl_armor:helmet_iron"), pt)
check("helmet routed to mcl_armor.equip", armor_calls[1] == "equip:mcl_armor:helmet_iron")

-- 9. LBM respawn: wipe entities, run action, both hands refilled
inv:set_stack("hand", 1, ItemStack("mcl_tools:sword_iron"))
inv:set_stack("offhand", 1, ItemStack("mcl_shields:shield"))
for _, o in ipairs(objects) do o._removed = true end
registered_lbms[1].action(pos, node)
check("LBM respawns stand entity", live("armor_stand_arms:armor_entity") == 1)
check("LBM respawns both item entities", live("armor_stand_arms:item_entity") == 2)
check("LBM-respawned shield also shows the display icon (on_activate path)",
    item_entity_for("off")._properties.textures[1] == "armor_stand_arms:shield_display")
check("LBM-respawned weapon still shows the raw item",
    item_entity_for("main")._properties.textures[1] == "mcl_tools:sword_iron")

-- 10. dig: drops armor + weapon + shield
inv:set_stack("armor", 2, ItemStack("mcl_armor:helmet_iron"))
nodedef.on_destruct(pos)
local dropped = table.concat(drops, ";")
check("drops include weapon", dropped:match("sword_iron") ~= nil)
check("drops include shield", dropped:match("shield") ~= nil)
check("drops include armor", dropped:match("helmet_iron") ~= nil)
check("all item entities removed on destruct", live("armor_stand_arms:item_entity") == 0)

-- 11. a fresh stand: hammer acceptance + the nil pointed_thing crash.
-- Some weapons (VoxeLibre's bow) forward a click to the pointed node's
-- on_rightclick with a nil pointed_thing (only 4 args passed through);
-- this must not crash, regardless of what's wielded or in-hand.
local pos3 = vnew(30, 5, 30)
nodes[poskey(pos3)] = {name = NODE, param2 = 0}
nodedef.on_construct(pos3)
local node3 = nodes[poskey(pos3)]
local inv3 = core.get_meta(pos3):get_inventory()

player._wielded = ItemStack("vl_weaponry:hammer_iron")
ret = nodedef.on_rightclick(pos3, node3, player, ItemStack("vl_weaponry:hammer_iron"), pt)
check("hammer accepted like any other melee weapon",
    inv3:get_stack("hand", 1):get_name() == "vl_weaponry:hammer_iron")
check("empty stack returned for the accepted hammer", ret:is_empty())

-- nil pointed_thing while wielding a rejected ranged weapon (the exact
-- reported crash): must not error, and must fall through to rejection
player._wielded = ItemStack("mcl_bows:bow")
local ok, ret_or_err = pcall(nodedef.on_rightclick, pos3, node3, player, ItemStack("mcl_bows:bow"), nil)
check("nil pointed_thing + rejected weapon does not crash", ok)
check("bow still rejected with nil pointed_thing", ok and ret_or_err:get_name() == "mcl_bows:bow")
check("hammer still in hand, untouched by the bow attempt",
    inv3:get_stack("hand", 1):get_name() == "vl_weaponry:hammer_iron")

-- nil pointed_thing with an empty hand (a "take" attempt gone through the
-- same broken forwarding path): must not error either
player._wielded = ItemStack()
local ok2, ret2_or_err = pcall(nodedef.on_rightclick, pos3, node3, player, ItemStack(), nil)
check("nil pointed_thing + empty hand does not crash", ok2)
check("hammer left untouched (no face info to act on)",
    inv3:get_stack("hand", 1):get_name() == "vl_weaponry:hammer_iron")

-- 12. Mineclonia path: reload without vl_weaponry -> both held items are
-- rendered 10% smaller, and the shield shows its own (real) icon
INSTALLED_MODS.vl_weaponry = nil
dofile(INIT_PATH)
nodedef = registered_nodes[NODE]
local pos4 = vnew(40, 5, 40)
nodes[poskey(pos4)] = {name = NODE, param2 = 0}
nodedef.on_construct(pos4)
local inv4 = core.get_meta(pos4):get_inventory()
inv4:set_stack("hand", 1, ItemStack("mcl_tools:sword_iron"))
inv4:set_stack("offhand", 1, ItemStack("mcl_shields:shield"))
registered_lbms[#registered_lbms].action(pos4, nodes[poskey(pos4)])
local mcl_sword, mcl_shield
for _, o in ipairs(objects) do
    local le = o:get_luaentity()
    if not o._removed and le.name == "armor_stand_arms:item_entity"
            and le.node_pos and vector.equals(le.node_pos, pos4) then
        if le.slot == "main" then mcl_sword = o else mcl_shield = o end
    end
end
check("Mineclonia weapon 10% smaller (0.27 * 0.9)",
    math.abs(mcl_sword._properties.visual_size.x - 0.27 * 0.9) < 1e-9)
check("Mineclonia shield 10% smaller, no VoxeLibre boost (0.34 * 0.9)",
    math.abs(mcl_shield._properties.visual_size.x - 0.34 * 0.9) < 1e-9)
check("Mineclonia shield shows the real shield icon",
    mcl_shield._properties.textures[1] == "mcl_shields:shield")

-- 12b. Mineclonia trident (no weapon_ranged) is accepted and shows its OWN
-- item, not the display stand-in (that substitution is VoxeLibre-only)
inv4:set_stack("hand", 1, "")
inv4:set_stack("offhand", 1, "")
registered_lbms[#registered_lbms].action(pos4, nodes[poskey(pos4)])
player._wielded = ItemStack("mcl_tridents:trident")
ret = nodedef.on_rightclick(pos4, nodes[poskey(pos4)], player, ItemStack("mcl_tridents:trident"),
    {type = "node", under = pos4, above = vnew(40, 5, 41)})
check("Mineclonia trident accepted", inv4:get_stack("hand", 1):get_name() == "mcl_tridents:trident")
local mcl_trident
for _, o in ipairs(objects) do
    local le = o:get_luaentity()
    if not o._removed and le.name == "armor_stand_arms:item_entity"
            and le.slot == "main" and le.node_pos and vector.equals(le.node_pos, pos4) then
        mcl_trident = o
    end
end
check("Mineclonia trident shows its own item, not the display stand-in",
    mcl_trident._properties.textures[1] == "mcl_tridents:trident")

return #checks
"""


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals()["INIT_PATH"] = os.path.abspath(INIT)
    lua.globals()["MOD_ROOT"] = os.path.abspath(os.path.join(HERE, ".."))
    n = lua.execute(HARNESS)
    print("OK: %d checks passed" % n)


if __name__ == "__main__":
    main()
