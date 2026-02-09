local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape

local command_blocks_activated = core.settings:get_bool("mcl_enable_commandblocks", true)
local msg_not_activated = S("Command blocks are not enabled on this server")

-- Use core.vector if available, otherwise fallback to table
local vector_sub = vector.subtract or function(p1, p2)
	return {x = p1.x - p2.x, y = p1.y - p2.y, z = p1.z - p2.z}
end

local vector_add = vector.add or function(p1, p2)
	return {x = p1.x + p2.x, y = p1.y + p2.y, z = p1.z + p2.z}
end

-- Helper to safely get redstone power without crashing if internal API fails
local function safe_get_power(pos)
	if not mcl_redstone or not mcl_redstone.get_power then return false end
	-- Wrap in pcall because mcl_redstone:get_power can crash internally on some versions
	local status, power = pcall(mcl_redstone.get_power, pos)
	if status then
		return (power or 0) > 0
	end
	return false
end

-- Helper to get the success state of the block behind
local function get_success_behind(pos)
	local node = core.get_node(pos)
	local dir = core.facedir_to_dir(node.param2)
	local behind_pos = vector_sub(pos, dir)
	local meta = core.get_meta(behind_pos)
	return meta:get_int("success_count") > 0
end

local function resolve_commands(commands, pos)
	local players = core.get_connected_players()
	local meta = core.get_meta(pos)
	local commander = meta:get_string("commander")
	local SUBSTITUTE_CHARACTER = "\26"

	if #players == 0 then
		commands = commands:gsub("[^\r\n]+", function (line)
			line = line:gsub("@@", SUBSTITUTE_CHARACTER)
			if line:find("@n") or line:find("@p") or line:find("@f") or line:find("@r") then return "" end
			line = line:gsub("@c", commander)
			line = line:gsub(SUBSTITUTE_CHARACTER, "@")
			return line
		end)
		return commands
	end

	local nearest, farthest = nil, nil
	local min_distance, max_distance = math.huge, -1
	for _, player in pairs(players) do
		local distance = vector.distance(pos, player:get_pos())
		if distance < min_distance then
			min_distance = distance
			nearest = player:get_player_name()
		end
		if distance > max_distance then
			max_distance = distance
			farthest = player:get_player_name()
		end
	end
	local random = players[math.random(#players)]:get_player_name()
	commands = commands:gsub("@@", SUBSTITUTE_CHARACTER)
	commands = commands:gsub("@p", nearest)
	commands = commands:gsub("@n", nearest)
	commands = commands:gsub("@f", farthest)
	commands = commands:gsub("@r", random)
	commands = commands:gsub("@c", commander)
	commands = commands:gsub(SUBSTITUTE_CHARACTER, "@")
	return commands
end

local function check_commands(commands, player_name)
	for _, command in pairs(commands:split("\n")) do
		if command ~= "" then
			local pos = command:find(" ")
			local cmd = pos and command:sub(1, pos - 1) or command
			local cmddef = core.chatcommands[cmd]
			if not cmddef then
				local msg = S("Error: The command “@1” does not exist.", cmd)
				return false, core.colorize("#FF0000", msg)
			end
			if player_name then
				local player_privs = core.get_player_privs(player_name)
				for cmd_priv, _ in pairs(cmddef.privs or {}) do
					if not player_privs[cmd_priv] then
						local msg = S("Error: Missing privilege: @1", cmd_priv)
						return false, core.colorize("#FF0000", msg)
					end
				end
			end
		end
	end
	return true
end

local function execute_commandblock(pos)
	if not command_blocks_activated then return end
	
	local meta = core.get_meta(pos)
	local node = core.get_node(pos)
	
	-- Check condition if conditional
	if meta:get_int("conditional") == 1 then
		if not get_success_behind(pos) then
			meta:set_int("success_count", 0)
			return
		end
	end

	local commander = meta:get_string("commander")
	local commands = resolve_commands(meta:get_string("commands"), pos)
	local success_count = 0
	
	for _, command in pairs(commands:split("\n")) do
		if command ~= "" then
			local cpos = command:find(" ")
			local cmd = cpos and command:sub(1, cpos - 1) or command
			local param = cpos and command:sub(cpos + 1) or ""
			local cmddef = core.chatcommands[cmd]
			if cmddef then
				local success, msg = cmddef.func(commander, param)
				if success ~= false then
					success_count = success_count + 1
				end
			end
		end
	end
	
	meta:set_int("success_count", success_count)
	
	-- Trigger chain blocks in front
	local dir = core.facedir_to_dir(node.param2)
	local front_pos = vector_add(pos, dir)
	local front_node = core.get_node(front_pos)
if front_node and front_node.name:find("chain") then
    local front_meta = core.get_meta(front_pos)
    local front_auto = front_meta:get_int("auto") == 1
    local front_powered = safe_get_power(front_pos)
    if front_auto or front_powered then
        execute_commandblock(front_pos)
    end
end

end

local function update_commandblock(pos)
    local meta = core.get_meta(pos)
    local auto = meta:get_int("auto") == 1
    local powered = safe_get_power(pos)
    local node = core.get_node(pos)

    if node.name:find("repeating") then
        if auto or powered then
            if not core.get_node_timer(pos):is_started() then
                core.get_node_timer(pos):start(0.1)
            end
        else
            core.get_node_timer(pos):stop()
        end
    elseif node.name:find("chain") then
        -- Agora Chain blocks também são disparados por si próprios se auto=1
        if auto or powered then
            execute_commandblock(pos)
        end
    else -- Impulse
        if (auto or powered) and meta:get_int("was_powered") == 0 then
            execute_commandblock(pos)
        end
        meta:set_int("was_powered", (auto or powered) and 1 or 0)
    end
end


local function get_formspec(pos, player)
	local meta = core.get_meta(pos)
	local commands = meta:get_string("commands")
	local mode = meta:get_int("mode") -- 0: Impulse, 1: Chain, 2: Repeat
	local conditional = meta:get_int("conditional") -- 0: Unconditional, 1: Conditional
	local auto = meta:get_int("auto") -- 0: Needs Redstone, 1: Always Active
	
	local mode_text = {S("Impulse"), S("Chain"), S("Repeat")}
	local cond_text = {S("Unconditional"), S("Conditional")}
	local auto_text = {S("Needs Redstone"), S("Always Active")}
	
	local formspec = "size[9,8]" ..
		"textarea[0.5,0.5;8.5,4;commands;" .. F(S("Commands:")) .. ";" .. F(commands) .. "]" ..
		"button[0.5,5;2.5,0.8;toggle_mode;" .. F(mode_text[mode+1]) .. "]" ..
		"button[3.25,5;2.5,0.8;toggle_cond;" .. F(cond_text[conditional+1]) .. "]" ..
		"button[6,5;2.5,0.8;toggle_auto;" .. F(auto_text[auto+1]) .. "]" ..
		"button_exit[3.5,7;2,1;submit;" .. F(S("Done")) .. "]" ..
		"label[0.5,4.5;" .. F(S("Commander: @1", meta:get_string("commander"))) .. "]"
	
	return formspec
end

local commdef = {
	groups = {creative_breakable=1, unmovable_by_piston = 1, command_block = 1},
	drop = "",
	is_ground_content = false,
	paramtype2 = "facedir",
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:set_string("commands", "")
		meta:set_string("commander", "")
		meta:set_int("mode", 0)
		meta:set_int("conditional", 0)
		meta:set_int("auto", 0)
		meta:set_int("success_count", 0)
		meta:set_int("was_powered", 0)
	end,
	after_place_node = function(pos, placer)
		if placer then
			local meta = core.get_meta(pos)
			meta:set_string("commander", placer:get_player_name())
		end
		update_commandblock(pos)
	end,
	on_rightclick = function(pos, node, player)
		local pname = player:get_player_name()
		local privs = core.get_player_privs(pname)
		if core.is_creative_enabled(pname) and privs.maphack then
			core.show_formspec(pname, "mcl_cb:" .. pos.x .. "," .. pos.y .. "," .. pos.z, get_formspec(pos, player))
		else
			core.chat_send_player(pname, S("You need Creative Mode and 'maphack' privilege to edit this."))
		end
	end,
	on_timer = function(pos)
		execute_commandblock(pos)
		return true
	end,
	_mcl_redstone = {
		update = function(pos, node)
			update_commandblock(pos)
		end,
	},
}

core.register_node("mcl_commandblock:commandblock_off", table.merge(commdef, {
	description = S("Impulse Command Block"),
	tiles = {{name="jeija_commandblock_off.png", animation={type="vertical_frames", aspect_w=32, aspect_h=32, length=2}}},
}))

core.register_node("mcl_commandblock:chain_commandblock", table.merge(commdef, {
	description = S("Chain Command Block"),
	tiles = {{name="mcl_commandblock_chain.png", animation={type="vertical_frames", aspect_w=32, aspect_h=32, length=2}}},
	groups = table.merge(commdef.groups, {not_in_creative_inventory=1}),
}))

core.register_node("mcl_commandblock:repeating_commandblock", table.merge(commdef, {
	description = S("Repeating Command Block"),
    tiles = {{name="mcl_commandblock_repeating.png", animation={type="vertical_frames", aspect_w=32, aspect_h=32, length=2}}},
	groups = table.merge(commdef.groups, {not_in_creative_inventory=1}),
}))

-- Field receive handler
core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:sub(1, 7) ~= "mcl_cb:" then return end

	local pos_str = formname:sub(8)
	local x, y, z = pos_str:match("([^,]+),([^,]+),([^,]+)")
	if not (x and y and z) then return end
	local pos = {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
	local meta = core.get_meta(pos)
	local node = core.get_node(pos)
	local pname = player:get_player_name()
	
	if not core.is_creative_enabled(pname)  then
	     return
	end

	local function swap_node_keep_meta(pos, new_node_name)
		local old_meta = core.get_meta(pos):to_table()
		local param2 = core.get_node(pos).param2
		core.swap_node(pos, {name=new_node_name, param2=param2})
		core.get_meta(pos):from_table(old_meta)
	end

	-- Antes de qualquer troca, salvar o conteúdo atual da textarea
	if fields.commands then
		meta:set_string("commands", fields.commands)
	end

	-- Trocar tipo de bloco (modo)
	if fields.toggle_mode then
		local mode = (meta:get_int("mode") + 1) % 3
		meta:set_int("mode", mode)

		local new_node = "mcl_commandblock:commandblock_off"
		if mode == 1 then
			new_node = "mcl_commandblock:chain_commandblock"
		elseif mode == 2 then
			new_node = "mcl_commandblock:repeating_commandblock"
		end

		swap_node_keep_meta(pos, new_node)
		update_commandblock(pos)
		core.show_formspec(pname, formname, get_formspec(pos, player))
	end

	-- Trocar condicional
	if fields.toggle_cond then
		meta:set_int("conditional", 1 - meta:get_int("conditional"))
		core.show_formspec(pname, formname, get_formspec(pos, player))
	end

	-- Trocar modo automático
	if fields.toggle_auto then
		meta:set_int("auto", 1 - meta:get_int("auto"))
		update_commandblock(pos)
		core.show_formspec(pname, formname, get_formspec(pos, player))
	end

	-- Submeter comandos (finalizar)
	if fields.submit or fields.key_enter then
		local check, err = check_commands(fields.commands, pname)
		if check then
			meta:set_string("commands", fields.commands)
			update_commandblock(pos)
		else
			core.chat_send_player(pname, err)
		end
	end
end)

