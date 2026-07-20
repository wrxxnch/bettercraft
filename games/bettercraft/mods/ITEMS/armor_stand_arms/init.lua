-- Armor Stand with Arms — one mod, multiple games.
--
-- The stand's arm geometry and the hand-display entities are the same
-- everywhere, but armor handling is game-specific: Mineclonia and VoxeLibre
-- use mcl_armor's right-click equip flow (mcl.lua), Minetest Game uses
-- 3d_armor's chest-style formspec inventory (minetest_game.lua). Exactly
-- one of the two files is loaded, picked by which game's armor-stand mod is
-- present.

local modpath = core.get_modpath(core.get_current_modname())

-- When the mod can't work here, don't crash the world with error() — a new
-- player who just installed the mod wouldn't know what hit them and would
-- likely uninstall. Load nothing, log the problem, and tell each joining
-- player in chat what to do about it.
local function refuse(msg)
	core.log("error", "[armor_stand_arms] " .. msg)
	core.register_on_joinplayer(function(player)
		local name = player:get_player_name()
		core.after(2, function()
			core.chat_send_player(name,
				core.colorize("#FF5555", "[Armor Stand with Arms] " .. msg))
		end)
	end)
end

if core.get_modpath("mcl_armor_stand") then
	-- Mineclonia or VoxeLibre (told apart further inside mcl.lua)
	dofile(modpath .. "/mcl.lua")
elseif core.get_modpath("3d_armor_stand") then
	-- Minetest Game with the 3d_armor modpack
	dofile(modpath .. "/minetest_game.lua")
elseif core.get_modpath("default") then
	refuse("This mod needs the \"3d Armor\" modpack (3d_armor) to work on " ..
		"Minetest Game. Install it from ContentDB, enable it for this " ..
		"world, and the armor stand will appear.")
else
	refuse("This game is not supported. The mod works on Mineclonia, " ..
		"VoxeLibre, and Minetest Game (with the 3d_armor modpack).")
end
