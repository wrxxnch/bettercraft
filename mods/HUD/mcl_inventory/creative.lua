local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape
local C = core.colorize

local show_nici = core.settings:get_bool("mcl_creative_show_nici_tab", false)

mcl_player.register_player_setting("mcl_inventory:scroll_on_creative_inventory", {
	type = "enum",
	options = {
		{ name = "auto", description = S("Auto") },
		{ name = "false", description = S("Off") },
		{ name = "true", description = S("On (causes problems on some client versions)") },
	},
	section = "Inventory",
	short_desc = S("Enable scrollable creative inventory"),
	long_desc = S([[Very large inventory displays may be slow when scrolling, especially on Luanti versions before 5.11.
Therefore the creative inventory display can be split into pages with prev/next page buttons.
Mineclonia defaults to use scrolling unless an older Luanti version is detected.
This setting allows you to override that heuristic.]]),
	ui_default = "auto",
	on_change = mcl_inventory.set_creative_formspec
})

-- Prepare player info table
local players = {}

-- Containing all the items for each Creative Mode tab
local inventory_lists = {}

-- Create tables
local builtin_filter_ids = {
	"blocks",
	"deco",
	"redstone",
	"rail",
	"food",
	"tools",
	"combat",
	"mobs",
	"brew",
	"matr",
	"misc",
	"all",
	"nici",
	"mcl_cblocks",
}

for _, f in pairs(builtin_filter_ids) do
	inventory_lists[f] = {}
end

-- Populate all the item tables. We only do this once.
core.register_on_mods_loaded(function()

	for name, def in pairs(core.registered_items) do
		if (not def.groups.not_in_creative_inventory or def.groups.not_in_creative_inventory == 0) and def.description and
			def.description ~= "" then
			local function is_redstone(def)
				return def._mcl_redstone or def.groups.redstone_wire
			end

			local function is_tool(def)
				return (def.groups.tool and def.groups.tool ~= 0) or (def.tool_capabilities and def.tool_capabilities.damage_groups == nil)
			end

			local function is_weapon_or_armor(def)
				return (def.groups.weapon and def.groups.weapon ~= 0) or
				( def.groups.weapon_ranged and def.groups.weapon_ranged ~= 0 ) or
				( def.groups.ammo and def.groups.ammo ~= 0) or
				( def.groups.combat_item and def.groups.combat_item ~= 0 ) or
					((
						( def.groups.armor_head and def.groups.armor_head ~= 0 ) or
					    ( def.groups.armor_torso and def.groups.armor_torso ~= 0 ) or
						( def.groups.armor_legs and def.groups.armor_legs ~= 0 ) or
						( def.groups.armor_feet and def.groups.armor_feet ~= 0 ) or
						( def.groups.horse_armor and def.groups.horse_armor ~= 0 )) and
					def.groups.non_combat_armor ~= 1)
			end

			-- Is set to true if it was added in any category besides misc
			local nonmisc = false

			-- LOGICA DE SEPARAÇÃO: Se for do mod mcl_cblocks, vai pra aba dele e IGNORA as outras
			if name:sub(1, 12) == "mcl_cblocks:" then
				table.insert(inventory_lists["mcl_cblocks"], name)
				nonmisc = true
			-- Usamos ELSEIF aqui para que, se for mcl_cblocks, ele NÃO entre em "blocks"
			elseif core.get_item_group(name, "building_block") ~= 0 then
				table.insert(inventory_lists["blocks"], name)
				nonmisc = true
			end

			-- Continuação dos outros grupos (sempre checando se já não foi adicionado)
			if not nonmisc then
				if core.get_item_group(name, "deco_block") ~= 0 then
					table.insert(inventory_lists["deco"], name)
					nonmisc = true
				end
				if is_redstone(def) then
					table.insert(inventory_lists["redstone"], name)
					nonmisc = true
				end
				if core.get_item_group(name, "transport") ~= 0 then
					table.insert(inventory_lists["rail"], name)
					nonmisc = true
				end
				if (core.get_item_group(name, "food") ~= 0 and core.get_item_group(name, "brewitem") == 0 ) or core.get_item_group(name, "eatable") ~= 0 then
					table.insert(inventory_lists["food"], name)
					nonmisc = true
				end
				if is_tool(def) then
					table.insert(inventory_lists["tools"], name)
					nonmisc = true
				end
				if is_weapon_or_armor(def) then
					table.insert(inventory_lists["combat"], name)
					nonmisc = true
				end
				if core.get_item_group(name, "spawn_egg") ~= 0 then
					table.insert(inventory_lists["mobs"], name)
					nonmisc = true
				end
				if core.get_item_group(name, "brewitem") ~= 0 then
					local str = name
					if def.groups._mcl_potion == 1 then
						local stack = ItemStack(name)
						tt.reload_itemstack_description(stack)
						str = stack:to_string()
					end
					table.insert(inventory_lists["brew"], str)
					nonmisc = true
				end
				if core.get_item_group(name, "craftitem") ~= 0 then
					table.insert(inventory_lists["matr"], name)
					nonmisc = true
				end
			end

			-- Misc. category
			if not nonmisc then
				table.insert(inventory_lists["misc"], name)
			end

			table.insert(inventory_lists["all"], name)
		elseif core.get_item_group(name, "not_in_creative_inventory") > 0 then
			table.insert(inventory_lists["nici"], name)
		end

		if def._get_all_virtual_items then
			for category, list in pairs(def._get_all_virtual_items()) do
				for _, virtual_item in pairs(list) do
					table.insert(inventory_lists[category], virtual_item)
					if category ~= "nici" then
						table.insert(inventory_lists["all"], virtual_item)
					end
				end
			end
		end
	end

	for _, to_sort in pairs(inventory_lists) do
		table.sort(to_sort)
	end
end)

