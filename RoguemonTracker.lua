local function RoguemonTracker()
    local self = {}
	self.version = "1.0.2"
	self.name = "Roguemon Tracker"
	self.author = "Croz & Smart"
	self.description = "Tracker extension for tracking & automating Roguemon rewards & caps."
	self.github = "something-smart/Roguemon-IronmonExtension"
	self.url = string.format("https://github.com/%s", self.github or "")

	-- turn this on to have the reward screen accessible at any time
	local DEBUG_MODE = false

	-- STATIC OR READ IN AT LOAD TIME:

	local CONFIG_FILE_PATH = FileManager.getCustomFolderPath() .. FileManager.slash .. "roguemon" .. FileManager.slash .. "roguemon_config.txt"
	local SAVED_DATA_PATH = FileManager.getCustomFolderPath() .. FileManager.slash .. "roguemon" .. FileManager.slash .. "roguemon_data-"
	local SAVED_OPTIONS_PATH = FileManager.getCustomFolderPath() .. FileManager.slash .. "roguemon" .. FileManager.slash .. "roguemon_options.tdat"
	local IMAGES_DIRECTORY = FileManager.getCustomFolderPath() .. FileManager.slash .. "roguemon" .. FileManager.slash .. "roguemon_images" .. FileManager.slash

	local CURSE_THEME = "FFFFFF FFFFFF B0FFB0 FF00B0 FFFF00 FFFFFF 33103B 510080 33103B 510080 000000 1 0"

	local prize_images = {} -- will get updated when config file is read

	local specialRedeemInfo = {
		["Luck Incense"] = {consumable = true, image = "luck.png", description = "You may keep one HP heal that exceeds your cap until you can add it."},
		["Reroll Chip"] = {consumable = true, image = "rerollchip.png", description = "May be used to reroll any reward spin once."},
		["Duplicator"] = {consumable = true, image = "duplicator.png", description = "Purchase a copy of one future HP/status heal found (immediate choice)."},
		["Temporary TM Voucher"] = {consumable = true, image = "tempvoucher.png", description = "Teach one ground TM found before the next badge (immediate choice)."},
		["Potion Investment"] = {consumable = true, image = "diamond.png", description = "Starts at 20; x2 value each badge. Redeem once for a heal up to its value in Buy Phase. Value:"},
		["Temporary Held Item"] = {consumable = true, image = "grounditem.png", description = "Temporarily unlock an item in your bag for 1 gym badge."},
		["Flutist"] = {consumable = false, image = "flute.png", description = "You may use flutes in battle (including Poke Flute). Don't cleanse flutes."},
		["Berry Pouch"] = {consumable = false, image = "berry-pouch.png", description = "HP Berries may be saved instead of equipped; status berries don't count against cap."},
		["Candy Jar"] = {consumable = false, image = "candy-jar.png", description = "You may save PP Ups, PP Maxes, and Rare Candies to use at any time."},
		["Temporary Item Voucher"] = {consumable = true, image = "tempvoucher.png", description = "Permanently unlock one found item before next gym (immediate decision)."},
		["X Factor"] = {consumable = false, image = "XFACTOR.png", description = "You may keep and use Battle Items freely."},
		["Held Item Voucher"] = {consumable = true, image = "tmvoucher.png", description = "Permanently unlock one found item found in the future (immediate decision)."},
		["Fight wilds in Rts 1/2/22"] = {consumable = "true", image = "exp-charm.png", description = "Fight the first encounter on each. You may PC heal anytime, but must stop there."},
		["Fight up to 5 random wilds"] = {consumable = "true", image = "exp-charm.png", description = "May be anywhere, but can't heal in between. Can run but counts as 1 of the 5."},
		["TM Voucher"] = {consumable = true, image = "tmvoucher.png", description = "Teach 1 Ground TM found in the future (immediate decision)."},
		["Revive"] = {consumable = true, image = "revive.png", description = "May be used in any battle. Keep your HM friend with you; send it out and revive if you faint."},
		["Warding Charm"] = {consumable = true, image = "warding-charm.png", description = "Cancel the effect of any one Curse."}
	}

	local gymLeaders = {[414] = true, [415] = true, [416] = true, [417] = true, [418] = true, [420] = true, [419] = true, [350] = true}

	-- Trainer IDs for milestones. "count" indicates how many trainers must be defeated for the milestone to count.
	local milestoneTrainers = {
		[326] = {["name"] = "Rival 1", ["count"] = 1},
		[327] = {["name"] = "Rival 1", ["count"] = 1},
		[328] = {["name"] = "Rival 1", ["count"] = 1},
		[414] = {["name"] = "Brock", ["count"] = 1},
		[415] = {["name"] = "Misty", ["count"] = 1},
		[416] = {["name"] = "Surge", ["count"] = 1},
		[417] = {["name"] = "Erika", ["count"] = 1},
		[418] = {["name"] = "Koga", ["count"] = 1},
		[349] = {["name"] = "Silph Co", ["count"] = 1},
		[420] = {["name"] = "Sabrina", ["count"] = 1},
		[419] = {["name"] = "Blaine", ["count"] = 1},
		[350] = {["name"] = "Giovanni", ["count"] = 1},
		["Mt. Moon"] = "Mt Moon FC",
		["Silph Co"] = "Silph Co",
		["Victory Road"] = "Victory Road"
	}

	-- Milestones that require entering an area; in this case, only the Pokemon League.
	local milestoneAreas = {
		
	}

	local phases = {
		["Brock"] = {buy = true, cleansing = true},
		["Misty"] = {buy = true, cleansing = true},
		["Surge"] = {buy = true, cleansing = true},
		["Erika"] = {buy = true, cleansing = true},
		["Koga"] = {buy = true, cleansing = true},
		["Sabrina"] = {buy = true, cleansing = true},
		["Blaine"] = {buy = true},
		["Giovanni"] = {buy = true, cleansing = true},
		["Victory Road"] = {buy = true, cleansing = true}
	}

	-- Options for prizes that have multiple options. If a selected prize contains any of these, it will open the OptionSelectScreen.
	-- Currently there is no support for a single prize having multiple DIFFERENT selections (e.g. 2x Any Vitamin is fine, Any Vitamin & Any Status Heal is not)
	local prizeAdditionalOptions = {
		["Any Status Heal"] = {"Antidote", "Parlyz Heal", "Awakening", "Burn Heal", "Ice Heal"},
		["Any Battle Item"] = {"X Attack", "X Defend", "X Special", "X Speed", "Dire Hit", "Guard Spec."},
		["Any Vitamin"] = {"Hp Up (HP)", "Protein (Attack)", "Iron (Defense)", "Calcium (Sp. Atk)", "Zinc (Sp. Def)", "Carbos (Speed)"}
	}

	-- Segments will autofill the required and optional trainers from the route info. Some segments encompass part of a route and must be hard-coded.
	-- "Rival" flag means the number of trainers is effectively 2 lower, because each rival fight has 3 IDs and only one is fought.
	local segments = {
		["Viridian Forest"] = {["routes"] = {117}, ["mandatory"] = {104}},
		["Rival 2"] = {["routes"] = {110}, ["trainers"] = {329, 330, 331}, ["allMandatory"] = true, ["rival"] = true},
		["Brock"] = {["routes"] = {28}, ["allMandatory"] = true},
		["Route 3"] = {["routes"] = {91}, ["mandatory"] = {105, 106, 107}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true}},
		["Mt. Moon"] = {["routes"] = {114, 116}, ["mandatory"] = {351, 170}, ["cursable"] = true},
		["Rival 3"] = {["routes"] = {81}, ["trainers"] = {332, 333, 334}, ["allMandatory"] = true, ["rival"] = true},
		["Route 24/25"] = {["routes"] = {112, 113}, ["mandatory"] = {110, 123, 92, 122, 144, 356, 153, 125}, ["choicePairs"] = {{182, 184}, {183, 471}}, ["cursable"] = true},
		["Misty"] = {["routes"] = {12}, ["allMandatory"] = true},
		["Route 6/11"] = {["routes"] = {182, 94, 99}, ["trainers"] = {355, 111, 112, 145, 146, 151, 152, 97, 98, 99, 100, 221, 222, 258, 259, 260, 261}, ["mandatory"] = {355, 146}, ["cursable"] = true},
		["Rival 4"] = {["routes"] = {119, 120, 121, 122}, ["trainers"] = {426, 427, 428}, ["allMandatory"] = true, ["rival"] = true},
		["Lt. Surge"] = {["routes"] = {25}, ["allMandatory"] = true},
		["Route 9/10 N"] = {["routes"] = {97, 98}, ["trainers"] = {114, 115, 148, 149, 154, 155, 185, 186, 465, 156}, ["mandatory"] = {154, 115}, ["cursable"] = true},
		["Rock Tunnel/Rt 10 S"] = {["routes"] = {154, 155}, ["trainers"] = {192, 193, 194, 168, 476, 475, 474, 158, 159, 189, 190, 191, 164, 165, 166, 157, 163, 187, 188}, ["mandatory"] = {168, 166, 159, 158, 189, 474}, ["choicePairs"] = {{191, 190}, {192, 193}}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true}},
		["Rival 5"] = {["routes"] = {161, 162}, ["trainers"] = {429, 430, 431}, ["allMandatory"] = true, ["rival"] = true},
		["Route 8"] = {["routes"] = {96}, ["choicePairs"] = {{131, 264}}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true}},
		["Erika"] = {["routes"] = {15}, ["allMandatory"] = true},
		["Game Corner"] = {["routes"] = {27, 128, 129, 130, 131}, ["mandatory"] = {357, 368, 366, 367, 348}, ["cursable"] = true},
		["Pokemon Tower"] = {["routes"] = {161, 163, 164, 165, 166, 167}, ["mandatory"] = {447, 453, 452, 369, 370, 371}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true}},
		["Cycling Rd/Rt 18/19"] = {["routes"] = {104, 105, 106, 107}, ["trainers"] = {199, 201, 202, 249, 250, 251, 203, 204, 205, 206, 252, 253, 254, 255, 256, 470, 307, 308, 309, 235, 236}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true}},
		["Koga"] = {["routes"] = {20}, ["allMandatory"] = true},
		["Safari Zone"] = {["routes"] = {147, 148, 149, 150}},
		["Silph Co"] = {["routes"] = {132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142}, ["mandatory"] = {432, 433, 434, 391, 349}, ["rival"] = true, ["cursable"] = true, ["bannedCurses"] = {["1000 Cuts"] = true, ["Toxic Fumes"] = true}},
		["Sabrina"] = {["routes"] = {34}, ["allMandatory"] = true},
		["Rt 21/Pokemon Mansion"] = {["routes"] = {109, 219, 143, 144, 145, 146}, ["cursable"] = true},
		["Blaine"] = {["routes"] = {36}, ["allMandatory"] = true},
		["Giovanni"] = {["routes"] = {37}, ["allMandatory"] = true},
		["Rival 7"] = {["routes"] = {110}, ["trainers"] = {435, 436, 437}, ["allMandatory"] = true, ["rival"] = true},
		["Victory Road"] = {["routes"] = {125, 126, 127}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true}},
		["Pokemon League"] = {["routes"] = {212, 213, 214, 215, 216, 217}, ["allMandatory"] = true, ["rival"] = true},
		["Congratulations!"] = {["routes"] = {}},
		["Route 12"] = {["routes"] = {100}},
		["Route 13"] = {["routes"] = {101}},
		["Route 14"] = {["routes"] = {102}},
		["Route 15"] = {["routes"] = {103}},
	}

	local curseInfo = {
		["Forgetfulness"] = {description = "Must pick up and teach one TM"},
		["Claustrophobia"] = {description = "If not full cleared, -50 HP Cap"},
		["Downsizing"] = {description = "If not full cleared, -1 prize option permanently"},
		["Tormented Soul"] = {description = "Cannot use the same move twice in a row"},
		["Kaizo Curse"] = {description = "Cannot use healing items outside of battle"},
		["Headwind"] = {description = "Start fights at -1 Speed"},
		["Sharp Rocks"] = {description = "All enemies have +2 crit rate"},
		["High Pressure"] = {description = "Start missing 50% PP on all moves"},
		["Heavy Fog"] = {description = "All combatants have -1 Accuracy"},
		["Unstable Ground"] = {description = "Flinch on the first turn of each fight"},
		["1000 Cuts"] = {description = "Permanent -5 HP Cap when hit by an attack"},
		["Acid Rain"] = {description = "Each fight has a random weather"},
		["Toxic Fumes"] = {description = "Take 1 damage every 8 steps (can't faint)"},
		["Narcolepsy"] = {description = "30% to fall asleep after each fight"},
		["Clean Air"] = {description = "Enemies have permanent Mist and Safeguard"},
		["Clouded Instincts"] = {description = "First move in battle must be 1st slot"},
		["Unruly Spirit"] = {description = "10% to flinch on every turn"},
		["Chameleon"] = {description = "Typing is randomized each battle"},
		["No Cover"] = {description = "Enemies cannot miss you"}
	}

	local notifyOnPickup = {
		consumables = {
			["Oran Berry"] = 2,
			["Sitrus Berry"] = 2,
			["Figy Berry"] = 1,
			["Iapapa Berry"] = 1,
			["Wiki Berry"] = 1,
			["Aguav Berry"] = 1,
			["Mago Berry"] = 1,
			["Berry Juice"] = 2,
			["White Herb"] = 1,
			["Mental Herb"] = 1
		},
		vitamins = {
			["Protein"] = 1,
			["Iron"] = 1,
			["Calcium"] = 1,
			["Zinc"] = 1,
			["Carbos"] = 1,
			["HP Up"] = 1
		},
		candies = {
			["PP Up"] = 1,
			["PP Max"] = 1,
			["Rare Candy"] = 1
		}
	}

	local allowedHeldItems = {
		["Pecha Berry"] = true, ["Cheri Berry"] = true, ["Chesto Berry"] = true, ["Aspear Berry"] = true, ["Rawst Berry"] = true,
		["Persim Berry"] = true, ["Leppa Berry"] = true, ["Lum Berry"] = true, ["Oran Berry"] = true, ["Sitrus Berry"] = true,
		["Figy Berry"] = true, ["Iapapa Berry"] = true, ["Wiki Berry"] = true, ["Aguav Berry"] = true, ["Mago Berry"] = true,
		["Liechi Berry"] = true, ["Ganlon Berry"] = true, ["Petaya Berry"] = true, ["Apicot Berry"] = true, ["Salac Berry"] = true,
		["Lansat Berry"] = true, ["Starf Berry"] = true, ["Berry Juice"] = true, ["White Herb"] = true, ["Mental Herb"] = true
	}
	
	local seedNumber = -1
	local milestones = {} -- Milestones stored in order
	local milestonesByName = {} -- Milestones keyed by name for easy access
	local wheels = {}

	local startingHpCap = 150
	local statingStatusCap = 3

	local currentHPVal = 0
	local currentStatusVal = 0
	local adjustedHPVal = 0

	local optionsList = {
		{text = "Display prizes on screen", default = true},
		{text = "Display small prizes", default = false},
		{text = "Show reminders", default = true},
		{text = "Show reminders over cap", default = false},
		{text = "Ascension 2+", default = false},
		{text = "Alternate Curse theme", default = true}
	}

	-- DYNAMIC, but does not need to be saved (because the player should not quit while these are relevant)

	local option1 = ""
	local option1Desc = ""
	local option2 = ""
	local option2Desc = ""
	local option3 = ""
	local option3Desc = ""
	local descriptionText = ""

	local additionalOptions = {"", "", "", "", "", "", "", ""}
	local additionalOptionsRemaining = 0
	
	local specialRedeemToDescribe = nil

	local patchedMoonStones = false
	local committed = false
	local caughtSomethingYet = false

	local currentRoguemonScreen = nil
	local screenQueue = {}
	local suppressedNotifications = {}
	local givenMoonStoneNotification = false

	local itemsPocket = {}
	local berryPocket = {}
	local pokeInfo = nil
	local itemFromPrize = nil
	local previousMap = nil

	local wildBattleCounter = 0
	local wildBattlesStarted = false
	local needToBuy = false
	local needToCleanse = false
	local shouldDismissNotification = nil

	-- curse related values
	local curseAppliedThisFight = false
	local inBattleTurnCount = 0
	local lastAttackDamage = 0
	local unrulySpiritFirstTurn = false
	local flinchCheckFirstTurn = false
	local weatherApplied = nil

	local natureMintUp = nil

	-- Dynamic, and must be saved/loaded:

	local segmentOrder = {
		"Viridian Forest", "Rival 2", "Brock", "Route 3", "Mt. Moon", 
		"Rival 3", "Route 24/25", "Misty", "Route 6/11", "Rival 4", 
		"Lt. Surge", "Route 9/10 N", "Rock Tunnel/Rt 10 S", "Rival 5", "Route 8", 
		"Erika", "Game Corner", "Pokemon Tower", "Cycling Rd/Rt 18/19", "Koga", 
		"Safari Zone", "Silph Co", "Sabrina", "Rt 21/Pokemon Mansion", "Blaine", 
		"Giovanni", "Rival 7", "Victory Road", "Pokemon League", "Congratulations!"
	} -- this is dynamic because the Route 12/13/14/15 prize can alter it

	local defeatedTrainerIds = {} -- ids of all trainers we have beaten

	-- info on the current segment
	local currentSegment = 1
	local segmentStarted = false
	local trainersDefeated = 0
	local mandatoriesDefeated = 0

	-- caps
	local hpCap = 150
	local statusCap = 3
	-- modifiers track how much higher or lower the cap is compared to the base value in the config
	local hpCapModifier = 0
	local statusCapModifier = 0
	-- "milestone" is unused except in testing; it's only used for the "Next" button
	-- which ignores the automatic milestone detection and spins the rewards in order
	local milestone = 0 
	-- last milestone completed
	local lastMilestone = nil
	-- trainers defeated for the current milestone
	local milestoneProgress = {}
	-- tracks redeemed prizes that persist through the run
	-- internal = one-time redeems that can't be found again
	-- unlocks = permanent upgrades, like Flutist
	-- consumable = one-time abilities that are saved, like TM Voucher
	local specialRedeems = {internal = {}, unlocks = {}, consumable = {}}

	-- unlocked held items
	local unlockedHeldItems = {}

	-- which routes are cursed, and what curses do they have
	local cursedSegments = {}

	-- true if the Downsizing curse has been triggered (-1 prize options)
	local downsized = false

	-- step count information for Toxic Fumes curse
	local stepCounter = {lastCounted = 0, toxicFumesCycle = 0}

	-- previous theme, to be stored while the curse theme is active
	local previousTheme = nil

	-- tracks if we have given the moon stone yet. 0 = not at all, 1 = initial trade was offered (-100 HP Cap), 2 = given for free
	local offeredMoonStoneFirst = 0

	-- Options
	local RoguemonOptions = {
		
	}

	-- Data editing functions. Credit to UTDZac for the AddItems functions, although AddItemsImproved was modified. --

	-- Returns the seed number (as a string) found in the auto-generated log file
	function self.generateSeed()
		-- Auto-determine the log file name & path that includes "AutoRandomized"
		local logpath = LogOverlay.getLogFileAutodetected() or nil
		if logpath then
			local file = io.open(logpath, "r")
			if file ~= nil then
				-- Read in the entire file as a single string
				local fileContents = file:read("*a") or ""
				file:close()
				-- Check for first match of Random Seed, should be near the first few lines
				local seed = string.match(fileContents, "Random Seed:%s*(%d+)")
				if seed then
					return seed
				end
			end
		end

		return math.random(2147483647)
	end
	
	-- Get item ID corresponding to an item name, if there is one
	function self.getItemId(itemName)
		if itemName == Constants.BLANKLINE then return 0 end
		for id, item in pairs(MiscData.Items) do
			if item == itemName then
				return id
			end
		end
		return 0
	end
	
	-- Get data for the back pocket that a particular item would be placed in
	function self.getBagPocketData(id)
		-- Returns: Offset for bag pocket, capacity of bag pocket, whether to limit quantity to 1
		local gameNumber = GameSettings.game
		local itemsOffset = GameSettings.bagPocket_Items_offset
		local keyItemsOffset = {0x5B0, 0x5D8, 0x03b8}
		local pokeballsOffset = {0x600, 0x650, 0x0430}
		local TMHMOffset = {0x640, 0x690, 0x0464}
		local berriesOffset = GameSettings.bagPocket_Berries_offset
	
		local itemsCapacity = GameSettings.bagPocket_Items_Size
		local keyItemsCapacity = {20, 30, 30}
		local pokeballsCapacity = {16, 16, 13}
		local TMHMCapacity = {64, 64, 58}
		local berriesCapacity = GameSettings.bagPocket_Berries_Size
	
		if id < 1 then
			return nil
		elseif id <= 12--[[Premier Ball]] then
			return pokeballsOffset[gameNumber], pokeballsCapacity[gameNumber], false
		elseif id <= 132--[[Retro Mail]] or (id >= 179--[[Bright Powder]] and id <= 258--[[Yellow Scarf]]) then
			return itemsOffset, itemsCapacity, false
		elseif id <= 175--[[Enigma Berry]] then
			return berriesOffset, berriesCapacity, false
		elseif id <= 288--[[Devon Scope]] or (id >= 349--[[Oak's Parcel]] and id <= 376--[[Old Sea Map]]) then
			return keyItemsOffset[gameNumber], keyItemsCapacity[gameNumber], true
		elseif id <= 338--[[TM50]] then
			return TMHMOffset[gameNumber], TMHMCapacity[gameNumber], false
		elseif id <= 346--[[HM08]] then
			return TMHMOffset[gameNumber], TMHMCapacity[gameNumber], true
		end
		return nil
	end

	-- Add [quantity] of [item] to the bag if there's space. If the item is already present, add to the same stack; otherwise, add it to the next open slot.
	function self.AddItemImproved(itemChoice, quantity)
		if itemChoice == Constants.BLANKLINE or quantity == nil or quantity == 0 then return false end
	
		local itemID = self.getItemId(itemChoice)
		local bagPocketOffset, bagPocketCapacity, limitQuantity = self.getBagPocketData(itemID)
		if bagPocketOffset == nil then return false end
	
		-- Limit quantity for key items / HMs, don't think it breaks if larger quantity but just in case
		if limitQuantity then quantity = 1 end

		local key = Utils.getEncryptionKey(2)
		local address = Utils.getSaveBlock1Addr()

		for i = 0,bagPocketCapacity - 1 do
			local itemid_and_quantity = Memory.readdword(address + bagPocketOffset + i * 4)
			local readItemID = Utils.getbits(itemid_and_quantity, 0, 16)
			local readQuantity = Utils.getbits(itemid_and_quantity, 16, 16)
			if key ~= nil then
				readQuantity = Utils.bit_xor(readQuantity, key)
			end
			if readItemID == itemID then
				quantity = readQuantity + quantity
				if key ~= nil then quantity = Utils.bit_xor(quantity, key) end
				Memory.writeword(address + bagPocketOffset + i * 4 + 2, quantity)
				return true
			end
		end
		for i = 0,bagPocketCapacity - 1 do
			local itemid_and_quantity = Memory.readdword(address + bagPocketOffset + i * 4)
			local readItemID = Utils.getbits(itemid_and_quantity, 0, 16)
			if readItemID == 0 then
				Memory.writeword(address + bagPocketOffset + i * 4, itemID)
				if key ~= nil then quantity = Utils.bit_xor(quantity, key) end
				Memory.writeword(address + bagPocketOffset + i * 4 + 2, quantity)
				return true
			end
		end
		return false
	end

	-- Read bag info.
	function self.readBagInfo()
		local newItems = {}
		local newBerries = {}
		local itemsOffset = GameSettings.bagPocket_Items_offset
		local berriesOffset = GameSettings.bagPocket_Berries_offset
		local key = Utils.getEncryptionKey(2)
		local address = Utils.getSaveBlock1Addr()
		for i = 0,GameSettings.bagPocket_Items_Size - 1 do
			local itemid_and_quantity = Memory.readdword(address + itemsOffset + i * 4)
			local readItemID = Utils.getbits(itemid_and_quantity, 0, 16)
			local readQuantity = Utils.getbits(itemid_and_quantity, 16, 16)
			if key ~= nil then
				readQuantity = Utils.bit_xor(readQuantity, key)
			end
			if readQuantity > 0 and readQuantity < 999 then
				newItems[readItemID] = readQuantity
			end
		end
		for i = 0,GameSettings.bagPocket_Berries_Size - 1 do
			local itemid_and_quantity = Memory.readdword(address + berriesOffset + i * 4)
			local readItemID = Utils.getbits(itemid_and_quantity, 0, 16)
			local readQuantity = Utils.getbits(itemid_and_quantity, 16, 16)
			if key ~= nil then
				readQuantity = Utils.bit_xor(readQuantity, key)
			end
			if readQuantity > 0 and readQuantity < 999 then
				newBerries[readItemID] = readQuantity
			end
		end
		return newItems, newBerries
	end

	-- Check & handle if certain items in the bag changed.
	function self.checkBagUpdates()
		Program.updateBagItems()
		local data = DataHelper.buildTrackerScreenDisplay()

		local newPokeInfo = Tracker.getPokemon(1, true)

		local itemToIgnore = nil
		if pokeInfo and newPokeInfo and pokeInfo.heldItem ~= newPokeInfo.heldItem then
			itemToIgnore = pokeInfo.heldItem
		end
		local itemFromPrizeToIgnore = nil
		if itemFromPrize then
			itemFromPrizeToIgnore = self.getItemId(itemFromPrize, true)
		end

		-- Check for info that changed
		local newItemsPocket, newBerryPocket = self.readBagInfo()
		local empty = (next(itemsPocket) == nil and next(berryPocket) == nil)

		local size = 0
		-- Check if items changed
		for i,q in pairs(newItemsPocket) do
			size = size + 1
			local oldq = itemsPocket[i] or 0
			if q > oldq and i ~= itemToIgnore and i ~= itemFromPrizeToIgnore then
				currentHPVal = data.x.healvalue
				currentStatusVal = self.countStatusHeals()
				if not empty then
					self.processItemAdded(TrackerAPI.getItemName(i, true))
				end
			end
		end
		if size > 0 then
			itemsPocket = newItemsPocket
		end
		if not itemsPocket[24] and specialRedeems.consumable["Revive"] then
			self.removeSpecialRedeem("Revive")
		end

		-- Check if berries changed
		for i,q in pairs(newBerryPocket) do
			size = size + 1
			local oldq = berryPocket[i] or 0
			if q > oldq and i ~= itemToIgnore and i ~= itemFromPrizeToIgnore then
				currentHPVal = data.x.healvalue
				currentStatusVal = self.countStatusHeals()
				if not empty then
					self.processItemAdded(TrackerAPI.getItemName(i, true))
				end
			end
		end
		if size > 0 then
			berryPocket = newBerryPocket
		end

		if pokeInfo and newPokeInfo and pokeInfo.personality == newPokeInfo.personality and pokeInfo.level + 1 == newPokeInfo.level then
			-- We leveled up. Check caps again
			self.countAdjustedHeals()
			if RoguemonOptions["Show reminders over cap"] and MiscData.HealingItems[itemId] and adjustedHPVal > hpCap and not needToBuy then
				self.displayNotification("An HP healing item must be used or trashed", "healing-pocket.png", function()
					self.countAdjustedHeals()
					return adjustedHPVal <= hpCap
				end)
			end
			if RoguemonOptions["Show reminders over cap"] and MiscData.StatusItems[itemId] and currentStatusVal > statusCap and not needToBuy then
				self.displayNotification("A status healing item must be used or trashed", "status-cap.png", function()
					return self.countStatusHeals() <= statusCap
				end)
			end
		end
		if pokeInfo and newPokeInfo and pokeInfo.personality == newPokeInfo.personality and pokeInfo.pokemonID ~= newPokeInfo.pokemonID then
			-- We evolved :D
			self.showPrettyStatScreen(pokeInfo, newPokeInfo)
		end
		pokeInfo = newPokeInfo
		itemFromPrize = nil
	end

	-- Read in encrypted pokemon data for the lead pokemon.
	function self.readLeadPokemonData()
		local pokemon = {}
		local startAddress = GameSettings.pstats
		pokemon.personality = Memory.readdword(startAddress)
		pokemon.otid = Memory.readdword(GameSettings.pstats + 4)
		local magicword = Utils.bit_xor(pokemon.personality, pokemon.otid)
		local aux = pokemon.personality % 24 + 1

		local growthoffset = (MiscData.TableData.growth[aux] - 1) * 12
		local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12
		local effortoffset = (MiscData.TableData.effort[aux] - 1) * 12
		local miscoffset = (MiscData.TableData.misc[aux] - 1) * 12

		pokemon.growth1 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + growthoffset), magicword)
		pokemon.growth2 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + growthoffset + 4), magicword)
		pokemon.growth3 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + growthoffset + 8), magicword)
		pokemon.attack1 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + attackoffset), magicword)
		pokemon.attack2 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + attackoffset + 4), magicword)
		pokemon.attack3 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + attackoffset + 8), magicword)
		pokemon.effort1 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + effortoffset), magicword)
		pokemon.effort2 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + effortoffset + 4), magicword)
		pokemon.effort3 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + effortoffset + 8), magicword)
		pokemon.misc1 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + miscoffset), magicword)
		pokemon.misc2 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + miscoffset + 4), magicword)
		pokemon.misc3 = Utils.bit_xor(Memory.readdword(startAddress + Program.Addresses.offsetPokemonSubstruct + miscoffset + 8), magicword)
		return pokemon
	end

	-- Write encrypted pokemon data, with the proper encryption and checksum.
	function self.writeLeadPokemonData(pokemon)
		local startAddress = GameSettings.pstats
		Memory.writedword(startAddress, pokemon.personality)
		Memory.writedword(startAddress + 4, pokemon.otid)
		local magicword = Utils.bit_xor(pokemon.personality, pokemon.otid)
		local aux = pokemon.personality % 24 + 1

		local growthoffset = (MiscData.TableData.growth[aux] - 1) * 12
		local attackoffset = (MiscData.TableData.attack[aux] - 1) * 12
		local effortoffset = (MiscData.TableData.effort[aux] - 1) * 12
		local miscoffset = (MiscData.TableData.misc[aux] - 1) * 12

		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + growthoffset, Utils.bit_xor(pokemon.growth1, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + growthoffset + 4, Utils.bit_xor(pokemon.growth2, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + growthoffset + 8, Utils.bit_xor(pokemon.growth3, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + attackoffset, Utils.bit_xor(pokemon.attack1, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + attackoffset + 4, Utils.bit_xor(pokemon.attack2, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + attackoffset + 8, Utils.bit_xor(pokemon.attack3, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + effortoffset, Utils.bit_xor(pokemon.effort1, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + effortoffset + 4, Utils.bit_xor(pokemon.effort2, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + effortoffset + 8, Utils.bit_xor(pokemon.effort3, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + miscoffset, Utils.bit_xor(pokemon.misc1, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + miscoffset + 4, Utils.bit_xor(pokemon.misc2, magicword))
		Memory.writedword(startAddress + Program.Addresses.offsetPokemonSubstruct + miscoffset + 8, Utils.bit_xor(pokemon.misc3, magicword))

		local cs = (Utils.addhalves(pokemon.growth1) + Utils.addhalves(pokemon.growth2) + Utils.addhalves(pokemon.growth3)
			+ Utils.addhalves(pokemon.attack1) + Utils.addhalves(pokemon.attack2) + Utils.addhalves(pokemon.attack3)
			+ Utils.addhalves(pokemon.effort1) + Utils.addhalves(pokemon.effort2) + Utils.addhalves(pokemon.effort3)
			+ Utils.addhalves(pokemon.misc1) + Utils.addhalves(pokemon.misc2) + Utils.addhalves(pokemon.misc3)) % 65536
		Memory.writeword(startAddress + 28, cs)
	end

	-- Change the lead pokemon's nature to the specified nature.
	function self.changeNature(nature)
		local pkmnData = self.readLeadPokemonData()
		local currNature = pkmnData.personality % 25
		pkmnData.personality = pkmnData.personality + (currNature - nature)*1024
		self.writeLeadPokemonData(pkmnData)
	end

	-- Flip the lead pokemon's ability to the other ability.
	function self.flipAbility()
		local pkmnData = self.readLeadPokemonData()
		pkmnData.misc2 = Utils.bit_xor(pkmnData.misc2, 0x80000000)
		self.writeLeadPokemonData(pkmnData)
	end

	-- UTIL FUNCTIONS --

	-- Insert newlines into a string so that words are not split up and no line is longer than a specified number of pixels.
	-- Use @ to manually insert a newline.
	function self.wrapPixelsInline(input, limit)
		local ret = ""
		local currentLine = ""
		for _,word in pairs(Utils.split(input, " ", true)) do
			if word == "@" then
				ret = ret .. currentLine .. "\n"
				currentLine = ""
			elseif Utils.calcWordPixelLength(currentLine .. " " .. word) > limit and currentLine ~= "" then
				ret = ret .. currentLine .. "\n"
				currentLine = word
			elseif currentLine == "" then
				currentLine = word
			else
				currentLine = currentLine .. " " .. word
			end
		end
		if currentLine == "" then
			ret = string.sub(ret, 1, #ret - 1)
		else
			ret = ret .. currentLine
		end
		return ret
	end

	-- Determine whether a table contains an item as a value.
	function self.contains(t, item)
		for _,i in pairs(t) do
			if i == item then return true end
		end
		return false
	end

	-- strip whitespace from a string
	function self.strip(input)
		while string.sub(input, 1, 1) == ' ' do input = string.sub(input, 2, #input) end
		while string.sub(input, #input, #input) == ' ' do input = string.sub(input, 1, #input - 1) end
		return input
	end

	-- split a string on a delimiter (Utils.split doesn't work with a reserved character as a delimiter)
	function self.splitOn(input, delim)
		local ret = {}
		if not input then return ret end
		local split = string.gmatch(input, '([^' .. delim .. ']+)')
		for s in split do
			ret[#ret + 1] = self.strip(s)
		end
		return ret
	end

	-- Return the portion of a string after a prefix, or nil if the prefix isn't present
	function self.getPrefixed(str, prefix)
		if string.sub(str, 1, string.len(prefix)) == prefix then
			return string.sub(str, string.len(prefix) + 1)
		end
		return nil
	end

	-- Helper function to change to or queue a screen
	function self.readyScreen(screen)
		if Program.currentScreen == TrackerScreen then
			Program.changeScreenView(screen)
		else
			screenQueue[#screenQueue + 1] = screen
		end
	end

	-- DATA FUNCTIONS --

	-- Read the config file. Executed once, on startup.
	function self.readConfig()
		local linesRead = io.lines(CONFIG_FILE_PATH)
		local lines = {}
		for l in linesRead do lines[#lines + 1] = l end
		local readIndex = 2
		local startingVals = Utils.split(lines[1], ",", true)
		startingHpCap = tonumber(startingVals[1])
		startingStatusCap = tonumber(startingVals[2])
		while true do
			local line = lines[readIndex]
			if line == "-" then break end
			local info = Utils.split(line, ",", true)
			milestones[#milestones + 1] = {['hpCap'] = tonumber(info[2]), ['statusCap'] = tonumber(info[3]), ['wheel'] = info[4], ['name'] = info[1]}
			milestonesByName[info[1]] = {['hpCap'] = tonumber(info[2]), ['statusCap'] = tonumber(info[3]), ['wheel'] = info[4]}
			readIndex = readIndex + 1
		end
		readIndex = readIndex + 1
		local currentWheel = {}
		local wheelName = ""
		while readIndex <= #lines do
			local line = lines[readIndex]
			if string.sub(line, 1, 1) == "*" then
				if wheelName then
					wheels[wheelName] = currentWheel
				end
				wheelName = string.sub(line, 2, #line)
				currentWheel = {}
			elseif not (line == "") and wheelName then
				local parts = Utils.split(line, "|", true)
				currentWheel[#currentWheel + 1] = parts[1]
				if parts[2] then
					local prizeName = Utils.split(parts[1], ":", true)[1]
					prize_images[prizeName] = parts[2]
					if prizeName == "Fight Route X" then
						prize_images["Fight Route 12"] = parts[2]
						prize_images["Fight Route 13"] = parts[2]
						prize_images["Fight Route 14"] = parts[2]
						prize_images["Fight Route 15"] = parts[2]
					end
				end
			end
			readIndex = readIndex + 1
		end
		if wheelName then
			wheels[wheelName] = currentWheel
		end
	end

	-- Autofill remaining information about segments.
	function self.populateSegmentData()
		for loc,data in pairs(segments) do
			-- If trainers aren't hard-coded, autofill them from the routes listed.
			if not data["trainers"] then
				data["trainers"] = {}
				for _,route in pairs(data["routes"]) do
					local trainers = RouteData.Info[route].trainers
					if trainers then
						for _,trainer in pairs(trainers) do
							data["trainers"][#data["trainers"] + 1] = trainer
						end
					end
				end
			end
			-- If there are no listed mandatory trainers, fill them all in if allMandatory is true, otherwise leave it empty.
			if not data["mandatory"] then
				data["mandatory"] = {}
				if data["allMandatory"] then
					for _,trainer in pairs(data["trainers"]) do
						data["mandatory"][#data["mandatory"] + 1] = trainer
					end
				end
			end
			-- Set up a two-way table for paired choice trainers so it's easier to check them.
			if data["choicePairs"] then
				data["pairs"] = {}
				for _,pair in pairs(data["choicePairs"]) do
					data["mandatory"][#data["mandatory"] + 1] = pair[1]
					data["mandatory"][#data["mandatory"] + 1] = pair[2]
					data["pairs"][pair[1]] = pair[2]
					data["pairs"][pair[2]] = pair[1]
				end
			end
		end
		local milestonesToUpdate = {}
		for segName, milestoneName in pairs(milestoneTrainers) do
			if segments[segName] then
				milestonesToUpdate[segName] = milestoneName
			end
		end
		for segName, milestoneName in pairs(milestonesToUpdate) do
			local trainerCount = #segments[segName]["trainers"]
			if segments[segName]["rival"] then
				trainerCount = trainerCount - 2
			end
			for _,tid in pairs(segments[segName]["trainers"]) do
				milestoneTrainers[tid] = {["name"] = milestoneName, ["count"] = trainerCount}
			end
		end
	end

	function self.patchStoneEvos()
		patchedMoonStones = true
		-- all these methods get changed to Rogue Stone
		local itemEvoMethods = {
			PokemonData.Evolutions.EEVEE_STONES_NATDEX, PokemonData.Evolutions.THUNDER, PokemonData.Evolutions.FIRE, PokemonData.Evolutions.WATER, 
			PokemonData.Evolutions.MOON, PokemonData.Evolutions.LEAF, PokemonData.Evolutions.SUN, PokemonData.Evolutions.LEAF_SUN, 
			PokemonData.Evolutions.WATER_ROCK, PokemonData.Evolutions.SHINY, PokemonData.Evolutions.DUSK, PokemonData.Evolutions.DAWN, 
			PokemonData.Evolutions.ICE, PokemonData.Evolutions.METAL_COAT, PokemonData.Evolutions.KINGS_ROCK, PokemonData.Evolutions.DRAGON_SCALE,
			PokemonData.Evolutions.UPGRADE, PokemonData.Evolutions.DUBIOUS_DISC, PokemonData.Evolutions.RAZOR_CLAW, PokemonData.Evolutions.RAZOR_FANG,
			PokemonData.Evolutions.LINKING_CORD, PokemonData.Evolutions.WATER_DUSK, PokemonData.Evolutions.MOON_SUN, PokemonData.Evolutions.SUN_LEAF_DAWN,
			PokemonData.Evolutions.COAT_ROCK, PokemonData.Evolutions.DEEPSEA
		}
		
		local rogue = {
			abbreviation = "ROGUE",
			short = {"Rogue"},
			detailed = {"RogueStone"},
			evoItemIds = { 94 },
		}

		-- dual evo methods get changed to RogueStone/Lvl
		local rogue30 = {
			abbreviation = "30/RG",
			short = { "Lv.30", "Rogue", },
			detailed = { "Level 30", "RogueStone", },
			evoItemIds = { 94 },
		}
		local rogue37 = {
			abbreviation = "37/RG",
			short = { "Lv.37", "Rogue", },
			detailed = { "Level 37", "RogueStone", },
			evoItemIds = { 94 },
		}
		local rogue42 = {
			abbreviation = "42/RG",
			short = { "Lv.42", "Rogue", },
			detailed = { "Level 42", "RogueStone", },
			evoItemIds = { 94, },
		}
		local extraEvo = {
			abbreviation = "BST/10",
			short = {"BST/10"},
			detailed = {"Evo BST/10"}
		}
		local itemLevelEvoMethods = {
			[PokemonData.Evolutions.WATER30] = rogue30,
			[PokemonData.Evolutions.WATER37] = rogue37,
			[PokemonData.Evolutions.WATER37_REV] = rogue37,
			[PokemonData.Evolutions.DAWN42] = rogue42,
			[PokemonData.Evolutions.DAWN30] = rogue30,
			[PokemonData.Evolutions.ROCK37] = rogue37,
		}
		for _,pk in pairs(PokemonData.Pokemon) do
			if pk.name ~= "none" then
				for _,method in pairs(itemEvoMethods) do
					if pk.evolution == method then
						pk.evolution = rogue
					end
				end
				for method,replacement in pairs(itemLevelEvoMethods) do
					if pk.evolution == method then
						pk.evolution = replacement
					end
				end
				if pk.evolution == PokemonData.Evolutions.NONE and pk.bst <= 450 then
					pk.evolution = extraEvo
				end
			end
		end
	end

	function self.itemNotPresent(itemID)
		local items = Program.GameData.Items
		if MiscData.PokeBalls[itemID] then
			return not (items.PokeBalls[itemID] and items.PokeBalls[itemID] > 0)
		end
		if MiscData.HealingItems[itemID] then
			return not (items.HPHeals[itemID] and items.HPHeals[itemID] > 0)
		end
		if MiscData.PPItems[itemID] then
			return not (items.PPHeals[itemID] and items.PPHeals[itemID] > 0)
		end
		if MiscData.StatusItems[itemID] then
			return not (items.StatusHeals[itemID] and items.StatusHeals[itemID] > 0)
		end
		if MiscData.EvolutionStones[itemID] then
			return not (items.EvoStones[itemID] and items.EvoStones[itemID] > 0)
		end
		if not (items.PokeBalls[itemID] or items.HPHeals[itemID] or items.PPHeals[itemID] or items.StatusHeals[itemID] or items.EvoStones[itemID]) then
			return not (items.Other[itemID] and items.Other[itemID] > 0)
		end
		return true
	end

	function self.uponItemAdded(item)
		self.countAdjustedHeals()
		if RoguemonOptions["Show reminders"] and item == "Moon Stone" and not TrackerAPI.hasDefeatedTrainer(414) and not givenMoonStoneNotification then
			givenMoonStoneNotification = true
			return "Brock says: Nice stone. Unfortunately, you'll need to defeat me if you want to use it!", "brock.png", nil
		end
		if RoguemonOptions["Show reminders"] then
			local itemId = self.getItemId(item)
			if notifyOnPickup.consumables[item] and not (specialRedeems.unlocks["Berry Pouch"] and string.sub(item, string.len(item)-4, string.len(item)) == "Berry") then
				if notifyOnPickup.consumables[item] == 2 then
					return (item .. " must be used, equipped or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
				else
					return (item .. " must be equipped or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
				end
			elseif notifyOnPickup.vitamins[item] then
				return (item .. " must be used or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
			elseif notifyOnPickup.candies[item] and not specialRedeems.unlocks["Candy Jar"] then
				return (item .. " must be used or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
			elseif RoguemonOptions["Show reminders over cap"] and MiscData.HealingItems[itemId] and adjustedHPVal > hpCap and not needToBuy then
				return ("An HP healing item must be used or trashed"), "healing-pocket.png", function()
					self.countAdjustedHeals()
					return adjustedHPVal <= hpCap
				end
			elseif RoguemonOptions["Show reminders over cap"] and MiscData.StatusItems[itemId] and currentStatusVal > statusCap and not needToBuy then
				return ("A status healing item must be used or trashed"), "status-cap.png", function()
					return self.countStatusHeals() <= statusCap
				end
			end
		end
		return nil
	end

	function self.processItemAdded(item)
		local itemId = self.getItemId(item)
		local s, img, dismissFunc = self.uponItemAdded(item)
		if s then
			if committed or item == "Moon Stone" then
				self.displayNotification(s, img, dismissFunc)
			else
				if not (img == "healing-pocket.png" or img == "status-cap.png") then
					local shouldAdd = true
					for _,notif in pairs(suppressedNotifications) do
						if notif.message == s then
							shouldAdd = false
						end
					end
					if shouldAdd then
						suppressedNotifications[#suppressedNotifications + 1] = {message = s, image = img, dismissFunction = dismissFunc}
					end
				end
			end
		end
		if MiscData.HealingItems[self.getItemId(item)] and specialRedeems.consumable["Luck Incense"] and adjustedHPVal > hpCap then
			self.offerBinaryOption("Luck Incense on " .. item, "Skip")
		end
		if specialRedeems.consumable["Duplicator"] then
			if MiscData.HealingItems[itemId] or MiscData.StatusItems[itemId] or MiscData.PPItems[itemId] then
				self.offerBinaryOption("Duplicate " .. item, "Skip")
			end
		end
	end

	function self.removeSpecialRedeem(redeem)
		if specialRedeems.consumable[redeem] then
			specialRedeems.consumable[redeem] = nil
			local id = nil
			for i,r in pairs(specialRedeems.consumable) do
				if r == redeem then
					id = i
					break
				end
			end
			if id then 
				table.remove(specialRedeems.consumable, id) 
				return true
			end
		end
		return false
	end

	-- Move to the next segment.
	function self.nextSegment()
		local curse = self.getActiveCurse()
		if curse and RoguemonOptions["Alternate Curse theme"] then
			Theme.importThemeFromText(previousTheme, true)
		end
		if trainersDefeated < self.getSegmentTrainerCount(currentSegment) then
			if curse == "Claustrophobia" then
				hpCap = hpCap - 50
				hpCapModifier = hpCapModifier - 50
			end
			if curse == "Downsizing" then
				downsized = true
			end
		end
		currentSegment = currentSegment + 1
		segmentStarted = false
		trainersDefeated = 0
		mandatoriesDefeated = 0
	end

	function self.startSegment()
		segmentStarted = true
		local curse = self.getActiveCurse()
		if curse then
			if RoguemonOptions["Alternate Curse theme"] then
				previousTheme = Theme.exportThemeToText()
				Theme.importThemeFromText(CURSE_THEME, true)
			end
			self.displayNotification("Curse: " .. curse .. " @ " .. curseInfo[curse].description, "Curse.png", nil)
			if curse == "High Pressure" then
				local pkmn = self.readLeadPokemonData()
				local pp1 = Utils.getbits(pkmn.attack3, 0, 8) / 2
				local pp2 = Utils.getbits(pkmn.attack3, 8, 8) / 2
				local pp3 = Utils.getbits(pkmn.attack3, 16, 8) / 2
				local pp4 = Utils.getbits(pkmn.attack3, 24, 8) / 2
				pkmn.attack3 = pp1 + Utils.bit_lshift(pp2, 8)  + Utils.bit_lshift(pp3, 16) + Utils.bit_lshift(pp4, 24)
				self.writeLeadPokemonData(pkmn)
			end
			if curse == "Toxic Fumes" then
				stepCounter.lastCounted = Utils.getGameStat(Constants.GAME_STATS.STEPS)
				stepCounter.toxicFumesCycle = 0
			end
		end
	end

	-- Determine if a particular segment has been reached yet
	function self.reachedSegment(seg)
		for i = 1,currentSegment do
			if segmentOrder[i] == seg then return true end
		end
		return false
	end

	-- Get the number of trainers in the current segment. We subtract 2 if there's a rival in the segment because the rival has 3 trainer IDs.
	function self.getSegmentTrainerCount(segment)
		return #segments[segmentOrder[segment]]['trainers'] - (segments[segmentOrder[segment]]['rival'] and 2 or 0)
	end

	-- Get the number of mandatory trainers in the current segment. See above, plus both trainers in a choice pair are marked mandatory when only one is.
	function self.getSegmentMandatoryCount(segment)
		local s = segments[segmentOrder[segment]]
		return #s['mandatory'] - (s['rival'] and 2 or 0) - (s['choicePairs'] and #s['choicePairs'] or 0)
	end

	-- Handle the buy phase.
	function self.buyPhase()
		self.displayNotification("Buy Phase @ May trade heals for equal value @ May trade status heals 1:1, or 3:1 for Full Heals or vice versa", "Poke_Mart.png", nil)
		if specialRedeems.consumable["Potion Investment"] then
			local buyable = "Potion"
			if specialRedeems.consumable["Potion Investment"] >= 50 then
				buyable = "Super Potion"
			end
			if specialRedeems.consumable["Potion Investment"] >= 200 then
				buyable = "Hyper Potion"
			end
			if self.reachedSegment("Victory Road") then
				buyable = "Max Potion"
			end
			self.offerBinaryOption("Cash Out - " .. buyable, "Wait")
		end
	end

	-- Handle the cleansing phase.
	function self.cleansingPhase()
		-- TODO: Implement automatic cleansing. Coming in a future update hopefully.
		self.displayNotification("Cleansing Phase @ Must sell all non-healing items (including TMs) unless they have been unlocked", "trash.png", function()
			local mapId = TrackerAPI.getMapId()
			return previousMap == 10 and mapId ~= 10
		end)
	end

	-- TRACKER SCREENS --

	-- Main screen for spinning and selecting rewards.
    local RewardScreen = {

	}

    RewardScreen.Colors = {
		text = "Default text",
		highlight = "Intermediate text",
		border = "Upper box border",
		fill = "Upper box background",
	}

	-- Layout constants
	local TOP_LEFT_X = 2
	local IMAGE_WIDTH = 25
	local IMAGE_GAP = 1
	local BUTTON_WIDTH = 101
	local TOP_BUTTON_Y = 28
	local BUTTON_HEIGHT = 25
	local BUTTON_VERTICAL_GAP = 4
	local DESC_WIDTH = 9
	local DESC_HORIZONTAL_GAP = 2
	local WRAP_BUFFER = 7
	local DESC_TEXT_HEIGHT = 68

    function RewardScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS[RewardScreen.Colors.text],
			border = Theme.COLORS[RewardScreen.Colors.border],
			fill = Theme.COLORS[RewardScreen.Colors.fill],
			shadow = Utils.calcShadowColor(Theme.COLORS[RewardScreen.Colors.fill]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		for _, button in pairs(RewardScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end

		self.drawCapsAt(DataHelper.buildTrackerScreenDisplay(), Constants.SCREEN.WIDTH + 45, 5)

		-- Draw the images
		if option1 ~= "" then
			Drawing.drawImage(IMAGES_DIRECTORY .. prize_images[option1], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y, IMAGE_WIDTH, BUTTON_HEIGHT)
		end
		if option2 ~= "" then
			Drawing.drawImage(IMAGES_DIRECTORY .. prize_images[option2], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, IMAGE_WIDTH, BUTTON_HEIGHT)
		end
		if option3 ~= "" then
			Drawing.drawImage(IMAGES_DIRECTORY .. prize_images[option3], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP*2 + BUTTON_HEIGHT*2, IMAGE_WIDTH, BUTTON_HEIGHT)
		end
	end

	RewardScreen.Buttons = {
		-- Option buttons
		Option1 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(option1, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				self.selectReward(option1)
			end,
		},
		Option2 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(option2, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				self.selectReward(option2)
			end,
		},
		Option3 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(option3, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP*2 + BUTTON_HEIGHT*2, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				self.selectReward(option3)
			end,
			isVisible = function() return option3 ~= "" end
		},
		-- Description buttons (the ? button)
		Option1Desc = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "? " end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP, TOP_BUTTON_Y, 
			DESC_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				descriptionText = option1Desc
			end,
			isVisible = function() return option1Desc ~= "" end
		},
		Option2Desc = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "? " end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, 
			DESC_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				descriptionText = option2Desc
			end,
			isVisible = function() return option2Desc ~= "" end
		},
		Option3Desc = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "? " end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP, TOP_BUTTON_Y + 2*BUTTON_VERTICAL_GAP + 2*BUTTON_HEIGHT, 
			DESC_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				descriptionText = option3Desc
			end,
			isVisible = function() return option3Desc ~= "" end
		},
		-- Next button-- only used for testing; disabled by default
		NextButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Next" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 110, 137, 22, 12 },
			onClick = function()
				Program.changeScreenView(TrackerScreen)
				milestone = milestone + 1
				self.spinReward(milestones[milestone]['name'], true)
			end,
			isVisible = function() return DEBUG_MODE end
		},
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 108, 8, 22, 10},
			onClick = function()
				Program.changeScreenView(TrackerScreen)
			end,
		},
		-- Reroll button-- only visible if the player has a Reroll Chip
		RerollButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Reroll" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, 7, 27, 12 },
			onClick = function()
				self.removeSpecialRedeem("Reroll Chip")
				self.spinReward(lastMilestone, true)
			end,
			isVisible = function() return 
				specialRedeems.consumable["Reroll Chip"] 
			end
		},
		-- Extra description text at the bottom
		Description = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function() return self.wrapPixelsInline(descriptionText, IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP + DESC_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X, TOP_BUTTON_Y + 3*BUTTON_VERTICAL_GAP + 3*BUTTON_HEIGHT, 
			IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP + DESC_WIDTH, DESC_TEXT_HEIGHT },
		}
	}

	-- It took me an embarrassingly long time to realize I needed this function for my buttons to work
	function RewardScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, RewardScreen.Buttons or {})
	end

	-- Screen for selecting an additional option.
	local OptionSelectionScreen = {
		
	}

    function OptionSelectionScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS["Default text"],
			border = Theme.COLORS["Upper box border"],
			fill = Theme.COLORS["Upper box background"],
			shadow = Utils.calcShadowColor(Theme.COLORS["Upper box border"]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		if additionalOptionsRemaining > 1 then
			Drawing.drawText(Constants.SCREEN.WIDTH + 35, 5, "Choose " .. additionalOptionsRemaining .. " more", Theme.COLORS["Default text"], Utils.calcShadowColor(Theme.COLORS["Upper box background"]))
		end

		for _, button in pairs(OptionSelectionScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	-- Layout constants
	local OSS_LEFT_TOP_LEFT_X = 6
	local OSS_BUTTON_WIDTH = 55
	local OSS_BUTTON_HORIZONTAL_GAP = 6
	local OSS_TOP_BUTTON_Y = 22
	local OSS_BUTTON_HEIGHT = 32
	local OSS_BUTTON_VERTICAL_GAP = 10
	local OSS_WRAP_BUFFER = 2

	OptionSelectionScreen.Buttons = {
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				Program.changeScreenView(TrackerScreen)
			end,
		}
	}

	-- Create the 2x3 grid of buttons
	for j = 0,2 do
		for i = 0,1 do
			local index = i + j*2 + 1
			OptionSelectionScreen.Buttons[index] = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() 
					return (additionalOptionsRemaining > 0) and self.wrapPixelsInline(additionalOptions[index], OSS_BUTTON_WIDTH - OSS_WRAP_BUFFER) or ""
				end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OSS_LEFT_TOP_LEFT_X + (i*(OSS_BUTTON_WIDTH + OSS_BUTTON_HORIZONTAL_GAP)), 
				OSS_TOP_BUTTON_Y + (j*(OSS_BUTTON_HEIGHT + OSS_BUTTON_VERTICAL_GAP)), OSS_BUTTON_WIDTH, OSS_BUTTON_HEIGHT },
				onClick = function()
					self.selectAdditionalOption(self.splitOn(additionalOptions[index], "(")[1]) -- if a button has (), it's clarification text; we display it but don't read it
				end,
				isVisible = function()
					return additionalOptions[index] and additionalOptions[index] ~= "" -- Visible as long as it has text
				end
			}
		end
	end

	function OptionSelectionScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, OptionSelectionScreen.Buttons or {})
	end

	function self.offerBinaryOption(opt1, opt2)
		additionalOptions[1] = opt1
		additionalOptions[2] = opt2
		for i = 3,8 do
			additionalOptions[i] = ""
		end
		additionalOptionsRemaining = 1
		self.setCurrentRoguemonScreen(OptionSelectionScreen)
		self.readyScreen(OptionSelectionScreen)
	end

	-- Screen for showing the special redeems
	local SpecialRedeemScreen = {
		
	}

    -- Layout constants
	local SRS_TOP_LEFT_X = 6
	local SRS_TEXT_WIDTH = 115
	local SRS_TOP_Y = 22
	local SRS_WRAP_BUFFER = 7
	local SRS_HORIZONTAL_GAP = 6
	local SRS_BUTTON_WIDTH = 10
	local SRS_BUTTON_HEIGHT = 10
	local SRS_LINE_HEIGHT = 10
	local SRS_LINE_COUNT = 8
	local SRS_DESC_WIDTH = 105

    function SpecialRedeemScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS["Default text"],
			border = Theme.COLORS["Upper box border"],
			fill = Theme.COLORS["Upper box background"],
			shadow = Utils.calcShadowColor(Theme.COLORS["Upper box border"]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		-- Header text
		Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, 10, "Redeemed Rewards")

		-- Display image, if any
		if specialRedeemToDescribe then
			Drawing.drawImage(IMAGES_DIRECTORY .. specialRedeemInfo[specialRedeemToDescribe].image, canvas.x + SRS_DESC_WIDTH + 2, SRS_TOP_Y + SRS_LINE_COUNT*SRS_LINE_HEIGHT)
		end

		for _, button in pairs(SpecialRedeemScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	SpecialRedeemScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				Program.changeScreenView(TrackerScreen)
			end,
		},
		-- Description text, works similar to main prize screen
		DescriptionText = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function()
				local toReturn = specialRedeemToDescribe and specialRedeemInfo[specialRedeemToDescribe].description or ""
				-- if we're displaying Potion Investment, grab the actual value of it
				if specialRedeemToDescribe == "Potion Investment" then
					toReturn = toReturn .. " " .. specialRedeems.consumable["Potion Investment"]
				end
				return  self.wrapPixelsInline(toReturn, SRS_DESC_WIDTH - SRS_WRAP_BUFFER)
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X, SRS_TOP_Y + SRS_LINE_COUNT*SRS_LINE_HEIGHT, SRS_DESC_WIDTH, 70}
		}
	}

	-- Create the row buttons
	for i = 1,SRS_LINE_COUNT do
		-- Delete button
		SpecialRedeemScreen.Buttons["X" .. i] = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() 
				return "X" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X + SRS_TEXT_WIDTH, SRS_TOP_Y + ((i-1)*(SRS_LINE_HEIGHT)), SRS_BUTTON_WIDTH, SRS_BUTTON_HEIGHT },
			onClick = function()
				local toRemove = specialRedeems.consumable[i-#specialRedeems.unlocks]
				if specialRedeemToDescribe == toRemove then
					specialRedeemToDescribe = nil
				end
				specialRedeems.consumable[toRemove] = nil
				table.remove(specialRedeems.consumable, i-#specialRedeems.unlocks)
				
			end,
			isVisible = function()
				return specialRedeems.consumable[i-#specialRedeems.unlocks]
			end
		}

		-- Redeem name button (it's a button because clicking on it brings up the description)
		SpecialRedeemScreen.Buttons["Text" .. i] = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function() 
				if i <= #specialRedeems.unlocks then 
					return specialRedeems.unlocks[i]
				elseif i<= #specialRedeems.unlocks + #specialRedeems.consumable then
					return specialRedeems.consumable[i-#specialRedeems.unlocks]
				end
				return ""
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X, SRS_TOP_Y + (i-1)*SRS_LINE_HEIGHT, SRS_TEXT_WIDTH, SRS_LINE_HEIGHT },
			onClick = function(this)
				local redeem = this.getText()
				if redeem ~= "" then 
					specialRedeemToDescribe = redeem
					Program.redraw(true)
				end
			end
		}
	end

	function SpecialRedeemScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, SpecialRedeemScreen.Buttons or {})
	end

	-- Screen for showing random messages
	local NotificationScreen = {
		message = "",
		image = nil,
		auxiliaryButtonInfo = {
			["Buy Phase"] = {
				name = "Heals",
				onClick = function() 
					HealsInBagScreen.changeTab(HealsInBagScreen.Tabs.All)
					Program.changeScreenView(HealsInBagScreen) 
				end
			},
			["Curse:"] = {
				name = "Ward",
				onClick = function()
					self.removeSpecialRedeem("Warding Charm")
					cursedSegments[segmentOrder[currentSegment]] = nil
					for i,seg in ipairs(cursedSegments) do
						if seg == segmentOrder[currentSegment] then
							table.remove(cursedSegments, i)
							break
						end
					end
					if RoguemonOptions["Alternate Curse theme"] then
						Theme.importThemeFromText(previousTheme, true)
					end
					Program.changeScreenView(TrackerScreen)
				end,
				isVisible = function()
					return specialRedeems.consumable["Warding Charm"]
				end
			}
		}
	}

	function NotificationScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS["Default text"],
			border = Theme.COLORS["Upper box border"],
			fill = Theme.COLORS["Upper box background"],
			shadow = Utils.calcShadowColor(Theme.COLORS["Upper box border"]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		-- Image
		if(NotificationScreen.image) then
			Drawing.drawImage(NotificationScreen.image, canvas.x + 40, 15, IMAGE_WIDTH*2, IMAGE_WIDTH*2)
		end

		-- Text
		Drawing.drawText(canvas.x + 10, 64, self.wrapPixelsInline(NotificationScreen.message, canvas.w - 20))

		local aux = nil
		for pre, info in pairs(NotificationScreen.auxiliaryButtonInfo) do
			if string.sub(NotificationScreen.message, 1, string.len(pre)) == pre then
				aux = info
			end
		end
		NotificationScreen.activeAuxiliary = aux
		if aux then
			NotificationScreen.Buttons.AuxiliaryButton.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 143, 
			Utils.calcWordPixelLength(aux.name) + 4, 10} 
		end

		for _, button in pairs(NotificationScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	NotificationScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				Program.changeScreenView(TrackerScreen)
			end
		},
		AuxiliaryButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function()
				local i = NotificationScreen.activeAuxiliary
				if i then
					return i.name
				end
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 143, 30, 10},
			onClick = function()
				local i = NotificationScreen.activeAuxiliary
				if i then
					return i.onClick()
				end
			end,
			isVisible = function()
				local i = NotificationScreen.activeAuxiliary
				if i then
					if i.isVisible then 
						return i.isVisible()
					else
						return true
					end
				end
				return false
			end
		}
	}

	function NotificationScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, NotificationScreen.Buttons or {})
	end

	function self.displayNotification(message, image, dismissFunction)
		NotificationScreen.message = message
		NotificationScreen.image = IMAGES_DIRECTORY .. image
		if Program.currentScreen == PrettyStatScreen then
			self.readyScreen(NotificationScreen)
		else
			Program.changeScreenView(NotificationScreen)
		end
		Program.redraw(true)
		shouldDismissNotification = dismissFunction
	end

	-- Options screen
	local OptionsScreen = {
		
	}

	local OS_LEFT_X = 10
	local OS_TOP_Y = 12
	local OS_BOX_SIZE = 10
	local OS_BOX_TEXT_GAP = 10
	local OS_BOX_VERTICAL_GAP = 5

	function OptionsScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS["Default text"],
			border = Theme.COLORS["Upper box border"],
			fill = Theme.COLORS["Upper box background"],
			shadow = Utils.calcShadowColor(Theme.COLORS["Upper box border"]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		if #OptionsScreen.Buttons == 0 then
			for i = 1,#optionsList do
				OptionsScreen.Buttons[i] = {
					type = Constants.ButtonTypes.CHECKBOX,
					getText = function() return optionsList[i].text end,
					box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OS_LEFT_X, OS_TOP_Y + i*(OS_BOX_SIZE + OS_BOX_VERTICAL_GAP), OS_BOX_SIZE, OS_BOX_SIZE},
					toggleState = RoguemonOptions[optionsList[i].text],
					updateSelf = function() self.toggleState = RoguemonOptions[optionsList[i].text] end,
					clickableArea = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OS_LEFT_X, OS_TOP_Y + i*(OS_BOX_SIZE + OS_BOX_VERTICAL_GAP), OS_BOX_SIZE, OS_BOX_SIZE},
					onClick = function(this)
						this.toggleState = not this.toggleState
						RoguemonOptions[optionsList[i].text] = this.toggleState
						Program.redraw(true)
					end
				}
			end
			OptionsScreen.Buttons.BackButton = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() return "Back" end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
				onClick = function()
					Program.changeScreenView(TrackerScreen)
				end
			}
		end

		for _, button in pairs(OptionsScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	OptionsScreen.Buttons = {
		
	}

	function OptionsScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, OptionsScreen.Buttons or {})
	end

	local PrettyStatScreen = {
		oldPoke = nil,
		newPoke = nil
	}

	local PSS_IMAGE_Y = 20
	local PSS_STAT_X = 10
	local PSS_LEFT_X = 30
	local PSS_MID_X = 60
	local PSS_RIGHT_X = 100
	local PSS_TEXT_Y = 55
	local PSS_TEXT_GAP = 11
	local IMAGE_CENTERING = 10

    function PrettyStatScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS["Default text"],
			border = Theme.COLORS["Upper box border"],
			fill = Theme.COLORS["Upper box background"],
			shadow = Utils.calcShadowColor(Theme.COLORS["Upper box border"]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		if PrettyStatScreen.oldPoke and PrettyStatScreen.newPoke then
			Drawing.drawImage(Drawing.getImagePath("PokemonIcon", tostring(PrettyStatScreen.oldPoke.pokemonID)), canvas.x + PSS_LEFT_X - IMAGE_CENTERING, PSS_IMAGE_Y)
			Drawing.drawImage(Drawing.getImagePath("PokemonIcon", tostring(PrettyStatScreen.newPoke.pokemonID)), canvas.x + PSS_RIGHT_X - IMAGE_CENTERING, PSS_IMAGE_Y)
			local dy = 0
			for _, statKey in ipairs(Constants.OrderedLists.STATSTAGES) do
				local oldStat = PrettyStatScreen.oldPoke.stats[statKey]
				local newStat = PrettyStatScreen.newPoke.stats[statKey]
				local statDiff = newStat - oldStat
				local statText = string.upper(statKey)
				gui.drawRectangle(canvas.x + PSS_STAT_X, PSS_TEXT_Y + dy, PSS_RIGHT_X - PSS_STAT_X + 19, PSS_TEXT_GAP, canvas.border)
				Drawing.drawText(canvas.x + PSS_STAT_X, PSS_TEXT_Y + dy, statText)
				Drawing.drawText(canvas.x + PSS_LEFT_X, PSS_TEXT_Y + dy, oldStat)
				if statDiff >= 0 then
					Drawing.drawText(canvas.x + PSS_MID_X, PSS_TEXT_Y + dy, "+" .. statDiff, Theme.COLORS["Positive text"])
				elseif statDiff == 0 then
					Drawing.drawText(canvas.x + PSS_MID_X, PSS_TEXT_Y + dy, "+" .. statDiff, Theme.COLORS["Default text"])
				else
					Drawing.drawText(canvas.x + PSS_MID_X, PSS_TEXT_Y + dy, statDiff, Theme.COLORS["Negative text"])
				end
				Drawing.drawText(canvas.x + PSS_RIGHT_X, PSS_TEXT_Y + dy, newStat)
				dy = dy + PSS_TEXT_GAP
			end
		end

		for _, button in pairs(PrettyStatScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	PrettyStatScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				Program.changeScreenView(TrackerScreen)
			end,
		},
	}

	function PrettyStatScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, PrettyStatScreen.Buttons or {})
	end

	function self.showPrettyStatScreen(oldmon, newmon)
		PrettyStatScreen.oldPoke = oldmon
		PrettyStatScreen.newPoke = newmon
		self.readyScreen(PrettyStatScreen)
	end

	-- REWARD SPIN FUNCTIONS --
	
	-- Update caps to match the current milestone
	function self.updateCaps(fromMilestone)
		local newHpCap = milestonesByName[lastMilestone]['hpCap'] + hpCapModifier
		local newStatusCap = milestonesByName[lastMilestone]['statusCap'] + statusCapModifier
		if (newHpCap ~= hpCap or newStatusCap ~= statusCap) and RoguemonOptions["Show reminders"] and fromMilestone then
			local notif = "Gained "
			if newHpCap - hpCap > 0 then
				notif = notif .. "+" .. (newHpCap - hpCap) .. " HP Cap "
			end
			if newHpCap - hpCap > 0 and newStatusCap - statusCap > 0 then
				notif = notif .. "and "
			end
			if newStatusCap - statusCap > 0 then
				notif = notif .. "+" .. (newStatusCap - statusCap) .. " Status Cap"
			end
			self.displayNotification(notif, "healing-pocket.png", nil)
		end
		hpCap = newHpCap
		statusCap = newStatusCap
	end

	-- Spin the reward for a given milestone.
	function self.spinReward(milestoneName, rerolled)
		if LogOverlay.isGameOver and Program.currentScreen == GameOverScreen then
			GameOverScreen.status = GameOverScreen.Statuses.STILL_PLAYING
			LogOverlay.isGameOver = false
			LogOverlay.isDisplayed = false
			Program.GameTimer:unpause()
			GameOverScreen.refreshButtons()
			GameOverScreen.Buttons.SaveGameFiles:reset()
		end

		lastMilestone = milestoneName
		self.updateCaps(true)
		local rewardOptions = wheels[milestonesByName[milestoneName]['wheel']]
		local choices = {}
		local choiceCount = downsized and 2 or 3
		while #choices < choiceCount do
			local choice = rewardOptions[math.random(#rewardOptions)]
			local choiceName = Utils.split(choice, ":", true)[1]
			local choiceParts = Utils.split(choiceName, '&', true)
			local add = true
			for _,part in pairs(choiceParts) do
				if specialRedeems.unlocks[part] or specialRedeems.consumable[part] or specialRedeems.internal[part] or 
					(part == "Fight Route X" and specialRedeems.internal["Route 15"]) then
					add = false
				end
				if part == "Warding Charm" and not RoguemonOptions["Ascension 2+"] then
					add = false
				end
				if(part == "Ability Capsule") then
					choice = choice .. ": Change ability to " .. AbilityData.Abilities[PokemonData.getAbilityId(Tracker.getPokemon(1).pokemonID, 1 - Tracker.getPokemon(1).abilityNum)].name .. "."
				end
			end
			if choiceName == "Fight Route X" then
				local routes = {"Route 12", "Route 13", "Route 14", "Route 15"}
				local rInd = 1
				while specialRedeems.internal[routes[rInd]] and rInd <= 4 do
					rInd = rInd + 1
				end
				choice = "Fight " .. routes[rInd] .. ": Treat the route as a segment. Keep items found."
			end
			for _, v in pairs(choices) do
				if v == choice then
					add = false
				end
			end
			if add and choice then choices[#choices + 1] = choice end
		end

		local option1Split = Utils.split(choices[1], ":", true)
		option1 = option1Split[1]
		option1Desc = option1Split[2] or ""
		local option2Split = Utils.split(choices[2], ":", true)
		option2 = option2Split[1]
		option2Desc = option2Split[2] or ""
		if downsized then
			option3 = ""
			option3Desc = ""
		else
			local option3Split = Utils.split(choices[3], ":", true)
			option3 = option3Split[1]
			option3Desc = option3Split[2] or ""
		end

		descriptionText = ""

		if rerolled then
			Program.changeScreenView(RewardScreen)
		else
			self.readyScreen(RewardScreen)
		end
		self.setCurrentRoguemonScreen(RewardScreen)
		Program.redraw(true)

		if phases[milestoneName] then
			if phases[milestoneName].buy then
				needToBuy = true
			end
			if phases[milestoneName].cleansing then
				needToCleanse = true
			end
		end

	end

	-- Select a particular reward option.
	function self.selectReward(option)
		local nextScreen = TrackerScreen -- by default we return to the main screen, unless the reward needs us to make another choice

		local rewards = Utils.split(option, '&', true) -- split the string up into its separate parts
		for _, reward in pairs(rewards) do
			-- Cover the route reward separately
			if string.sub(reward, 1, 11) == 'Fight Route' then
				local route = string.sub(reward, 7)
				specialRedeems.internal[route] = true
				table.insert(segmentOrder, currentSegment, route)
			else
				-- Check cap increases first
				if string.sub(reward, 1, 8) == 'HP Cap +' then
					hpCapModifier = hpCapModifier + tonumber(string.sub(reward, 9, #reward))
				end
				if string.sub(reward, 1, 12) == 'Status Cap +' then
					statusCapModifier = statusCapModifier + tonumber(string.sub(reward, 13, #reward))
				end

				-- Determine item name and item count
				local itemCount = 1
				local split = Utils.split(reward, " ", true)
				if string.sub(split[#split], 1, 1) == 'x' then
					local s = split[1]
					for i = 2,#split-1 do s = s .. " " .. split[i] end
					reward = s
					itemCount = tonumber(string.sub(split[#split], 2, #(split[#split])))
				end
				local itemId = self.getItemId(reward)
				if reward == "Berry Pouch" then itemId = 0 end -- this is an item in the game, but not what we want
				if itemId ~= 0 then
					-- This reward simply yields items, so provide them
					self.AddItemImproved(reward, itemCount)
				end
				if reward == "Nature Mint" then
					additionalOptions = {"+Atk", "+Def", "+SpAtk", "+SpDef", "+Speed", "", "", ""}
					additionalOptionsRemaining = 1
					nextScreen = OptionSelectionScreen
					specialRedeems.internal["Nature Mint"] = true
				end
				if reward == "Ability Capsule" then
					self.flipAbility()
					specialRedeems.internal["Ability Capsule"] = true
				end
				if reward == "Luck Incense" then
					specialRedeems.internal["Luck Incense"] = true
				end
				if string.sub(reward, 1, 3) == 'Any' then
					-- This reward is a choice of items
					for key,choices in pairs(prizeAdditionalOptions) do
						if key == reward then
							for i,_ in pairs(additionalOptions) do
								if i > #choices then 
									additionalOptions[i] = ""
								else 
									additionalOptions[i] = choices[i]
								end
							end
							additionalOptionsRemaining = itemCount
							nextScreen = OptionSelectionScreen
						end
					end
				end
				if specialRedeemInfo[reward] then
					-- This reward is a special redeem
					if specialRedeemInfo[reward].consumable then 
						specialRedeems.consumable[reward] = true
						specialRedeems.consumable[#specialRedeems.consumable + 1] = reward
						if reward == "Potion Investment" then
							specialRedeems.consumable[reward] = 20
						end
						if reward == "Revive" then
							specialRedeems.internal["Revive"] = true
						end
						if reward == "Fight up to 5 random wilds" then
							wildBattleCounter = 5
							wildBattlesStarted = false
						end
						if reward == "Fight wilds in Rts 1/2/22" then
							wildBattleCounter = 3
							wildBattlesStarted = false
						end
					else
						specialRedeems.unlocks[reward] = true
						specialRedeems.unlocks[#specialRedeems.unlocks + 1] = reward
					end
				end
			end
		end

		descriptionText = ""

		self.updateCaps(false)

		Program.changeScreenView(nextScreen)

		if nextScreen == TrackerScreen then
			currentRoguemonScreen = SpecialRedeemScreen
		else
			currentRoguemonScreen = nextScreen
		end

		Program.redraw(true)
	end

	local prefixHandlers = {
		["Luck Incense on "] = function(value)
			specialRedeems.consumable["luckIncenseItem"] = value
			self.removeSpecialRedeem("Luck Incense")
		end,
		["Duplicate "] = function(value)
			self.removeSpecialRedeem("Duplicator")
			self.AddItemImproved(value, 1)
		end,
		["Cash Out - "] = function(value)
			self.removeSpecialRedeem("Potion Investment")
			self.AddItemImproved(value, 1)
		end
	}

	-- Select an option on the additional option screen. Usually this just yields an item.
	function self.selectAdditionalOption(option)
		local special = false
		-- Special button options provided by certain redeems.
		for prefix,func in pairs(prefixHandlers) do
			local val = self.getPrefixed(option, prefix)
			if val then
				func(val)
				special = true
				additionalOptionsRemaining = additionalOptionsRemaining - 1
			end
		end
		if string.sub(option, 1, 1) == "+" then
			-- Nature + selection
			natureMintUp = option
			special = true
			additionalOptionsRemaining = additionalOptionsRemaining - 1
		end
		if string.sub(option, 1, 1) == "-" then
			local natureChart = {
				["+Atk"] = 0,
				["+Def"] = 5,
				["+Speed"] = 10,
				["+SpAtk"] = 15,
				["+SpDef"] = 20,
				["-Atk"] = 0,
				["-Def"] = 1,
				["-Speed"] = 2,
				["-SpAtk"] = 3,
				["-SpDef"] = 4
			}
			local nature = natureChart[natureMintUp] + natureChart[option]
			self.changeNature(nature)
			special = true
			additionalOptionsRemaining = additionalOptionsRemaining - 1
		end
		if option == "RogueStone" then
			-- Moon stone trade reduces HP cap by 100
			hpCapModifier = hpCapModifier - 100
			hpCap = hpCap - 100
			self.AddItemImproved("Moon Stone", 1)
			additionalOptionsRemaining = additionalOptionsRemaining - 1
			special = true
		end
		-- Regular item option
		if not special and option ~= "" and additionalOptionsRemaining > 0 then
			self.AddItemImproved(option, 1)
			self.itemFromPrize = option
			additionalOptionsRemaining = additionalOptionsRemaining - 1
		end
		if additionalOptionsRemaining <= 0 then
			if string.sub(option, 1, 1) == "+" then
				additionalOptions = {"-Atk", "-Def", "-SpAtk", "-SpDef", "-Speed", "", "", ""}
				additionalOptionsRemaining = 1
				Program.redraw(true)
			else
				Program.changeScreenView(TrackerScreen)
				if currentRoguemonScreen == OptionSelectionScreen then
					currentRoguemonScreen = SpecialRedeemScreen
				end
			end
		end
	end

	-- CURSE RELATED FUNCTIONS -- 

	function self.determineCurses()
		local curseCount = RoguemonOptions["Ascension 2+"] and 5 or 1
		local availableCurses = {}
		for c,d in pairs(curseInfo) do
			availableCurses[#availableCurses + 1] = c
		end
		local added = 0
		while added < curseCount do
			local seg = segmentOrder[math.random(#segmentOrder)]
			if segments[seg]["cursable"] and not cursedSegments[seg] then
				local curseIndex = math.random(#availableCurses)
				while segments[seg]["bannedCurses"] and segments[seg]["bannedCurses"][availableCurses[curseIndex]] do
					curseIndex = math.random(#availableCurses)
				end
				cursedSegments[seg] = table.remove(availableCurses, curseIndex)
				added = added + 1
			end
		end
		for _,seg in ipairs(segmentOrder) do
			if cursedSegments[seg] then
				cursedSegments[#cursedSegments + 1] = seg
			end
		end
	end

	function self.getActiveCurse()
		if segmentStarted then
			return cursedSegments[segmentOrder[currentSegment]]
		end
	end

	function self.applyStatus(index, bitPattern, useStatus3)
		local address = useStatus3 and (GameSettings.gStatuses3 + index * BattleDetailsScreen.Addresses.sizeofStatus3) or
		(GameSettings.gBattleMons + index * Program.Addresses.sizeofBattlePokemon + BattleDetailsScreen.Addresses.offsetBattleMonsStatus2)
		local statusData = Memory.readdword(address)
		statusData = Utils.bit_or(statusData, bitPattern)
		Memory.writedword(address, statusData)
	end

	function self.removeStatus(index, bitPattern, useStatus3)
		local address = useStatus3 and (GameSettings.gStatuses3 + index * BattleDetailsScreen.Addresses.sizeofStatus3) or
		(GameSettings.gBattleMons + index * Program.Addresses.sizeofBattlePokemon + BattleDetailsScreen.Addresses.offsetBattleMonsStatus2)
		local statusData = Memory.readdword(address)
		statusData = Utils.bit_and(statusData, bitPattern)
		Memory.writedword(address, statusData)
	end

	function self.applyStatusToTeam(ownSide, bitPattern, useStatus3)
		local baseIndex = ownSide and 0 or 1
		self.applyStatus(baseIndex, bitPattern, useStatus3)
		if Battle.numBattlers == 4 then
			self.applyStatus(baseIndex + 2, bitPattern, useStatus3)
		end
	end

	function self.applyStatusToSide(ownSide, bitPattern, structIndex, value)
		local index = ownSide and 0 or 1
		local sideStatusesAddress = GameSettings.gSideStatuses + (index * BattleDetailsScreen.Addresses.sizeofSideStatuses)
		local sideStatuses = Memory.readword(sideStatusesAddress)
		sideStatuses = Utils.bit_or(sideStatuses, bitPattern)
		Memory.writeword(sideStatusesAddress, sideStatuses)

		local sideTimersBaseAddress = GameSettings.gSideTimers + (index * BattleDetailsScreen.Addresses.sizeofSideTimers)
		Memory.writebyte(sideTimersBaseAddress + structIndex, value)
	end

	function self.setDisableStructByte(index, structIndex, value)
		local disableStructBase = GameSettings.gDisableStructs + (index * BattleDetailsScreen.Addresses.sizeofDisableStruct)
		Memory.writebyte(disableStructBase + structIndex, value)
	end

	function self.setDisableStructWord(index, structIndex, value)
		local disableStructBase = GameSettings.gDisableStructs + (index * BattleDetailsScreen.Addresses.sizeofDisableStruct)
		Memory.writeword(disableStructBase + structIndex, value)
	end

	function self.setWeather(bitValue, turns)
		Memory.writebyte(GameSettings.gBattleWeather, bitValue)
		if turns then
			Memory.writebyte(GameSettings.gWishFutureKnock + 0x28, turns)
		end
	end

	function self.setStatStageOnTeam(ownSide, stat, stage)
		local baseIndex = ownSide and 0 or 1
		self.setStatStage(baseIndex, stat, stage)
		if Battle.numBattlers == 4 then
			self.setStatStage(baseIndex + 2, stat, stage)
		end
	end

	function self.setStatStage(index, stat, stage)
		local startAddress = GameSettings.gBattleMons + Program.Addresses.sizeofBattlePokemon*index
		local statStageOffset = Program.Addresses.offsetBattlePokemonStatStages
		local hp_atk_def_speed = Memory.readdword(startAddress + statStageOffset)
		local spatk_spdef_acc_evasion = Memory.readdword(startAddress + statStageOffset + 4)
	
		local statStages = {
			["hp"] = Utils.getbits(hp_atk_def_speed, 0, 8),
			["atk"] = Utils.getbits(hp_atk_def_speed, 8, 8),
			["def"] = Utils.getbits(hp_atk_def_speed, 16, 8),
			["spa"] = Utils.getbits(spatk_spdef_acc_evasion, 0, 8),
			["spd"] = Utils.getbits(spatk_spdef_acc_evasion, 8, 8),
			["spe"] = Utils.getbits(hp_atk_def_speed, 24, 8),
			["acc"] = Utils.getbits(spatk_spdef_acc_evasion, 16, 8),
			["eva"] = Utils.getbits(spatk_spdef_acc_evasion, 24, 8),
		}

		statStages[stat] = stage

		hp_atk_def_speed = statStages["hp"] + Utils.bit_lshift(statStages["atk"], 8)  + Utils.bit_lshift(statStages["def"], 16) + Utils.bit_lshift(statStages["spe"], 24)
		spatk_spdef_acc_evasion = statStages["spa"] + Utils.bit_lshift(statStages["spd"], 8)  + Utils.bit_lshift(statStages["acc"], 16) + Utils.bit_lshift(statStages["eva"], 24)
		Memory.writedword(startAddress + statStageOffset, hp_atk_def_speed)
		Memory.writedword(startAddress + statStageOffset + 4, spatk_spdef_acc_evasion)
	end

	function self.getStatStage(index, stat)
		local startAddress = GameSettings.gBattleMons + Program.Addresses.sizeofBattlePokemon*index
		local statStageOffset = Program.Addresses.offsetBattlePokemonStatStages
		local hp_atk_def_speed = Memory.readdword(startAddress + statStageOffset)
		local spatk_spdef_acc_evasion = Memory.readdword(startAddress + statStageOffset + 4)
	
		local statStages = {
			["hp"] = Utils.getbits(hp_atk_def_speed, 0, 8),
			["atk"] = Utils.getbits(hp_atk_def_speed, 8, 8),
			["def"] = Utils.getbits(hp_atk_def_speed, 16, 8),
			["spa"] = Utils.getbits(spatk_spdef_acc_evasion, 0, 8),
			["spd"] = Utils.getbits(spatk_spdef_acc_evasion, 8, 8),
			["spe"] = Utils.getbits(hp_atk_def_speed, 24, 8),
			["acc"] = Utils.getbits(spatk_spdef_acc_evasion, 16, 8),
			["eva"] = Utils.getbits(spatk_spdef_acc_evasion, 24, 8),
		}

		return statStages[stat]
	end

	function self.getLastAttackDamage()
		-- attackerValue = 0 or 2 for player mons and 1 or 3 for enemy mons (2,3 are doubles partners)
		self.attacker = Memory.readbyte(GameSettings.gBattlerAttacker)
	
		local currentTurn = Memory.readbyte(GameSettings.gBattleResults + Program.Addresses.offsetBattleResultsCurrentTurn)
		local currDamageTotal = Memory.readword(GameSettings.gTakenDmg)
	
		-- As a new turn starts, note the previous amount of total damage, reset turn counters
		if currentTurn ~= self.turnCount then
			self.turnCount = currentTurn
			self.prevDamageTotal = currDamageTotal
			if self.turnCount > 0 then
				lastAttackDamage = self.damageReceived or 0
			end
			self.damageReceived = 0
		end
	
		self.damageDelta = currDamageTotal - self.prevDamageTotal
		if self.damageDelta ~= 0 then
			-- Check current and previous attackers to see if enemy attacked within the last 30 frames
			if self.attacker % 2 ~= 0 then
				local enemyMoveId = Memory.readword(GameSettings.gBattleResults + Program.Addresses.offsetBattleResultsEnemyMoveId)
				if enemyMoveId ~= 0 then
					-- If a new move is being used, reset the damage from the last move
					if not self.enemyHasAttacked then
						self.damageReceived = 0
						self.enemyHasAttacked = true
					end
					self.damageReceived = self.damageReceived + self.damageDelta
					self.prevDamageTotal = currDamageTotal
				end
			else
				self.prevDamageTotal = currDamageTotal
			end
		end
	end

	function self.startOfBattleCurse(curse)
		if curse == "Tormented Soul" then
			self.applyStatusToTeam(true, 0x80000000)
		end
		if curse == "Clean Air" then
			self.applyStatusToSide(false, 0x0020, 6, 0xFF)
			self.applyStatusToSide(false, 0x0100, 4, 0xFF)
		end
		if curse == "Acid Rain" then
			local weathers = {
				{0x04, nil, "Rain"}, -- Permanent rain
				{0x10, nil, "Sandstorm"}, -- Permanent sand
				{0x40, nil, "Sun"}, -- Permanent sun
				{0x80, 0xFF, "Hail"} -- Hail for 255 turns (permanent hail is not possible in gen 3)			
			}
			local rando = math.random(#weathers)
			self.setWeather(weathers[rando][1], weathers[rando][2])
			weatherApplied = weathers[rando][3]
		end
		if curse == "Chameleon" then
			local types = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12}
			local type1 = types[math.random(#types)]
			local type2 = type1
			if math.random(4) ~= 1 then
				type2 = types[math.random(#types)]
			end
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes, type1)
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + 1, type2)
		end
		if curse == "Headwind" then
			self.setStatStageOnTeam(true, "spe", 5)
		end
		if curse == "1000 Cuts" then
			Program.addFrameCounter("Last Attack Damage", 10, self.getLastAttackDamage)
		end
		if curse == "Clouded Instincts" then
			local pkmn = self.readLeadPokemonData()
			local pps = {Utils.getbits(pkmn.attack3, 0, 8), Utils.getbits(pkmn.attack3, 8, 8), Utils.getbits(pkmn.attack3, 16, 8), Utils.getbits(pkmn.attack3, 24, 8)}
			local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
			for i = 1,4 do
				if pps[i] > 0 then
					self.setDisableStructWord(0, 0x06, moves[i])
					self.setDisableStructWord(0, 0x0C, i-1)
					self.setDisableStructWord(0, 0x0E, 1)
					self.setDisableStructWord(0, 0x0F, 1)
					break
				end
			end
		end
		if curse == "Unruly Spirit" then
			if math.random(10) <= 1 then
				unrulySpiritFirstTurn = true
			end
		end
	end

	function self.endOfBattleCurse(curse)
		if curse == "1000 Cuts" then
			if self.damageReceived > 0 then
				hpCapModifier = hpCapModifier - 5
				hpCap = hpCap - 5
				self.damageReceived = 0
			end
			Program.removeFrameCounter("Last Attack Damage")
		end
		if curse == "Narcolepsy" then
			local startAddress = GameSettings.pstats
			local status_aux = Memory.readdword(startAddress + Program.Addresses.offsetPokemonStatus)
			if math.random(10) <= 3 then
				local sleepTurns = math.random(4)
				Memory.writedword(startAddress + Program.Addresses.offsetPokemonStatus, sleepTurns)
			end
		end
		if curse == "Unruly Spirit" then
			unrulySpiritFirstTurn = false
		end
		if curse == "Unruly Spirit" or curse == "Unstable Ground" then
			flinchCheckFirstTurn = false
		end
	end

	function self.ongoingCurse(curse)
		if curse == "Sharp Rocks" then
			self.applyStatusToTeam(false, 0x00100000)
		end
		if curse == "Heavy Fog" then
			for i = 1, Battle.numBattlers do
				if self.getStatStage(i-1, "acc") > 5 then
					self.setStatStage(i-1, "acc", 5)
				end
			end
		end
		if curse == "Unruly Spirit" then
			if Battle.turnCount == 0 and unrulySpiritFirstTurn then
				self.applyStatusToTeam(true, 0x00000008)
			end
		end
		if curse == "Unstable Ground" then
			if Battle.turnCount == 0 then
				self.applyStatusToTeam(true, 0x00000008)
			end
		end
		if curse == "Unruly Spirit" or curse == "Unstable Ground" then
			if Battle.turnCount == 1 and not flinchCheckFirstTurn then
				flinchCheckFirstTurn = true
				self.removeStatus(0, 0xFFFFFFF7)
			end
		end
	end

	function self.everyTurnCurse(curse)
		if curse == "1000 Cuts" and inBattleTurnCount > 0 then
			if lastAttackDamage > 0 then
				hpCapModifier = hpCapModifier - 5
				hpCap = hpCap - 5
			end
		end
		if curse == "Unruly Spirit" then
			if math.random(10) == 1 then
				self.applyStatusToTeam(true, 0x00000008)
			end
		end
		if curse == "No Cover" then
			self.applyStatus(0, 0x00000018, true)
			self.setDisableStructWord(0, 0x15, 1)
		end
	end

	-- DISPLAY/NOTIFICATION FUNCTIONS -- 

	local screenPriorities = {
		[SpecialRedeemScreen] = 1,
		[OptionSelectionScreen] = 2,
		[RewardScreen] = 3
	}
	function self.setCurrentRoguemonScreen(newScreen)
		if screenPriorities[newScreen] > screenPriorities[currentRoguemonScreen] then
			currentRoguemonScreen = newScreen
		end
	end

	local gymMapIds = {
		[12] = true, -- Cerulean
		[15] = true, -- Celadon
		[20] = true, -- Fuchsia
		[25] = true, -- Vermilion
		[28] = true, -- Pewter
		[34] = true, -- Saffron
		[36] = true, -- Cinnabar
		[37] = true  -- Viridian
	}

	-- Buy phase notification followed by cleansing phase notification, once the player leaves the gym
	function self.handleBuyCleanseNotifs(mapId)
		if Program.currentScreen == TrackerScreen then
			if needToBuy then
				if not gymMapIds[mapId] then
					needToBuy = false
					self.buyPhase()
				end
			elseif needToCleanse then
				needToCleanse = false
				self.cleansingPhase()
			end
		end
	end

	-- Draw special redeem images on the main screen.
	function self.redrawScreenImages()
		if not Battle.inBattle and RoguemonOptions["Display prizes on screen"] then
			--local dx = 180 - (#specialRedeems.unlocks + #specialRedeems.consumable)*30 - use this for top right display
			local dx = 0
			local dy = 0
			local imageSize = 32
			local imageGap = 30
			if RoguemonOptions["Display small prizes"] then
				imageSize = 20
				imageGap = 18
			end
			local screen = Program.currentScreen
			if screen ~= StartupScreen then
				for _,r in ipairs(specialRedeems.unlocks) do
					local imageButton = {
						type = Constants.ButtonTypes.IMAGE,
						box = {dx*imageGap, dy, imageSize, imageSize},
						onClick = function()
							specialRedeemToDescribe = r
							Program.changeScreenView(SpecialRedeemScreen)
						end
					}
					Drawing.drawImage(IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx*imageGap, dy, imageSize, imageSize)
					if screen.Buttons then
						screen.Buttons["RoguemonPrize" .. dx] = imageButton
					end
					dx = dx + 1
				end
				for _,r in ipairs(specialRedeems.consumable) do
					local imageButton = {
						type = Constants.ButtonTypes.IMAGE,
						box = {dx*imageGap, dy, imageSize, imageSize},
						onClick = function()
							specialRedeemToDescribe = r
							Program.changeScreenView(SpecialRedeemScreen)
						end
					}
					Drawing.drawImage(IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx*imageGap, dy, imageSize, imageSize)
					if screen.Buttons then
						screen.Buttons["RoguemonPrize" .. dx] = imageButton
					end
					if r == "Fight wilds in Rts 1/2/22" or r == "Fight up to 5 random wilds" then
						Drawing.drawText(dx*imageGap + imageSize - 7, dy + imageSize - 7, wildBattleCounter, Drawing.Colors.BLACK)
					end
					dx = dx + 1
				end
			end
			while dx < 8 do
				screen.Buttons["RoguemonPrize" .. dx] = nil
				dx = dx + 1
			end
		end
	end
	
	-- Count status heals, taking Berry Pouch into account.
	function self.countStatusHeals()
		local statusBerries = {133, 134, 135, 136, 137, 140, 141}
		local statusHealsInBagCount = 0
		for id,ct in pairs(Program.GameData.Items.StatusHeals) do
			if(ct <= 999) then
				if not (specialRedeems.unlocks["Berry Pouch"] and self.contains(statusBerries, id)) then
					statusHealsInBagCount = statusHealsInBagCount + ct
				end
			end
		end
		return statusHealsInBagCount
	end

	-- Count heals, ignoring the Luck Incense item
	function self.countAdjustedHeals()
		Program.updateBagItems()
		local leadPokemon = Tracker.getPokemon(1)
		local maxHP = leadPokemon and leadPokemon.stats and leadPokemon.stats.hp or 0
		if maxHP == 0 then
			return
		end
	
		local healingTotal = 0
		local healingPercentage = 0
		local healingValue = 0
	
		for itemID, quantity in pairs(Program.GameData.Items.HPHeals or {}) do
			-- An arbitrary max value to prevent erroneous game data reads
			if quantity >= 0 and quantity <= 999 then
				if(specialRedeems.consumable["luckIncenseItem"] and specialRedeems.consumable["luckIncenseItem"] == TrackerAPI.getItemName(itemID, true)) then
					quantity = quantity - 1
				end
				local healItemData = MiscData.HealingItems[itemID] or {}
				local percentageAmt = 0
				if healItemData.type == MiscData.HealingType.Constant then
					-- Healing is in a percentage compared to the mon's max HP
					percentageAmt = quantity * math.min(healItemData.amount / maxHP * 100, 100) -- max of 100
				elseif healItemData.type == MiscData.HealingType.Percentage then
					percentageAmt = quantity * healItemData.amount
				end
				healingTotal = healingTotal + quantity
				healingPercentage = healingPercentage + percentageAmt
				healingValue = healingValue + math.floor(percentageAmt * maxHP / 100 + 0.5)
			end
		end

		adjustedHPVal = healingValue
		return healingTotal, healingPercentage, healingValue
	end

	-- Draw caps at a particular x,y
	function self.drawCapsAt(data, x, y)
		local shadowcolor = Utils.calcShadowColor(Theme.COLORS["Upper box background"])
		-- these don't count as status heals if Berry Pouch is active
		local statusHealsInBagCount = self.countStatusHeals()

		local healsTextColor = data.x.healvalue > hpCap and Theme.COLORS["Negative text"] or Theme.COLORS["Default text"]
		if specialRedeems.consumable["luckIncenseItem"] then
			self.countAdjustedHeals()
			if adjustedHPVal <= hpCap then
				healsTextColor = Theme.COLORS["Default text"]
			end
		end
		
		local healsValueText
		if Options["Show heals as whole number"] then
			healsValueText = string.format("%.0f/%.0f %s (%s)", data.x.healvalue, hpCap, Resources.TrackerScreen.HPAbbreviation, data.x.healnum)
		else
			healsValueText = string.format("%.0f%%/%.0f %s (%s)", data.x.healperc, hpCap, Resources.TrackerScreen.HPAbbreviation, data.x.healnum)
		end
		Drawing.drawText(x, y, healsValueText, healsTextColor, shadowcolor)
		currentHPVal = data.x.healvalue

		local statusHealsTextColor = statusHealsInBagCount > statusCap and Theme.COLORS["Negative text"] or Theme.COLORS["Default text"]
		local statusHealsValueText = string.format("%.0f/%.0f %s", statusHealsInBagCount, statusCap, "Status")
		Drawing.drawText(x, y + 11, statusHealsValueText, statusHealsTextColor, shadowcolor)
		currentStatusVal = statusHealsInBagCount
	end

	function self.drawCapsAndRoguemonMenu()
		local data = DataHelper.buildTrackerScreenDisplay()
		if Program.currentScreen == TrackerScreen and Battle.isViewingOwn and data.p.id ~= 0 then
			gui.drawRectangle(Constants.SCREEN.WIDTH + 6, 58, 94, 21, Theme.COLORS["Lower box background"], Theme.COLORS["Lower box background"])
			self.drawCapsAt(data, Constants.SCREEN.WIDTH + 6, 57)
			TrackerScreen.Buttons.RogueMenuButton.textColor = (currentRoguemonScreen == SpecialRedeemScreen) and Theme.COLORS["Intermediate text"] or Theme.COLORS["Negative text"]
			Drawing.drawButton(TrackerScreen.Buttons.RogueMenuButton)
			Drawing.drawButton(TrackerScreen.Buttons.CurseMenuButton)
			if DEBUG_MODE then
				Drawing.drawButton(TrackerScreen.Buttons.DebugButton)
			end
		end
	end

	-- Save roguemon data to file
	function self.saveData()
		local saveData = {
			['seed'] = seedNumber,
			['romHash'] = GameSettings.getRomHash(),
			['segmentOrder'] = segmentOrder,
			['defeatedTrainerIds'] = defeatedTrainerIds,
			['currentSegment'] = currentSegment,
			['segmentStarted'] = segmentStarted,
			['trainersDefeated'] = trainersDefeated,
			['mandatoriesDefeated'] = mandatoriesDefeated,
			['hpCap'] = hpCap,
			['statusCap'] = statusCap,
			['hpCapModifier'] = hpCapModifier,
			['statusCapModifier'] = statusCapModifier,
			['lastMilestone'] = lastMilestone,
			['milestoneProgress'] = milestoneProgress,
			['specialRedeems'] = specialRedeems,
			['offeredMoonStoneFirst'] = offeredMoonStoneFirst,
			['cursedSegments'] = cursedSegments,
			['unlockedHeldItems'] = unlockedHeldItems,
			['downsized'] = downsized,
			['stepCounter'] = stepCounter,
			['previousTheme'] = previousTheme
		}

		if not DEBUG_MODE then
			FileManager.writeTableToFile(saveData, SAVED_DATA_PATH .. QuickloadScreen.getActiveProfile().Name .. ".tdat")
		end

		FileManager.writeTableToFile(RoguemonOptions, SAVED_OPTIONS_PATH)
	end

	-- Load roguemon data from file
	function self.loadData()
		local saveData = FileManager.readTableFromFile(SAVED_DATA_PATH .. QuickloadScreen.getActiveProfile().Name .. ".tdat")
		if saveData and GameSettings.getRomHash() == saveData['romHash'] then
			seedNumber = saveData['seedNumber'] or self.generateSeed()
			segmentOrder = saveData['segmentOrder'] or segmentOrder
			defeatedTrainerIds = saveData['defeatedTrainerIds'] or defeatedTrainerIds
			currentSegment = saveData['currentSegment'] or currentSegment
			segmentStarted = saveData['segmentStarted'] or segmentStarted
			trainersDefeated = saveData['trainersDefeated'] or trainersDefeated
			mandatoriesDefeated = saveData['mandatoriesDefeated'] or mandatoriesDefeated
			hpCap = saveData['hpCap'] or hpCap
			statusCap = saveData['statusCap'] or statusCap
			hpCapModifier = saveData['hpCapModifier'] or hpCapModifier
			statusCapModifier = saveData['statusCapModifier'] or statusCapModifier
			lastMilestone = saveData['lastMilestone'] or lastMilestone
			milestoneProgress = saveData['milestoneProgress'] or milestoneProgress
			specialRedeems = saveData['specialRedeems'] or specialRedeems
			offeredMoonStoneFirst = saveData['offeredMoonStoneFirst'] or offeredMoonStoneFirst
			cursedSegments = saveData['cursedSegments'] or cursedSegments
			unlockedHeldItems = saveData['unlockedHeldItems'] or unlockedHeldItems
			downsized = saveData['downsized'] or downsized
			stepCounter = saveData['stepCounter'] or stepCounter
			previousTheme = saveData['previousTheme'] or Theme.exportThemeToText()
		end
		if seedNumber == -1 then
			seedNumber = self.generateSeed()
		end
		math.randomseed(seedNumber)

		RoguemonOptions = {}
		for _,o in pairs(optionsList) do
			RoguemonOptions[o.text] = o.default
		end

		local readOptions = FileManager.readTableFromFile(SAVED_OPTIONS_PATH)
		if readOptions then
			for k,v in pairs(readOptions) do
				RoguemonOptions[k] = v
			end
		end
	end

	-- EXTENSION FUNCTIONS --

	function self.afterBattleEnds()
		if TrackerAPI.getBattleOutcome() == 2 then
			-- We lost :(
			return
		end
		-- Determine if we have just defeated a trainer
		local trainerId = Memory.readword(GameSettings.gTrainerBattleOpponent_A)
		if defeatedTrainerIds[trainerId] then
			-- Fought a wild
			if TrackerAPI.getBattleOutcome() == 1 or (wildBattlesStarted and TrackerAPI.getBattleOutcome() == 4) then
				-- Defeated/ran from a wild
				if wildBattleCounter > 0 then
					wildBattlesStarted = true
					wildBattleCounter = wildBattleCounter - 1
					if wildBattleCounter <= 0 then
						self.removeSpecialRedeem("Fight wilds in Rts 1/2/22")
						self.removeSpecialRedeem("Fight up to 5 random wilds")
					end
				end
			end
			return
		else
			defeatedTrainerIds[trainerId] = true
		end

		-- Check bag updates before doing anything else
		self.checkBagUpdates()

		local curse = self.getActiveCurse()
		if curse then
			self.endOfBattleCurse(curse)
		end

		-- Checks for special redeems after gym leaders specifically
		if (gymLeaders[trainerId]) then
			self.removeSpecialRedeem("Temporary Item Voucher")
			self.removeSpecialRedeem("Temporary TM Voucher")
			local pv = specialRedeems.consumable["Potion Investment"]
			if pv then specialRedeems.consumable["Potion Investment"] = pv * 2 end
		end

		-- Add 4 potions after rival 1
		if trainerId >= 326 and trainerId <= 328 then
			self.AddItemImproved("Potion", 4)
			self.AddItemImproved("Lucky Egg", 1)
			if RoguemonOptions["Show reminders"] then
				self.displayNotification("4 Potions and a nice egg have been added to your bag", "4potegg.png", nil)
			end
		end

		-- Check if trainer was part of a milestone
		if milestoneTrainers[trainerId] then
			local milestoneName = milestoneTrainers[trainerId]['name']
			if milestoneProgress[milestoneName] then
				milestoneProgress[milestoneName] = milestoneProgress[milestoneName] + 1
			else
				milestoneProgress[milestoneName] = 1
			end
			if milestoneProgress[milestoneName] == milestoneTrainers[trainerId]['count'] then
				self.spinReward(milestoneName, false)
			end
		end

		if segmentOrder[currentSegment + 1] then
			for _,t in pairs(segments[segmentOrder[currentSegment + 1]]["trainers"]) do
				if t == trainerId then
					self.nextSegment()
					break
				end
			end
		end

		-- Check if trainer was part of the current segment
		local segInfo = segments[segmentOrder[currentSegment]]
		for _,t in pairs(segInfo["mandatory"]) do
			if t == trainerId then
				if not (segInfo["pairs"] and defeatedTrainerIds[segInfo["pairs"][trainerId]]) then
					mandatoriesDefeated = mandatoriesDefeated + 1
				end
			end
		end
		for _,t in pairs(segInfo["trainers"]) do
			if t == trainerId then
				if not segmentStarted then
					self.startSegment()
				end
				trainersDefeated = trainersDefeated + 1
				if trainersDefeated >= self.getSegmentTrainerCount(currentSegment) then
					self.nextSegment()
				end
			end
		end
	end

	
	self.configureOptions = function()
		Program.changeScreenView(OptionsScreen)
	end
	

	function self.startup()
		-- Read & populate configuration info
		self.readConfig()
		self.populateSegmentData()

		itemsPocket = {}
		berryPocket = {}

		-- Add the segment & curse carousel item
		self.SEGMENT_CAROUSEL_INDEX = #TrackerScreen.CarouselTypes + 1
		TrackerScreen.CarouselItems[self.SEGMENT_CAROUSEL_INDEX] = {
			type = self.SEGMENT_CAROUSEL_INDEX,
			framesToShow = 240,
			canShow = function(this)
				return true
			end,
			getContentList = function(this)
				if segmentStarted then
					local text = segmentOrder[currentSegment] .. ": " .. mandatoriesDefeated .. "/" .. self.getSegmentMandatoryCount(currentSegment) .. " mandatory, " .. 
					trainersDefeated .. "/" .. self.getSegmentTrainerCount(currentSegment) .. " total"
					if milestoneTrainers[segmentOrder[currentSegment]] then
						text = text .. " (Full Clear = Prize)"
					end
					return Main.IsOnBizhawk() and { text } or text
				else
					local text = 'Next Segment: ' .. segmentOrder[currentSegment]
					if segmentOrder[currentSegment] == "Congratulations!" then
						text = "Congratulations!"
					end
					return Main.IsOnBizhawk() and { text } or text
				end
			end,
		}

		self.CURSE_CAROUSEL_INDEX = #TrackerScreen.CarouselTypes + 2
		TrackerScreen.CarouselItems[self.CURSE_CAROUSEL_INDEX] = {
			type = self.CURSE_CAROUSEL_INDEX,
			framesToShow = 240,
			canShow = function(this)
				return segmentStarted and self.getActiveCurse()
			end,
			getContentList = function(this)
				local curse = self.getActiveCurse()
				local text = "> " .. curse .. ": " .. curseInfo[curse].description
				if curse == "Acid Rain" and weatherApplied then
					text = text .. " (" .. weatherApplied .. ")"
				end
				return Main.IsOnBizhawk() and { text } or text
			end,
		}

		Constants.PixelImages.SKULL = {
			{1,1,1,1,1,1,1,1,1},
			{1,0,0,0,0,0,0,0,1},
			{1,0,0,0,0,0,0,0,1},
			{1,0,0,1,1,1,0,0,1},
			{1,0,1,1,1,1,1,0,1},
			{1,0,1,0,1,0,1,0,1},
			{1,0,1,1,1,1,1,0,1},
			{1,0,0,1,0,1,0,0,1},
			{1,0,0,1,0,1,0,0,1},
			{1,0,0,0,0,0,0,0,1},
			{1,0,0,0,0,0,0,0,1},
			{1,0,0,0,0,0,0,0,1},
			{1,1,1,1,1,1,1,1,1},
		}

		-- Add the buttons to access the Roguemon screens
		TrackerScreen.Buttons.RogueMenuButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "!" end,
			box = { Constants.SCREEN.WIDTH + 90, 59, 6, 12},
			onClick = function()
				specialRedeemToDescribe = nil
				Program.changeScreenView(currentRoguemonScreen)
			end,
			isVisible = function()
				return Program.currentScreen == TrackerScreen and Battle.isViewingOwn
			end,
			textColor = Theme.COLORS["Intermediate text"],
			boxColors = {Theme.COLORS["Default text"]}
		}

		TrackerScreen.Buttons.CurseMenuButton = {
			type = Constants.ButtonTypes.PIXELIMAGE,
			image = Constants.PixelImages.SKULL,
			box = { Constants.SCREEN.WIDTH + 80, 59, 7, 12},
			onClick = function()
				local curseInfoText = "Cursed Segments: @ "
				for _,seg in ipairs(cursedSegments) do
					if not (self.reachedSegment(seg) and not (segmentOrder[currentSegment] == seg)) then
						curseInfoText = curseInfoText .. seg .. " @ "
					end
				end
				self.displayNotification(curseInfoText, "Curse.png", nil)
			end,
			isVisible = function()
				return Program.currentScreen == TrackerScreen and Battle.isViewingOwn
			end
		}

		-- this button is only for debugging
		if DEBUG_MODE then
			TrackerScreen.Buttons.DebugButton = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() return ":" end,
				box = { Constants.SCREEN.WIDTH + 72, 59, 6, 12},
				onClick = function()
					Program.changeScreenView(RewardScreen)
				end,
				textColor = Drawing.Colors.GREEN,
				boxColors = {Drawing.Colors.GREEN}
			}
		end

		currentRoguemonScreen = SpecialRedeemScreen

		-- Load data from file if it exists
		self.loadData()

		local curse = self.getActiveCurse()
		if curse then
			if RoguemonOptions["Alternate Curse theme"] then
				previousTheme = Theme.exportThemeToText()
				Theme.importThemeFromText(CURSE_THEME, true)
			end
		end

		-- Set up a frame counter for using the "Next" button (R by default) to dismiss notifications
		Program.addFrameCounter("Roguemon Notification Input Check", 1, function()
			if Program.currentScreen == NotificationScreen then
				local joypad = Input.getJoypadInputFormatted()
				CustomCode.inputCheckMGBA()
				local nextBtn = Options.CONTROLS["Next page"] or ""
				if joypad[nextBtn] then
					Program.changeScreenView(TrackerScreen)
				end
			end
		end, nil, true)

		-- Set up a frame counter to save the roguemon data every 30 seconds
		Program.addFrameCounter("Roguemon Saving", 1800, self.saveData, nil, true)

		-- Add a setting so Roguemon seeds default to being over when the entire party faints
		QuickloadScreen.SettingsKeywordToGameOverMap["Ascension"] = "EntirePartyFaints"
	end

	function self.unload()
		if curse and RoguemonOptions["Alternate Curse theme"] then
			Theme.importThemeFromText(previousTheme, true)
		end
		TrackerScreen.CarouselItems[self.SEGMENT_CAROUSEL_INDEX] = nil
		TrackerScreen.Buttons.RogueMenuButton = nil
		TrackerScreen.Buttons.CurseMenuButton = nil
		Program.removeFrameCounter("Roguemon Saving")
		Program.removeFrameCounter("Roguemon Notification Input Check")
		QuickloadScreen.SettingsKeywordToGameOverMap["Roguemon"] = nil
	end

	function self.afterRedraw()
		self.redrawScreenImages()
		self.drawCapsAndRoguemonMenu()
	end

	function self.afterProgramDataUpdate()
		-- Check what map we're on
		local mapId = TrackerAPI.getMapId()
		-- Check if there's a milestone for just being on this map
		if(milestoneAreas[mapId]) then
			if not milestoneProgress[mapId] then
				milestoneProgress[mapId] = 1
				self.spinReward(milestoneAreas[mapId]['name'], false)
			end
		end
		-- Check if we stepped onto the route for the segment we're supposed to do next
		if not segmentStarted then
			for _,r in pairs(segments[segmentOrder[currentSegment]]["routes"]) do
				if mapId == r then
					self.startSegment()
				end
			end
		end
		-- Check if a pokemon has been caught (for determining if the player has committed)
		if not caughtSomethingYet and #Program.GameData.PlayerTeam > 1 then
			caughtSomethingYet = true
		end
		-- Check if the player has previously caught something but deposited down to 1
		if not committed and caughtSomethingYet and #Program.GameData.PlayerTeam == 1 and mapId ~= 8 then
			committed = true
		end
		-- Check if we have fought a trainer in Viridian Forest
		if not committed and (defeatedTrainerIds[102] or defeatedTrainerIds[103] or defeatedTrainerIds[104] or 
		defeatedTrainerIds[531] or defeatedTrainerIds[532]) then
			committed = true
		end
		-- Check if we are in a Pokemon Center/Pokemon League with full HP when all mandatory trainers in the current segment are defeated.
		-- If so, the segment is assumed to be finished.
		local pokemon = TrackerAPI.getPlayerPokemon()
		if pokemon and pokemon.curHP == pokemon.stats.hp and (mapId == 8 or mapId == 212) and segmentStarted and mandatoriesDefeated >= self.getSegmentMandatoryCount(currentSegment) then
			self.nextSegment()
		end
		-- Check if we have entered Celadon for the first time with a pokemon that can evolve with a moon stone.
		if offeredMoonStoneFirst == 0 and mapId == 84 and PokemonData.Pokemon[pokemon.pokemonID].evolution.detailed and self.contains(PokemonData.Pokemon[pokemon.pokemonID].evolution.detailed, "RogueStone") then
			offeredMoonStoneFirst = 1
			-- Set up the options to offer the trade
			self.offerBinaryOption("RogueStone (-100 HP Cap)", "Skip")
		end
		-- Check if we are in Celadon City with Hideout completed with a pokemon that can evolve with a moon stone.
		if offeredMoonStoneFirst < 2 and mapId == 84 and defeatedTrainerIds[348] and PokemonData.Pokemon[pokemon.pokemonID].evolution.detailed and self.contains(PokemonData.Pokemon[pokemon.pokemonID].evolution.detailed, "RogueStone") then
			offeredMoonStoneFirst = 2
			-- Give it for free
			self.AddItemImproved("Moon Stone", 1)
			self.displayNotification("A RogueStone has been added to your bag", "moon-stone.png", nil)
		end

		-- Check if NatDex is loaded and we haven't yet changed everything's evo method to Rogue Stone
		if not patchedMoonStones and PokemonData.Pokemon[412] ~= nil then
			self.patchStoneEvos()
		end

		-- Check if we are in battle for curses
		local curse = self.getActiveCurse()
		if curse then
			if Battle.inBattle then
				self.ongoingCurse(curse)
				if not curseAppliedThisFight then
					curseAppliedThisFight = true
					self.startOfBattleCurse(curse)
				end
				if inBattleTurnCount ~= Battle.turnCount then
					inBattleTurnCount = Battle.turnCount
					self.everyTurnCurse(curse)
				end
			else
				weatherApplied = nil
				curseAppliedThisFight = false
				inBattleTurnCount = -1
				if curse == "Toxic Fumes" then
					local steps = Utils.getGameStat(Constants.GAME_STATS.STEPS)
					local stepDiff = (steps - stepCounter.lastCounted) % (2^32)
					stepCounter.toxicFumesCycle = stepCounter.toxicFumesCycle + stepDiff
					local hpToDeduct = math.floor(stepCounter.toxicFumesCycle / 8)
					if hpToDeduct >= 0 and hpToDeduct <= 3 then
						-- Guard against garbage/erroneous reads
						if hpToDeduct > 0 then
							stepCounter.toxicFumesCycle = stepCounter.toxicFumesCycle - 8*hpToDeduct
							local startAddress = GameSettings.pstats
							local level_and_currenthp = Memory.readdword(startAddress + Program.Addresses.offsetPokemonStatsLvCurHp)
							local levelPlusUnusedByte = Utils.getbits(level_and_currenthp, 0, 16)
							local currentHP = Utils.getbits(level_and_currenthp, 16, 16)
							currentHP = currentHP - hpToDeduct
							if currentHP < 1 then
								currentHP = 1
							end
							Memory.writedword(startAddress + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.bit_lshift(currentHP, 16) + levelPlusUnusedByte)
						end
						stepCounter.lastCounted = steps
					end
				end
			end
		end

		-- Check updates to bag items and pokemon info
		if Program.currentScreen == TrackerScreen then
			self.checkBagUpdates()
		end

		-- If the Luck Incense item is gone, then the effect is removed
		if specialRedeems.consumable["luckIncenseItem"] and not Program.GameData.Items.HPHeals[self.getItemId(specialRedeems.consumable["luckIncenseItem"])] then
			specialRedeems.consumable["luckIncenseItem"] = nil
		end

		-- Check if we have an Item Voucher and are currently holding an illegal item
		if pokemon then
			local heldItem = TrackerAPI.getItemName(pokemon.heldItem, true)
			if not Battle.inBattle and heldItem and not allowedHeldItems[heldItem] and not unlockedHeldItems[heldItem] then
				local hadV = self.removeSpecialRedeem("Temporary Item Voucher")
				if not hadV then
					hadV = self.removeSpecialRedeem("Held Item Voucher")
				end
				if hadV then
					unlockedHeldItems[heldItem] = true
				end
			end
		end

		-- Check if the notification should be dismissed
		if Program.currentScreen == NotificationScreen then
			if shouldDismissNotification and shouldDismissNotification() then
				Program.changeScreenView(TrackerScreen)
			end
		end

		-- Check if the game should be over but there's a Revive
		if Program.currentScreen == GameOverScreen and specialRedeems.consumable["Revive"] and GameOverScreen.status ~= GameOverScreen.Statuses.WON then
			self.removeSpecialRedeem("Revive")
			GameOverScreen.status = GameOverScreen.Statuses.STILL_PLAYING
			LogOverlay.isGameOver = false
			LogOverlay.isDisplayed = false
			Program.GameTimer:unpause()
			GameOverScreen.refreshButtons()
			GameOverScreen.Buttons.SaveGameFiles:reset()
			self.displayNotification("The game is not over! Use your Revive!", "revive.png", function() return self.itemNotPresent(self.getItemId("Revive")) end)
		end

		-- Display suppressed notifications from before the player has committed
		if committed and Program.currentScreen == TrackerScreen and #suppressedNotifications > 0 then
			local n = table.remove(suppressedNotifications, 1)
			self.displayNotification(n.message, n.image, n.dismissFunction)
		end

		-- if we haven't yet chosen the curses for this seed, choose them now
		if next(cursedSegments) == nil then
			self.determineCurses()
		end

		-- Display any queued screens
		if Program.currentScreen == TrackerScreen and #screenQueue > 0 then
			Program.changeScreenView(table.remove(screenQueue, 1))
		end

		self.handleBuyCleanseNotifs(mapId)

		if previousMap ~= mapId then
			if previousMap == 51 and mapId == 85 and segmentOrder[currentSegment] == "Safari Zone" then
				-- Went from Safari Gate to Fuchsia City
				self.nextSegment()
			end
			previousMap = mapId
		end
	end

	function self.checkForUpdates()
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+%.*%d*)"' -- matches "1.0" in "tag_name": "v1.0"
		local versionCheckUrl = string.format("https://api.github.com/repos/%s/releases/latest", self.github or "")
		local downloadUrl = string.format("%s/releases/latest", self.url or "")
		local compareFunc = function(a, b) return a ~= b and not Utils.isNewerVersion(a, b) end -- if current version is *older* than online version
		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, compareFunc)
		return isUpdateAvailable, downloadUrl
	end

	-- This is temporary, until Zac fixes the actual function
	TrackerScreen.drawCarouselArea = function(data)
		local shadowcolor = Utils.calcShadowColor(Theme.COLORS["Lower box background"])
	
		-- Draw the border box for the Stats area
		gui.drawRectangle(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 136, Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN), 19, Theme.COLORS["Lower box border"], Theme.COLORS["Lower box background"])
	
		local carousel = TrackerScreen.getCurrentCarouselItem()
		for _, content in pairs(carousel:getContentList(data.p.id)) do
			if content.type == Constants.ButtonTypes.IMAGE or content.type == Constants.ButtonTypes.PIXELIMAGE or content.type == Constants.ButtonTypes.FULL_BORDER then
				Drawing.drawButton(content, shadowcolor)
			elseif type(content) == "string" then
				local wrappedText = self.wrapPixelsInline(content, Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN) - 10)
				if not string.find(wrappedText, "%\n") then
					Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 140, wrappedText, Theme.COLORS["Lower box text"], shadowcolor)
				else
					Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 136, wrappedText, Theme.COLORS["Lower box text"], shadowcolor)
					gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 155, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 155, Theme.COLORS["Lower box border"])
					gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 156, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 156, Theme.COLORS["Main background"])
				end
			end
		end
	
		--work around limitation of drawText not having width limit: paint over any spillover
		local x = Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN
		local y = 137
		gui.drawLine(x, y, x, y + 14, Theme.COLORS["Lower box border"])
		gui.drawRectangle(x + 1, y, 12, 14, Theme.COLORS["Main background"], Theme.COLORS["Main background"])
	end

	return self
end
return RoguemonTracker
