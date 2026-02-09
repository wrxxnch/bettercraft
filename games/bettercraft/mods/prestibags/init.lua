--- prestibags Luanti mod
--
-- @author prestidigitator
-- @copyright 2013, licensed under WTFPL
--
-- @author Codiac
-- @copyright 2024, licensed under GPL-3.0-or-later
--

---- Configuration
--
--- Width and height of bag inventory (>0)
local BAG_WIDTH = 9	
local BAG_HEIGHT = 3

--- Sound played when placing/dropping a bag on the ground
local DROP_BAG_SOUND = "prestibags_drop_bag"
local DROP_BAG_SOUND_GAIN = 1.0
local DROP_BAG_SOUND_DIST = 5.0

--- Sound played when opening a bag's inventory
local OPEN_BAG_SOUND = "prestibags_rustle_bag"
local OPEN_BAG_SOUND_GAIN = 1.0
local OPEN_BAG_SOUND_DIST = 5.0

--- HP of undamaged bag (integer >0).
local BAG_MAX_HP = 4

--- How often the inventories of destroyed bags are checked and cleaned up
-- (>0.0).
local CLEANUP_PERIOD__S = 10.0

--- How often environmental effects like burning are checked (>0.0).
local ENV_CHECK_PERIOD__S = 0.5

--- Max distance an igniter node can be and still ignite/burn the bag (>=1).
local MAX_IGNITE_DIST = 4.0

