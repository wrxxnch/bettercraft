local S = core.get_translator(core.get_current_modname())

-- =========================
-- /playsound (direto)
-- =========================
core.register_chatcommand("playsound", {
	params = S("<sound> <target>"),
	description = S("Play a sound"),
	privs = { server = true },

	func = function(_, rawparams)
		local sound, target = rawparams:match("^(%S+)%s+(%S+)$")

		if not sound then
			return false, S("Sound name is invalid!")
		end

		if not (target and core.player_exists(target)) then
			return false, S("Target is invalid!")
		end

		core.sound_play(
			{ name = sound },
			{ to_player = target },
			true
		)

		return true, S("Sound played.")
	end,
})

-- =========================
-- /playsound_search
-- =========================
core.register_chatcommand("playsound_search", {
	params = S("<search>"),
	description = S("Search sounds and cache results"),
	privs = { server = true },

	func = function(name, param)
		if param == "" then
			return false, S("You must provide a search term")
		end

		local search = param:lower()
		local results = {}

		for soundname in pairs(core.registered_sounds or {}) do
			if soundname:lower():find(search, 1, true) then
				results[#results + 1] = soundname
				if #results >= 10 then
					break
				end
			end
		end

		if #results == 0 then
			return false, S("No sounds found for: @1", search)
		end

		-- cache persistente
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end

		local meta = player:get_meta()
		meta:set_string("playsound_search_results", core.serialize(results))

		-- listar
		local msg = S("Cached sounds:\n")
		for i, snd in ipairs(results) do
			msg = msg .. i .. ": " .. snd .. "\n"
		end
		msg = msg .. S("Use: /playsound_pick <number> <player>")

		core.chat_send_player(name, msg)
		return true, S("Search cached.")
	end,
})

-- =========================
-- /playsound_pick
-- =========================
core.register_chatcommand("playsound_pick", {
	params = S("<number> <target>"),
	description = S("Play cached sound"),
	privs = { server = true },

	func = function(name, rawparams)
		local idx, target = rawparams:match("^(%d+)%s+(%S+)$")
		idx = tonumber(idx)

		if not idx then
			return false, S("Invalid number")
		end

		if not (target and core.player_exists(target)) then
			return false, S("Target is invalid!")
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false
		end

		local meta = player:get_meta()
		local results = core.deserialize(meta:get_string("playsound_search_results"))

		if not (results and results[idx]) then
			return false, S("No cached sound found")
		end

		core.sound_play(
			{ name = results[idx] },
			{ to_player = target },
			true
		)

		return true, S("Sound played: @1", results[idx])
	end,
})
