local S = core.get_translator(core.get_current_modname())

--------------------------------------------------
-- GLOBAL SOUND CACHE
--------------------------------------------------

local ALL_SOUNDS = {}

--------------------------------------------------
-- COUNT HELPER
--------------------------------------------------

local function table_count(t)
	local c = 0
	for _ in pairs(t) do
		c = c + 1
	end
	return c
end

--------------------------------------------------
-- BUILD SOUND CACHE (ALL MODS SAFE)
--------------------------------------------------

local function build_sound_cache()

	ALL_SOUNDS = {}

	local modnames = core.get_modnames()

	for _, modname in ipairs(modnames) do

		local modpath = core.get_modpath(modname)

		if modpath then
			local soundpath = modpath .. "/sounds"

			-- verificar se pasta existe
			if core.get_dir_list(soundpath, false) then

				local files = core.get_dir_list(soundpath, false)

				for _, file in ipairs(files) do
					if file:match("%.ogg$") then

						local soundname = file:gsub("%.ogg$", "")

						ALL_SOUNDS[soundname] = true
					end
				end
			end
		end
	end

	core.log("action", "[PlaySound] Loaded sounds: " .. table_count(ALL_SOUNDS))
end

--------------------------------------------------
-- BUILD CACHE AFTER ALL MODS LOADED
--------------------------------------------------

core.register_on_mods_loaded(function()
	build_sound_cache()
end)

--------------------------------------------------
-- /playsound
--------------------------------------------------

core.register_chatcommand("playsound", {
	params = "<sound> <target>",
	description = "Play a sound directly",
	privs = { server = true },

	func = function(_, rawparams)

		local sound, target = rawparams:match("^(%S+)%s+(%S+)$")

		if not sound then
			return false, "Sound name is invalid!"
		end

		if not (target and core.player_exists(target)) then
			return false, "Target is invalid!"
		end

		core.sound_play(sound, {
			to_player = target,
			gain = 1.0,
		})

		return true, "Sound played."
	end,
})

--------------------------------------------------
-- /playsound_search
--------------------------------------------------

core.register_chatcommand("playsound_search", {
	params = "<search>",
	description = "Search sounds globally",
	privs = { server = true },

	func = function(name, param)

		if param == "" then
			return false, "You must provide a search term"
		end

		local search = param:lower()
		local results = {}

		for soundname in pairs(ALL_SOUNDS) do
			if soundname:lower():find(search, 1, true) then
				results[#results + 1] = soundname
				if #results >= 20 then
					break
				end
			end
		end

		if #results == 0 then
			return false, "No sounds found for: " .. search
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false
		end

		local meta = player:get_meta()
		meta:set_string("playsound_search_results", core.serialize(results))

		local msg = "Cached sounds:\n"

		for i, snd in ipairs(results) do
			msg = msg .. i .. ": " .. snd .. "\n"
		end

		msg = msg .. "\nUse: /playsound_pick <number> <player>"

		core.chat_send_player(name, msg)

		return true, "Search cached."
	end,
})

--------------------------------------------------
-- TARGET PARSER
--------------------------------------------------

local function get_targets(executor_name, target_string)

	local targets = {}

	-- sem argumento = self
	if not target_string or target_string == "" then
		local player = core.get_player_by_name(executor_name)
		if player then
			table.insert(targets, player)
		end
		return targets
	end

	-- @s
	if target_string == "@s" then
		local player = core.get_player_by_name(executor_name)
		if player then
			table.insert(targets, player)
		end
		return targets
	end

	-- @e
	if target_string == "@e" then
		for _, player in ipairs(core.get_connected_players()) do
			table.insert(targets, player)
		end
		return targets
	end

	-- @e[r=10]
	local radius = target_string:match("^@e%[r=(%d+)%]$")
	if radius then
		radius = tonumber(radius)

		local executor = core.get_player_by_name(executor_name)
		if not executor then return targets end

		local pos = executor:get_pos()

		for _, player in ipairs(core.get_connected_players()) do
			if vector.distance(pos, player:get_pos()) <= radius then
				table.insert(targets, player)
			end
		end

		return targets
	end

	-- nome específico
	if core.player_exists(target_string) then
		local player = core.get_player_by_name(target_string)
		if player then
			table.insert(targets, player)
		end
	end

	return targets
end

--------------------------------------------------
-- /playsound_pick (UPGRADED)
--------------------------------------------------

core.register_chatcommand("playsound_pick", {
	params = "<number> [target]",
	description = "Play cached sound",
	privs = { server = true },

	func = function(name, rawparams)

		local idx, target = rawparams:match("^(%d+)%s*(.*)$")
		idx = tonumber(idx)

		if not idx then
			return false, "Invalid number"
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false
		end

		local meta = player:get_meta()
		local results = core.deserialize(meta:get_string("playsound_search_results"))

		if not (results and results[idx]) then
			return false, "No cached sound found"
		end

		local targets = get_targets(name, target)

		if #targets == 0 then
			return false, "No valid targets"
		end

		for _, target_player in ipairs(targets) do
			core.sound_play(results[idx], {
				to_player = target_player:get_player_name(),
				gain = 1.0,
			})
		end

		return true, "Sound played: " .. results[idx]
	end,
})