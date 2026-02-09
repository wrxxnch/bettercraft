--[[
    BlockHead — A Minetest mod for putting blocks on your head.
    Copyright © 2023-2024, Silver Sandstone <@SilverSandstone@craftodon.social>

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]


--- BlockHead — A Minetest mod for putting blocks on your head.
-- @module blockhead


local S = minetest.get_translator('blockhead');


-- For compatibility with older Minetest versions:
local vector_copy = vector.copy or vector.new;
local vector_zero = vector.zero or function() return vector.new(0, 0, 0); end;


--- Mod API namespace.
blockhead = {};


blockhead.HEAD_BONE = 'Head';
blockhead.ATTACH_OFFSET = vector.new(0, 2.0, 0);
blockhead.SCALE = vector.new(0.301, 0.301, 0.301);

blockhead.PARAMS = '[-<|--left|->|--right|-b|--backwards] [-t|--top] [-r|--remove] [-S|--scale <X,Y,Z>] [-T|--translate <X,Y,Z>] [-R|--rotate <X,Y,Z>] [<ItemString>]';

if minetest.get_modpath('rp_player') then
    blockhead.HEAD_BONE = 'head';
    blockhead.ATTACH_OFFSET = vector.new(0, 1.1, 0);
end;


-- Functions:


--- Sets the player's state.
-- @param player [ObjectRef] The player to set the state of.
-- @param state  [State]     The new state.
-- @return       [boolean]   true on success.
function blockhead.set_state(player, state)
    local item = ItemStack(state and state.item);
    if item:is_empty() then
        blockhead.clear_state(player);
        return true;
    end;

    state =
    {
        item   = item:to_string();
        offset = state.offset and vector_copy(state.offset);
        rotate = state.rotate and vector_copy(state.rotate);
        scale  = state.scale  and vector_copy(state.scale);
    };

    local meta = player:get_meta();
    meta:set_string('blockhead:state', minetest.serialize(state));

    local entity = blockhead.get_or_add_entity(player);
    if not entity then
        return false;
    end;

    state.item = item;
    entity:set_state(state);
    return true;
end;


--- Gets the player's current state.
-- @param player [ObjectRef] The player to get the state of.
-- @return       [State|nil] The player's current state, or nil.
function blockhead.get_state(player)
    if not player then
        return nil;
    end;
    local meta = player:get_meta();
    local state = minetest.deserialize(meta:get_string('blockhead:state'));
    if not state then
        return nil;
    end;
    state.item   = ItemStack(state.item);
    state.offset = state.offset and vector_copy(state.offset);
    state.rotate = state.rotate and vector_copy(state.rotate);
    state.scale  = state.scale  and vector_copy(state.scale);
    return state;
end;


--- Clears the player's state.
-- @param player [ObjectRef] The player to clear the state of.
function blockhead.clear_state(player)
    local meta = player:get_meta();
    meta:set_string('blockhead:state', '');

    local entity = blockhead.get_entity(player);
    if entity then
        entity.object:remove();
    end;
end;


--- Puts a block from an ItemStack onto the player's head.
-- @param player       [ObjectRef]     The player to put the block on.
-- @param stack        [ItemStack]     The itemstack to take the block from.
-- @param args         [State]         Additional state parameters.
-- @return             [ItemStack|nil] The leftover itemstack, or nil on failure.
-- @return             [ItemStack|nil] The old item.
-- @return             [string|nil]    An error message on failure.
function blockhead.set_head_block_from_stack(player, stack, args)
    if not (stack:is_empty() or blockhead.is_node(stack:get_name())) then
        return nil, nil, S'This item is not a block.';
    end;

    stack = ItemStack(stack);
    local old = blockhead.get_state(player);
    local item = stack:take_item(1);

    local state = {item = item};
    for key, value in pairs(args or {}) do
        state[key] = value;
    end;
    local success = blockhead.set_state(player, state);

    if not success then
        return nil, nil, S'An error occurred.';
    end;

    return stack, old and old.item, nil;
end;


--- Gets the player's head block entity, or creates a new one if necessary.
-- @param player [ObjectRef]           The player to get the entity of.
-- @return       [BlockHeadEntity|nil] The player's head block entity, or nil on failure.
function blockhead.get_or_add_entity(player)
    local entity = blockhead.get_entity(player);
    if not entity then
        entity = blockhead.add_entity(player);
    end;
    return entity;
end;


--- Gets the player's head block entity.
-- @param player [ObjectRef]           The player to get the entity of.
-- @return       [BlockHeadEntity|nil] The player's head block entity, or nil if they don't have one.
function blockhead.get_entity(player)
    local player_name = player:get_player_name();
    if (not player_name) or player_name == '' then
        return nil;
    end;
    local children;
    if player.get_children then
        children = player:get_children();
    else
        children = minetest.get_objects_inside_radius(player:get_pos(), 1);
    end;
    for __, object in ipairs(children) do
        local entity = object:get_luaentity();
        if entity and entity.name == 'blockhead:blockhead' and entity.player_name == player_name then
            return entity;
        end;
    end;
    return nil;
end;


--- Creates a head block entity for the player.
-- @param player [ObjectRef]           The player to create the entity for.
-- @param state  [State]               The initial state of the entity.
-- @return       [BlockHeadEntity|nil] The new entity, or nil on failure.
function blockhead.add_entity(player, state)
    local object = minetest.add_entity(player:get_pos(), 'blockhead:blockhead');
    if not object then
        minetest.log('error', '[BlockHead] Failed to spawn entity!');
        return nil;
    end;
    object:set_attach(player, 'Head', vector_zero(), vector_zero());

    local entity = object:get_luaentity();
    entity.player_name = player:get_player_name();
    return entity;
end;


--- Checks if the specified item name refers to a node.
-- @param name [string]  An item name.
-- @return     [boolean] true if the item is a node.
function blockhead.is_node(name)
    return minetest.registered_nodes[name] ~= nil;
end;


--- Checks if the player is allowed to spawn the specified item.
-- @param player [ObjectRef|string] The player to check.
-- @param item   [string]           The name of the item to spawn.
-- @return       [boolean]          true if the player is allowed to spawn the item.
function blockhead.can_spawn_item(player, item)
    if type(player) ~= 'string' then
        player = player:get_player_name();
    end;

    -- Players with the ‘give’ privilege can spawn anything.
    if minetest.check_player_privs(player, 'give') then
        return true;
    end;

    -- Players in creative mode can spawn non-technical items.
    if minetest.is_creative_enabled(player) then
        return minetest.get_item_group(item, 'not_in_creative_inventory') <= 0;
    end;

    -- Other players can't spawn items.
    return false;
end;


--- Parses a vector string.
-- @param str    [string]     A string in the form 'X, Y, Z' or '(X, Y, Z)'.
-- @param coords [string|nil] A subset of 'xyz', or nil. If not nil, a single number will be assigned to these coordinates.
-- @return       [vector|nil] A vector on success.
-- @return       [string|nil] A human-readable error message on failure.
function blockhead.parse_vector(str, coords)
    if not str then
        return nil, S'Vector required.';
    end;

    local x, y, z = string.match(str, '%s*%(?%s*([%d.+-]+)%s*,%s*([%d.+-]+)%s*,%s*([%d.+-]+)%s*%)?%s*');
    if x then
        return vector.new(tonumber(x), tonumber(y), tonumber(z));
    end;

    if coords then
        local number = tonumber(str);
        if number then
            local result = vector_zero();
            for coord in coords:gmatch('[xyz]') do
                result[coord] = number;
            end;
            return result;
        end;
    end;

    return nil, S('Invalid vector: ‘@1’.', str);
end;


--- Implements the /blockhead command.
-- @param name  [string]  The name of the player running the command.
-- @param param [string]  Arguments passed to the command.
-- @return      [boolean] true on success.
function blockhead.run_chatcommand(name, param)
    local function _send(message)
        minetest.chat_send_player(name, message);
    end;

    local player = minetest.get_player_by_name(name);
    if not player then
        return false;
    end;
    local item = nil;
    local offset = vector_zero();
    local rotate = vector_zero();
    local scale = vector.new(1, 1, 1);

    local args = param:split(' ');
    local index = 1;
    while index <= #args do
        local function _shift()
            local result = args[index];
            index = index + 1;
            return result;
        end;

        local arg = _shift();
        if arg == '' then
        elseif arg == '-h' or arg == '--help' then
            _send('/blockhead ' .. blockhead.PARAMS);
            return true;
        elseif arg == '-b' or arg == '--backwards' then
            rotate = vector.add(rotate, vector.new(0, 180, 0));
        elseif arg == '-t' or arg == '--top' then
            offset = vector.add(offset, vector.new(0, 8.5, 0));
        elseif arg == '-r' or arg == '--remove' then
            item = ItemStack();
        elseif arg == '-<' or arg == '--left' then
            rotate = vector.add(rotate, vector.new(0, -90, 0));
        elseif arg == '->' or arg == '--right' then
            rotate = vector.add(rotate, vector.new(0, 90, 0));
        elseif arg == '-T' or arg == '--translate' then
            local v, message = blockhead.parse_vector(_shift(), 'y');
            if not v then
                _send(message);
                return false;
            end;
            offset = vector.add(offset, v);
        elseif arg == '-R' or arg == '--rotate' then
            local v, message = blockhead.parse_vector(_shift(), 'y');
            if not v then
                _send(message);
                return false;
            end;
            rotate = vector.add(rotate, v);
        elseif arg == '-S' or arg == '--scale' then
            local v, message = blockhead.parse_vector(_shift(), 'xyz');
            if not v then
                _send(message);
                return false;
            end;
            scale = vector.multiply(scale, v);
        elseif arg:sub(1, 1) == '-' then
            _send(S('Invalid argument: ‘@1’.', arg));
            return false;
        elseif not item then
            item = ItemStack(arg);
        else
            _send(S'Cannot specify multiple items.')
            return false;
        end;
    end;

    local stack = player:get_wielded_item();
    local give_mode = minetest.is_creative_enabled(name);
    if item then
        if not blockhead.can_spawn_item(player, item) then
            _send(S'You do not have permission to spawn this item.');
            return false;
        end;
        give_mode = true;
        stack = item;
    end;

    local args = {offset = offset, rotate = rotate, scale = scale};
    local leftover, old_item, err = blockhead.set_head_block_from_stack(player, stack, args);
    if not give_mode then
        player:set_wielded_item(leftover);
    end;
    if old_item then
        minetest.handle_node_drops(player:get_pos(), {old_item}, player);
    end;
    if err then
        minetest.chat_send_player(name, err);
        return false;
    end;
    return true;
end;


--- Called when a player joins, to restore their saved head block state.
-- @param player [ObjectRef] The player who joined.
function blockhead.on_joinplayer(player)
    local function _initialise()
        local state = blockhead.get_state(player);
        local ok = blockhead.set_state(player, state);
        if not ok then
            minetest.log('error', ('Failed to set state of %s.'):format(player:get_player_name()));
        end;
    end;

    minetest.after(0.1, _initialise);
end;
minetest.register_on_joinplayer(blockhead.on_joinplayer);


-- Chat command:


minetest.register_chatcommand('blockhead',
{
    description = S'Puts a block on your head.';
    params      = blockhead.PARAMS;
    func        = blockhead.run_chatcommand;
});


-- Entity:


--- The head block entity.
-- @type blockhead.BlockHeadEntity
blockhead.BlockHeadEntity = {};

blockhead.BlockHeadEntity.initial_properties =
{
    visual       = 'item';
    static_save  = false;
    visual_size  = blockhead.SCALE;
    physical     = false;
    pointable    = false;
};

--- Called every game tick.
-- @param dtime [number] Seconds elapsed since the last tick.
function blockhead.BlockHeadEntity:on_step(dtime)
    if not self:get_player() then
        self.object:remove();
    end;
end;

--- Sets the entity's state.
-- @param state [State] The new state.
function blockhead.BlockHeadEntity:set_state(state)
    local player = self:get_player();
    if not player then
        return;
    end;
    local offset = vector.add(blockhead.ATTACH_OFFSET, vector.multiply(state.offset or vector_zero(), 0.5));
    local rotate = state.rotate or vector_zero();
    local scale = vector.multiply(blockhead.SCALE, state.scale or 1);
    self.object:set_properties{wield_item = state.item:to_string(), visual_size = scale};
    self.object:set_attach(player, blockhead.HEAD_BONE, offset, rotate);
end;

--- Gets the entity's associated player.
-- @return [ObjectRef] The player associated with this entity.
function blockhead.BlockHeadEntity:get_player()
    return self.object:get_attach();
end;

minetest.register_entity('blockhead:blockhead', blockhead.BlockHeadEntity);