local function filter_item(name, description, lang, filter)
	local desc
	if not lang then
		desc = string.lower(description)
	else
		desc = string.lower(core.get_translated_string(lang, description))
	end
	return string.find(name, filter, nil, true) or string.find(desc, filter, nil, true)
end

local function set_inv_search(filter, player)
	local playername = player:get_player_name()
	local inv = core.get_inventory({ type = "detached", name = "creative_" .. playername })
	local creative_list = {}
	filter = filter:gsub("%s+", " ")
	filter = string.lower(filter)
	filter = string.trim(filter)
	local lang = core.get_player_information(playername).lang_code
	for name, def in pairs(core.registered_items) do
		if (not def.groups.not_in_creative_inventory or def.groups.not_in_creative_inventory == 0)
		and def.description and
			def.description ~= "" then
			local name = string.lower(def.name)
			if filter_item (name, def.description, lang, filter) then
				if def.groups._mcl_potion == 1 then
					local stack = ItemStack (name)
					tt.reload_itemstack_description (stack)
					table.insert(creative_list, stack:to_string ())
				else
					table.insert(creative_list, name)
				end
			end
		end

		if def._get_all_virtual_items then
			for category, list in pairs(def._get_all_virtual_items()) do
				if category ~= "nici" then
					for _, virtual_item in pairs(list) do
						if filter_item (virtual_item, core.strip_colors(ItemStack(virtual_item):get_description()), lang, filter) then
							table.insert(creative_list, virtual_item)
						end
					end
				end
			end
		end
	end

	table.sort(creative_list)

	inv:set_size("main", #creative_list)
	inv:set_list("main", creative_list)
end

local function set_inv_page(page, player)
	local playername = player:get_player_name()
	local inv = core.get_inventory({ type = "detached", name = "creative_" .. playername })
	inv:set_size("main", 0)
	local creative_list = {}
	if inventory_lists[page] then -- Standard filter
		creative_list = inventory_lists[page]
	end
	inv:set_size("main", #creative_list)
	players[playername].inv_size = #creative_list
	inv:set_list("main", creative_list)
end

local function init(player)
	local playername = player:get_player_name()
	core.create_detached_inventory("creative_" .. playername, {
		allow_move = function()
			return 0
		end,
		allow_put = function()
			return 0
		end,
		allow_take = function(_, _, _, _, player)
			if core.is_creative_enabled(player:get_player_name()) then
				return -1
			else
				return 0
			end
		end,
	}, playername)
	set_inv_page("all", player)
end

-- Create the trash field
local trash = core.create_detached_inventory("trash", {
	allow_put = function(_, _, _, stack, player)
		if core.is_creative_enabled(player:get_player_name()) then
			return stack:get_count()
		else
			return 0
		end
	end,
	on_put = function(inv, listname, index)
		inv:set_stack(listname, index, "")
	end,
})

trash:set_size("main", 1)

------------------------------
-- Formspec Precalculations --
------------------------------

local noffset = {}
local offset = {}
local boffset = {}
local button_bg_postfix = {}
local filtername = {}

local noffset_x_start = 0.2
local noffset_x = noffset_x_start
local noffset_y = -1.34

local function next_noffset(id, right)
	if right then
		noffset[id] = { 11.3, noffset_y }
	else
		noffset[id] = { noffset_x, noffset_y }
		noffset_x = noffset_x + 1.6
	end
end

-- Upper row
next_noffset("blocks")
next_noffset("deco")
next_noffset("redstone")
next_noffset("rail")
next_noffset("brew")
next_noffset("misc")
next_noffset("nix", true)

noffset_x = noffset_x_start
noffset_y = 8.64

-- Lower row
next_noffset("food")
next_noffset("tools")
next_noffset("combat")
next_noffset("mobs")
next_noffset("matr")
next_noffset("nici")
next_noffset("mcl_cblocks")
next_noffset("inv", true)

for k, v in pairs(noffset) do
	offset[k] = tostring(v[1]) .. "," .. tostring(v[2])
	boffset[k] = tostring(v[1] + 0.24) .. "," .. tostring(v[2] + 0.25)
end

button_bg_postfix["blocks"] = ""
button_bg_postfix["deco"] = ""
button_bg_postfix["redstone"] = ""
button_bg_postfix["rail"] = ""
button_bg_postfix["brew"] = ""
button_bg_postfix["misc"] = ""
button_bg_postfix["nix"] = ""
button_bg_postfix["default"] = ""
button_bg_postfix["food"] = "_down"
button_bg_postfix["tools"] = "_down"
button_bg_postfix["combat"] = "_down"
button_bg_postfix["mobs"] = "_down"
button_bg_postfix["matr"] = "_down"
button_bg_postfix["inv"] = "_down"
button_bg_postfix["nici"] = "_down"
button_bg_postfix["mcl_cblocks"] = "_down"

filtername["blocks"] = S("Building Blocks")
filtername["deco"] = S("Decoration Blocks")
filtername["redstone"] = S("Redstone")
filtername["rail"] = S("Transportation")
filtername["misc"] = S("Miscellaneous")
filtername["nix"] = S("Search Items")
filtername["food"] = S("Foodstuffs")
filtername["tools"] = S("Tools")
filtername["combat"] = S("Combat")
filtername["mobs"] = S("Mobs")
filtername["brew"] = S("Brewing")
filtername["matr"] = S("Materials")
filtername["inv"] = S("Survival Inventory")
filtername["nici"] = S("Not in Creative Inventory")
filtername["mcl_cblocks"] = "CBlocks" -- ESSA LINHA CORRIGE O ERRO DE NIL

-- Item name representing a tab, indexed by tab name
local tab_icon = {
	blocks = "mcl_core:brick_block",
	deco = "mcl_flowers:peony",
	redstone = "mcl_redstone:redstone",
	rail = "mcl_minecarts:golden_rail",
	misc = "mcl_buckets:bucket_lava",
	nix = "mcl_compass:compass",
	food = "mcl_core:apple",
	tools = "mcl_core:axe_iron",
	combat = "mcl_core:sword_gold",
	mobs = "mobs_mc:cow",
	brew = "mcl_potions:dragon_breath",
	matr = "mcl_core:stick",
	inv = "mcl_chests:chest",
	nici = "mcl_core:barrier",
	mcl_cblocks = "mcl_cblocks:cobble_light_blue",
}

-- Get the player configured stack size when taking items from creative inventory
local function get_stack_size(player)
	return player:get_meta():get_int("mcl_inventory:switch_stack")
end

-- Set the player configured stack size when taking items from creative inventory
local function set_stack_size(player, n)
	player:get_meta():set_int("mcl_inventory:switch_stack", n)
end

core.register_on_joinplayer(function(player)
	if get_stack_size(player) == 0 then
		set_stack_size(player, 64)
	end
end)

local function is_touch_enabled(playername)
	if not core.get_player_window_information then return false end
	local window = core.get_player_window_information(playername)
	return window and window.touch_controls or false
end

function mcl_inventory.set_creative_formspec(player)
	local playername = player:get_player_name()
	if not players[playername] then return end

	local start_i = players[playername].start_i
	local pagenum = start_i / (9 * 5) + 1
	local page = players[playername].page
	local inv_size = players[playername].inv_size
	local filter = players[playername].filter

	if not inv_size then
		if page == "nix" then
			local inv = core.get_inventory({ type = "detached", name = "creative_" .. playername })
			inv_size = inv:get_size("main")
		elseif page and page ~= "inv" then
			inv_size = #(inventory_lists[page])
		else
			inv_size = 0
		end
	end
	local pagemax = math.max(1, math.floor((inv_size - 1) / (9 * 5) + 1))
	local name = "nix"
	local main_list
	local listrings = table.concat({
		"listring[detached:creative_" .. playername .. ";main]",
		"listring[current_player;main]",
		"listring[detached:trash;main]",
	})

	if page then
		name = page
		if players[playername] then
			players[playername].page = page
		end
	end

	if name == "inv" then
		local armor_slot_imgs = ""
		local inv = player:get_inventory()
		if inv:get_stack("armor", 2):is_empty() then armor_slot_imgs = armor_slot_imgs .. "image[3.5,0.375;1,1;mcl_inventory_empty_armor_slot_helmet.png]" end
		if inv:get_stack("armor", 3):is_empty() then armor_slot_imgs = armor_slot_imgs .. "image[3.5,2.125;1,1;mcl_inventory_empty_armor_slot_chestplate.png]" end
		if inv:get_stack("armor", 4):is_empty() then armor_slot_imgs = armor_slot_imgs .. "image[7.25,0.375;1,1;mcl_inventory_empty_armor_slot_leggings.png]" end
		if inv:get_stack("armor", 5):is_empty() then armor_slot_imgs = armor_slot_imgs .. "image[7.25,2.125;1,1;mcl_inventory_empty_armor_slot_boots.png]" end
		if inv:get_stack("offhand", 1):is_empty() then armor_slot_imgs = armor_slot_imgs .. "image[2.25,1.25;1,1;mcl_inventory_empty_armor_slot_shield.png]" end

		local stack_size = get_stack_size(player)

		main_list = table.concat({
			mcl_formspec.get_itemslot_bg_v4(0.375, 3.375, 9, 3),
			"list[current_player;main;0.375,3.375;9,3;9]",
			mcl_formspec.get_itemslot_bg_v4(3.5, 0.375, 1, 1),
			mcl_formspec.get_itemslot_bg_v4(3.5, 2.125, 1, 1),
			mcl_formspec.get_itemslot_bg_v4(7.25, 0.375, 1, 1),
			mcl_formspec.get_itemslot_bg_v4(7.25, 2.125, 1, 1),
			"list[current_player;armor;3.5,0.375;1,1;1]",
			"list[current_player;armor;3.5,2.125;1,1;2]",
			"list[current_player;armor;7.25,0.375;1,1;3]",
			"list[current_player;armor;7.25,2.125;1,1;4]",
			mcl_formspec.get_itemslot_bg_v4(2.25, 1.25, 1, 1),
			"list[current_player;offhand;2.25,1.25;1,1]",
			armor_slot_imgs,
			"image[4.75,0.33;2.25,2.83;mcl_inventory_background9.png;2]",
			mcl_player.get_player_formspec_model(player, 4.75, 0.45, 2.25, 2.75, ""),
			"image_button[11.575,0.825;1.1,1.1;craftguide_book.png;__mcl_craftguide;]",
			"tooltip[__mcl_craftguide;" .. F(S("Recipe book")) .. "]",
			"image_button[11.575,2.075;1.1,1.1;doc_button_icon_lores.png;__mcl_doc;]",
			"tooltip[__mcl_doc;" .. F(S("Help")) .. "]",
			"image_button[11.575,3.325;1.1,1.1;mcl_achievements_button.png;__mcl_achievements;]",
			"tooltip[__mcl_achievements;" .. F(S("Advancements")) .. "]",
			"image_button[11.575,4.575;1.1,1.1;mcl_stacksize_button.png;__switch_stack;]",
			"label[12.275,5.35;" .. F(C("#FFFFFF", tostring(stack_size ~= 1 and stack_size or ""))) .. "]",
			"tooltip[__switch_stack;" .. F(S("Switch stack size")) .. "]",
			"image_button[11.575,5.825;1.1,1.1;mcl_player_settings.png;__mcl_player_settings;]",
			"tooltip[__mcl_player_settings;" .. F(S("Player settings")) .. "]",
		})

		listrings = listrings .. "listring[current_player;armor]listring[current_player;main]listring[current_player;offhand]listring[current_player;main]"
	else
		local scroll_setting = mcl_player.get_player_setting(player, "mcl_inventory:scroll_on_creative_inventory", "auto")
		local scroll = scroll_setting == "true"
		if scroll_setting == "auto" then
			local protocol_version = core.get_player_information(playername).protocol_version
			scroll = 47 <= protocol_version and protocol_version < 49
		end
		if scroll then
			local nb_lines = math.ceil(inv_size / 9)
			main_list = table.concat({
				mcl_formspec.get_itemslot_bg_v4(0.375, 0.875, 9, 5),
				"scroll_container[0.375,0.875;11.575,6;scroll;vertical;1.25]",
				"list[detached:creative_", playername, ";main;0,0;9,", nb_lines, ";]",
				"scroll_container_end[]",
				"scrollbaroptions[min=0;max=", math.max(nb_lines - 5, 0), ";smallstep=1;largestep=1;arrows=hide]",
				"scrollbar[11.75,0.825;0.75,6.1;vertical;scroll;0]"
			})
		else
			main_list = table.concat({
				mcl_formspec.get_itemslot_bg_v4(0.375, 0.875, 9, 5),
				"list[detached:creative_", playername, ";main;0.375,0.875;9,5;", start_i, "]",
				"label[11.65,4.33;", F(S("@1 / @2", pagenum, pagemax)), "]",
				"image_button[11.575,4.58;1.1,1.1;crafting_creative_prev.png^[transformR270;creative_prev;]",
				"image_button[11.575,5.83;1.1,1.1;crafting_creative_next.png^[transformR270;creative_next;]",
			})
		end
	end

	local function tab(current_tab, this_tab)
		local bg_img = (current_tab == this_tab) and ("crafting_creative_active" .. button_bg_postfix[this_tab] .. ".png") or ("crafting_creative_inactive" .. button_bg_postfix[this_tab] .. ".png")
		return table.concat({
			"style[" .. this_tab .. ";border=false;bgimg=;bgimg_pressed=]",
			"style[" .. this_tab .. "_outer;border=false;bgimg=" .. bg_img .. ";bgimg_pressed=" .. bg_img .. "]",
			"button[" .. offset[this_tab] .. ";1.5,1.44;" .. this_tab .. "_outer;]",
			"item_image_button[" .. boffset[this_tab] .. ";1,1;" .. tab_icon[this_tab] .. ";" .. this_tab .. ";]",
		})
	end

	local caption = (name ~= "inv" and filtername[name]) and ("label[0.375,0.375;" .. F(C(mcl_formspec.label_color, filtername[name])) .. "]") or ""
	local nici = show_nici and (tab(name, "nici") .. "tooltip[nici;"..F(filtername["nici"]).."]") or ""
	local touch_enabled = is_touch_enabled(playername)
	players[playername].last_touch_enabled = touch_enabled

	local formspec = table.concat({
		"formspec_version[6]",
		"size[13,11.43]",
		touch_enabled and "padding[-0.015,-0.015]" or "",
		"no_prepend[]", mcl_vars.gui_nonbg, mcl_vars.gui_bg_color,
		"background9[0,1.34;13,8.75;mcl_base_textures_background9.png;;7]",
		"container[0,1.34]",
		mcl_formspec.get_itemslot_bg_v4(0.375, 7.375, 9, 1),
		"list[current_player;main;0.375,7.375;9,1;]",
		mcl_formspec.get_itemslot_bg_v4(11.625, 7.375, 1, 1, nil, "crafting_creative_trash.png"),
		"list[detached:trash;main;11.625,7.375;1,1;]",
		main_list,
		caption,
		listrings,
		tab(name, "blocks") .. "tooltip[blocks;"..F(filtername["blocks"]).."]"..
		tab(name, "deco") .. "tooltip[deco;"..F(filtername["deco"]).."]"..
		tab(name, "redstone") .. "tooltip[redstone;"..F(filtername["redstone"]).."]"..
		tab(name, "rail") .. "tooltip[rail;"..F(filtername["rail"]).."]"..
		tab(name, "misc") .. "tooltip[misc;"..F(filtername["misc"]).."]"..
		tab(name, "nix") .. "tooltip[nix;"..F(filtername["nix"]).."]"..
		tab(name, "food") .. "tooltip[food;"..F(filtername["food"]).."]"..
		tab(name, "tools") .. "tooltip[tools;"..F(filtername["tools"]).."]"..
		tab(name, "combat") .. "tooltip[combat;"..F(filtername["combat"]).."]"..
		tab(name, "mobs") .. "tooltip[mobs;"..F(filtername["mobs"]).."]"..
		tab(name, "brew") .. "tooltip[brew;"..F(filtername["brew"]).."]"..
		tab(name, "matr") .. "tooltip[matr;"..F(filtername["matr"]).."]",
		nici,
		tab(name, "inv") .. "tooltip[inv;"..F(filtername["inv"]).."]",
		--mcl_cblocks and mcl_colorblocks
		
		tab(name, "mcl_cblocks") .. "tooltip[mcl_cblocks;"..F(filtername["mcl_cblocks"]).."]"
	})

	if name == "nix" then
		formspec = formspec .. "field[5.325,0.15;6.1,0.6;search;;" .. core.formspec_escape(filter or "") .. "]" ..
			"field_enter_after_edit[search;true]field_close_on_enter[search;false]set_focus[search;true]"
	end
	formspec = formspec .. "container_end[]"
	if pagenum then formspec = formspec .. "p" .. tostring(pagenum) end
	mcl_player.set_inventory_formspec (player, formspec, 0)
end

core.register_on_player_receive_fields(function(player, formname, fields)
	local page = nil
	if not core.is_creative_enabled(player:get_player_name()) then return end
	if formname ~= "" or fields.quit == "true" then return end
	local scrollbar_event = core.explode_scrollbar_event(fields.scroll)
	if scrollbar_event.type == "CHG" then return end

	local name = player:get_player_name()

	if fields.blocks or fields.blocks_outer then page = "blocks"
	elseif fields.deco or fields.deco_outer then page = "deco"
	elseif fields.redstone or fields.redstone_outer then page = "redstone"
	elseif fields.rail or fields.rail_outer then page = "rail"
	elseif fields.misc or fields.misc_outer then page = "misc"
	elseif fields.nix or fields.nix_outer then page = "nix"
	elseif fields.food or fields.food_outer then page = "food"
	elseif fields.tools or fields.tools_outer then page = "tools"
	elseif fields.combat or fields.combat_outer then page = "combat"
	elseif fields.mobs or fields.mobs_outer then page = "mobs"
	elseif fields.brew or fields.brew_outer then page = "brew"
	elseif fields.matr or fields.matr_outer then page = "matr"
	elseif fields.nici or fields.nici_outer then page = "nici"
	elseif fields.mcl_cblocks or fields.mcl_cblocks_outer then page = "mcl_cblocks" 
	elseif fields.inv or fields.inv_outer then page = "inv"
	elseif fields.search then
		set_inv_search(fields.search, player)
		page = "nix"
	elseif fields.__switch_stack then
		set_stack_size(player, get_stack_size(player) == 1 and 64 or 1)
	end

	if page then
		if page ~= "inv" and page ~= "nix" then set_inv_page(page, player) end
		players[name].page = page
	else
		page = players[name].page
	end

	local start_i = players[name].start_i or 0
	if fields.creative_prev then start_i = start_i - 9 * 5
	elseif fields.creative_next then start_i = start_i + 9 * 5
	else start_i = 0 end
	
	local inv_size = 0
	if page == "nix" then inv_size = core.get_inventory({ type = "detached", name = "creative_" .. name }):get_size("main")
	elseif page and page ~= "inv" then inv_size = #(inventory_lists[page] or {}) end
	
	players[name].inv_size = inv_size
	if start_i < 0 or start_i >= inv_size then start_i = 0 end
	players[name].start_i = start_i
	players[name].filter = (not fields.nix and fields.search) and fields.search or ""

	mcl_inventory.set_creative_formspec(player)
	mcl_inventory.show_inventory(player)
end)

core.register_on_placenode(function(_, _, placer, _, itemstack)
	if placer and core.is_creative_enabled(placer:get_player_name()) then
		local group = core.get_item_group(itemstack:get_name(), "shulker_box")
		return group == 0 or group == nil
	end
end)

local old_mt_handle_node_drops = core.handle_node_drops
function core.handle_node_drops(pos, drops, digger)
	if digger and core.is_creative_enabled(digger:get_player_name()) then
		if not digger:is_player() then
			for _, item in ipairs(drops) do core.add_item(pos, item) end
		else
			local inv = digger:get_inventory()
			if inv then
				for _, item in ipairs(drops) do
					if not inv:contains_item("main", item, true) then inv:add_item("main", item) end
				end
			end
		end
	else
		return old_mt_handle_node_drops(pos, drops, digger)
	end
end

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if not players[name] then
		players[name] = { page = "nix", filter = "", start_i = 0 }
	end
	init(player)
	mcl_inventory.set_creative_formspec(player)
end)

core.register_on_player_inventory_action(function(player, action, _, inventory_info)
	if core.is_creative_enabled(player:get_player_name()) and get_stack_size(player) == 64 and action == "put" and inventory_info.listname == "main" then
		local stack = inventory_info.stack
		stack:set_count(stack:get_stack_max())
		player:get_inventory():set_stack("main", inventory_info.index, stack)
	end
end)

mcl_player.register_globalstep_slow(function(player)
	local name = player:get_player_name()
	if core.is_creative_enabled(name) then
		local touch_enabled = is_touch_enabled(name)
		if touch_enabled ~= players[name].last_touch_enabled then
			mcl_inventory.set_creative_formspec(player)
		end
	end
end)