--- Probability (0.0 <= p <= 1.0) bag will be damaged for each igniter touching
--    it (increases if igniter's max range is greater than current distance).
--    Always damaged if in lava.
local BURN_DAMAGE_PROB = 0.25

--- Probability (0.0 <= p <= 1.0) bag will ignite and spawn some flames on or
--    touching it for each igniter within igniter range (increases if
--    igniter's max range is greater than current distance).  Alawys ignites
--    if in lava.  Ignition is ignored if "fire:basic_flame" is not available.
local IGNITE_PROB = 0.25

--- Amount of damage bag takes each time it is burned.  Note that a bag can be
--    burned at most once each update cycle, so this is the MAXIMUM damage
--    taken by burning each ENV_CHECK_PERIOD__S period.
local BURN_DAMAGE__HP = 1

---- end of configuration

local EPSILON = 0.001 -- "close enough"

local S = core.get_translator(core.get_current_modname())

local game_info = core.get_game_info()
local is_mineclonia = game_info.id == "mineclonia"

local colors = {
	bag = "mcl_mobitems:leather",
	black = "mcl_dye:black",
	blue = "mcl_dye:blue",
	brown = "mcl_dye:brown",
	cyan = "mcl_dye:cyan",
	green = "mcl_dye:green",
	grey = "mcl_dye:light_gray",
	lightblue = "mcl_dye:light_blue",
	lightgreen = "mcl_dye:lime",
	magenta = "mcl_dye:magenta",
	orange = "mcl_dye:orange",
	pink = "mcl_dye:pink",
	purple = "mcl_dye:purple",
	red = "mcl_dye:red",
	silver = "mcl_dye:light_gray",
	yellow = "mcl_dye:yellow",
	white = "mcl_dye:white",
}



local hsl = {
	bag = {h = 0, s = 0, l = 0},
	black = {h = -180, s = -100, l = -40},
	blue = {h = -180, s = 50, l = -45},
	brown = {h = -15, s = 40, l = -60},
	cyan = {h = 147, s = 30, l = -30},
	green = {h = 100, s = 0, l = -60},
	grey = {h = -180, s = -100, l = -20},
	leather = {h = -0, s = -40, l = -0},
	lightblue = {h = -180, s = 0, l = -10},
	lightgreen = {h = 70, s = 0, l = -20},
	magenta = {h = -100, s = 0, l = 0},
	orange = {h = -10, s = 100, l = -10},
	pink = {h = -100, s = 10, l = 20},
	purple = {h = -140, s = 0, l = 0},
	red = {h = -30, s = 75, l = -40},
	silver = {h = -180, s = -100, l = -10},
	yellow = {h = 10, s = 100, l = 10},
	white = {h = -180, s = -100, l = 40},
}




-- In some languages colours have gender, which can change word order ... translation is hard
local descrs = {
	bag = S("Bag of Stuff"),
	black = S("Black Bag of Stuff"),
	blue = S("Blue Bag of Stuff"),
	brown = S("Brown Bag of Stuff"),
	cyan = S("Cyan Bag of Stuff"),
	green = S("Green Bag of Stuff"),
	grey = S("Grey Bag of Stuff"),
	lightblue = S("Light Blue Bag of Stuff"),
	lightgreen = S("Light Green Bag of Stuff"),
	magenta = S("Magenta Bag of Stuff"),
	orange = S("Orange Bag of Stuff"),
	pink = S("Pink Bag of Stuff"),
	purple = S("Purple Bag of Stuff"),
	red = S("Red Bag of Stuff"),
	silver = S("Silver Bag of Stuff"),
	yellow = S("Yellow Bag of Stuff"),
	white = S("White Bag of Stuff"),
}



local function serializeContents(contents)
	if not contents then return "" end

	local tabs = {}
	for i, stack in ipairs(contents) do tabs[i] = stack and stack:to_table() or "" end

	return core.serialize(tabs)
end

local function deserializeContents(data)
	if not data or data == "" then return nil end
	local tabs = core.deserialize(data)
	if not tabs or type(tabs) ~= "table" then return nil end

	local contents = {}
	for i, tab in ipairs(tabs) do contents[i] = ItemStack(tab) end

	return contents
end

-- weak references to keep track of what detached inventory lists to remove
local idSet = {}
local idToWeakEntityMap = {}

setmetatable(idToWeakEntityMap, {__mode = "v"})

local entityInv
local function cleanInventory()
	for id, dummy in pairs(idSet) do
		if not idToWeakEntityMap[id] then
			entityInv:set_size(id, 0)
			idSet[id] = nil
		end
	end
	core.after(CLEANUP_PERIOD__S, cleanInventory)
end
core.after(CLEANUP_PERIOD__S, cleanInventory)

entityInv = core.create_detached_inventory("prestibags:bags", {
	allow_move = function(inv, fromList, fromIndex, toList, toIndex, count, player)
		return idToWeakEntityMap[fromList] and idToWeakEntityMap[toList] and count or 0
	end,

	allow_put = function(inv, toList, toIndex, stack, player)
		return idToWeakEntityMap[toList] and stack:get_count() or 0
	end,

	allow_take = function(inv, fromList, fromIndex, stack, player)
		return idToWeakEntityMap[fromList] and stack:get_count() or 0
	end,

	on_move = function(inv, fromList, fromIndex, toList, toIndex, count, player)
		local fromEntity = idToWeakEntityMap[fromList]
		local toEntity = idToWeakEntityMap[toList]
		local fromStack = fromEntity.contents[fromIndex]
		local toStack = toEntity.contents[toIndex]

		local moved = fromStack:take_item(count)
		toStack:add_item(moved)
	end,

	on_put = function(inv, toList, toIndex, stack, player)
		local toEntity = idToWeakEntityMap[toList]
		local toStack = toEntity.contents[toIndex]

		toStack:add_item(stack)
	end,

	on_take = function(inv, fromList, fromIndex, stack, player)
		local fromEntity = idToWeakEntityMap[fromList]
		local fromStack = fromEntity.contents[fromIndex]

		fromStack:take_item(stack:get_count())
	end,
})

-- local function bag_envUpdate(self, dt) end

local function rezEntity(stack, pos, player, bag_ent_name)
	local x = pos.x
	local y = math.floor(pos.y)
	local z = pos.z

	while true do
		local node = core.get_node({x = x, y = y - 1, z = z})
		local nodeType = node and core.registered_nodes[node.name]
		if not nodeType or nodeType.walkable then break end
		y = y - 1
	end

	local obj = core.add_entity(pos, bag_ent_name)
	if not obj then return stack end

	local contentData = stack:get_meta():get_string("")
	local contents = deserializeContents(contentData)
	if contents then obj:get_luaentity().contents = contents end

	obj:set_hp(BAG_MAX_HP - BAG_MAX_HP * stack:get_wear() / 2 ^ 16)

	core.sound_play(DROP_BAG_SOUND, {
		object = obj,
		gain = DROP_BAG_SOUND_GAIN,
		max_hear_distance = DROP_BAG_SOUND_DIST,
		loop = false,
	})

	return ItemStack(nil)
end

local function show_bag_fromspec(self, player, inventory_image)
	local inv = player:get_inventory()
	local inv_size = inv:get_size("main")
	local inv_width = math.max(inv:get_width("main"), 8)
	local inv_rows = math.floor(inv_size / inv_width)

	-- local invLoc = "detached:" .. self.id
	local w = math.max(inv_width, BAG_WIDTH) + 3
	local h = inv_rows + BAG_HEIGHT + 2
	local yImg = math.floor(BAG_HEIGHT / 2)
	local yPlay = BAG_HEIGHT + 1

	if not self.contents or #self.contents <= 0 then return end

	entityInv:set_size(self.id, #self.contents)
	for i, stack in ipairs(self.contents) do entityInv:set_stack(self.id, i, stack) end

	local template = [[
			formspec_version[4]
			size[%s,%s]
			bgcolor[#00000000]
			listcolors[#9990;#FFF;#000]
			image[0,%s;1,1;%s]
			list[detached:prestibags:bags;%s;1,0.2;%s,%s;]
			list[current_player;main;0.5,%s;%s,%s;]
			listring[]
		]]

	local formspec = string.format(template, w, h, yImg, inventory_image, self.id, BAG_WIDTH,
	                               BAG_HEIGHT, yPlay, inv_width, inv_rows)

	core.show_formspec(player:get_player_name(), "prestibags:bag", formspec)

	core.sound_play(OPEN_BAG_SOUND, {
		object = self.object,
		gain = OPEN_BAG_SOUND_GAIN,
		max_hear_distance = OPEN_BAG_SOUND_DIST,
		loop = false,
	})
end

local function drop_bag_with_contents(self)
	if not self or not self.object then return end

	local pos = self.object:get_pos()
	if not pos then return end

	local contentData = serializeContents(self.contents or {})

	local stack = ItemStack({
		name = self.bag_node_name,
		metadata = contentData,
		wear = (2 ^ 16) * (BAG_MAX_HP - self.object:get_hp()) / BAG_MAX_HP,
	})

	core.add_item(pos, stack)
	self:remove()
end


local function bag_on_step(self, dt)
	self.timer = self.timer - dt
	if self.timer > 0.0 then return end
	self.timer = ENV_CHECK_PERIOD__S

	local haveFlame = core.registered_nodes["fire:basic_flame"]
	-- Because the bag pos was lowered the check pos must be raised
	local pos = vector.offset(self.object:get_pos(), 0, 0.5, 0)
	local node = core.get_node(pos)
	local nodeType = node and core.registered_nodes[node.name]

if nodeType and nodeType.walkable and not nodeType.buildable_to then
	core.log("verbose", "DEBUG - Dropping bag due to invalid node")
	return drop_bag_with_contents(self)
end


	if core.get_item_group(node.name, "lava") > 0 then
		if haveFlame then
			local flamePos = core.find_node_near(pos, 1.0, "air")
			if flamePos then core.add_node(flamePos, {name = "fire:basic_flame"}) end
		end
		return self:burn()
	end

	if core.find_node_near(pos, 1.0, "group:puts_out_fire") then return end

	local minPos = {
		x = pos.x - MAX_IGNITE_DIST,
		y = pos.y - MAX_IGNITE_DIST,
		z = pos.z - MAX_IGNITE_DIST,
	}
	local maxPos = {
		x = pos.x + MAX_IGNITE_DIST,
		y = pos.y + MAX_IGNITE_DIST,
		z = pos.z + MAX_IGNITE_DIST,
	}
	local wasIgnited = false
	local burnLevels = 0.0

	local igniterPosList = core.find_nodes_in_area(minPos, maxPos, "group:igniter")
	for i, igniterPos in ipairs(igniterPosList) do
		local distSq = (igniterPos.x - pos.x) ^ 2 + (igniterPos.y - pos.y) ^ 2 +
			               (igniterPos.z - pos.z) ^ 2
		if distSq <= MAX_IGNITE_DIST ^ 2 + EPSILON then
			local igniterNode = core.get_node(igniterPos)
			local igniterLevel = core.get_item_group(igniterNode.name, "igniter") -
				                     math.max(1.0, math.sqrt(distSq) - EPSILON)

			if igniterLevel >= 0.0 then
				if distSq <= 1.0 then wasIgnited = true end
				burnLevels = burnLevels + igniterLevel
			end
		end
	end

	if burnLevels >= 1.0 then
		if haveFlame and not wasIgnited and math.random() >= (1.0 - IGNITE_PROB) ^ burnLevels then
			local flamePos = (node.name == "air") and pos or core.find_node_near(pos, 1.0, "air")
			if flamePos then core.add_node(flamePos, {name = "fire:basic_flame"}) end
		end

		if math.random() >= (1.0 - BURN_DAMAGE_PROB) ^ burnLevels then self:burn() end
	end
end

-- Function to check if a bag is empty
local function is_bag_empty(stack)
	local meta = stack:get_meta()
	local contentData = meta:get_string("")
	if contentData == "" then return true end
	
	local contents = deserializeContents(contentData)
	if not contents then return true end
	
	for _, item in ipairs(contents) do
		if not item:is_empty() then
			return false
		end
	end
	return true
end



-- Global callback to prevent crafting with non-empty bags
core.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
	local has_non_empty_bag = false
	for _, stack in ipairs(old_craft_grid) do
		if core.get_item_group(stack:get_name(), "bag") > 0 then
			if not is_bag_empty(stack) then
				has_non_empty_bag = true
				break
			end
		end
	end

	if has_non_empty_bag then
		-- Inform the player
		if player then
			core.chat_send_player(player:get_player_name(), S("You cannot craft with a bag that contains items!"))
			
			-- Return all items from the old craft grid to the player's inventory
			local inv = player:get_inventory()
			for _, stack in ipairs(old_craft_grid) do
				if not stack:is_empty() then
					local leftover = inv:add_item("main", stack)
					if not leftover:is_empty() then
						core.add_item(player:get_pos(), leftover)
					end
				end
			end
		end
		-- Return an empty itemstack to cancel the craft result
		return ItemStack("")
	end
end)

for color, material in pairs(colors) do
	-- DEFINIÇÕES NORMAIS
local bag_ent_name = "prestibags:bag_entity_" .. color
local bag_node_name = "prestibags:bag_" .. color
local hsl_val = string.format("^[hsl:%d:%d:%d", hsl[color]["h"], hsl[color]["s"], hsl[color]["l"])
local inventory_image = "prestibags_bag_inv.png" .. hsl_val
local wield_image = "prestibags_bag_inv.png" .. hsl_val
local textures = {"prestibags_bag.png" .. hsl_val}
local descr = descrs[color] or S("Bag of Stuff")

-- BAG BASE
if color == "bag" then
	bag_ent_name = "prestibags:bag_entity"
	bag_node_name = "prestibags:bag"
	inventory_image = "prestibags_bag_inv.png"
	wield_image = "prestibags_bag_inv.png"
	textures = {"prestibags_bag.png"}
end


	core.register_entity(bag_ent_name, {
		initial_properties = {
			hp_max = BAG_MAX_HP,
			physical = false,
			collisionbox = {-0.44, -0.5, -0.425, 0.44, 0.35, 0.425},
			visual = "mesh",
			visual_size = {x = 1, y = 1},
			mesh = "prestibags_bag.obj",
			textures = textures,
		},

		on_activate = function(self, staticData, dt)
			self.bag_node_name = bag_node_name

			local id
			repeat id = "bag" .. (math.random(0, 2 ^ 15 - 1) * 2 ^ 15 + math.random(0, 2 ^ 15 - 1)) until not idSet[id]
			idSet[id] = id
			idToWeakEntityMap[id] = self

			self.id = id

			self.object:set_armor_groups({punch_operable = 1, flammable = 1})

			local contents = deserializeContents(staticData)
			if not contents then
				contents = {}
				for i = 1, BAG_WIDTH * BAG_HEIGHT do contents[#contents + 1] = ItemStack(nil) end
			end
			self.contents = contents

			self.timer = ENV_CHECK_PERIOD__S
		end,

		get_staticdata = function(self) return serializeContents(self.contents) end,

		on_punch = function(self, hitterObj, timeSinceLastPunch, toolCaps, dir)
			local playerName = hitterObj:get_player_name()
			local playerInv = hitterObj:get_inventory()
			if not playerName or not playerInv then return end

			local contentData = serializeContents(self.contents)

			local hp = self.object:get_hp()
			local newItem = ItemStack({
				name = bag_node_name,
				metadata = contentData,
				wear = (2 ^ 16) * (BAG_MAX_HP - hp) / BAG_MAX_HP,
			})
			if not playerInv:room_for_item("main", newItem) then return end

			self:remove()

			playerInv:add_item("main", newItem)
		end,

		on_rightclick = function(self, player) show_bag_fromspec(self, player, inventory_image) end,

		on_step = function(self, dt) bag_on_step(self, dt) end,

		remove = function(self)
			entityInv:set_size(self.id, 0)
			idSet[self.id] = nil
			self.object:remove()
		end,

		burn = function(self)
			local hp = self.object:get_hp() - BURN_DAMAGE__HP
			self.object:set_hp(hp)
			core.log("verbose", "DEBUG - bag HP = " .. hp)
			if hp <= 0 then return self:remove() end
		end,
	})

	core.register_tool(bag_node_name, {
		description = descr,
		groups = {bag = BAG_WIDTH * BAG_HEIGHT, flammable = 1},
		inventory_image = inventory_image,
		wield_image = wield_image,
		stack_max = 1,

		on_place = function(stack, player, pointedThing)
			local pos = pointedThing and pointedThing.under
			local node = pos and core.get_node(pos)
			local nodeType = node and core.registered_nodes[node.name]
			if not nodeType or not nodeType.buildable_to then
				pos = pointedThing and pointedThing.above
				node = pos and core.get_node(pos)
				nodeType = node and core.registered_nodes[node.name]
			end

			-- Prevent bag being placed where it will be deleted
			if nodeType and nodeType.walkable and not nodeType.buildable_to then return stack end

			if not pos then pos = player:get_pos() end

			return rezEntity(stack, pos, player, bag_ent_name)
		end,

		on_drop = function(stack, player, pos) return rezEntity(stack, pos, player, bag_ent_name) end,

		-- Eventually add on_use(stack, player, pointedThing) which actually
		--    opens the bag from player inventory; trick is, has to track whether
		--    bag is still in inventory OR replace "player inventory" with a
		--    detached proxy that doesn't allow the bag's stack to be changed
		--    while open!
	})

-- Craft da bolsa base (só couro)
if color == "bag" then
	core.register_craft({
		output = bag_node_name,
		recipe = {
			{"mcl_mobitems:string", "mcl_mobitems:leather", "mcl_mobitems:string"},
			{"mcl_mobitems:leather", "", "mcl_mobitems:leather"},
			{"mcl_mobitems:leather", "mcl_mobitems:leather", "mcl_mobitems:leather"},
		},
	})
else
	-- Recolorir qualquer bolsa com corante
	core.register_craft({
		type = "shapeless",
		output = bag_node_name,
		recipe = {
			"group:bag",
			material,
		},
	})
end

end
