local function RoguemonTracker()
    local self = {}
	self.version = "0.2"
	self.name = "Roguemon Tracker"
	self.author = "Croz & Smart"
	self.description = "Tracker extension for tracking and automating Roguemon rewards and caps."
	self.github = "something-smart/Roguemon-IronmonExtension"
	self.url = string.format("https://github.com/%s", self.github or "")

	-- STATIC OR READ IN AT LOAD TIME:

	local CONFIG_FILE_PATH = "extensions/roguemon_config.txt"
	local SAVED_DATA_PATH = "extensions/roguemon_data.tdat"
	local IMAGES_DIRECTORY = "extensions/roguemon_images/"

	local prize_images = {}

	local specialRedeemInfo = {
		["Luck Incense"] = {consumable = true, image = "luck.png", description = "You may keep one HP heal that exceeds your cap until you can add it."},
		["Reroll Chip"] = {consumable = true, image = "rerollchip.png", description = "May be used to reroll any reward spin once."},
		["Duplicator"] = {consumable = true, image = "duplicator.png", description = "Purchase a copy of one HP/status heal found (immediate choice; must be shop available)."},
		["Temporary TM Voucher"] = {consumable = true, image = "tempvoucher.png", description = "Teach one ground TM found before the next badge (immediate choice)."},
		["Potion Investment"] = {consumable = true, image = "diamond.png", description = "Store Potion in PC; x2 value each badge. Withdraw to buy a heal up to its value in Buy Phase. Value:"},
		["Temporary Held Item"] = {consumable = true, image = "grounditem.png", description = "Temporarily unlock an item in your bag for 1 gym badge."},
		["Flutist"] = {consumable = false, image = "flute.png", description = "You may use flutes in battle (including Poke Flute)."},
		["Berry Pouch"] = {consumable = false, image = "berry-pouch.png", description = "HP Berries may be saved instead of equipped; status berries don't count against cap."},
		["Candy Jar"] = {consumable = false, image = "candy-jar.png", description = "You may save PP Ups, PP Maxes, and Rare Candies to use at any time."},
		["Temporary Item Voucher"] = {consumable = true, image = "tempvoucher.png", description = "Permanently unlock one non-healing ground item before next gym (immediate decision)."},
		["X Factor"] = {consumable = false, image = "XFACTOR.png", description = "You may keep and use Battle Items freely."},
		["Held Item Voucher"] = {consumable = true, image = "tmvoucher.png", description = "Permanently unlock one non-healing ground item you find (immediate decision)."}
	}

	local milestoneIds = {
		["Brock"] = 414,
		["Misty"] = 415,
		["Surge"] = 416,
		["Erika"] = 417,
		["Koga"] = 418,
		["Sabrina"] = 420,
		["Blaine"] = 419,
		["Giovanni"] = 350
	}

	local gymLeaders = {[414] = true, [415] = true, [416] = true, [417] = true, [418] = true, [420] = true, [419] = true, [350] = true}

	local milestoneTrainers = {
		[326] = {["name"] = "Rival 1", ["count"] = 1},
		[327] = {["name"] = "Rival 1", ["count"] = 1},
		[328] = {["name"] = "Rival 1", ["count"] = 1},
		[414] = {["name"] = "Brock", ["count"] = 1},
		[415] = {["name"] = "Misty", ["count"] = 1},
		[416] = {["name"] = "Surge", ["count"] = 1},
		[417] = {["name"] = "Erika", ["count"] = 1},
		[418] = {["name"] = "Koga", ["count"] = 1},
		[420] = {["name"] = "Sabrina", ["count"] = 1},
		[419] = {["name"] = "Blaine", ["count"] = 1},
		[350] = {["name"] = "Giovanni", ["count"] = 1},
		[108] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[109] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[121] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[169] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[120] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[91] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[181] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[170] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[351] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[352] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[353] = {["name"] = "Mt Moon FC", ["count"] = 12},
		[354] = {["name"] = "Mt Moon FC", ["count"] = 12}
	}

	local milestoneAreas = {
		[87] = {["name"] = "Victory Road"}
	}

	local prizeAdditionalOptions = {
		["Any Status Heal"] = {"Antidote", "Parlyz Heal", "Awakening", "Burn Heal", "Ice Heal"},
		["Any Battle Item"] = {"X Attack", "X Defend", "X Special", "X Speed", "Dire Hit", "Guard Spec."},
		["Any Vitamin"] = {"Protein (Attack)", "Iron (Defense)", "Calcium (Sp. Atk)", "Zinc (Sp. Def)", "Carbos (Speed)"}
	}

	local segments = {
		["Viridian Forest"] = {["routes"] = {117}, ["mandatory"] = {104}},
		["Rival 2"] = {["routes"] = {110}, ["trainers"] = {329, 330, 331}, ["allMandatory"] = true, ["rival"] = true},
		["Brock"] = {["routes"] = {28}, ["allMandatory"] = true},
		["Route 3"] = {["routes"] = {91}, ["mandatory"] = {105, 106, 107}},
		["Mt. Moon"] = {["routes"] = {114, 116}, ["mandatory"] = {351, 170}},
		["Rival 3"] = {["routes"] = {81}, ["trainers"] = {332, 333, 334}, ["allMandatory"] = true, ["rival"] = true},
		["Route 24/25"] = {["routes"] = {112, 113}, ["mandatory"] = {110, 123, 92, 122, 144, 356, 153, 125}, ["choicePairs"] = {{182, 184}, {183, 471}}},
		["Misty"] = {["routes"] = {12}, ["allMandatory"] = true},
		["Route 6/11"] = {["routes"] = {94, 99}, ["trainers"] = {355, 111, 112, 145, 146, 151, 152, 97, 98, 99, 100, 221, 222, 258, 259, 260, 261}, ["mandatory"] = {146}},
		["Rival 4"] = {["routes"] = {119, 120, 121, 122}, ["trainers"] = {426, 427, 428}, ["allMandatory"] = true, ["rival"] = true},
		["Lt. Surge"] = {["routes"] = {25}, ["allMandatory"] = true},
		["Route 9/10 N"] = {["routes"] = {97, 98}, ["trainers"] = {114, 115, 148, 149, 154, 155, 185, 186, 465, 156}, ["mandatory"] = {154, 115}},
		["Rock Tunnel/Rt 10 S"] = {["routes"] = {154, 155}, ["trainers"] = {192, 193, 194, 168, 476, 475, 474, 158, 159, 189, 190, 191, 164, 165, 166, 157, 163, 187, 188}, ["mandatory"] = {168, 166, 159, 158, 189, 474}, ["choicePairs"] = {{191, 190}, {192, 193}}},
		["Rival 5"] = {["routes"] = {161, 162}, ["trainers"] = {429, 430, 431}, ["allMandatory"] = true, ["rival"] = true},
		["Route 8"] = {["routes"] = {96}, ["choicePairs"] = {{131, 264}}},
		["Erika"] = {["routes"] = {15}, ["allMandatory"] = true},
		["Game Corner"] = {["routes"] = {27, 128, 129, 130, 131}, ["mandatory"] = {357, 368, 366, 367, 348}},
		["Pokemon Tower"] = {["routes"] = {161, 163, 164, 165, 166, 167}, ["mandatory"] = {447, 453, 452, 369, 370, 371}},
		["Cycling Rd/Rt 18/19"] = {["routes"] = {105, 106, 107}},
		["Koga"] = {["routes"] = {20}, ["allMandatory"] = true},
		["Safari Zone"] = {["routes"] = {147, 148, 149, 150}},
		["Silph Co"] = {["routes"] = {132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142}, ["mandatory"] = {432, 433, 434, 391, 349}, ["rival"] = true},
		["Sabrina"] = {["routes"] = {34}, ["allMandatory"] = true},
		["Rt 21/Pokemon Mansion"] = {["routes"] = {109, 219, 143, 144, 145, 146}},
		["Blaine"] = {["routes"] = {36}, ["allMandatory"] = true},
		["Giovanni"] = {["routes"] = {37}, ["allMandatory"] = true},
		["Rival 7"] = {["routes"] = {110}, ["trainers"] = {435, 436, 437}, ["allMandatory"] = true, ["rival"] = true},
		["Victory Road"] = {["routes"] = {125, 126, 127}},
		["Pokemon League"] = {["routes"] = {212, 213, 214, 215, 216, 217}, ["allMandatory"] = true, ["rival"] = true},
		["Route 12"] = {["routes"] = {100}},
		["Route 13"] = {["routes"] = {101}},
		["Route 14"] = {["routes"] = {102}},
		["Route 15"] = {["routes"] = {103}},
	}

	local milestones = {}
	local milestonesByName = {}
	local wheels = {}

	local startingHpCap = 100
	local statingStatusCap = 1

	-- DYNAMIC, but does not need to be saved (because the player should not quit while these are relevant)

	local topText = "Reward Spin"
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

	-- Dynamic, and must be saved:

	local segmentOrder = {
		"Viridian Forest", "Rival 2", "Brock", "Route 3", "Mt. Moon", "Rival 3", "Route 24/25", "Misty", "Route 6/11", "Rival 4", "Lt. Surge",
		"Route 9/10 N", "Rock Tunnel/Rt 10 S", "Rival 5", "Route 8", "Erika", "Game Corner", "Pokemon Tower", "Cycling Rd/Rt 18/19",
		"Koga", "Silph Co", "Sabrina", "Rt 21/Pokemon Mansion", "Blaine", "Giovanni", "Rival 7", "Victory Road", "Pokemon League"
	}

	local defeatedTrainerIds = {}

	local currentSegment = 1
	local segmentStarted = false
	local trainersDefeated = 0
	local mandatoriesDefeated = 0

	local hpCap = 100
	local statusCap = 1
	local hpCapModifier = 0
	local statusCapModifier = 0
	local milestone = 0
	local lastMilestone = nil
	local milestoneProgress = {}
	local specialRedeems = {routes = {}, unlocks = {}, consumable = {}}

	local offeredMoonStoneFirst = 0

	-- AddItems utility functions

	AddItems = {}

	function AddItems.getItemId(itemName)
		if itemName == Constants.BLANKLINE then return 0 end
		for id, item in pairs(MiscData.Items) do
			if item == itemName then
				return id
			end
		end
		return 0
	end
	
	function AddItems.getBagPocketData(id)
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

	function AddItems.addItemImproved(itemChoice, quantity)
		if itemChoice == Constants.BLANKLINE or quantity == nil or quantity == 0 then return false end
	
		local itemID = AddItems.getItemId(itemChoice)
		local bagPocketOffset, bagPocketCapacity, limitQuantity = AddItems.getBagPocketData(itemID)
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
			elseif readItemID == 0 then
				Memory.writeword(address + bagPocketOffset + i * 4, itemID)
				if key ~= nil then quantity = Utils.bit_xor(quantity, key) end
				Memory.writeword(address + bagPocketOffset + i * 4 + 2, quantity)
				return true
			end
		end
		return false
	end

	function strip(input)
		while string.sub(input, 1, 1) == ' ' do input = string.sub(input, 2, #input) end
		while string.sub(input, #input, #input) == ' ' do input = string.sub(input, 1, #input - 1) end
		return input
	end

	function splitOn(input, delim)
		local ret = {}
		if not input then return ret end
		local split = string.gmatch(input, '([^' .. delim .. ']+)')
		for s in split do
			ret[#ret + 1] = strip(s)
		end
		return ret
	end

	function wrapInline(input, length)
		local ret = ""
		for _,line in pairs(Utils.getWordWrapLines(input, length)) do
			ret = ret .. line .. "\n"
		end
		return ret
	end

	function wrapPixelsInline(input, limit)
		local ret = ""
		local currentLine = ""
		for _,word in pairs(splitOn(input, " ")) do
			if Utils.calcWordPixelLength(currentLine .. " " .. word) > limit then
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

	function contains(t, item)
		for _,i in pairs(t) do
			if i == item then return true end
		end
		return false
	end

	

	function keysIn(t)
		local ct = 0
		for _,_ in pairs(t) do
			ct = ct + 1
		end
		return ct
	end

	function removeElement(table, element)
		for i,e in pairs(table) do
			if e == element then
				table.remove(t, i)
				return true
			end
		end
		return false
	end

	function readConfig()
		local linesRead = io.lines(CONFIG_FILE_PATH)
		local lines = {}
		for l in linesRead do lines[#lines + 1] = l end
		local readIndex = 2
		local startingVals = splitOn(lines[1], ",")
		startingHpCap = tonumber(startingVals[1])
		startingStatusCap = tonumber(startingVals[2])
		while true do
			local line = lines[readIndex]
			if line == "-" then break end
			local info = splitOn(line, ",")
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
				local parts = splitOn(line, "|")
				currentWheel[#currentWheel + 1] = parts[1]
				if parts[2] then
					prize_images[splitOn(parts[1], ":")[1]] = parts[2]
				end
			end
			readIndex = readIndex + 1
		end
		if wheelName then
			wheels[wheelName] = currentWheel
		end
	end

	function populateSegmentData()
		for loc,data in pairs(segments) do
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
			if not data["mandatory"] then
				data["mandatory"] = {}
				if data["allMandatory"] then
					for _,trainer in pairs(data["trainers"]) do
						data["mandatory"][#data["mandatory"] + 1] = trainer
					end
				end
			end
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
	end

	function nextSegment()
		currentSegment = currentSegment + 1
		segmentStarted = false
		trainersDefeated = 0
		mandatoriesDefeated = 0
	end

	function getSegmentTrainerCount(segment)
		return #segments[segmentOrder[segment]]['trainers'] - (segments[segmentOrder[segment]]['rival'] and 2 or 0)
	end

	function getSegmentMandatoryCount(segment)
		local s = segments[segmentOrder[segment]]
		return #s['mandatory'] - (s['rival'] and 2 or 0) - (s['choicePairs'] and #s['choicePairs'] or 0)
	end

    local RewardScreen = {

	}

    RewardScreen.Colors = {
		text = "Default text",
		highlight = "Intermediate text",
		border = "Upper box border",
		fill = "Upper box background",
	}

	local TOP_LEFT_X = 2
	local IMAGE_WIDTH = 25
	local IMAGE_GAP = 1
	local BUTTON_WIDTH = 101
	local TOP_BUTTON_Y = 22
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

		local centeredX = Utils.getCenteredTextX(topText, canvas.w) - 2
		Drawing.drawTransparentTextbox(canvas.x + centeredX, canvas.y + 2, topText, canvas.text, canvas.fill, canvas.shadow)

		for _, button in pairs(RewardScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end

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
		Option1 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return wrapPixelsInline(option1, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				selectOption(option1)
			end,
		},
		Option2 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return wrapPixelsInline(option2, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				selectOption(option2)
			end,
		},
		Option3 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return wrapPixelsInline(option3, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP*2 + BUTTON_HEIGHT*2, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				selectOption(option3)
			end,
		},
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
		NextButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Next" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 5, 7, 22, 12 },
			onClick = function()
				spinNextReward()
			end,
			isVisible = function() return false end
		},
		RerollButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Reroll" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 7, 32, 12 },
			onClick = function()
				specialRedeems.consumable["Reroll Chip"] = nil
				removeElement(specialRedeems.consumable, "Reroll Chip")
			end,
			isVisible = function() return 
				specialRedeems.consumable["Reroll Chip"] 
			end
		},
		Description = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function() return wrapPixelsInline(descriptionText, IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP + DESC_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X, TOP_BUTTON_Y + 3*BUTTON_VERTICAL_GAP + 3*BUTTON_HEIGHT, 
			IMAGE_WIDTH + IMAGE_GAP + BUTTON_WIDTH + DESC_HORIZONTAL_GAP + DESC_WIDTH, DESC_TEXT_HEIGHT },
		}
	}

	function RewardScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, RewardScreen.Buttons or {})
	end

	local OptionSelectionScreen = {
		
	}

    OptionSelectionScreen.Colors = {
		text = "Default text",
		highlight = "Intermediate text",
		border = "Upper box border",
		fill = "Upper box background",
	}

    function OptionSelectionScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS[OptionSelectionScreen.Colors.text],
			border = Theme.COLORS[OptionSelectionScreen.Colors.border],
			fill = Theme.COLORS[OptionSelectionScreen.Colors.fill],
			shadow = Utils.calcShadowColor(Theme.COLORS[OptionSelectionScreen.Colors.fill]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		for _, button in pairs(OptionSelectionScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	local OSS_LEFT_TOP_LEFT_X = 6
	local OSS_BUTTON_WIDTH = 55
	local OSS_BUTTON_HORIZONTAL_GAP = 6
	local OSS_TOP_BUTTON_Y = 22
	local OSS_BUTTON_HEIGHT = 32
	local OSS_BUTTON_VERTICAL_GAP = 10
	local OSS_WRAP_BUFFER = 10

	OptionSelectionScreen.Buttons = {}

	for j = 0,2 do
		for i = 0,1 do
			local index = i + j*2 + 1
			OptionSelectionScreen.Buttons[index] = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() 
					return (additionalOptionsRemaining > 0) and wrapPixelsInline(additionalOptions[index], OSS_BUTTON_WIDTH - OSS_WRAP_BUFFER) or ""
				end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OSS_LEFT_TOP_LEFT_X + (i*(OSS_BUTTON_WIDTH + OSS_BUTTON_HORIZONTAL_GAP)), 
				OSS_TOP_BUTTON_Y + (j*(OSS_BUTTON_HEIGHT + OSS_BUTTON_VERTICAL_GAP)), OSS_BUTTON_WIDTH, OSS_BUTTON_HEIGHT },
				onClick = function()
					selectAdditionalOption(splitOn(additionalOptions[index], "(")[1])
				end,
				isVisible = function()
					return additionalOptions[index] and additionalOptions[index] ~= ""
				end
			}
		end
	end

	function OptionSelectionScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, OptionSelectionScreen.Buttons or {})
	end

	local SpecialRedeemScreen = {
		
	}

    SpecialRedeemScreen.Colors = {
		text = "Default text",
		highlight = "Intermediate text",
		border = "Upper box border",
		fill = "Upper box background",
	}

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
			text = Theme.COLORS[OptionSelectionScreen.Colors.text],
			border = Theme.COLORS[OptionSelectionScreen.Colors.border],
			fill = Theme.COLORS[OptionSelectionScreen.Colors.fill],
			shadow = Utils.calcShadowColor(Theme.COLORS[OptionSelectionScreen.Colors.fill]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, 10, "Redeemed Rewards")
		if specialRedeemToDescribe then
			Drawing.drawImage(IMAGES_DIRECTORY .. specialRedeemInfo[specialRedeemToDescribe].image, canvas.x + SRS_DESC_WIDTH + 2, SRS_TOP_Y + SRS_LINE_COUNT*SRS_LINE_HEIGHT)
		end

		for _, button in pairs(SpecialRedeemScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	SpecialRedeemScreen.Buttons = {
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 10, 22, 10},
			onClick = function()
				Program.changeScreenView(TrackerScreen)
			end,
		},
		DescriptionText = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function()
				local toReturn = specialRedeemToDescribe and specialRedeemInfo[specialRedeemToDescribe].description or ""
				if specialRedeemToDescribe == "Potion Investment" then
					toReturn = toReturn .. " " .. specialRedeems.consumable["Potion Investment"]
				end
				return  wrapPixelsInline(toReturn, SRS_DESC_WIDTH - SRS_WRAP_BUFFER)
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X, SRS_TOP_Y + SRS_LINE_COUNT*SRS_LINE_HEIGHT, SRS_DESC_WIDTH, 70}
		}
	}

	for i = 1,SRS_LINE_COUNT do
		SpecialRedeemScreen.Buttons["X" .. i] = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() 
				return "X" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X + SRS_TEXT_WIDTH, SRS_TOP_Y + ((i-1)*(SRS_LINE_HEIGHT)), SRS_BUTTON_WIDTH, SRS_BUTTON_HEIGHT },
			onClick = function()
				local toRemove = specialRedeems.consumable[i-keysIn(specialRedeems.unlocks)]
				specialRedeems.consumable[toRemove] = nil
				table.remove(specialRedeems.consumable, i-keysIn(specialRedeems.unlocks))
			end,
			isVisible = function()
				return specialRedeems.consumable[i-#specialRedeems.unlocks]
			end
		}

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
			onClick = function(self)
				local redeem = self.getText()
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
	

	function updateCaps()
		hpCap = milestonesByName[lastMilestone]['hpCap'] + hpCapModifier
		statusCap = milestonesByName[lastMilestone]['statusCap'] + statusCapModifier
	end

	function spinNextReward()
		milestone = milestone + 1
		lastMilestone = milestones[milestone]['name']
		updateCaps()
		local rewardOptions = wheels[milestones[milestone]['wheel']]
		local choices = {}
		while #choices < 3 do
			choice = math.random(#rewardOptions)
			local add = true
			for _, v in pairs(choices) do
				if v == choice then
					add = false
				end
			end
			if specialRedeems.unlocks[rewardOptions[choice]] or specialRedeems.consumable[rewardOptions[choice]] then
				add = false
			end
			if add then choices[#choices + 1] = choice end
		end
		option1Split = splitOn(rewardOptions[choices[1]], ":")
		option1 = option1Split[1]
		option1Desc = option1Split[2] or ""
		option2Split = splitOn(rewardOptions[choices[2]], ":")
		option2 = option2Split[1]
		option2Desc = option2Split[2] or ""
		option3Split = splitOn(rewardOptions[choices[3]], ":")
		option3 = option3Split[1]
		option3Desc = option3Split[2] or ""
		descriptionText = ""

		Program.redraw(true)
	end

	function spinReward(milestoneName)
		if LogOverlay.isGameOver and Program.currentScreen == GameOverScreen then
			GameOverScreen.status = GameOverScreen.Statuses.STILL_PLAYING
			LogOverlay.isGameOver = false
			LogOverlay.isDisplayed = false
			Program.GameTimer:unpause()
			GameOverScreen.refreshButtons()
			GameOverScreen.Buttons.SaveGameFiles:reset()
		end

		lastMilestone = milestoneName
		local rewardOptions = wheels[milestonesByName[milestoneName]['wheel']]
		local choices = {}
		while #choices < 3 do
			choice = math.random(#rewardOptions)
			local add = true
			for _, v in pairs(choices) do
				if v == choice then
					add = false
				end
			end
			if specialRedeems.unlocks[rewardOptions[choice]] or specialRedeems.consumable[rewardOptions[choice]] then
				add = false
			end
			if add then choices[#choices + 1] = choice end
		end
		option1Split = splitOn(rewardOptions[choices[1]], ":")
		option1 = option1Split[1]
		option1Desc = option1Split[2] or ""
		option2Split = splitOn(rewardOptions[choices[2]], ":")
		option2 = option2Split[1]
		option2Desc = option2Split[2] or ""
		option3Split = splitOn(rewardOptions[choices[3]], ":")
		option3 = option3Split[1]
		option3Desc = option3Split[2] or ""

		Program.redraw(true)
		Program.changeScreenView(RewardScreen)
	end

	function selectOption(option)
		local nextScreen = TrackerScreen

		local rewards = splitOn(option, '&')
		for _, reward in pairs(rewards) do
			if reward == 'Fight one of Route 12/13/14/15' then
				openRoutes = {}
				for _,r in pairs({"Route 12", "Route 13", "Route 14", "Route 15"}) do
					if not specialRedeems.routes[r] then openRoutes[#openRoutes + 1] = r end
				end
				if #openRoutes == 1 then
					table.insert(segmentOrder, currentSegment, openRoutes[1])
					specialRedeems.routes[reward] = true
				elseif #openRoutes > 1 then
					for i,_ in pairs(additionalOptions) do
						if i > #openRoutes then 
							additionalOptions[i] = ""
						else 
							additionalOptions[i] = openRoutes[i]
						end
					end
					additionalOptionsRemaining = 1
					nextScreen = OptionSelectionScreen
				end
			else
				if string.sub(reward, 1, 8) == 'HP Cap +' then
					hpCapModifier = hpCapModifier + tonumber(string.sub(reward, 9, #reward))
				end
				if string.sub(reward, 1, 12) == 'Status Cap +' then
					statusCapModifier = statusCapModifier + tonumber(string.sub(reward, 13, #reward))
				end
				local itemCount = 1
				local split = splitOn(reward, " ")
				if string.sub(split[#split], 1, 1) == 'x' then
					local s = split[1]
					for i = 2,#split-1 do s = s .. " " .. split[i] end
					reward = s
					itemCount = tonumber(string.sub(split[#split], 2, #(split[#split])))
				end
				local itemId = AddItems.getItemId(reward)
				if reward == "Berry Pouch" then itemId = 0 end
				if itemId ~= 0 then
					AddItems.addItemImproved(reward, itemCount)
				elseif string.sub(reward, 1, 3) == 'Any' then
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
				elseif specialRedeemInfo[reward] then
					if specialRedeemInfo[reward].consumable then 
						specialRedeems.consumable[reward] = true
						specialRedeems.consumable[#specialRedeems.consumable + 1] = reward
						if reward == "Potion Investment" then
							specialRedeems.consumable[reward] = 20
						end
					else
						specialRedeems.unlocks[reward] = true
						specialRedeems.unlocks[#specialRedeems.unlocks + 1] = reward
					end
				end
			end
		end

		updateCaps()

		Program.changeScreenView(nextScreen)

		Program.redraw(true)
	end

	function selectAdditionalOption(option)
		if option ~= "" and additionalOptionsRemaining > 0 then
			AddItems.addItemImproved(option, 1)
			additionalOptionsRemaining = additionalOptionsRemaining - 1
		end
		if option == "Moon Stone" then
			hpCap = hpCap - 100
		end
		if additionalOptionsRemaining <= 0 then
			Program.changeScreenView(TrackerScreen)
		end
		if string.sub(option, 1, 5) == 'Route' then
			table.insert(segmentOrder, currentSegment, option)
			specialRedeems.routes[option] = true
		end
	end

	function redrawScreenImages()
		--local dx = 180 - (#specialRedeems.unlocks + #specialRedeems.consumable)*30
		local dx = 0
		local dy = 0
		for _,r in ipairs(specialRedeems.unlocks) do
			Drawing.drawImage(IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx, dy)
			dx = dx + 30
		end
		for _,r in ipairs(specialRedeems.consumable) do
			Drawing.drawImage(IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx, dy)
			dx = dx + 30
		end
		Program.redraw(true)
	end

	function self.afterEachFrame()
		if not Battle.inBattle then
			redrawScreenImages()
		end
	end

	function self.afterBattleEnds()
		local trainerId = Memory.readword(GameSettings.gTrainerBattleOpponent_A)
		if defeatedTrainerIds[trainerId] then
			return
		else
			defeatedTrainerIds[trainerId] = true
		end

		if (gymLeaders[trainerId]) then
			for i,r in ipairs(specialRedeems.consumable) do
				if r == "Temporary Item Voucher" then
					specialRedeems.consumable[r] = nil
					table.remove(specialRedeems.consumable, i)
					break
				end
			end
			for i,r in ipairs(specialRedeems.consumable) do
				if r == "Temporary TM Voucher" then
					specialRedeems.consumable[r] = nil
					table.remove(specialRedeems.consumable, i)
					break
				end
			end
			local pv = specialRedeems.consumable["Potion Investment"]
			if pv then specialRedeems.consumable["Potion Investment"] = pv * 2 end
		end

		-- Add 4 potions after rival 1
		if trainerId >= 326 and trainerId <= 328 then
			AddItems.addItemImproved("Potion", 4)
		end
		if milestoneTrainers[trainerId] then
			local milestoneName = milestoneTrainers[trainerId]['name']
			if milestoneProgress[milestoneName] then
				milestoneProgress[milestoneName] = milestoneProgress[milestoneName] + 1
			else
				milestoneProgress[milestoneName] = 1
			end
			if milestoneProgress[milestoneName] == milestoneTrainers[trainerId]['count'] then
				spinReward(milestoneName)
			end
		end
		local segInfo = segments[segmentOrder[currentSegment]]
		for _,t in pairs(segInfo["trainers"]) do
			if t == trainerId then
				segmentStarted = true
				trainersDefeated = trainersDefeated + 1
				if trainersDefeated == getSegmentTrainerCount(currentSegment) then
					nextSegment()
				end
			end
		end
		for _,t in pairs(segInfo["mandatory"]) do
			if t == trainerId then
				if not (segInfo["choices"] and defeatedTrainerIds[segInfo["choices"][trainerId]]) then
					mandatoriesDefeated = mandatoriesDefeated + 1
				end
			end
		end
	end

	-- function self.configureOptions()
	-- 	Program.changeScreenView(RewardScreen)
	-- end

	function saveData()
		local saveData = {
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
			['milestone'] = milestone,
			['lastMilestone'] = lastMilestone,
			['milestoneProgress'] = milestoneProgress,
			['specialRedeems'] = specialRedeems,
			['offeredMoonStoneFirst'] = offeredMoonStoneFirst
		}
		
		FileManager.writeTableToFile(saveData, SAVED_DATA_PATH)
	end

	function loadData()
		local saveData = FileManager.readTableFromFile(SAVED_DATA_PATH)
		if saveData and GameSettings.getRomHash() == saveData['romHash'] then
			segmentOrder = saveData['segmentOrder']
			defeatedTrainerIds = saveData['defeatedTrainerIds']
			currentSegment = saveData['currentSegment']
			segmentStarted = saveData['segmentStarted']
			trainersDefeated = saveData['trainersDefeated']
			mandatoriesDefeated = saveData['mandatoriesDefeated']
			hpCap = saveData['hpCap']
			statusCap = saveData['statusCap']
			hpCapModifier = saveData['hpCapModifier']
			statusCapModifier = saveData['statusCapModifier']
			milestone = saveData['milestone']
			lastMilestone = saveData['lastMilestone']
			milestoneProgress = saveData['milestoneProgress']
			specialRedeems = saveData['specialRedeems']
			offeredMoonStoneFirst = saveData['offeredMoonStoneFirst']
		end
	end

	function self.startup()
		readConfig()
		populateSegmentData()
		local SEGMENT_CAROUSEL_INDEX = #TrackerScreen.CarouselTypes + 1
		TrackerScreen.CarouselItems[SEGMENT_CAROUSEL_INDEX] = {
			type = SEGMENT_CAROUSEL_INDEX,
			framesToShow = 300,
			canShow = function(self)
				return true
			end,
			getContentList = function(self)
				if segmentStarted then
					local text = wrapPixelsInline(segmentOrder[currentSegment] .. ": " .. mandatoriesDefeated .. "/" .. getSegmentMandatoryCount(currentSegment) .. " mandatory, " .. 
					trainersDefeated .. "/" .. getSegmentTrainerCount(currentSegment) .. " total",
					Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN) - 10)
					return Main.IsOnBizhawk() and { text } or text
				else
					local text = wrapPixelsInline('Next Segment: ' .. segmentOrder[currentSegment],
					Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN) - 10)
					return Main.IsOnBizhawk() and { text } or text
				end
			end,
		}
		TrackerScreen.Buttons.RogueMenuButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "!" end,
			box = { Constants.SCREEN.WIDTH + 90, 59, 6, 12},
			onClick = function()
				specialRedeemToDescribe = nil
				Program.changeScreenView(SpecialRedeemScreen)
			end,
			textColor = Drawing.Colors.YELLOW,
			boxColors = {Drawing.Colors.WHITE}
		}

		loadData()
	end

	function self.afterProgramDataUpdate()
		local mapId = TrackerAPI.getMapId()
		if(milestoneAreas[mapId]) then
			if not milestoneProgress[mapId] then
				milestoneProgress[mapId] = 1
				spinReward(milestoneAreas[mapId]['name'])
			end
		end
		if not segmentStarted then
			for _,r in pairs(segments[segmentOrder[currentSegment]]["routes"]) do
				if mapId == r then
					segmentStarted = true
				end
			end
		end
		if Tracker.getPokemon(1, true, true) and Tracker.getPokemon(1, true, true).curHP == Tracker.getPokemon(1, true, true).stats.hp and mapId == 8 and segmentStarted 
		and mandatoriesDefeated == getSegmentMandatoryCount(currentSegment) then
			-- In a Pokemon Center with full HP, the segment is *probably* done
			nextSegment()
		end
		if offeredMoonStoneFirst == 0 and mapId == 84 and contains(PokemonData.Pokemon[Tracker.getPokemon(1, true, true).pokemonID].evolution.detailed, "Moon Stone") then
			offeredMoonStoneFirst = 1
			additionalOptions[1] = "Moon Stone (-100 HP Cap)"
			additionalOptions[2] = "Skip"
			for i = 3,8 do
				additionalOptions[i] = ""
			end
			additionalOptionsRemaining = 1
			Program.changeScreenView(OptionSelectionScreen)
		end
		if offeredMoonStoneFirst < 2 and mapId == 84 and defeatedTrainerIds[348] and contains(PokemonData.Pokemon[Tracker.getPokemon(1, true, true).pokemonID].evolution.detailed, "Moon Stone") then
			offeredMoonStoneFirst = 2
			AddItems.addItemImproved("Moon Stone", 1)
		end

		if not patchedMoonStones and PokemonData.Pokemon[412] ~= nil then
			patchedMoonStones = true
			local itemEvoMethods = {
				PokemonData.Evolutions.EEVEE_STONES_NATDEX, PokemonData.Evolutions.THUNDER, PokemonData.Evolutions.FIRE, PokemonData.Evolutions.WATER, 
				PokemonData.Evolutions.MOON, PokemonData.Evolutions.LEAF, PokemonData.Evolutions.SUN, PokemonData.Evolutions.LEAF_SUN, 
				PokemonData.Evolutions.WATER_ROCK, PokemonData.Evolutions.SHINY, PokemonData.Evolutions.DUSK, PokemonData.Evolutions.DAWN, 
				PokemonData.Evolutions.ICE, PokemonData.Evolutions.METAL_COAT, PokemonData.Evolutions.KINGS_ROCK, PokemonData.Evolutions.DRAGON_SCALE,
				PokemonData.Evolutions.UPGRADE, PokemonData.Evolutions.DUBIOUS_DISC, PokemonData.Evolutions.RAZOR_CLAW, PokemonData.Evolutions.RAZOR_FANG,
				PokemonData.Evolutions.LINKING_CORD, PokemonData.Evolutions.WATER_DUSK, PokemonData.Evolutions.MOON_SUN, PokemonData.Evolutions.SUN_LEAF_DAWN,
				PokemonData.Evolutions.COAT_ROCK, PokemonData.Evolutions.DEEPSEA
			}
			local moon30 = {
				abbreviation = "30/MN",
				short = { "Lv.30", "Moon", },
				detailed = { "Level 30", "Moon Stone", },
				evoItemIds = { 94 },
			}
			local moon37 = {
				abbreviation = "37/MN",
				short = { "Lv.37", "Moon", },
				detailed = { "Level 37", "Moon Stone", },
				evoItemIds = { 94 },
			}
			local moon42 = {
				abbreviation = "42/MN",
				short = { "Lv.42", "Moon", },
				detailed = { "Level 42", "Moon Stone", },
				evoItemIds = { 94, },
			}
			local itemLevelEvoMethods = {
				[PokemonData.Evolutions.WATER30] = moon30,
				[PokemonData.Evolutions.WATER37] = moon37,
				[PokemonData.Evolutions.WATER37_REV] = moon37,
				[PokemonData.Evolutions.DAWN42] = moon42,
				[PokemonData.Evolutions.DAWN30] = moon30,
				[PokemonData.Evolutions.ROCK37] = moon37,
			}
			for _,pk in pairs(PokemonData.Pokemon) do
				for _,method in pairs(itemEvoMethods) do
					if pk.evolution == method then
						pk.evolution = PokemonData.Evolutions.MOON
					end
				end
				for method,replacement in pairs(itemLevelEvoMethods) do
					if pk.evolution == method then
						pk.evolution = replacement
					end
				end
			end
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

	saveToFileOld = Tracker.AutoSave.saveToFile
	Tracker.AutoSave.saveToFile = function()
		saveData()
		saveToFileOld()
	end

	local statusBerries = {133, 134, 135, 136, 137, 140, 141}

	local drawPokemonInfoAreaOld = TrackerScreen.drawPokemonInfoArea
	TrackerScreen.drawPokemonInfoArea = function(data)
		drawPokemonInfoAreaOld(data)
		if Battle.isViewingOwn and data.p.id ~= 0 then
			gui.drawRectangle(Constants.SCREEN.WIDTH + 6, 58, 95, 21, Theme.COLORS["Lower box background"], Theme.COLORS["Lower box background"])

			local healsTextColor = data.x.healvalue > hpCap and Drawing.Colors.RED or Theme.COLORS["Default text"]
			local healsValueText
			if Options["Show heals as whole number"] then
				healsValueText = string.format("%.0f/%.0f %s (%s)", data.x.healvalue, hpCap, Resources.TrackerScreen.HPAbbreviation, data.x.healnum)
			else
				healsValueText = string.format("%.0f%% %s (%s) bb", data.x.healperc, Resources.TrackerScreen.HPAbbreviation, data.x.healnum)
			end
			Drawing.drawText(Constants.SCREEN.WIDTH + 6, 57, healsValueText, healsTextColor, shadowcolor)

			local statusHealsInBagCount = 0

			for id,ct in pairs(Program.GameData.Items.StatusHeals) do
				if not (specialRedeems.unlocks["Berry Pouch"] and contains(statusBerries, id)) then
					statusHealsInBagCount = statusHealsInBagCount + ct
				end
			end
			local statusHealsTextColor = statusHealsInBagCount > statusCap and Drawing.Colors.RED or Theme.COLORS["Default text"]
			local statusHealsValueText = string.format("%.0f/%.0f %s", statusHealsInBagCount, statusCap, "Status")
			Drawing.drawText(Constants.SCREEN.WIDTH + 6, 68, statusHealsValueText, statusHealsTextColor, shadowcolor)
			Drawing.drawButton(TrackerScreen.Buttons.RogueMenuButton)
		end
	end

	return self
end
return RoguemonTracker