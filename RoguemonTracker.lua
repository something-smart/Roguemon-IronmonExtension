local function RoguemonTracker()
    local self = {}
	self.version = "1.4.1-beta.2"
	self.name = "Roguemon Tracker"
	self.author = "Croz & Smart"
	self.description = "Tracker extension for tracking & automating Roguemon rewards & caps."
	self.github = "something-smart/Roguemon-IronmonExtension"
	self.url = string.format("https://github.com/%s", self.github or "")

	EXTENSION_DIRECTORY = FileManager.getCustomFolderPath() .. "roguemon" .. FileManager.slash

	local RoguemonUtils = dofile(EXTENSION_DIRECTORY .. "utils.lua")

	-- turn this on to have the reward screen accessible at any time
	local DEBUG_MODE = false

	-- turn this on to be noisy about any io.open failures (except "No such file")
	self.DEBUG_IO_OPEN_ERRORS = false

	-- STATIC OR READ IN AT LOAD TIME:

	self.Paths = {
		IMAGES_DIRECTORY    = EXTENSION_DIRECTORY .. "roguemon_images" .. FileManager.slash,
		CONFIG_FILE         = EXTENSION_DIRECTORY .. "roguemon_config.txt",
		SAVED_DATA_PREFIX   = EXTENSION_DIRECTORY .. "roguemon_data-",
		SAVED_OPTIONS       = EXTENSION_DIRECTORY .. "roguemon_options.tdat",
		RANDOMIZER_JAR      = EXTENSION_DIRECTORY .. "roguemon_randomizer_natdex.jar",
		PATCHER_JAR         = EXTENSION_DIRECTORY .. "jbps.jar",
		ROM_BPS             = EXTENSION_DIRECTORY .. "roguemon.bps",
		ROGUEMON_ROM        = EXTENSION_DIRECTORY .. "roguemon.gba",
		ROGUEMON_UNRAND_ROM = EXTENSION_DIRECTORY .. "roguemon_unrandomized.gba",
		VANILLA_ROM         = EXTENSION_DIRECTORY .. "vanilla.gba",
		DEBUG_LOG           = EXTENSION_DIRECTORY .. "roguemon_debug_log.txt",
		RANDOMIZING_STATE   = EXTENSION_DIRECTORY .. "randomizing.State",
	}

	local CURSE_THEME = "FFFFFF FFFFFF B0FFB0 FF00B0 FFFF00 FFFFFF 33103B 510080 33103B 510080 000000 1 0"

	local STATIC_PROFILE_ID = "8cca5a43-967c-469a-858b-123456789abc"

	local REQUIRED_BIZHAWK_VERSION = "2.9.1"

	local prize_images = {} -- will get updated when config file is read

	local specialRedeemInfo = {
		["Luck Incense"] = {consumable = false, image = "luck.png", description = "Instead of trashing heals over cap, may have your lead pokemon hold them and take them back later."},
		["Reroll Chip"] = {consumable = true, button = "", image = "rerollchip.png", description = "May be used to reroll any reward spin once."},
		["Duplicator"] = {consumable = true, image = "duplicator.png", description = "Gain a copy of one future HP/PP/status healing item found (immediate choice)."},
		["Temporary TM Voucher"] = {consumable = true, image = "bluevoucher.png", description = "Teach one future TM found before the next badge (immediate choice)."},
		["Potion Investment"] = {consumable = true, image = "diamond.png", description = "Starts at 20; x2 value each badge. Redeem once for a heal up to its value in Buy Phase. Value:"},
		["Temporary Found Item"] = {consumable = true, image = "grounditem.png", description = "Temporarily unlock an item in your bag for 2 gym badges."},
		["Flutist"] = {consumable = false, image = "flute.png", description = "You may use flutes in battle (including Poke Flute). Don't cleanse flutes."},
		["Berry Pouch"] = {consumable = false, image = "berry-pouch.png", description = "HP Berries may be saved instead of equipped; status berries don't count against cap."},
		["Candy Jar"] = {consumable = false, image = "candy-jar.png", description = "You may save PP Ups, PP Maxes, and Rare Candies to use at any time."},
		["Temporary Item Voucher"] = {consumable = true, image = "tempvoucher.png", description = "Permanently unlock one future non-revive item found before next gym (immediate decision)."},
		["X Factor"] = {consumable = false, image = "XFACTOR.png", description = "You may keep and use Battle Items freely."},
		["Item Voucher"] = {consumable = true, image = "voucher.png", description = "Permanently unlock one non-revive item found in the future (immediate decision)."},
		["Fight wilds in Rts 1/2/22"] = {consumable = "true", image = "exp-charm.png", description = "Fight the first encounter on each. You may PC heal anytime, but must stop there."},
		["Fight first 5 wilds in Forest"] = {consumable = "true", image = "exp-forest.png", description = "Can't heal in between. Can run but counts as 1 of the 5."},
		["TM Voucher"] = {consumable = true, image = "tmvoucher.png", description = "Teach 1 TM found in the future (immediate decision)."},
		["Revive"] = {consumable = true, image = "revive.png", description = "May be used in any battle. Keep your HM friend with you; send it out and revive if you faint."},
		["Max Revive"] = {consumable = true, image = "max-revive.png", description = "May be used in any battle. Keep your HM friend with you; send it out and revive if you faint."},
		["Warding Charm"] = {consumable = true, button = "", image = "warding-charm.png", description = "Cancel the effect of any one Curse."},
		["Cooler Bag"] = {consumable = false, image = "coolerbag.png", description = "Drinks don't count against HP cap, and Berry Juices may be saved."},
		["Regenerator"] = {consumable = false, image = "leftovers.png", description = "Regain 3% of max HP after every fight."},
		["Remodeler"] = {consumable = false, image = "remodeler.png", description = "May immediately teach a found TM over a move of the same type. This is reusable."},
		["Choose 2"] = {consumable = true, image = "choose-2.png", description = "Choose 2 prizes at the next gym milestone."},
		["Secret Dex"] = {consumable = false, image = "secret-dex.png", description = "Get stat info on all 570+ BST pokemon."},
		["Special Insight"] = {consumable = false, image = "special-insight.png", description = "Learn every enemy pokemon's ability."},
		["Spidey Sense"] = {consumable = false, image = "spidey-sense.png", description = "Learn if enemies have Counter, Mirror Coat, or Destiny Bond."},
		["Temporary Item Pass"] = {consumable = true, image = "tempvoucher.png", description = "All legal items are unlocked for the next two gyms."},
		["Smuggler's Pouch"] = {consumable = false, image = "smugglers-pouch.png", description = "May choose one item not to cleanse each Cleansing Phase."},
		["Pocket Sand"] = {consumable = false, button = "Use", charges = 5, image = "pocket-sand.png", description = "5 times in the run, may reduce enemy's accuracy to -6."},
		["Tera Orb"] = {consumable = false, button = "Use", charges = 5, image = "tera-orb.png", description = "Choose a type matching a move; 5 times, you may Terastalize to that type."},
		["Notetaker"] = {consumable = false, image = "notetaker.png", description = "Notes on enemy pokemon transfer to their evolution."},
		["Midas Touch"] = {consumable = false, image = "midas-touch.png", description = "If you trash an HP heal, gain 30% of its value as HP cap."},
	}

	local gymLeaders = {[414] = true, [415] = true, [416] = true, [417] = true, [418] = true, [420] = true, [419] = true, [350] = true}

	-- Trainer IDs for milestones. "count" indicates how many trainers must be defeated for the milestone to count.
	local milestoneTrainers = {
		[414] = {["name"] = "Brock", ["count"] = 1},
		[415] = {["name"] = "Misty", ["count"] = 1},
		[416] = {["name"] = "Surge", ["count"] = 1},
		[417] = {["name"] = "Erika", ["count"] = 1},
		[418] = {["name"] = "Koga", ["count"] = 1},
		[349] = {["name"] = "Silph Co", ["count"] = 1},
		[420] = {["name"] = "Sabrina", ["count"] = 1},
		[419] = {["name"] = "Blaine", ["count"] = 1},
		[350] = {["name"] = "Giovanni", ["count"] = 1},
		["Mt. Moon"] = "Mt. Moon",
		["Silph Co"] = "Silph Co",
		["Victory Road"] = "Victory Road"
	}

	-- Milestones that require entering an area; in this case, only the Pokemon League.
	local milestoneAreas = {
		[87] = {["name"] = "Pokemon League"}
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
		["Pokemon League"] = {buy = true, cleansing = true}
	}

	-- Options for prizes that have multiple options. If a selected prize contains any of these, it will open the self.OptionSelectionScreen.
	-- Currently there is no support for a single prize having multiple DIFFERENT selections (e.g. 2x Any Vitamin is fine, Any Vitamin & Any Status Heal is not)
	local prizeAdditionalOptions = {
		["Any Status Heal"] = {"Antidote", "Parlyz Heal", "Awakening", "Burn Heal", "Ice Heal"},
		["Any Battle Item"] = {"X Attack", "X Defend", "X Special", "X Speed", "X Accuracy", "Dire Hit", "Guard Spec."},
		["Any Vitamin"] = {"Hp Up (HP)", "Protein (Attack)", "Iron (Defense)", "Calcium (Sp. Atk)", "Zinc (Sp. Def)", "Carbos (Speed)"}
	}

	-- Segments will autofill the required and optional trainers from the route info. Some segments encompass part of a route and must be hard-coded.
	-- "Rival" flag means the number of trainers is effectively 2 lower, because each rival fight has 3 IDs and only one is fought.
	local segments = {
		["Viridian Forest"] = {["routes"] = {117}, ["mandatory"] = {104}, ["itemsBefore"] = {0x1E7, 0x1CD}, ["items"] = {1000, 1001, 0x157, 0x156, 0x158, 0x1BE}},
		["Rival 2"] = {["routes"] = {110}, ["trainers"] = {329, 330, 331}, ["allMandatory"] = true, ["rival"] = true},
		["Brock"] = {["routes"] = {28}, ["allMandatory"] = true, ["gymCursable"] = true, ["itemsBefore"] = {1112}},
		["Route 3"] = {["routes"] = {91}, ["mandatory"] = {105, 107}, ["choicePairs"] = {{106, 117}}, ["cursable"] = true, ["items"] = {1113, 1114}},
		["Mt. Moon"] = {["routes"] = {114, 116}, ["mandatory"] = {351, 170}, ["cursable"] = true, ["items"] = {0x15D, 0x15E, 0x159, 0x15B, 0x15C, 0x15A, 1002, 1003, 0x1C0, 0x1BF, 0x15F, 0x160, 1050, 1156, 0x161}},
		["Rival 3"] = {["routes"] = {81}, ["trainers"] = {332, 333, 334}, ["allMandatory"] = true, ["rival"] = true},
		["Route 24/25"] = {["routes"] = {112, 113}, ["mandatory"] = {110, 123, 92, 122, 144, 356, 153, 125}, ["choicePairs"] = {{182, 184}, {183, 471}}, ["cursable"] = true,
			["items"] = {1115, 0x162, 1117, 1004, 1005, 1116, 0x163}},
		["Misty"] = {["routes"] = {12}, ["allMandatory"] = true, ["gymCursable"] = true},
		["Route 6/11"] = {["routes"] = {182, 94, 99}, ["trainers"] = {355, 111, 112, 145, 146, 151, 152, 97, 98, 99, 100, 221, 222, 258, 259, 260, 261}, ["mandatory"] = {355, 146}, ["cursable"] = true,
			["items"] = {1119, 1118, 1048, 1041, 0x1CF, 0x1CE, 0x1C1}},
		["Rival 4"] = {["routes"] = {119, 120, 121, 122}, ["trainers"] = {426, 427, 428}, ["allMandatory"] = true, ["rival"] = true, ["items"] = {1008, 1121, 1122, 1120, 0x16A}},
		["Lt. Surge"] = {["routes"] = {25}, ["allMandatory"] = true, ["gymCursable"] = true},
		["Route 9/10 N"] = {["routes"] = {97, 98}, ["trainers"] = {114, 115, 148, 149, 154, 155, 185, 186, 465, 156}, ["mandatory"] = {154, 115}, ["cursable"] = true, ["items"] = {1150, 1006, 1123, 0x1C2, 0x16B, 1126, 1125, 1009}},
		["Rock Tunnel/Rt 10 S"] = {["routes"] = {154, 155}, ["trainers"] = {192, 193, 194, 168, 476, 475, 474, 158, 159, 189, 190, 191, 164, 165, 166, 157, 163, 187, 188}, ["mandatory"] = {168, 166, 159, 158, 189, 474}, ["choicePairs"] = {{191, 190}, {192, 193}}, ["cursable"] = true,
			["items"] = {0x1C5, 0x1C4, 0x1C3, 0x1C7, 0x1C6, 1151}},
		["Rival 5"] = {["routes"] = {161, 162}, ["trainers"] = {429, 430, 431}, ["allMandatory"] = true, ["rival"] = true},
		["Route 8"] = {["routes"] = {96}, ["choicePairs"] = {{131, 264}}, ["cursable"] = true, ["items"] = {1129, 1128, 1127}},
		["Erika"] = {["routes"] = {15}, ["allMandatory"] = true, ["gymCursable"] = true, ["itemsBefore"] = {1152, 1047, 0x1D1}},
		["Game Corner"] = {["routes"] = {27, 128, 129, 130, 131}, ["mandatory"] = {357, 368, 366, 367, 348}, ["cursable"] = true, ["items"] = {1011, 0x16C, 0x16D, 0x16F, 0x171, 0x170, 0x16E, 1012, 0x1D2, 0x172, 0x173, 1013, 1134, 0x176, 0x175, 0x174}},
		["Pokemon Tower"] = {["routes"] = {161, 163, 164, 165, 166, 167}, ["mandatory"] = {447, 453, 452, 369, 370, 371}, ["cursable"] = true, ["items"] = {0x177, 0x179, 0x178, 0x17A, 1014, 0x1D0, 0x17B, 0x17C, 0x17D}},
		["Cycling Rd/Rt 18/19"] = {["routes"] = {104, 105, 106, 107}, ["trainers"] = {199, 201, 202, 249, 250, 251, 203, 204, 205, 206, 252, 253, 254, 255, 256, 470, 307, 308, 309, 235, 236}, ["cursable"] = true,
			["items"] = {1018, 1021, 1020, 1019, 1017}},
		["Koga"] = {["routes"] = {20}, ["allMandatory"] = true, ["gymCursable"] = true},
		["Safari Zone"] = {["routes"] = {147, 148, 149, 150}, ["items"] = {1022, 0x181, 0x183, 0x185, 0x182, 0x184, 0x186, 0x1D3, 0x187, 1023, 0x189, 0x18A, 0x18B, 0x188}},
		["Silph Co"] = {["routes"] = {132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142}, ["mandatory"] = {432, 433, 434, 391, 349}, ["rival"] = true, ["cursable"] = true, ["bannedCurses"] = {["1000 Cuts"] = true, ["Toxic Fumes"] = true},
			["items"] = {1143, 0x197, 0x199, 0x198, 1144, 0x1C9, 1135, 1136, 0x18C, 1137, 0x18E, 0x18F, 0x18D, 0x1FE, 1024, 1138, 0x190, 0x191, 1139, 0x193, 0x194, 1140, 0x195, 0x196, 1141, 0x1C8, 1142, 1025}},
		["Sabrina"] = {["routes"] = {34}, ["allMandatory"] = true, ["gymCursable"] = true},
		["Rt 21/Pokemon Mansion"] = {["routes"] = {109, 219, 143, 144, 145, 146}, ["cursable"] = true, ["items"] = {1031, 0x19F, 0x1A0, 0x1CA, 0x1A1, 0x1CC, 0x1CB, 1032, 0x1A3, 0x1A2, 1033, 0x1A5, 0x1A4, 0x1A7}},
		["Blaine"] = {["routes"] = {36}, ["allMandatory"] = true, ["gymCursable"] = true},
		["Giovanni"] = {["routes"] = {37}, ["allMandatory"] = true, ["gymCursable"] = true},
		["Rival 7"] = {["routes"] = {110}, ["trainers"] = {435, 436, 437}, ["allMandatory"] = true, ["rival"] = true},
		["Victory Road"] = {["routes"] = {125, 126, 127}, ["cursable"] = true, ["bannedCurses"] = {["Forgetfulness"] = true, ["Downsizing"] = true, ["Poltergeist"] = true},
			["itemsBefore"] = {1147, 1034, 1148, 1036, 1146, 1035}, ["items"] = {1038, 1037, 0x1A9, 0x1AA, 0x1AD, 0x1AB, 0x1AC, 0x1AE, 0x1AF, 0x1B0, 1145, 1155}},
		["Pokemon League"] = {["routes"] = {212, 213, 214, 215, 216, 217}, ["allMandatory"] = true, ["rival"] = true},
		["Congratulations!"] = {["routes"] = {}},
		["Route 12 + 13"] = {["routes"] = {100, 101}, ["items"] = {1042, 1130, 0x17F, 0x17E, 1015}},
		["Route 14 + 15"] = {["routes"] = {102, 103}, ["items"] = {1157, 1149, 0x180}},
	}

	-- Curse flags which are coordinated with the ROM. See include/roguemon.h for complementary enum.
	local ROM_CURSE_NONE           = 0
	local ROM_CURSE_TIKTOK         = 1 << 0
	local ROM_CURSE_TOXIC_FUMES    = 1 << 1
	local ROM_CURSE_MOODY          = 1 << 2
	local ROM_CURSE_DAVID_VS       = 1 << 3
	local ROM_CURSE_MEDIOCRITIZE   = 1 << 4

	local curseInfo = {
		["Forgetfulness"] = {description = "4th move is changed randomly after 1st fight", segment = true, gym = false,
							longDescription = "After the first fight this segment, your bottom-most move is changed to a random move."},
		["Claustrophobia"] = {description = "If not full cleared, -50 HP Cap", segment = true, gym = false,
							longDescription = "If this segment is not full cleared, lose 50 HP Cap."},
		["Downsizing"] = {description = "If not full cleared, -1 prize option permanently", segment = true, gym = false,
							longDescription = "If this segment is not full cleared, all future prize spins will have only 2 options."},
		["Tormented Soul"] = {description = "Cannot use the same move twice in a row", segment = true, gym = true},
		["Kaizo Curse"] = {description = "Cannot use healing items outside of battle", segment = true, gym = true},
		["Headwind"] = {description = "Start fights at -1 or -2 Speed", segment = true, gym = true},
		["Sharp Rocks"] = {description = "All enemies have +2 crit rate", segment = true, gym = true},
		["High Pressure"] = {description = "Start missing 50% PP on all moves", segment = true, gym = true},
		["Heavy Fog"] = {description = "All combatants have -1 Accuracy", segment = true, gym = true},
		["Unstable Ground"] = {description = "75% to flinch on first turn of a fight", segment = true, gym = true},
		["1000 Cuts"] = {description = "Permanent -5 HP Cap when hit by an attack", segment = true, gym = false},
		["Acid Rain"] = {description = "Each fight has a random weather", segment = true, gym = false},
		["Toxic Fumes"] = {description = "Take 1 damage every 8 steps (can't faint)", segment = true, gym = false,
							longDescription = "Take 1 damage for every 8 steps walked. This can't bring you below 1 HP.", romCurse = ROM_CURSE_TOXIC_FUMES},
		["Narcolepsy"] = {description = "30% to fall asleep after each fight", segment = true, gym = false},
		["Clean Air"] = {description = "Enemies have Mist, Safeguard, and Ingrain", segment = true, gym = false},
		["Clouded Instincts"] = {description = "First move in battle must be 1st slot", segment = true, gym = false},
		["Unruly Spirit"] = {description = "10% to flinch on every turn", segment = true, gym = true},
		["Chameleon"] = {description = "Typing is randomized each battle", segment = true, gym = true,
							longDescription = "Your typing is randomized for each battle. This cannot give you STAB on your attacks."},
		["No Cover"] = {description = "Enemies cannot miss you", segment = true, gym = true},
		["Relay Race"] = {description = "Enemy stat stages carry over, with +1 Speed", segment = true, gym = true,
							longDescription = "All enemy pokemon start with +1 Speed, plus any stat changes that the previous pokemon in the fight had."},
		["Resourceful"] = {description = "Lose PP after fights; moves at 0 change", segment = true, gym = false,
							longDescription = "After each battle, lose 0-2 PP on your last used move. Then, if any moves are at 0 PP, they are changed to a random move."},
		["Safety Zone"] = {description = "If fighting, <75% HP, 30% to lose a heal", segment = true, gym = false,
							longDescription = "If you start a fight with less than 75% of your max HP, 30% chance to lose a random HP heal from your bag."},
		["Live Audience"] = {description = "When hit by a move, Encored for 2-3 turns", segment = true, gym = false,
							longDescription = "When you are hit by a damaging move, you are forced to repeat the same move you used for 2-3 turns."},
		["Moody"] = {description = "+1 and -1 to random stats each turn", segment = true, gym = true, romCurse = ROM_CURSE_MOODY},
		["Curse of Decay"] = {description = "When you use a move, -1 EV in its attacking stat", segment = true, gym = true},
		["Poltergeist"] = {description = "No FC = cursed item effects on pickup", segment = true, gym = false,
							longDescription = "If this segment isn't full cleared, all type-boosting items will apply a unique negative effect on pickup.",
						extremelyLongDescription = {
							"If this segment isn't full cleared, all type-boosting items will apply a unique negative effect on pickup.",
							"Poison Barb: Poisoned @ Charcoal: Burned @ NeverMeltIce: Frozen @ TwistedSpoon: Put to sleep @ Magnet: Paralyzed @ Hard Stone: Lose 20 Speed EVs @ Spell Tag: Lose 2 PP on all moves",
							"Silk Scarf: Start next fight confused @ Black Belt: Lose 20 EVs in highest attacking stat @ Dragon Fang: Reset to start of level @ BlackGlasses: Lose your smallest PP heal @ FairyFeather: -1 option on next prize spin",
							"Mystic Water: Lose a random specific status heal @ SilverPowder: Lose your smallest HP heal @ Sharp Beak: Lose 1/8 of your max HP (can't faint) @ Metal Coat: -20 HP Cap @ Soft Sand: Lose 1 to all IVs @ Miracle Seed: Start next fight Leech Seeded"
						}},
		["Debilitation"] = {description = "Attacking IVs temporarily set to 0", segment = true, gym = false},
		["Time Warp"] = {description = "Lose 25% of your EXP until the segment ends", segment = true, gym = true},
		["TikTok"] = {description = "One move per fight is secretly Metronome", segment = true, gym = false, romCurse = ROM_CURSE_TIKTOK},
		["Bloodborne"] = {description = "When you use an HP heal, lose 20% of its value from your cap", segment = true, gym = false},
		-- ["Freefall"] = {description = "+1 Speed per turn, take 1/8 damage at +6 ", segment = true, gym = true, 
		-- 					longDescription = "Gain +1 Speed at the end of every turn. When ending a turn with +6 speed, take damage equal to 1/8 of your maximum HP."},
		["Backseating"] = {description = "Don't use marked move: -1 to a random stat", segment = true, gym = false,
							longDescription = "Each turn, 'chat' suggests one move; if you don't use that move on that turn, you get -1 to a random stat for the fight."},
		["Malware"] = {description = "-1 in attack stat for lead's lower defense", segment = true, gym = false,
							longDescription = "-1 in attacking stat corresponding to lead's lower defense",},
		["Conversion"] = {description = "Enemy pokemon become a type matching a move", segment = true, gym = true,
							longDescription = "Enemy pokemon change to a type matching one of their moves"},
		["Perfectly Balanced"] = {description = "Your BST is redistributed evenly for this segment", segment = true, gym = true, romCurse = ROM_CURSE_MEDIOCRITIZE},
		["Slot Machine"] = {description = "HP set to 25%, 50%, 75%, or 100% after fight", segment = true, gym = false,
							longDescription = "HP is randomized to 25%, 50%, 75%, or 100% after each fight"},
		["David vs Goliath"] = {description = "3 random enemy pokemon have +150% HP", segment = true, gym = false, romCurse = ROM_CURSE_DAVID_VS},
		-- ["Distorted Heart"] = {description = "Your moves' typings are randomized each battle", segment = true, gym = false,
		-- 						longDescription = "Your moves' typings are randomized for each battle. This cannot give you STAB on your attacks."},
		-- ["Distorted Soul"] = {description = "Your moves' powers are randomized each battle", segment = true, gym = false,
		-- 						longDescription = "Your moves' powers are randomized for each battle, between 30 and 90."},
	}

	local FIRERED_11_SHA1SUM = "dd5945db9b930750cb39d00c84da8571feebf417"
	local FIRERED_11_SIZE = 16777216

	-- This is incremented whenever we make a change in the ROM that
	-- requires a change in the tracker, or vice versa. We check it against
	-- what is the ROM, and throw an error if it doesn't match.
	local trackerCompatVersion = 0x04

	-- This is the version of the ROM patch which has been bundled with the
	-- Tracker. If the ROM is older than this, we prompt the user to patch.
	-- This should be updated whenever `roguemon.bps` is updated.
	local bundledRomPatchVersion = "0.3.4-beta"

	-- This is set by the ROM. We track it to apply complementary rule enforcement in the tracker.
	local enforceRules = false

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

	local ancestralItems = {
		[PokemonData.Types.NORMAL] = "Silk Scarf", [PokemonData.Types.FIGHTING] = "Black Belt", [PokemonData.Types.FLYING] = "Sharp Beak",
		[PokemonData.Types.POISON] = "Poison Barb", [PokemonData.Types.GROUND] = "Soft Sand", [PokemonData.Types.ROCK] = "Hard Stone",
		[PokemonData.Types.BUG] = "SilverPowder", [PokemonData.Types.GHOST] = "Spell Tag", [PokemonData.Types.STEEL] = "Metal Coat",
		[PokemonData.Types.FIRE] = "Charcoal", [PokemonData.Types.WATER] = "Mystic Water", [PokemonData.Types.GRASS] = "Miracle Seed",
		[PokemonData.Types.ELECTRIC] = "Magnet", [PokemonData.Types.PSYCHIC] = "TwistedSpoon", [PokemonData.Types.ICE] = "NeverMeltIce",
		[PokemonData.Types.DRAGON] = "Dragon Fang", [PokemonData.Types.DARK] = "BlackGlasses", ["fairy"] = "FairyFeather"
	}
	
	local seedNumber = -1
	local loadedData = false
	local loadedExtension = false
	local milestones = {} -- Milestones stored in order
	local milestonesByName = {} -- Milestones keyed by name for easy access
	local wheels = {}

	local startingHpCap = 150
	local statingStatusCap = 3

	local currentStatusVal = 0
	local adjustedHPVal = 0

	local optionsList = {
		{text = "Ascension", options = {"1", "2", "3", "Auto"}, default = "Auto"},
		{text = "Display prizes on screen", default = true},
		{text = "Display small prizes", default = false},
		{text = "Show reminders", default = true},
		{text = "Show reminders over cap", default = false},
		{text = "Alternate Curse theme", default = true},
		{text = "Egg reminders", default = true}
	}
	local populatedOptions = false

	local evolutionTable = {}

	-- DYNAMIC, but does not need to be saved (because the player should not quit while these are relevant)

	local updateCounters = {}

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

	local patchedChangedEvos = false
	local randomizingROM = false
	local syncedAttempts = false
	local committed = false
	local caughtSomethingYet = false

	local currentRoguemonScreen = nil
	local screenQueue = {}
	local suppressedNotifications = {}
	local givenMoonStoneNotification = false
	local natureMintUp = nil
	local hpHealsSetting = nil
	local showedEggReminderAfterBrock = false
	local centersUsed = 0

	local priorItemsPocket = {}
	local itemsPocket = {}
	local priorBerryPocket = {}
	local berryPocket = {}
	local pokeInfo = nil
	local itemsFromPrize = {}
	local previousMap = nil

	local wildBattleCounter = 0
	local wildBattlesStarted = false
	local needToBuy = false
	local needToCleanse = 0
	local shouldDismissNotification = nil
	local foundItemPrizeActive = false
	local lastFoughtTrainerId = 0

	-- curse related values
	local curseAppliedThisFight = false
	local curseAppliedThisSegment = false
	local inBattleTurnCount = 0
	local lastAttackDamage = 0
	local shouldFlinchFirstTurn = false
	local flinchCheckFirstTurn = false
	local weatherApplied = nil
	local thisFightFaintCount = 0
	local relayRaceStats = {atk = 0, def = 0, spa = 0, spd = 0, spe = 0, acc = 0, eva = 0}
	local faintToProcess = false
	local lastUsedMove = nil
	local ppValues = {0, 0, 0, 0}
	local curseCooldown = 0
	local backseatingMove = nil
	local currentEnemyMon = nil

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
	local rivalCombined = false

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
	local specialRedeems = {internal = {}, unlocks = {}, consumable = {}, battle = {}}

	-- unlocked held items
	local unlockedHeldItems = {}

	-- which routes are cursed, and what curses do they have
	local cursedSegments = {}

	-- true if the Downsizing curse has been triggered (-1 prize options)
	local downsized = false

	-- exists if the Poltergeist curse has been triggered, and holds any carried-over effects
	local haunted = nil

	-- atk/spatk IVs if Debilitation is active
	local savedIVs = {}

	-- exp temporarily lost to Time Warp
	local timeWarpedExp = 0

	-- previous theme, to be stored while the curse theme is active
	local previousTheme = nil

	-- tracks how many times the roguestone has been offered
	local offeredMoonStoneFirst = 1

	-- Options
	local RoguemonOptions = {
		
	}

	-- Run summary information
	local runSummary = {{type = "None"}}

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
		if itemName == "Poke Doll" then return 80 end
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
		return self.AddItemById(itemID, quantity)
	end

	function self.AddItemById(itemID, quantity)
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

	function self.correctZeroItems(itemID)
		local key = Utils.getEncryptionKey(2)
		local address = Utils.getSaveBlock1Addr()
		local bagPocketOffset, bagPocketCapacity, limitQuantity = self.getBagPocketData(itemID)
		for i = 0,bagPocketCapacity - 1 do
			local itemid_and_quantity = Memory.readdword(address + bagPocketOffset + i * 4)
			local readItemID = Utils.getbits(itemid_and_quantity, 0, 16)
			local readQuantity = Utils.getbits(itemid_and_quantity, 16, 16)
			if key ~= nil then
				readQuantity = Utils.bit_xor(readQuantity, key)
			end
			if readItemID ~= 0 and readQuantity == 0 then
				Memory.writeword(address + bagPocketOffset + i * 4, 0)
			end
		end
	end

	function self.removeItem(itemChoice, quantity)
		quantity = quantity or 1
		if itemChoice == Constants.BLANKLINE or quantity == 0 then return false end
	
		local itemID = self.getItemId(itemChoice)
		local bagPocketOffset, bagPocketCapacity, limitQuantity = self.getBagPocketData(itemID)
		if bagPocketOffset == nil then return false end

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
				local newQuantity = readQuantity - quantity
				if newQuantity < 0 then
					newQuantity = 0
					Memory.writeword(address + bagPocketOffset + i * 4, 0)
				end
				if key ~= nil then newQuantity = Utils.bit_xor(newQuantity, key) end
				Memory.writeword(address + bagPocketOffset + i * 4 + 2, newQuantity)
				self.correctZeroItems(itemID)
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

		Program.updatePokemonTeams()
		local newPokeInfo = Tracker.getPokemon(1, true)

		local itemUnequipped = nil
		if pokeInfo and newPokeInfo and pokeInfo.heldItem ~= newPokeInfo.heldItem then
			itemUnequipped = pokeInfo.heldItem
		end

		local itemEquipped = nil
		if pokeInfo and newPokeInfo and pokeInfo.heldItem ~= newPokeInfo.heldItem then
			itemEquipped = newPokeInfo.heldItem
		end

		-- Check for info that changed
		local newItemsPocket, newBerryPocket = self.readBagInfo()
		local empty = (next(itemsPocket) == nil and next(berryPocket) == nil)

		local size = 0
		local redFlags = 0
		-- Check if items changed
		local toProcess = {}
		for i,q in pairs(newItemsPocket) do
			size = size + 1
			local oldq = itemsPocket[i] or 0
			local olderq = priorItemsPocket[i] or 0
			if olderq == q and oldq ~= q then
				redFlags = redFlags + 1
			end
			if q ~= oldq and i ~= itemUnequipped then
				currentStatusVal = self.countStatusHeals()
				if not (empty and TrackerAPI.getMapId() ~= 5) and TrackerAPI.getItemName(i, true) then
					toProcess[TrackerAPI.getItemName(i, true)] = q - oldq
				end
			end
		end

		-- Check for items fully removed
		for i,oldq in pairs(itemsPocket) do
			local q = newItemsPocket[i] or 0
			local olderq = priorItemsPocket[i] or 0
			if q == 0 and q ~= oldq and i ~= itemUnequipped then
				currentStatusVal = self.countStatusHeals()
				if not (empty and TrackerAPI.getMapId() ~= 5) and TrackerAPI.getItemName(i, true) then
					toProcess[TrackerAPI.getItemName(i, true)] = q - oldq
				end
			end
		end

		-- Check if berries changed
		for i,q in pairs(newBerryPocket) do
			size = size + 1
			local oldq = berryPocket[i] or 0
			local olderq = priorBerryPocket[i] or 0
			if olderq == q and oldq ~= q then
				redFlags = redFlags + 1
			end
			if q ~= oldq and i ~= itemUnequipped and i ~= itemEquipped then
				currentStatusVal = self.countStatusHeals()
				if not (empty and TrackerAPI.getMapId() ~= 5) then
					toProcess[TrackerAPI.getItemName(i, true)] = q - oldq
				end
			end
		end

		-- Check for berries fully removed
		for i,oldq in pairs(berryPocket) do
			local q = newBerryPocket[i] or 0
			local olderq = priorBerryPocket[i] or 0
			if q == 0 and q ~= oldq and i ~= itemUnequipped then
				currentStatusVal = self.countStatusHeals()
				if not (empty and TrackerAPI.getMapId() ~= 5) and TrackerAPI.getItemName(i, true) then
					toProcess[TrackerAPI.getItemName(i, true)] = q - oldq
				end
			end
		end

		if redFlags <= 3  and size > 0 then
			if priorItemsPocket[24] and (not itemsPocket[24]) and (not newItemsPocket[24]) and specialRedeems.consumable["Revive"] then
				self.removeSpecialRedeem("Revive")
			end
			if priorItemsPocket[25] and (not itemsPocket[25]) and (not newItemsPocket[25]) and specialRedeems.consumable["Max Revive"] then
				self.removeSpecialRedeem("Max Revive")
			end
			priorItemsPocket = itemsPocket
			priorBerryPocket = berryPocket
			for item, q in pairs(toProcess) do
				if q > 0 then
					-- item added
					self.processItemAdded(item)
				else
					-- item removed
					local hInfo = MiscData.HealingItems[self.getItemId(item)]
					if hInfo and self.getActiveCurse() == "Bloodborne" then
						if pokeInfo and newPokeInfo and newPokeInfo.curHP > pokeInfo.curHP then
							local hVal = 0
							if hInfo.type == MiscData.HealingType.Constant then
								hVal = math.floor(.2 * hInfo.amount)
							else
								hVal = math.floor(.2 * hInfo.amount / 100 * newPokeInfo.stats.hp)
							end
							hpCap = hpCap - hVal
							hpCapModifier = hpCapModifier - hVal
						end
					end
					if hInfo and specialRedeems.unlocks["Midas Touch"] and not notifyOnPickup.consumables[item] then
						if pokeInfo and newPokeInfo and newPokeInfo.curHP <= pokeInfo.curHP then
							local hVal = 0
							if hInfo.type == MiscData.HealingType.Constant then
								hVal = math.floor(.3 * hInfo.amount)
							else
								hVal = math.floor(.3 * hInfo.amount / 100 * newPokeInfo.stats.hp)
							end
							hpCap = hpCap + hVal
							hpCapModifier = hpCapModifier + hVal
							specialRedeems.unlocks["Midas Touch"] = specialRedeems.unlocks["Midas Touch"] + hVal
						end
					end
				end
			end
		end
		itemsPocket = newItemsPocket
		berryPocket = newBerryPocket

		if pokeInfo and newPokeInfo and pokeInfo.personality == newPokeInfo.personality and pokeInfo.level + 1 == newPokeInfo.level then
			-- We leveled up. Check caps again
			self.countAdjustedHeals()
			if RoguemonOptions["Show reminders over cap"] and adjustedHPVal > hpCap and not needToBuy then
				self.displayNotification("An HP healing item must be used or trashed", "healing-pocket.png", function()
					self.countAdjustedHeals()
					return adjustedHPVal <= hpCap
				end)
			end
			if RoguemonOptions["Show reminders over cap"] and currentStatusVal > statusCap and not needToBuy then
				self.displayNotification("A status healing item must be used or trashed", "status-cap.png", function()
					return self.countStatusHeals() <= statusCap
				end)
			end
		end
		if pokeInfo and newPokeInfo and pokeInfo.personality == newPokeInfo.personality and pokeInfo.pokemonID ~= newPokeInfo.pokemonID then
			-- We evolved :D
			self.showPrettyStatScreen(pokeInfo, newPokeInfo)
			runSummary[#runSummary + 1] = {
				type = "Evolution",
				prev = {stats = pokeInfo.stats, pokemonID = pokeInfo.pokemonID},
				new = {stats = newPokeInfo.stats, pokemonID = newPokeInfo.pokemonID},
				level = newPokeInfo.level
			}
			offeredMoonStoneFirst = 1
		end
		pokeInfo = newPokeInfo
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
	function self.wrapPixelsInline(input, limit, lineLimit, alternate)
		local ret = ""
		local currentLine = ""
		local lineCount = 1
		for _,word in pairs(Utils.split(input, " ", true)) do
			if word == "@" then
				ret = ret .. currentLine .. "\n"
				currentLine = ""
				lineCount = lineCount + 1
			elseif Utils.calcWordPixelLength(currentLine .. " " .. word) > limit and currentLine ~= "" then
				ret = ret .. currentLine .. "\n"
				currentLine = word
				lineCount = lineCount + 1
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

		if lineLimit and alternate and lineCount > lineLimit then
			return self.wrapPixelsInline(alternate, limit)
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

	function self.resetTheme()
		if RoguemonOptions["Alternate Curse theme"] and previousTheme then
			Theme.importThemeFromText(previousTheme, true)
		end
	end

	function self.addUpdateCounter(name, updates, fct, count)
		if not count then
			count = -1
		end
		updateCounters[name] = {updateCount = updates, currentUpdateCount = updates, functionToUse = fct, executionCount = count}
	end

	function self.removeUpdateCounter(name)
		updateCounters[name] = null
	end

	function self.errorLog(msg, ...)
		Utils.printDebug("!! RogueMon Error: " .. msg, ...)
	end

	function self.warningLog(msg, ...)
		Utils.printDebug("> RogueMon Warning: " .. msg, ...)
	end

	-- writes a message in a single line to the debug log file.
	function self.debugLog(msg)
		local file = io.open(self.Paths.DEBUG_LOG, "a")
		file:write(msg .. "\n")
		file:close()
	end

	-- DATA FUNCTIONS --

	-- Read the config file. Executed once, on startup.
	function self.readConfig()
		local linesRead = io.lines(self.Paths.CONFIG_FILE)
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
						prize_images["Fight Route 12 + 13"] = parts[2]
						prize_images["Fight Route 14 + 15"] = parts[2]
					end
					if prizeName == "Revive" then
						prize_images["Max Revive"] = "max-revive.png"
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

	function self.loadEvolutionTable()
		for i = 1,1235 do
			for j = 0,7 do
				local evoIndex = Memory.readword(0x0827d00c + 64*i + 4 + 8*j)
				if evoIndex > 0 then
					evolutionTable[evoIndex] = i
				end
			end
		end
	end

	local changedEvoMethods = {
		["Rhyhorn"] = "28",
		["Sunkern"] = "18",
		["Slugma"] = "18",
		["Snover"] = "28",
		["Happiny"] = "19",
		["Tynamo"] = "21",
		["Litwick"] = "20",
		["Mienfoo"] = "32",
		["Pawniard"] = "30",
		["Rufflet"] = "40",
		["Vullaby"] = "42",
		["Deino"] = "35",
		["Zweilous"] = "52",
		["Larvesta"] = "40",
		["Binacle"] = "32",
		["Skrelp"] = "34",
		["Amaura"] = "30",
		["Noibat"] = "32",
		["Cosmog"] = "18",
		["Toxel"] = "19",
		["Dreepy"] = "30",
		["Drakloak"] = "52",
		["Varoom"] = "32",
		["Gimmighoul"] = "34",
		["Gimmighoul R"] = "34",
		["Salandit"] = "33",
		["Combee"] = "21"
	}

	function self.patchChangedEvos()
		patchedChangedEvos = true
		-- all these methods get changed to RogueStone
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
				if pk.evolution == PokemonData.Evolutions.NONE and pk.bst <= 450 and pk.name ~= "Shedinja" then
					pk.evolution = extraEvo
				end
				for name,method in pairs(changedEvoMethods) do
					if pk.name == name then
						pk.evolution = method
					end
				end
			end
		end
	end

	-- Manages a static run profile that is used for RogueMon.
	-- Actions are idempotent.
	function self.setupRunProfile()
		local uid, ascension, typeIndex = self.getRomStamp()

		Options["Generate ROM each time"] = true
		Options["Game Over condition"]    = "EntirePartyFaints"
		Options.FILES["Randomizer JAR"]   = self.Paths.RANDOMIZER_JAR
		Options.FILES["Source ROM"]       = self.Paths.ROGUEMON_UNRAND_ROM

		local profile = QuickloadScreen.IProfile:new({
			Name = "RogueMon",
			Mode = "Generate",
			GameVersion = "firered",
			GameOverCondition = Options["Game Over condition"],
			GUID = STATIC_PROFILE_ID,
			Paths = {
				Rom = Options.FILES["Source ROM"],
				Jar = Options.FILES["Randomizer JAR"],
			}
		})

		if ascension > 0 then
			local settingsFile = self.getSettingsFilePath(ascension, typeIndex)
			Options.FILES["Settings File"] = settingsFile
			profile.Paths.Settings = Options.FILES["Settings File"]
		end

		QuickloadScreen.addUpdateProfile(profile, true)
	end

	function self.updateGameSettings()

		-- We use this particular setting as a sentinel to determine if
		-- NatDexExtension has overridden our game settings, which can happen
		-- if it reloads after we have already loaded. In that case, the checks
		-- in `startup` don't even save us, because the global Move data has
		-- already been updated.
		local sSpecialFlagsPtr = 0x08000354
		if GameSettings["sSpecialFlags"] == Memory.readdword(sSpecialFlagsPtr) then
			-- settings are updated
			return
		end

		-- A table of GameSettings keys to the pointers which contain
		-- the addresses they should be set to.
		-- Commented addresses are cases where the symbol we're pointing at
		-- doesn't match the name of the setting, either because the
		-- tracker calls it something else, or because NatDex wants an
		-- alternate function pointed at.
		local pointers = {
			["BattleIntroDrawPartySummaryScreens"]         = 0x08000300,
			["ReturnFromBattleToOverworld"]                = 0x08000304,
			["BattleIntroOpponentSendsOutMonAnimation"]    = 0x0800030c, -- BattleIntroRecordMonsToDex
			["HandleTurnActionSelectionState"]             = 0x08000310,
			["gBattleMainFunc"]                            = 0x08000314,
			["Task_EvolutionScene"]                        = 0x08000318,
			["gSaveBlock1ptr"]                             = 0x0800031c,
			["gSaveBlock3"]                                = 0x08000320,
			["gTasks"]                                     = 0x08000324,
			["gMapHeader"]                                 = 0x08000328,
			["estats"]                                     = 0x0800032c, -- gEnemyParty
			["pstats"]                                     = 0x08000330, -- gPlayerParty
			["gBattleResults"]                             = 0x08000334,
			["gBattleMoves"]                               = 0x08000338,
			["gBaseStats"]                                 = 0x0800033c, -- gSpeciesInfo
			["sEvoStructPtr"]                              = 0x08000340,
			["sMonSummaryScreen"]                          = 0x08000344,
			["gBattleStructPtr"]                           = 0x08000348, -- gBattleStruct
			["gExperienceTables"]                          = 0x0800034c,
			["gMultiUsePlayerCursor"]                      = 0x08000350,
			["sSpecialFlags"]                              = sSpecialFlagsPtr,
			["gSpecialVar_Result"]                         = 0x08000358,
			["gTrainerBattleOpponent_A"]                   = 0x0800035c,
			["gSpecialVar_ItemId"]                         = 0x08000360,
			["sBattlerAbilities"]                          = 0x08000364,
			["sStartMenuWindowId"]                         = 0x08000368,
			["FriendshipRequiredToEvo"]                    = 0x0800036c,
			["gBattleTerrain"]                             = 0x08000370,
			["gMoveToLearn"]                               = 0x08000374,
			["gPlayerPartyCount"]                          = 0x08000378,
			["sTMHMMoves"]                                 = 0x08000380,
		}

		for setting, ptrAddr in pairs(pointers) do
			local address = Memory.readdword(ptrAddr);
			GameSettings[setting] = address
		end

		GameSettings.roguemon = {
			romCompat                 = 0x08000200,
			romUid                    = 0x08000175,

			-- these are offset from SaveBlock1Addr + GameSettings.gameVarsOffset
			varType                   = 0x5c,
			varAscension              = 0x5e,
			varCurse                  = 0x7e,
			varMilestone              = 0x82,

			-- these are offset from SaveBlock2Addr
			optionsRoguemonRules      = 0x15, -- bit flag at 1 << 5; 0=Unenforced, 1=Enforced (default)

			-- these are offset from SaveBlock3
			ascensionTypeStats        = 0x73e4,

			-- these are offset from sSpecialFlags, in bits
			flagAwaitingRandomization = 0x2,
			flagBackToTower           = 0x3,
			flagSentToTower           = 0x4,

			-- these are offset from gRoguemonTrackerData
			queuedMoveLearn           = 0xa,
		}

		local roguemonSettingPointers = {
			["gRoguemonTrackerData"]                      = 0x08000384,
		}

		for setting, ptrAddr in pairs(roguemonSettingPointers) do
			local address = Memory.readdword(ptrAddr);
			GameSettings.roguemon[setting] = address
		end
	end

	function self.getROMCompatVersion()
		return Memory.readbyte(GameSettings.roguemon.romCompat)
	end

	function self.setROMAscension()
		self.writeGameVar(GameSettings.roguemon.varAscension, self.ascensionLevel())
	end

	function self.triggerROMLearnMove(moveId)
		local addr = GameSettings.roguemon.gRoguemonTrackerData + GameSettings.roguemon.queuedMoveLearn
		Memory.writeword(addr, moveId)
	end

	-- Gets the address of the attempts byte for the given ascension and
	-- typeIndex.
	function self.getAttemptsAddr(ascension, typeIndex)
		local roguemonStatsStructSize = 8
		local GS = GameSettings
		local ascensionIndex = ascension - 1
		-- attempts is the first DWORD in the struct
		return GS.gSaveBlock3 + GS.roguemon.ascensionTypeStats + (roguemonStatsStructSize * (ascensionIndex * 19 + typeIndex))
	end

	-- Reads the ROM attempts count for the given ascension and typeIndex.
	function self.getROMAttempts(ascension, typeIndex)
		return Memory.readdword(self.getAttemptsAddr(ascension, typeIndex))
	end

	-- Writes the attempts count for the given ascension and typeIndex.
	function self.writeROMAttempts(ascension, typeIndex, attempts)
		return Memory.writedword(self.getAttemptsAddr(ascension, typeIndex), attempts)
	end

	function self.getWinsAddr(ascension, typeIndex)
		return self.getAttemptsAddr(ascension, typeIndex) + 4;
	end

	function self.writeROMWins(ascension, typeIndex, wins)
		return Memory.writedword(self.getWinsAddr(ascension, typeIndex), wins)
	end

	-- Read rules enforcement state from the ROM. Set in game options menu.
	function self.getRulesEnforcement()
		local saveBlock2Addr = Utils.getSaveBlock2Addr()

		local options = Memory.readbyte(saveBlock2Addr + GameSettings.roguemon.optionsRoguemonRules)
		enforceRules = Utils.getbits(options, 5, 1) ~= 0
	end

	function self.updateFriendshipValues()
		local friendshipRequired = Memory.readbyte(GameSettings.FriendshipRequiredToEvo) + 1
		if friendshipRequired > 1 and friendshipRequired ~= Program.GameData.FriendshipRequiredToEvo then
			Program.GameData.friendshipRequired = friendshipRequired
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

	local hauntingResponses = {
		["Poison Barb"] = function()
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatus, 0x08)
			return "The Poltergeist has poisoned you"
		end,
		["Charcoal"] = function()
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatus, 0x10)
			return "The Poltergeist has burned you"
		end,
		["NeverMeltIce"] = function()
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatus, 0x20)
			return "The Poltergeist has frozen you"
		end,
		["TwistedSpoon"] = function()
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatus, math.random(4) + 1)
			return "The Poltergeist has put you to sleep"
		end,
		["Magnet"] = function()
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatus, 0x40)
			return "The Poltergeist has paralyzed you"
		end,
		["Hard Stone"] = function() 
			local evs = self.getEVs()
			evs["spe"] = math.max(evs["spe"] - 20, 0)
			self.setEVs(evs)
			self.recalculateStats()
			return "The Poltergeist has reduced your Speed EVs by 20"
		end,
		["Spell Tag"] = function()
			local pkmn = self.readLeadPokemonData()
			local pp1 = Utils.getbits(pkmn.attack3, 0, 8)
			local pp2 = Utils.getbits(pkmn.attack3, 8, 8)
			local pp3 = Utils.getbits(pkmn.attack3, 16, 8)
			local pp4 = Utils.getbits(pkmn.attack3, 24, 8)
			ppValues = {pp1, pp2, pp3, pp4}
			pkmn.attack3 = math.max(pp1 - 2, 0) + Utils.bit_lshift(math.max(pp2 - 2, 0), 8)  + Utils.bit_lshift(math.max(pp3 - 2, 0), 16) + Utils.bit_lshift(math.max(pp4 - 2, 0), 24)
			self.writeLeadPokemonData(pkmn)
			return "The Poltergeist has reduced your moves' PP by 2"
		end,
		["Silk Scarf"] = function()
			haunted["Confusion"] = true
			return "The Poltergeist has confused you in your next fight"
		end,
		["Black Belt"] = function()
			local pokeInfo = Tracker.getPokemon(1)
			local atkToDed = 0
			local spaToDed = 0
			if pokeInfo.stats['atk'] > pokeInfo.stats['spa'] then
				atkToDed = 20
			elseif pokeInfo.stats['atk'] < pokeInfo.stats['spa'] then
				spaToDed = 20
			else
				atkToDed = 10
				spaToDed = 10
			end
			local evs = self.getEVs()
			evs["atk"] = math.max(evs["atk"] - atkToDed, 0)
			evs["spa"] = math.max(evs["spa"] - spaToDed, 0)
			self.setEVs(evs)
			self.recalculateStats()
			if atkToDed == 20 then
				return "The Poltergeist has reduced your Attack EVs by 20"
			elseif spaToDed == 20 then
				return "The Poltergeist has reduced your Sp. Atk EVs by 20"
			else
				return "The Poltergeist has reduced your Attack and Sp. Atk EVs by 10"
			end
		end,
		["Dragon Fang"] = function() 
			local pkmn = self.readLeadPokemonData()
			local pokeInfo = Tracker.getPokemon(1)
			local cur, tot = Program.getNextLevelExp(pokeInfo.pokemonID, pokeInfo.level, pokeInfo.experience) 
			pkmn.growth2 = pokeInfo.experience - cur
			self.writeLeadPokemonData(pkmn)
			return "The Poltergeist has reduced your experience"
		end,
		["Miracle Seed"] = function()
			haunted["Leech Seed"] = true
			return "The Poltergeist has Leech Seeded you in your next fight"
		end,
		["BlackGlasses"] = function()
			Program.updateBagItems()
			local ppHealHierarchy = {
				[34] = 0, [138] = 1, [35] = 2, [36] = 3, [37] = 4
			}
			local smallestHeal = nil
			for itemID, quantity in pairs(Program.GameData.Items.PPHeals or {}) do
				if (not smallestHeal) or ppHealHierarchy[itemID] < ppHealHierarchy[smallestHeal] then
					smallestHeal = itemID
				end
			end
			if smallestHeal then
				local itemLost = TrackerAPI.getItemName(smallestHeal)
				self.removeItem(itemLost, 1)
				return "The Poltergeist has stolen a " .. itemLost
			end
		end,
		["FairyFeather"] = function()
			haunted["2 Prize Options"] = true
			return "The Poltergeist has reduced your prize options at the next milestone"
		end,
		["Mystic Water"] = function()
			Program.updateBagItems()
			local possibleToRemove = {}
			for itemID, quantity in pairs(Program.GameData.Items.StatusHeals or {}) do
				if MiscData.StatusItems[itemID] and not (MiscData.StatusItems[itemID].type == MiscData.StatusType.All) then
					possibleToRemove[#possibleToRemove + 1] = itemID
				end
			end
			if #possibleToRemove > 0 then
				local itemLost = TrackerAPI.getItemName(possibleToRemove[math.random(#possibleToRemove)])
				self.removeItem(itemLost, 1)
				return "The Poltergeist has stolen a " .. itemLost
			end
		end,
		["SilverPowder"] = function()
			Program.updateBagItems()
			local smallestHeal = nil
			for itemID, quantity in pairs(Program.GameData.Items.HPHeals or {}) do
				if (not smallestHeal) or (MiscData.HealingItems[itemID] and MiscData.HealingItems[itemID].amount < MiscData.HealingItems[smallestHeal].amount) then
					smallestHeal = itemID
				end
			end
			if smallestHeal then
				local itemLost = TrackerAPI.getItemName(smallestHeal)
				self.removeItem(itemLost, 1)
				return "The Poltergeist has stolen a " .. itemLost
			end
		end,
		["Sharp Beak"] = function()
			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			local currentHP = Utils.getbits(lvCurHp, 16, 16)
			currentHP = currentHP - math.floor(maxHP / 8 + 0.5)
			if currentHP < 1 then
				currentHP = 1
			end
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
			return "The Poltergeist has damaged you"
		end,
		["Metal Coat"] = function() 
			hpCap = hpCap - 20
			hpCapModifier = hpCapModifier - 20
			return "The Poltergeist has reducecd your HP cap by 20"
		end,
		["Soft Sand"] = function()
			local pkmn = self.readLeadPokemonData()
			local ivs = Utils.convertIVNumberToTable(pkmn.misc2)
			for st,iv in pairs(ivs) do
				if iv > 0 then
					ivs[st] = iv - 1
				end
			end
			pkmn.misc2 = Utils.bit_lshift(Utils.getbits(pkmn.misc2, 30, 2), 30) +
				ivs['hp'] + Utils.bit_lshift(ivs['atk'], 5) + Utils.bit_lshift(ivs['def'], 10) + 
				Utils.bit_lshift(ivs['spe'], 15) + Utils.bit_lshift(ivs['spa'], 20) + Utils.bit_lshift(ivs['spd'], 25)
			self.writeLeadPokemonData(pkmn)
			self.recalculateStats()

			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			local currentHP = Utils.getbits(lvCurHp, 16, 16)
			if currentHP > maxHP then
				currentHP = maxHP
				Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
			end
			
			return "The Poltergeist has reduced your IVs by 1"
		end,
	}

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

	function self.uponItemAdded(item)
		self.countAdjustedHeals()
		if RoguemonOptions["Show reminders"] and item == "RogueStone" and not TrackerAPI.hasDefeatedTrainer(414) and not givenMoonStoneNotification then
			givenMoonStoneNotification = true
			return "Brock says: Nice stone. Unfortunately, you'll need to defeat me if you want to use it!", "brock.png", nil
		end
		if RoguemonOptions["Show reminders"] then
			local itemId = self.getItemId(item)
			if notifyOnPickup.consumables[item] and not (specialRedeems.unlocks["Berry Pouch"] and string.sub(item, string.len(item)-4, string.len(item)) == "Berry")
			and not (specialRedeems.unlocks["Cooler Bag"] and item == "Berry Juice") then
				self.NotificationScreen.queuedAuxiliary = self.NotificationScreen.auxiliaryButtonInfo["EquipTrashPickup"]
				self.NotificationScreen.itemInQuestion = item
				if notifyOnPickup.consumables[item] == 2 and not (self.getActiveCurse() == "Kaizo Curse") then
					return (item .. " must be used, equipped, or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
				else
					return (item .. " must be equipped or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
				end
			elseif notifyOnPickup.vitamins[item] then
				self.NotificationScreen.queuedAuxiliary = self.NotificationScreen.auxiliaryButtonInfo["TrashPickup"]
				self.NotificationScreen.itemInQuestion = item
				return (item .. " must be used or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
			elseif notifyOnPickup.candies[item] and not specialRedeems.unlocks["Candy Jar"] then
				if item == "PP Max" and gymMapIds[TrackerAPI.getMapId()] then
					return ("Tutor first, then PP Max!"), "supernerd.png", function() return self.itemNotPresent(itemId) end
				else
					return (item .. " must be used or trashed"), item .. ".png", function() return self.itemNotPresent(itemId) end
				end
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
			if committed or item == "RogueStone" then
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
						local notif = {message = s, image = img, dismissFunction = dismissFunc}
						if self.NotificationScreen.queuedAuxiliary then
							notif.queuedAuxiliary = self.NotificationScreen.queuedAuxiliary
							notif.itemInQuestion = self.NotificationScreen.itemInQuestion
						end
						suppressedNotifications[#suppressedNotifications + 1] = {message = s, image = img, dismissFunction = dismissFunc}
						self.NotificationScreen.queuedAuxiliary = nil
						self.NotificationScreen.itemInQuestion = nil
					end
				end
			end
		end
		if specialRedeems.consumable["Duplicator"] and TrackerAPI.getMapId() ~= 10 and TrackerAPI.getMapId() ~= 193 then
			local msg = true
			for _,itm in pairs(itemsFromPrize) do
				if itm == item then
					msg = false
				end
			end
			if msg and (MiscData.HealingItems[itemId] or MiscData.StatusItems[itemId] or MiscData.PPItems[itemId] or item == "PP Up" or item == "PP Max") and not
			((not specialRedeems.unlocks["Berry Pouch"]) and (string.sub(item, string.len(item)-4, string.len(item)) == "Berry") and MiscData.HealingItems[itemId]) then
				self.offerBinaryOption("Duplicate " .. item, "Skip")
			end
		end
		if haunted then
			local response = hauntingResponses[item]
			if response then
				local message = response()
				if message then
					self.displayNotification(message, "ghost.png", nil)
				end
			end
		end
	end

	function self.useChargedRedeem(redeemName)
		if redeemName == "Pocket Sand" and Battle.inBattle then
			self.setStatStages(1, {["acc"] = 0})
			return true
		end

		if redeemName == "Tera Orb" and Battle.inBattle then
			local tp = specialRedeems.internal["Tera Type"]
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes, tp)
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + 1, tp)
			return true
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
				self.saveData()
				return true
			end
		end
		return false
	end

	function self.ascensionLevel()
		if RoguemonOptions["Ascension"] == "Auto" then
			_, ascension, _ = self.getRomStamp()
			return ascension
		else
			return tonumber(RoguemonOptions["Ascension"])
		end
	end

	function self.undoCurse(curse)
		if curse == "Debilitation" then
			local pkmn = self.readLeadPokemonData()
			local ivs = Utils.convertIVNumberToTable(pkmn.misc2)
			ivs['atk'] = savedIVs['atk']
			ivs['spa'] = savedIVs['spa']
			savedIVs['atk'] = nil
			savedIVs['spa'] = nil
			pkmn.misc2 = Utils.bit_lshift(Utils.getbits(pkmn.misc2, 30, 2), 30) +
				ivs['hp'] + Utils.bit_lshift(ivs['atk'], 5) + Utils.bit_lshift(ivs['def'], 10) + 
				Utils.bit_lshift(ivs['spe'], 15) + Utils.bit_lshift(ivs['spa'], 20) + Utils.bit_lshift(ivs['spd'], 25)
			self.writeLeadPokemonData(pkmn)
			self.recalculateStats()
		end
		if curse == "Time Warp" then
			local pkmn = self.readLeadPokemonData()
			local pkInfo = Tracker.getPokemon(1)

			local targetLevel = pkInfo.level
			local targetExp = pkInfo.experience + timeWarpedExp
			local growthRateIndex = Memory.readbyte(GameSettings.gBaseStats + (pkInfo.pokemonID * Program.Addresses.sizeofBaseStatsPokemon) + Program.Addresses.offsetGrowthRateIndex)
			local expTableOffset = GameSettings.gExperienceTables + (growthRateIndex * Program.Addresses.sizeofExpTablePokemon) + (targetLevel * Program.Addresses.sizeofExpTableLevel)
			local expAtLv = Memory.readdword(expTableOffset)
			while expAtLv < targetExp do
				targetLevel = targetLevel + 1
				expTableOffset = GameSettings.gExperienceTables + (growthRateIndex * Program.Addresses.sizeofExpTablePokemon) + (targetLevel * Program.Addresses.sizeofExpTableLevel)
				expAtLv = Memory.readdword(expTableOffset)
			end
			targetLevel = targetLevel - 1
			local level_and_currenthp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.bit_lshift(Utils.getbits(level_and_currenthp, 16, 16), 16) + targetLevel) 

			pkmn.growth2 = targetExp

			self.writeLeadPokemonData(pkmn)
			self.addUpdateCounter("Recalculate Time Warp Stats", 2, self.recalculateStats, 1) 

			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			local currentHP = Utils.getbits(lvCurHp, 16, 16)
			self.hpMissing = maxHP - currentHP
			self.addUpdateCounter("Readjust Time Warp HP", 4, function()
				local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
				local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
				local currentHP = Utils.getbits(lvCurHp, 16, 16)
				currentHP = maxHP - self.hpMissing
				Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
			end, 1)
		end
		if curseInfo[curse].romCurse then
			self.romCurseOff(curseInfo[curse].romCurse)
		end
	end

	function self.getItemsInCurrentSegment()
		local segInfo = segments[segmentOrder[currentSegment]]
		local prevSegInfo = nil
		if segmentOrder[currentSegment - 1] then
			prevSegInfo = segments[segmentOrder[currentSegment - 1]]
		end
		local addrList = {}
		if segmentStarted then
			if segInfo["items"] then
				for _,itm in pairs(segInfo["items"]) do
					addrList[#addrList + 1] = itm
				end
			end
		else
			if segInfo["itemsBefore"] then
				for _,itm in pairs(segInfo["itemsBefore"]) do
					addrList[#addrList + 1] = itm
				end
			end
			if prevSegInfo and prevSegInfo["items"] then
				for _,itm in pairs(prevSegInfo["items"]) do
					addrList[#addrList + 1] = itm
				end
			end
		end
		local count = 0
		local saveBlock1Addr = Utils.getSaveBlock1Addr()
		for _,addr in pairs(addrList) do
			local itemAddrOffset = math.floor(addr / 8)
			local itemBit = addr % 8
			if Utils.getbits(Memory.readbyte(saveBlock1Addr + GameSettings.gameFlagsOffset + itemAddrOffset), itemBit, 1) == 0 then
				count = count + 1
			end
		end
		return count
	end

	-- Marks all of the trainers for the given segment as defeated in the ROM, such that
	-- players don't accidentally fight trainers from past segments when backtracking.
	function self.nullifyTrainers(segment)
		local segInfo = segments[segmentOrder[segment]]
		local flagBytes = {}

		local saveBlock1Addr = Utils.getSaveBlock1Addr()

		for _,trainerId in pairs(segInfo["trainers"]) do
			-- largely copied from Program.hasDefeatedTrainer

			local idAddrOffset = math.floor((Program.Addresses.offsetTrainerFlagStart + trainerId) / 8)
			local idBit = (Program.Addresses.offsetTrainerFlagStart + trainerId) % 8
			local trainerFlagAddr = saveBlock1Addr + GameSettings.gameFlagsOffset + idAddrOffset

			if not flagBytes[trainerFlagAddr] then
				flagBytes[trainerFlagAddr] = Memory.readbyte(trainerFlagAddr)
			end

			flagBytes[trainerFlagAddr] = Utils.bit_or(flagBytes[trainerFlagAddr], Utils.bit_lshift(1, idBit))
		end

		for addr, flags in pairs(flagBytes) do
			Memory.writebyte(addr, flags)
		end
	end

	-- Move to the next segment.
	function self.nextSegment()
		local curse = self.getActiveCurse()
		if curse then
			self.resetTheme()
			self.undoCurse(curse)
		end
		if trainersDefeated < self.getSegmentTrainerCount(currentSegment) then
			if curse == "Claustrophobia" then
				hpCap = hpCap - 50
				hpCapModifier = hpCapModifier - 50
			end
			if curse == "Downsizing" then
				downsized = true
			end
			if curse == "Poltergeist" then
				haunted = {}
			end
		end

		if enforceRules then
			self.nullifyTrainers(currentSegment)
		end

		for c,info in pairs(specialRedeems.battle) do
			if specialRedeemInfo[c] and specialRedeemInfo[c].charges and specialRedeemInfo[c].charges == -1 then
				specialRedeems[c] = -1
			end
		end

		rivalCombined = false
		if segmentOrder[currentSegment + 1] and string.sub(segmentOrder[currentSegment + 1], 1, 5) == "Rival" and (self.ascensionLevel() > 2) then
			rivalCombined = true
			for _,tid in pairs(segments[segmentOrder[currentSegment + 1]]["trainers"]) do
				if defeatedTrainerIds[tid] then
					rivalCombined = false
				end
			end
			if rivalCombined then
				for _,tid in pairs(segments[segmentOrder[currentSegment + 1]]["trainers"]) do
					segments[segmentOrder[currentSegment + 2]]["trainers"][#segments[segmentOrder[currentSegment + 2]]["trainers"] + 1] = tid
				end
				for _,tid in pairs(segments[segmentOrder[currentSegment + 1]]["mandatory"]) do
					segments[segmentOrder[currentSegment + 2]]["mandatory"][#segments[segmentOrder[currentSegment + 2]]["mandatory"] + 1] = tid
				end
				segments[segmentOrder[currentSegment + 2]]["rival"] = true
				for _,rid in pairs(segments[segmentOrder[currentSegment + 1]]["routes"]) do
					segments[segmentOrder[currentSegment + 2]]["routes"][#segments[segmentOrder[currentSegment + 2]]["routes"] + 1] = rid
				end
			end
			currentSegment = currentSegment + 1
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
			runSummary[#runSummary + 1] = {
				type = "Curse",
				curse = curse,
				title = segmentOrder[currentSegment]
			}
			if RoguemonOptions["Alternate Curse theme"] then
				local t = Theme.exportThemeToText()
				if t ~= CURSE_THEME then
					previousTheme = t
				end
				Theme.importThemeFromText(CURSE_THEME, true)
			end
			local curseNotif = "Curse: " .. curse .. " @ " .. self.getCurseDescription(curse)
			if curse == "High Pressure" then
				local pkmn = self.readLeadPokemonData()
				local pp1 = Utils.getbits(pkmn.attack3, 0, 8)
				local pp2 = Utils.getbits(pkmn.attack3, 8, 8)
				local pp3 = Utils.getbits(pkmn.attack3, 16, 8)
				local pp4 = Utils.getbits(pkmn.attack3, 24, 8)
				ppValues = {pp1, pp2, pp3, pp4}
				pkmn.attack3 = pp1/2 + Utils.bit_lshift(pp2/2, 8)  + Utils.bit_lshift(pp3/2, 16) + Utils.bit_lshift(pp4/2, 24)
				self.writeLeadPokemonData(pkmn)
			end
			if curse == "Debilitation" then
				local iMon = Tracker.getPokemon(1)
				local iAtk = iMon.stats['atk']
				local iSpa = iMon.stats['spa']
				local pkmn = self.readLeadPokemonData()
				local ivs = Utils.convertIVNumberToTable(pkmn.misc2)
				savedIVs['atk'] = ivs['atk']
				savedIVs['spa'] = ivs['spa']
				ivs['atk'] = 0
				ivs['spa'] = 0
				pkmn.misc2 = Utils.bit_lshift(Utils.getbits(pkmn.misc2, 30, 2), 30) +
					ivs['hp'] + Utils.bit_lshift(ivs['atk'], 5) + Utils.bit_lshift(ivs['def'], 10) + 
					Utils.bit_lshift(ivs['spe'], 15) + Utils.bit_lshift(ivs['spa'], 20) + Utils.bit_lshift(ivs['spd'], 25)
				self.writeLeadPokemonData(pkmn)
				local newStats = self.recalculateStats()
				local fAtk = newStats['atk']
				local fSpa = newStats['spa']
				curseNotif = curseNotif .. " @ ATK: " .. iAtk .. " -> " .. fAtk .. " @ " .. "SPA: " .. iSpa .. " -> " .. fSpa
			end
			if curse == "Time Warp" then
				local pkmn = self.readLeadPokemonData()
				local pkInfo = Tracker.getPokemon(1)
				local currentLevel = pkInfo.level
				local targetLevel = currentLevel

				timeWarpedExp = math.floor(pkInfo.experience * 0.25)

				local targetExp = pkInfo.experience - timeWarpedExp
				local growthRateIndex = Memory.readbyte(GameSettings.gBaseStats + (pkInfo.pokemonID * Program.Addresses.sizeofBaseStatsPokemon) + Program.Addresses.offsetGrowthRateIndex)
				local expTableOffset = GameSettings.gExperienceTables + (growthRateIndex * Program.Addresses.sizeofExpTablePokemon) + (targetLevel * Program.Addresses.sizeofExpTableLevel)
				local expAtLv = Memory.readdword(expTableOffset)
				while expAtLv > targetExp do
					targetLevel = targetLevel - 1
					expTableOffset = GameSettings.gExperienceTables + (growthRateIndex * Program.Addresses.sizeofExpTablePokemon) + (targetLevel * Program.Addresses.sizeofExpTableLevel)
					expAtLv = Memory.readdword(expTableOffset)
				end

				local level_and_currenthp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
				Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.bit_lshift(Utils.getbits(level_and_currenthp, 16, 16), 16) + targetLevel) 

				pkmn.growth2 = pkInfo.experience - timeWarpedExp

				self.writeLeadPokemonData(pkmn)
				self.addUpdateCounter("Recalculate Time Warp Stats", 2, self.recalculateStats, 1) 
				self.addUpdateCounter("Adjust Time Warp HP", 4, function()
					local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
					local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
					local currentHP = Utils.getbits(lvCurHp, 16, 16)
					if currentHP > maxHP then
						currentHP = maxHP
						Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
					end
				end, 1)
			end
			if curseInfo[curse].romCurse then
				self.romCurseOn(curseInfo[curse].romCurse)
			end
			if curse == "David vs Goliath" then
				local tids = {}
				for i,t in segments[segmentOrder[currentSegment]]["trainers"] do
					tids[i] = t
				end
				for i = 0,2 do
					local t = table.remove(tids, math.random(#tids))
					Memory.writeword(0x0203c7e4 + (i*2), t)
				end
			end
			self.displayNotification(curseNotif, "Curse.png", nil)
		end
	end

	function self.wardCurse()
		self.removeSpecialRedeem("Warding Charm")
		local summaryItem = runSummary[#runSummary]
		if summaryItem.type == "Curse" then
			summaryItem.title = summaryItem.title .. " (Warded)"
		end
		if self.getActiveCurse() == "High Pressure" then
			local pkmn = self.readLeadPokemonData()
			pkmn.attack3 = ppValues[1] + Utils.bit_lshift(ppValues[2], 8)  + Utils.bit_lshift(ppValues[3], 16) + Utils.bit_lshift(ppValues[4], 24)
			self.writeLeadPokemonData(pkmn)
		end
		self.undoCurse(self.getActiveCurse())
		if self.getActiveCurse() == "Time Warp" then
			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			local currentHP = Utils.getbits(lvCurHp, 16, 16)
			self.hpMissing = maxHP - currentHP
			self.addUpdateCounter("Readjust Time Warp HP", 4, function()
				local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
				local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
				local currentHP = Utils.getbits(lvCurHp, 16, 16)
				currentHP = maxHP - self.hpMissing
				Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
			end, 1)
		end
		cursedSegments[currentSegment] = "Warded"
		self.resetTheme()
		self.returnToHomeScreen()
		self.saveData()
	end

	function self.romCurseOn(curse)
		local newVal = self.readGameVar(GameSettings.roguemon.varCurse) | curse
		self.writeGameVar(GameSettings.roguemon.varCurse, newVal)
	end

	function self.romCurseOff(curse)
		local newVal = self.readGameVar(GameSettings.roguemon.varCurse) & ~curse
		self.writeGameVar(GameSettings.roguemon.varCurse, newVal)
	end

	-- Determine if a particular segment has been reached yet
	function self.reachedSegment(seg)
		for i = 1,currentSegment do
			if segmentOrder[i] == seg then 
				return true 
			end
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

	function self.isNextSegmentRivalDefeated()
		if segmentOrder[currentSegment + 1] and string.sub(segmentOrder[currentSegment + 1], 1, 5) == "Rival" then
			for _,tid in pairs(segments[segmentOrder[currentSegment + 1]]['trainers']) do
				if defeatedTrainerIds[tid] then
					return true
				end
			end
		end
		return false
	end

	-- TRACKER SCREENS --

	-- Main screen for spinning and selecting rewards.
    self.RewardScreen = {

	}

    self.RewardScreen.Colors = {
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

    function self.RewardScreen.drawScreen()
		local canvas = {
			x = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN,
			y = Constants.SCREEN.MARGIN,
			w = Constants.SCREEN.RIGHT_GAP - (Constants.SCREEN.MARGIN * 2),
			h = Constants.SCREEN.HEIGHT - (Constants.SCREEN.MARGIN * 2),
			text = Theme.COLORS[self.RewardScreen.Colors.text],
			border = Theme.COLORS[self.RewardScreen.Colors.border],
			fill = Theme.COLORS[self.RewardScreen.Colors.fill],
			shadow = Utils.calcShadowColor(Theme.COLORS[self.RewardScreen.Colors.fill]),
		}
		Drawing.drawBackgroundAndMargins()
		gui.defaultTextBackground(canvas.fill)

		gui.drawRectangle(canvas.x, canvas.y, canvas.w, canvas.h, canvas.border, canvas.fill)

		for _, button in pairs(self.RewardScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end

		self.drawCapsAt(DataHelper.buildTrackerScreenDisplay(), Constants.SCREEN.WIDTH + 45, 5)

		-- Draw the images
		if option1 ~= "" then
			Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. prize_images[option1], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y, IMAGE_WIDTH, BUTTON_HEIGHT)
		end
		if option2 ~= "" then
			Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. prize_images[option2], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, IMAGE_WIDTH, BUTTON_HEIGHT)
		end
		if option3 ~= "" then
			Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. prize_images[option3], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP*2 + BUTTON_HEIGHT*2, IMAGE_WIDTH, BUTTON_HEIGHT)
		end
	end

	self.RewardScreen.Buttons = {
		-- Option buttons
		Option1 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(option1, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				self.selectReward(option1)
			end,
			isVisible = function() return option1 ~= "" end
		},
		Option2 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(option2, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			onClick = function()
				self.selectReward(option2)
			end,
			isVisible = function() return option2 ~= "" end
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
				self.returnToHomeScreen()
				milestone = milestone + 1
				self.spinReward(milestones[milestone]['name'], true)
			end,
			isVisible = function() return DEBUG_MODE end,
			boxColors = {"Default text"}
		},
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 108, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
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
	function self.RewardScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.RewardScreen.Buttons or {})
	end

	-- Screen for selecting an additional option.
	self.OptionSelectionScreen = {
		
	}

	-- Layout constants
	local OSS_LEFT_TOP_LEFT_X = 6
	local OSS_BUTTON_WIDTH = 55
	local OSS_BUTTON_HORIZONTAL_GAP = 6
	local OSS_TOP_BUTTON_Y = 22
	local OSS_BUTTON_HEIGHT = 32
	local OSS_BUTTON_SHORT_HEIGHT = 22
	local OSS_BUTTON_VERTICAL_GAP = 10
	local OSS_WRAP_BUFFER = 2

    function self.OptionSelectionScreen.drawScreen()
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

		if additionalOptions[7] and additionalOptions[7] ~= "" then
			for j = 0,3 do
				for i = 0,1 do
					local index = i + j*2 + 1
					self.OptionSelectionScreen.Buttons[index].box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OSS_LEFT_TOP_LEFT_X + (i*(OSS_BUTTON_WIDTH + OSS_BUTTON_HORIZONTAL_GAP)), 
					OSS_TOP_BUTTON_Y + (j*(OSS_BUTTON_SHORT_HEIGHT + OSS_BUTTON_VERTICAL_GAP)), OSS_BUTTON_WIDTH, OSS_BUTTON_SHORT_HEIGHT }
				end
			end
		else
			for j = 0,3 do
				for i = 0,1 do
					local index = i + j*2 + 1
					self.OptionSelectionScreen.Buttons[index].box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OSS_LEFT_TOP_LEFT_X + (i*(OSS_BUTTON_WIDTH + OSS_BUTTON_HORIZONTAL_GAP)), 
					OSS_TOP_BUTTON_Y + (j*(OSS_BUTTON_HEIGHT + OSS_BUTTON_VERTICAL_GAP)), OSS_BUTTON_WIDTH, OSS_BUTTON_HEIGHT }
				end
			end
		end

		if (not additionalOptions[3]) or (additionalOptions[3] == "") then
			self.drawCapsAt(DataHelper.buildTrackerScreenDisplay(), Constants.SCREEN.WIDTH + 10, 120)
		end

		for _, button in pairs(self.OptionSelectionScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	self.OptionSelectionScreen.Buttons = {
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
		}
	}

	-- Create the 2x4 grid of buttons
	for j = 0,3 do
		for i = 0,1 do
			local index = i + j*2 + 1
			self.OptionSelectionScreen.Buttons[index] = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() 
					return (additionalOptionsRemaining > 0) and self.wrapPixelsInline(additionalOptions[index], OSS_BUTTON_WIDTH - OSS_WRAP_BUFFER) or ""
				end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OSS_LEFT_TOP_LEFT_X + (i*(OSS_BUTTON_WIDTH + OSS_BUTTON_HORIZONTAL_GAP)), 
				OSS_TOP_BUTTON_Y + (j*(OSS_BUTTON_HEIGHT + OSS_BUTTON_VERTICAL_GAP)), OSS_BUTTON_WIDTH, OSS_BUTTON_HEIGHT },
				onClick = function()
					self.selectAdditionalOption(additionalOptions[index])
				end,
				isVisible = function()
					return additionalOptions[index] and additionalOptions[index] ~= "" -- Visible as long as it has text
				end,
				boxColors = {"Default text"}
			}
		end
	end

	function self.OptionSelectionScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.OptionSelectionScreen.Buttons or {})
	end

	function self.offerBinaryOption(opt1, opt2)
		additionalOptions[1] = opt1
		additionalOptions[2] = opt2
		for i = 3,8 do
			additionalOptions[i] = ""
		end
		additionalOptionsRemaining = 1
		self.readyScreen(self.OptionSelectionScreen)
	end

	-- Screen for showing the special redeems
	self.SpecialRedeemScreen = {
		
	}

    -- Layout constants
	local SRS_TOP_LEFT_X = 6
	local SRS_TEXT_WIDTH = 115
	local SRS_TOP_Y = 22
	local SRS_WRAP_BUFFER = 7
	local SRS_HORIZONTAL_GAP = 6
	local SRS_BUTTON_WIDTH = 10
	local SRS_USE_BUTTON_WIDTH = 17
	local SRS_BUTTON_HEIGHT = 10
	local SRS_LINE_HEIGHT = 10
	local SRS_LINE_COUNT = 8
	local SRS_DESC_WIDTH = 105

    function self.SpecialRedeemScreen.drawScreen()
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
		Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, 10, "Inventory", Theme.COLORS["Default text"])

		-- Display image, if any
		if specialRedeemToDescribe then
			Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. specialRedeemInfo[specialRedeemToDescribe].image, canvas.x + SRS_DESC_WIDTH + 2, SRS_TOP_Y + SRS_LINE_COUNT*SRS_LINE_HEIGHT)
		end

		for i = 1,SRS_LINE_COUNT do
			local button = self.SpecialRedeemScreen.Buttons["X" .. i]
			local redeem = (i <= #specialRedeems.battle) and specialRedeems.consumable[i] or specialRedeems.consumable[i-#specialRedeems.unlocks-#specialRedeems.battle]
			button.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X + SRS_TEXT_WIDTH, SRS_TOP_Y + ((i-1)*(SRS_LINE_HEIGHT)), 
			(specialRedeems.battle[i] and specialRedeemInfo[specialRedeems.battle[i]].button == "Use") and SRS_USE_BUTTON_WIDTH or SRS_BUTTON_WIDTH, SRS_BUTTON_HEIGHT }
		end

		for _, button in pairs(self.SpecialRedeemScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	self.SpecialRedeemScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
		},
		-- Description text, works similar to main prize screen
		DescriptionText = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function()
				local toReturn = specialRedeemToDescribe and specialRedeemInfo[specialRedeemToDescribe].description or ""
				-- if we're displaying Potion Investment, grab the actual value of it
				if specialRedeemToDescribe == "Potion Investment" then
					toReturn = toReturn .. " " .. specialRedeems.consumable["Potion Investment"]
				elseif specialRedeemToDescribe == "Midas Touch" then
					toReturn = toReturn .. " (" .. specialRedeems.consumable["Midas Touch"] .. " gained)"
				end
				return  self.wrapPixelsInline(toReturn, SRS_DESC_WIDTH - SRS_WRAP_BUFFER)
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X, SRS_TOP_Y + SRS_LINE_COUNT*SRS_LINE_HEIGHT, SRS_DESC_WIDTH, 70}
		}
	}

	-- Create the row buttons
	for i = 1,SRS_LINE_COUNT do
		-- Delete button
		self.SpecialRedeemScreen.Buttons["X" .. i] = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function()
				local redeem = nil
				if i <= #specialRedeems.battle then
					redeem = specialRedeems.battle[i]
				else
					redeem = specialRedeems.consumable[i-#specialRedeems.unlocks-#specialRedeems.battle]
				end
				if redeem then
					if specialRedeemInfo[redeem].button then
						return specialRedeemInfo[redeem].button
					else
						return "X"
					end
				end
				return ""
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + SRS_TOP_LEFT_X + SRS_TEXT_WIDTH, SRS_TOP_Y + ((i-1)*(SRS_LINE_HEIGHT)), 
			(specialRedeems.battle[i] and specialRedeemInfo[specialRedeems.battle[i]].button == "Use") and SRS_USE_BUTTON_WIDTH or SRS_BUTTON_WIDTH, SRS_BUTTON_HEIGHT },
			onClick = function(this)
				local charges = 0
				local redeemName = nil
				if this.getText() == "Use" then
					redeemName = specialRedeems.battle[i]
					charges = specialRedeems.battle[redeemName] or 0
					if charges > 0 or charges == -1 then
						if self.useChargedRedeem(redeemName) then
							charges = charges - 1
							specialRedeems.battle[redeemName] = charges
						end
					end
					Program.changeScreenView(TrackerScreen)
					if charges == 0 then
						if specialRedeemToDescribe == redeemName then
							specialRedeemToDescribe = nil
						end
						specialRedeems.battle[redeemName] = nil
						table.remove(specialRedeems.battle, i)
					end
				else
					redeemName = specialRedeems.consumable[i-#specialRedeems.unlocks-#specialRedeems.battle]
					if specialRedeemToDescribe == redeemName then
						specialRedeemToDescribe = nil
					end
					specialRedeems.consumable[redeemName] = nil
					table.remove(specialRedeems.consumable, i-#specialRedeems.unlocks-#specialRedeems.battle)
				end
				
				
			end,
			isVisible = function()
				if i <= #specialRedeems.battle then
					local redeem = specialRedeems.consumable[i]
					return not (specialRedeems.consumable[redeem] == -2)
				end
				local redeem = specialRedeems.consumable[i-#specialRedeems.unlocks-#specialRedeems.battle]
				return redeem and not (specialRedeemInfo[redeem].button and specialRedeemInfo[redeem].button == "")
			end,
			boxColors = {"Default text"}
		}

		-- Redeem name button (it's a button because clicking on it brings up the description)
		self.SpecialRedeemScreen.Buttons["Text" .. i] = {
			type = Constants.ButtonTypes.NO_BORDER,
			getText = function() 
				if i <= #specialRedeems.battle then
					return specialRedeems.battle[i]
				elseif i <= #specialRedeems.battle + #specialRedeems.unlocks then 
					return specialRedeems.unlocks[i-#specialRedeems.battle]
				elseif i<= #specialRedeems.battle + #specialRedeems.unlocks + #specialRedeems.consumable then
					return specialRedeems.consumable[i-#specialRedeems.unlocks-#specialRedeems.battle]
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

	function self.SpecialRedeemScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.SpecialRedeemScreen.Buttons or {})
	end

	-- Screen for showing random messages
	self.NotificationScreen = {
		message = "",
		image = nil,
		activeAuxiliary = {},
		queuedAuxiliary = nil,
		itemInQuestion = nil,
		auxiliaryButtonInfo = {
			["Buy Phase"] = {
				{
					name = "Heals",
					onClick = function() 
						HealsInBagScreen.changeTab(HealsInBagScreen.Tabs.All)
						Program.changeScreenView(HealsInBagScreen) 
					end
				}
			},
			["Curse:"] = {
				nil,
				{
					name = "Ward",
					onClick = function()
						self.wardCurse()
					end,
					isVisible = function()
						return specialRedeems.consumable["Warding Charm"]
					end
				}
			},
			["EquipTrashPickup"] = {
				{
					name = "Equip",
					onClick = function()
						local heldItem = Tracker.getPokemon(1, true).heldItem
						self.removeItem(self.NotificationScreen.itemInQuestion)
						if heldItem then
							self.AddItemById(heldItem, 1)
						end
						local pkmn = self.readLeadPokemonData()
						pkmn.growth1 = Utils.getbits(pkmn.growth1, 0, 16) + Utils.bit_lshift(self.getItemId(self.NotificationScreen.itemInQuestion), 16)
						self.writeLeadPokemonData(pkmn)
						self.returnToHomeScreen()
					end
				},
				{
					name = "Trash",
					onClick = function()
						self.removeItem(self.NotificationScreen.itemInQuestion)
						self.returnToHomeScreen()
					end
				}
			},
			["TrashPickup"] = {
				nil,
				{
					name = "Trash",
					onClick = function()
						self.removeItem(self.NotificationScreen.itemInQuestion)
						self.returnToHomeScreen()
					end
				}
			},
			["EquipPickup"] = {
				{
					name = "Equip",
					onClick = function()
						local heldItem = Tracker.getPokemon(1, true).heldItem
						self.removeItem(self.NotificationScreen.itemInQuestion)
						if heldItem then
							self.AddItemById(heldItem, 1)
						end
						local pkmn = self.readLeadPokemonData()
						pkmn.growth1 = Utils.getbits(pkmn.growth1, 0, 16) + Utils.bit_lshift(self.getItemId(self.NotificationScreen.itemInQuestion), 16)
						self.writeLeadPokemonData(pkmn)
						self.returnToHomeScreen()
					end
				},
				nil
			},
			["CurseList"] = {
				{
					name = "",
					onClick = function()
						self.NotificationScreen.queuedAuxiliary = nil
						local curse = self.getActiveCurse()
						if curse then
							if curseInfo[curse].extremelyLongDescription then
								local msgs = {}
								for i,msg in pairs(curseInfo[curse].extremelyLongDescription) do
									msgs[i] = msg
								end
								local msg1 = table.remove(msgs, 1)
								self.NotificationScreen.queuedAuxiliary = self.NotificationScreen.auxiliaryButtonInfo["NextPage"]
								self.NotificationScreen.auxiliaryButtonInfo["NextPage"][2].messages = msgs
								self.displayNotification(msg1, "Curse.png", nil)
							else
								self.displayNotification(curseInfo[curse].longDescription or curseInfo[curse].description, "Curse.png", nil)
							end
						end
					end,
					isVisible = function()
						return self.getActiveCurse()
					end
				},
				nil
			},
			["NextPage"] = {
				nil,
				{
					name = ">",
					onClick = function(this)
						local msg = table.remove(self.NotificationScreen.auxiliaryButtonInfo["NextPage"][2].messages, 1)
						self.displayNotification(msg, nil, nil)
					end,
					isVisible = function()
						return (#self.NotificationScreen.auxiliaryButtonInfo["NextPage"][2].messages > 0)
					end,
					messages = {}
				}
			}
		}
	}

	function self.NotificationScreen.drawScreen()
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

		local textY = 24

		-- Image
		if(self.NotificationScreen.image) then
			Drawing.drawImage(self.NotificationScreen.image, canvas.x + 40, 15, IMAGE_WIDTH*2, IMAGE_WIDTH*2)
			textY = 64
		end

		-- Text
		Drawing.drawText(canvas.x + 10, textY, self.wrapPixelsInline(self.NotificationScreen.message, canvas.w - 20), Theme.COLORS["Default text"])

		local aux = {}
		if self.NotificationScreen.queuedAuxiliary then
			aux = self.NotificationScreen.queuedAuxiliary
		else
			for pre, info in pairs(self.NotificationScreen.auxiliaryButtonInfo) do
				if string.sub(self.NotificationScreen.message, 1, string.len(pre)) == pre then
					aux = info
				end
			end
		end
		self.NotificationScreen.activeAuxiliary = aux
		if aux[1] then
			self.NotificationScreen.Buttons.AuxiliaryButton1.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 20, 143, 
			Utils.calcWordPixelLength(aux[1].name) + 5, 10} 
		end
		if aux[2] then
			local width = Utils.calcWordPixelLength(aux[2].name) + 5
			self.NotificationScreen.Buttons.AuxiliaryButton2.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 120 - width, 143, 
			width, 10} 
		end

		for _, button in pairs(self.NotificationScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	self.NotificationScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
		},
		AuxiliaryButton1 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function()
				local i = self.NotificationScreen.activeAuxiliary[1]
				if i then
					return i.name
				end
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 30, 143, 30, 10},
			onClick = function()
				local i = self.NotificationScreen.activeAuxiliary[1]
				if i then
					return i.onClick()
				end
			end,
			isVisible = function()
				local i = self.NotificationScreen.activeAuxiliary[1]
				if i then
					if i.isVisible then 
						return i.isVisible()
					else
						return true
					end
				end
				return false
			end,
			boxColors = {"Default text"}
		},
		AuxiliaryButton2 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function()
				local i = self.NotificationScreen.activeAuxiliary[2]
				if i then
					return i.name
				end
			end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 90, 143, 30, 10},
			onClick = function()
				local i = self.NotificationScreen.activeAuxiliary[2]
				if i then
					return i.onClick()
				end
			end,
			isVisible = function()
				local i = self.NotificationScreen.activeAuxiliary[2]
				if i then
					if i.isVisible then 
						return i.isVisible()
					else
						return true
					end
				end
				return false
			end,
			boxColors = {"Default text"}
		}
	}

	function self.NotificationScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.NotificationScreen.Buttons or {})
	end

	-- Options screen
	self.RoguemonOptionsScreen = {
		
	}

	local OS_LEFT_X = 10
	local OS_TOP_Y = 12
	local OS_BOX_SIZE = 10
	local OS_BOX_TEXT_GAP = 10
	local OS_BOX_VERTICAL_GAP = 5

	function self.RoguemonOptionsScreen.drawScreen()
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

		if not populatedOptions then
			populatedOptions = true
			for i = 1,#optionsList do
				if optionsList[i].options then
					local runningX = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OS_LEFT_X + Utils.calcWordPixelLength(optionsList[i].text) + 5
					for _, opt in pairs(optionsList[i].options) do
						self.RoguemonOptionsScreen.Buttons[i .. " " .. opt] = {
							type = Constants.ButtonTypes.FULL_BORDER,
							getText = function() return opt end,
							box = {runningX, OS_TOP_Y + i*(OS_BOX_SIZE + OS_BOX_VERTICAL_GAP), Utils.calcWordPixelLength(opt) + 5, OS_BOX_SIZE},
							onClick = function(this)
								self.RoguemonOptionsScreen.Buttons[i .. " " .. RoguemonOptions[optionsList[i].text]].boxColors = {"Default text"}
								self.RoguemonOptionsScreen.Buttons[i .. " " .. RoguemonOptions[optionsList[i].text]].textColor = Theme.COLORS["Default text"]
								this.boxColors = {"Positive text"}
								this.textColor = Theme.COLORS["Positive text"]
								RoguemonOptions[optionsList[i].text] = opt
								Program.redraw(true)
							end,
							boxColors = RoguemonOptions[optionsList[i].text] == opt and {"Positive text"} or {"Default text"},
							textColor = RoguemonOptions[optionsList[i].text] == opt and Theme.COLORS["Positive text"] or Theme.COLORS["Default text"]
						}
						runningX = runningX + Utils.calcWordPixelLength(opt) + 8
					end
				else
					self.RoguemonOptionsScreen.Buttons[i] = {
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
			end
			self.RoguemonOptionsScreen.Buttons.BackButton = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() return "Back" end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
				onClick = function()
					self.returnToHomeScreen()
				end,
				boxColors = {"Default text"}
			}

			self.RoguemonOptionsScreen.Buttons.EditWins = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() return "Edit Wins" end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OS_LEFT_X, OS_TOP_Y + (#optionsList+1)*(OS_BOX_SIZE + OS_BOX_VERTICAL_GAP), 40, 10},
				onClick = function()
					self.editWinsForm()
				end,
				boxColors = {"Default text"}
			}

			self.RoguemonOptionsScreen.Buttons.EditAttempts = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() return "Edit Attempts" end,
				box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OS_LEFT_X + 60, OS_TOP_Y + (#optionsList+1)*(OS_BOX_SIZE + OS_BOX_VERTICAL_GAP), 58, 10},
				onClick = function()
					self.editAttemptsForm()
				end,
				boxColors = {"Default text"}
			}
		end

		for i = 1,#optionsList do
			if optionsList[i].options then
				Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + OS_LEFT_X, OS_TOP_Y + i*(OS_BOX_SIZE + OS_BOX_VERTICAL_GAP),
				optionsList[i].text, Theme.COLORS["Default text"])
			end
		end

		for _, button in pairs(self.RoguemonOptionsScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	self.RoguemonOptionsScreen.Buttons = {
		
	}

	function self.RoguemonOptionsScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.RoguemonOptionsScreen.Buttons or {})
	end

	self.PrettyStatScreen = {
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

	function self.drawPrettyStats(canvas, poke1, poke2, level)
		Drawing.drawImage(Drawing.getImagePath("PokemonIcon", tostring(poke1.pokemonID)), canvas.x + PSS_LEFT_X - IMAGE_CENTERING, PSS_IMAGE_Y)
		Drawing.drawImage(Drawing.getImagePath("PokemonIcon", tostring(poke2.pokemonID)), canvas.x + PSS_RIGHT_X - IMAGE_CENTERING, PSS_IMAGE_Y)
		local dy = 0
		for i = 1,#Constants.OrderedLists.STATSTAGES + 1 do
			local statKey = Constants.OrderedLists.STATSTAGES[i]
			local oldStat = 0
			local newStat = 0
			local statText = ""
			if statKey then
				oldStat = poke1.stats[statKey]
				newStat = poke2.stats[statKey]
				statText = string.upper(statKey)
			else
				oldStat = PokemonData.Pokemon[poke1.pokemonID].bst
				newStat = PokemonData.Pokemon[poke2.pokemonID].bst
				statText = "BST"
			end
			local statDiff = newStat - oldStat
			
			gui.drawRectangle(canvas.x + PSS_STAT_X, PSS_TEXT_Y + dy, PSS_RIGHT_X - PSS_STAT_X + 19, PSS_TEXT_GAP, canvas.border)
			Drawing.drawText(canvas.x + PSS_STAT_X, PSS_TEXT_Y + dy, statText, Theme.COLORS["Default text"])
			Drawing.drawText(canvas.x + PSS_LEFT_X, PSS_TEXT_Y + dy, oldStat, Theme.COLORS["Default text"])
			if statDiff >= 0 then
				Drawing.drawText(canvas.x + PSS_MID_X, PSS_TEXT_Y + dy, "+" .. statDiff, Theme.COLORS["Positive text"])
			elseif statDiff == 0 then
				Drawing.drawText(canvas.x + PSS_MID_X, PSS_TEXT_Y + dy, "+" .. statDiff, Theme.COLORS["Default text"])
			else
				Drawing.drawText(canvas.x + PSS_MID_X, PSS_TEXT_Y + dy, statDiff, Theme.COLORS["Negative text"])
			end
			Drawing.drawText(canvas.x + PSS_RIGHT_X, PSS_TEXT_Y + dy, newStat, Theme.COLORS["Default text"])
			dy = dy + PSS_TEXT_GAP
		end
		Drawing.drawText(canvas.x + PSS_MID_X - 10, PSS_IMAGE_Y + 10, "Lv. " .. level, Theme.COLORS["Default text"])
	end

    function self.PrettyStatScreen.drawScreen()
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

		if self.PrettyStatScreen.oldPoke and self.PrettyStatScreen.newPoke then
			self.drawPrettyStats(canvas, self.PrettyStatScreen.oldPoke, self.PrettyStatScreen.newPoke, self.PrettyStatScreen.newPoke.level)
		end

		for _, button in pairs(self.PrettyStatScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end
	end

	self.PrettyStatScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
		},
	}

	function self.PrettyStatScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.PrettyStatScreen.Buttons or {})
	end

	function self.showPrettyStatScreen(oldmon, newmon)
		self.PrettyStatScreen.oldPoke = oldmon
		self.PrettyStatScreen.newPoke = newmon
		table.insert(screenQueue, 1, self.PrettyStatScreen)
	end

	self.RunSummaryScreen = {
		index = 1,
		option1 = "",
		option2 = "",
		option3 = ""
	}

	function self.RunSummaryScreen.drawScreen()
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

		if #runSummary > 1 and runSummary[1].type == "None" then
			table.remove(runSummary, 1)
		end
		local summaryItem = runSummary[self.RunSummaryScreen.index]
		local title = summaryItem.title
		if summaryItem.type == "Prize" then
			self.RunSummaryScreen.Buttons.Option1.boxColors = {summaryItem.chosen[summaryItem.options[1]] and "Positive text" or "Default text"}
			self.RunSummaryScreen.option1 = summaryItem.options[1]
			Drawing.drawButton(self.RunSummaryScreen.Buttons.Option1)

			self.RunSummaryScreen.Buttons.Option2.boxColors = {summaryItem.chosen[summaryItem.options[2]] and "Positive text" or "Default text"}
			self.RunSummaryScreen.option2 = summaryItem.options[2]
			Drawing.drawButton(self.RunSummaryScreen.Buttons.Option2)

			self.RunSummaryScreen.Buttons.Option3.boxColors = {summaryItem.chosen[summaryItem.options[3]] and "Positive text" or "Default text"}
			self.RunSummaryScreen.option3 = summaryItem.options[3]
			Drawing.drawButton(self.RunSummaryScreen.Buttons.Option3)

			if self.RunSummaryScreen.option1 ~= "" then
				Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. prize_images[self.RunSummaryScreen.option1], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y, IMAGE_WIDTH, BUTTON_HEIGHT)
			end
			if self.RunSummaryScreen.option2 ~= "" then
				Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. prize_images[self.RunSummaryScreen.option2], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, IMAGE_WIDTH, BUTTON_HEIGHT)
			end
			if self.RunSummaryScreen.option3 ~= "" then
				Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. prize_images[self.RunSummaryScreen.option3], canvas.x + TOP_LEFT_X, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP*2 + BUTTON_HEIGHT*2, IMAGE_WIDTH, BUTTON_HEIGHT)
			end
		elseif summaryItem.type == "Curse" then
			-- Image
			local imgName = "Curse.png"
			if summaryItem.title and #summaryItem.title > 8 and string.sub(summaryItem.title, #summaryItem.title - 8, #summaryItem.title) == "(Warded)" then
				imgName = "warding-charm.png"
			end
			Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. imgName, canvas.x + 40, 20, IMAGE_WIDTH*2, IMAGE_WIDTH*2)

			-- Text
			Drawing.drawText(canvas.x + 10, 69, self.wrapPixelsInline("Curse: " .. summaryItem.curse .. " @ " .. self.getCurseDescription(summaryItem.curse), canvas.w - 20), Theme.COLORS["Default text"])
		elseif summaryItem.type == "Evolution" then
			self.drawPrettyStats(canvas, summaryItem.prev, summaryItem.new, summaryItem.level)
		end

		Drawing.drawButton(self.RunSummaryScreen.Buttons.BackButton)
		Drawing.drawButton(self.RunSummaryScreen.Buttons.NextButton)
		Drawing.drawButton(self.RunSummaryScreen.Buttons.PrevButton)
		Drawing.drawButton(self.RunSummaryScreen.Buttons.LastButton)
		Drawing.drawButton(self.RunSummaryScreen.Buttons.FirstButton)
		Drawing.drawButton(self.RunSummaryScreen.Buttons.PrizeInfoButton)
		if title then
			Drawing.drawText(canvas.x + 6, 5, self.wrapPixelsInline(title, 100), Theme.COLORS["Default text"])
		end
	end

	self.RunSummaryScreen.Buttons = {
		-- Back to main screen button
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
		},
		PrevButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "<" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 30, 138, 10, 10},
			onClick = function()
				self.RunSummaryScreen.index = self.RunSummaryScreen.index - 1
				Program.redraw(true)
			end,
			isVisible = function()
				return self.RunSummaryScreen.index > 1
			end,
			boxColors = {"Default text"}
		},
		NextButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return ">" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 100, 138, 10, 10},
			onClick = function()
				self.RunSummaryScreen.index = self.RunSummaryScreen.index + 1
				Program.redraw(true)
			end,
			isVisible = function()
				return self.RunSummaryScreen.index < #runSummary
			end,
			boxColors = {"Default text"}
		},
		FirstButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "<<" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 10, 138, 15, 10},
			onClick = function()
				self.RunSummaryScreen.index = 1
				Program.redraw(true)
			end,
			isVisible = function()
				return self.RunSummaryScreen.index > 1
			end,
			boxColors = {"Default text"}
		},
		LastButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return ">>" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 115, 138, 15, 10},
			onClick = function()
				self.RunSummaryScreen.index = #runSummary
				Program.redraw(true)
			end,
			isVisible = function()
				return self.RunSummaryScreen.index < #runSummary
			end,
			boxColors = {"Default text"}
		},
		PrizeInfoButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Inventory" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 50, 138, 40, 10},
			onClick = function()
				Program.changeScreenView(self.SpecialRedeemScreen)
			end,
			boxColors = {"Default text"}
		},
		Option1 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(self.RunSummaryScreen.option1, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y, BUTTON_WIDTH, BUTTON_HEIGHT },
			isVisible = function() return self.RunSummaryScreen.option1 ~= "" and runSummary[self.RunSummaryScreen.index].type == "Prize" end,
			boxColors = {"Default text"}
		},
		Option2 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(self.RunSummaryScreen.option2, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP + BUTTON_HEIGHT, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			isVisible = function() return self.RunSummaryScreen.option2 ~= "" and runSummary[self.RunSummaryScreen.index].type == "Prize" end,
			boxColors = {"Default text"}
		},
		Option3 = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return self.wrapPixelsInline(self.RunSummaryScreen.option3, BUTTON_WIDTH - WRAP_BUFFER) end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + TOP_LEFT_X + IMAGE_WIDTH + IMAGE_GAP, TOP_BUTTON_Y + BUTTON_VERTICAL_GAP*2 + BUTTON_HEIGHT*2, 
			BUTTON_WIDTH, BUTTON_HEIGHT },
			isVisible = function() return self.RunSummaryScreen.option3 ~= "" and runSummary[self.RunSummaryScreen.index].type == "Prize" end,
			boxColors = {"Default text"}
		}
	}

	function self.RunSummaryScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.RunSummaryScreen.Buttons or {})
	end

	local SHOP_BUTTON_X = Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 3
	local SHOP_BUTTON_Y = 41
	local SHOP_BUTTON_HOR_COUNT = 8
	local SHOP_BUTTON_WIDTH = 16
	local SHOP_BUTTON_HEIGHT = 16

	self.ShopScreen = {
		hp = 0,
		status = 0,
		updates = {}
	}

	local shopItemImages = {
		["Oran Berry"] = "oran-berry.png",
		["Potion"] = "potion.png",
		["Berry Juice"] = "berry-juice-small.png",
		["Sitrus Berry"] = "Sitrus Berry.png",
		["Super Potion"] = "super-potion-small.png",
		["Fresh Water"] = "fresh-water.png",
		["EnergyPowder"] = "energy-powder.png",
		["Soda Pop"] = "soda-pop.png",
		["Lemonade"] = "lemonade.png",
		["Moomoo Milk"] = "moomoo-milk.png",
		["Hyper Potion"] = "hyper-potion.png",
		["Energy Root"] = "energy-root.png",
		["Antidote"] = "antidote2.png",
		["Parlyz Heal"] = "paralyze-heal2.png",
		["Burn Heal"] = "burn-heal2.png",
		["Ice Heal"] = "ice-heal2.png",
		["Awakening"] = "awakening2.png",
		["Pecha Berry"] = "pecha-berry.png",
		["Cheri Berry"] = "cheri-berry.png",
		["Chesto Berry"] = "chesto-berry.png",
		["Aspear Berry"] = "aspear-berry.png",
		["Rawst Berry"] = "rawst-berry.png",
		["Persim Berry"] = "persim-berry.png",
		["Lum Berry"] = "lum-berry.png",
		["Full Heal"] = "full-heal.png",
		["Lava Cookie"] = "lava-cookie.png",
		["Heal Powder"] = "heal-powder.png",
	}

	function self.getShopButtonLocation(index)
		return SHOP_BUTTON_X + ((index-1) % SHOP_BUTTON_HOR_COUNT) * SHOP_BUTTON_WIDTH, SHOP_BUTTON_Y + math.floor((index-1) / SHOP_BUTTON_HOR_COUNT) * SHOP_BUTTON_HEIGHT
	end

	function self.ShopScreen.addButton(item)
		local index = #self.ShopScreen.Buttons + 1
		local x,y = self.getShopButtonLocation(index)
		local b = {
			type = Constants.ButtonTypes.FULL_BORDER,
			box = {x, y, SHOP_BUTTON_WIDTH, SHOP_BUTTON_HEIGHT},
			onClick = function(this)
				if not self.ShopScreen.updates[this.item] then
					self.ShopScreen.updates[this.item] = 0
				end
				self.ShopScreen.updates[this.item] = self.ShopScreen.updates[this.item] - 1
				local itemId = self.getItemId(this.item)
				local itemInfo = MiscData.HealingItems[itemId]
				if itemInfo then
					self.ShopScreen.hp = self.ShopScreen.hp + itemInfo.amount
				else
					itemInfo = MiscData.StatusItems[itemId]
					self.ShopScreen.status = self.ShopScreen.status + (itemInfo.type == MiscData.StatusType.All and 3 or 1)
				end
				for i = this.index,#self.ShopScreen.Buttons - 1 do
					self.ShopScreen.Buttons[i] = self.ShopScreen.Buttons[i + 1]
					self.ShopScreen.Buttons[i].index = i
					local x1,y1 = self.getShopButtonLocation(i)
					self.ShopScreen.Buttons[i].box = {x1, y1, SHOP_BUTTON_WIDTH, SHOP_BUTTON_HEIGHT}
				end
				self.ShopScreen.Buttons[#self.ShopScreen.Buttons] = nil
				Program.redraw(true)
			end,
			boxColors = {"Default text"},
			draw = function(this, shadowcolor)
				local x, y, w, h = this.box[1], this.box[2], this.box[3], this.box[4]
				Drawing.drawImage(this.image, x + 1, y + 1, w - 2, h - 2)
			end,
			image = self.Paths.IMAGES_DIRECTORY .. shopItemImages[item],
			item = item,
			index = index
		}
		self.ShopScreen.Buttons[index] = b
	end

	function self.beginShop()
		self.ShopScreen.hp = 0
		self.ShopScreen.status = 0
		self.ShopScreen.updates = {}
		for i,b in ipairs(self.ShopScreen.Buttons) do
			self.ShopScreen.Buttons[i] = nil
		end
		for id,ct in pairs(Program.GameData.Items.StatusHeals) do
			if(ct <= 999) then
				local name = TrackerAPI.getItemName(id)
				if shopItemImages[name] then
					for i = 1, ct do
						self.ShopScreen.addButton(name)
					end
				end
			end
		end
		for id,ct in pairs(Program.GameData.Items.HPHeals) do
			if(ct <= 999) then
				local name = TrackerAPI.getItemName(id)
				if shopItemImages[name] then
					for i = 1, ct do
						self.ShopScreen.addButton(name)
					end
				end
			end
		end
	end

	function self.endShop()
		for item,ct in pairs(self.ShopScreen.updates) do
			if ct > 0 then
				self.AddItemImproved(item, ct)
			elseif ct < 0 then
				self.removeItem(item, ct*-1)
			end
		end
		local newItemsPocket, newBerryPocket = self.readBagInfo()
		priorItemsPocket = newItemsPocket
		itemsPocket = newItemsPocket
		priorBerryPocket = newBerryPocket
		berryPocket = newBerryPocket
	end

	function self.ShopScreen.drawScreen()
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

		local bagToDisplay = {}
		for _,btn in ipairs(self.ShopScreen.Buttons) do
			local itm = btn.item
			if bagToDisplay[itm] then
				bagToDisplay[itm] = bagToDisplay[itm] + 1
			else
				bagToDisplay[itm] = 1
			end
		end
		local ht, hp, hv = self.countHealsIn(bagToDisplay)
		local sv = self.countStatusHealsIn(bagToDisplay)
		local capsToDisplay = {hp = hv, status = sv}
		self.drawCapsAt(DataHelper.buildTrackerScreenDisplay(), Constants.SCREEN.WIDTH + 30, 5, capsToDisplay)
		Drawing.drawText(canvas.x + 2, 30, "BAG:", Theme.COLORS["Default text"])
		Drawing.drawText(canvas.x + 2, 108, "SHOP:", Theme.COLORS["Positive text"])

		local hpTextColor
		local hpText
		if self.ShopScreen.hp > 0 then
			hpTextColor = Theme.COLORS["Positive text"]
			hpText = "HP: +" .. self.ShopScreen.hp
		elseif self.ShopScreen.hp < 0 then
			hpTextColor = Theme.COLORS["Negative text"]
			hpText = "HP: " .. self.ShopScreen.hp
		else
			hpTextColor = Theme.COLORS["Default text"]
			hpText = "HP: " .. self.ShopScreen.hp
		end
		Drawing.drawText(canvas.x + 59, 120, hpText, hpTextColor)

		local statusTextColor
		local statusText
		if self.ShopScreen.status > 0 then
			statusTextColor = Theme.COLORS["Positive text"]
			statusText = "Status: +" .. self.ShopScreen.status
		elseif self.ShopScreen.status < 0 then
			statusTextColor = Theme.COLORS["Negative text"]
			statusText = "Status: " .. self.ShopScreen.status
		else
			statusTextColor = Theme.COLORS["Default text"]
			statusText = "Status: " .. self.ShopScreen.status
		end
		Drawing.drawText(canvas.x + 98, 120, statusText, statusTextColor)

		for _, button in pairs(self.ShopScreen.Buttons or {}) do
			Drawing.drawButton(button)
		end

		-- gui.drawLine(canvas.x, 109, canvas.x + 139, 109, Theme.COLORS["Lower box border"])
	end

	self.ShopScreen.Buttons = {
		BackButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Back" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 110, 8, 22, 10},
			onClick = function()
				self.returnToHomeScreen()
			end,
			boxColors = {"Default text"}
		},
		ResetButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Reset" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 110, 25, 27, 10},
			onClick = function()
				self.beginShop()
				Program.redraw(true)
			end,
			boxColors = {"Default text"}
		},
		DoneButton = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "Done" end,
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 110, 136, 24, 10},
			textColor = Theme.COLORS["Default text"],
			onClick = function(this)
				if self.ShopScreen.hp >= 0 and self.ShopScreen.status >= 0 then
					self.endShop()
					currentRoguemonScreen = self.RunSummaryScreen
					self.returnToHomeScreen()
				else
					this.textColor = Theme.COLORS["Negative text"]
					self.addUpdateCounter("Done Button Flash Red", 2, function()
						this.textColor = Theme.COLORS["Default text"]
					end, 1)
				end
			end,
			boxColors = {"Default text"}
		}
	}

	local shopAddButtonItems = {
		["Potion"] = {x = 0, y = 0},
		["Super Potion"] = {x = 1, y = 0},
		["Hyper Potion"] = {x = 2, y = 0},
		["Antidote"] = {x = 0, y = 1},
		["Parlyz Heal"] = {x = 1, y = 1},
		["Burn Heal"] = {x = 2, y = 1},
		["Awakening"] = {x = 3, y = 1},
		["Ice Heal"] = {x = 4, y = 1},
		["Full Heal"] = {x = 5, y = 1}
	}

	for item, info in pairs(shopAddButtonItems) do
		self.ShopScreen.Buttons[item .. " Button"] = {
			type = Constants.ButtonTypes.FULL_BORDER,
			box = {SHOP_BUTTON_X + info.x * SHOP_BUTTON_WIDTH, SHOP_BUTTON_Y + 78 + info.y * SHOP_BUTTON_HEIGHT,
				SHOP_BUTTON_WIDTH, SHOP_BUTTON_HEIGHT},
			onClick = function(this)
				if not self.ShopScreen.updates[this.item] then
					self.ShopScreen.updates[this.item] = 0
				end
				self.ShopScreen.updates[this.item] = self.ShopScreen.updates[this.item] + 1
				local itemId = self.getItemId(this.item)
				local itemInfo = MiscData.HealingItems[itemId]
				if itemInfo then
					self.ShopScreen.hp = self.ShopScreen.hp - itemInfo.amount
				else
					itemInfo = MiscData.StatusItems[itemId]
					self.ShopScreen.status = self.ShopScreen.status - (itemInfo.type == MiscData.StatusType.All and 3 or 1)
				end
				self.ShopScreen.addButton(item)
				Program.redraw(true)
			end,
			boxColors = {"Positive text"},
			draw = function(this, shadowcolor)
				local x, y, w, h = this.box[1], this.box[2], this.box[3], this.box[4]
				Drawing.drawImage(this.image, x + 1, y + 1, w - 2, h - 2)
			end,
			isVisible = function()
				return (not info.segment or self.reachedSegment(info.segment))
			end,
			image = self.Paths.IMAGES_DIRECTORY .. shopItemImages[item],
			item = item
		}
	end

	function self.ShopScreen.checkInput(xmouse, ymouse)
		Input.checkButtonsClicked(xmouse, ymouse, self.ShopScreen.Buttons or {})
	end

	-- Helper function to change to or queue a screen
	function self.readyScreen(screen)
		if Program.currentScreen == TrackerScreen and currentRoguemonScreen == self.RunSummaryScreen then
			if screen == self.OptionSelectionScreen or screen == self.RewardScreen or screen == self.ShopScreen then
				self.setCurrentRoguemonScreen(screen)
			end
			Program.changeScreenView(screen)
		else
			local found = false
			for _,s in ipairs(screenQueue) do
				if s == screen then
					found = true
				end
			end
			if not found then
				screenQueue[#screenQueue + 1] = screen
			end
		end
	end

	-- REWARD SPIN FUNCTIONS --

	function self.displayNotification(message, image, dismissFunction)
		self.NotificationScreen.message = message
		self.NotificationScreen.image = image and (self.Paths.IMAGES_DIRECTORY .. image) or nil
		if Program.currentScreen == self.PrettyStatScreen or Program.currentScreen == self.OptionSelectionScreen then
			self.readyScreen(self.NotificationScreen)
		else
			Program.changeScreenView(self.NotificationScreen)
		end
		Program.redraw(true)
		shouldDismissNotification = dismissFunction
	end

	-- Handle the buy phase.
	function self.buyPhase()
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
		self.beginShop()
		self.readyScreen(self.ShopScreen)
	end

	-- Handle the cleansing phase.
	function self.cleansingPhase(remindNoCleansing)
		-- TODO: Implement automatic cleansing. Coming in a future update hopefully.
		if remindNoCleansing then
			self.displayNotification("Reminder: NO Cleansing Phase!", "supernerd.png", function()
				local mapId = TrackerAPI.getMapId()
				return (previousMap == 10 and mapId ~= 10) or (previousMap == 192 and mapId ~= 192)
			end)
		else
			self.displayNotification("Cleansing Phase @ Must sell all non-healing items (including TMs) unless they have been unlocked", "trash.png", function()
				local mapId = TrackerAPI.getMapId()
				return (previousMap == 10 and mapId ~= 10) or (previousMap == 192 and mapId ~= 192)
			end)
		end
	end

	
	
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

	function self.baseMilestone(ms)
		if string.sub(ms, #ms - 1, #ms) == " 2" then
			return string.sub(ms, 1, #ms - 2)
		else
			return ms
		end
	end

	-- Spin the reward for a given milestone.
	function self.spinReward(milestoneName, rerolled)
		local minHealingPrizes = 1
		local maxHealingPrizes = 2
		if milestoneName == "Mt. Moon" then
			minHealingPrizes = 0
		end
		local rerollBans = nil
		if rerolled then
			rerollBans = {[option1] = true,
						[option2] = true,
						[option3] = true}
		end
		if LogOverlay.isGameOver and Program.currentScreen == GameOverScreen then
			GameOverScreen.status = GameOverScreen.Statuses.STILL_PLAYING
			LogOverlay.isGameOver = false
			LogOverlay.isDisplayed = false
			Program.GameTimer:unpause()
			GameOverScreen.refreshButtons()
			GameOverScreen.Buttons.SaveGameFiles:reset()
		end
		if milestonesByName[milestoneName] then
			lastMilestone = milestoneName
			local pkmn = self.readLeadPokemonData()
			local isShiny = Utils.bit_xor(Utils.bit_xor(Utils.bit_xor(Utils.getbits(pkmn.otid, 0, 16), Utils.getbits(pkmn.otid, 16, 16)), math.floor(pkmn.personality / 65536)), pkmn.personality % 65536) < Program.Values.ShinyOdds

			self.updateCaps(true)
			local rewardOptions = wheels[milestonesByName[milestoneName]['wheel']]
			local choices = {}
			local choiceCount = downsized and 2 or 3
			if haunted and haunted["2 Prize Options"] then
				haunted["2 Prize Options"] = nil
				choiceCount = 2
			end

			local healingPrizes = 0
			local nonHealingPrizes = 0

			local loopCount = 0
			while #choices < choiceCount and loopCount < 10000 do
				local choice = rewardOptions[math.random(#rewardOptions)]
				if string.sub(choice, 1, 6) == "Revive" and specialRedeems.consumable["Revive"] then
					choice = "Max Revive: Upgrade your Revive to a Max Revive."
				end
				local choiceName = Utils.split(choice, ":", true)[1]
				local choiceParts = Utils.split(choiceName, '&', true)
				local add = true
				local healingPrize = false
				for _,part in pairs(choiceParts) do
					if specialRedeems.unlocks[part] or specialRedeems.consumable[part] or specialRedeems.internal[part] or specialRedeems.battle[part] or 
						(part == "Fight Route X" and specialRedeems.internal["Route 14 + 15"]) then
						add = false
					end
					if (part == "Warding Charm" or part == "Clairvoyance") and not (self.ascensionLevel() > 1) then
						add = false
					end
					if part == "Nature Mint" and isShiny then
						add = false
					end
					if(part == "Ability Capsule") then
						local otherAbil = AbilityData.Abilities[PokemonData.getAbilityId(Tracker.getPokemon(1).pokemonID, 1 - Tracker.getPokemon(1).abilityNum)].name
						if (self.ascensionLevel() > 1) and (otherAbil == "Huge Power" or otherAbil == "Pure Power") then
							add = false
						else
							choice = choice .. ": Change ability to " .. otherAbil .. "."
						end
					end
					for _,itm in pairs(MiscData.HealingItems) do
						if string.len(itm.name) <= string.len(part) and string.sub(part, 1, string.len(itm.name)) == itm.name and not (part == "Potion Investment") then
							healingPrize = true
						end
					end
				end
				if healingPrize and healingPrizes == maxHealingPrizes then
					add = false
				end
				if not healingPrize and nonHealingPrizes == (choiceCount - minHealingPrizes) then
					add = false
				end
				if rerollBans and rerollBans[choiceName] then
					add = false
				end
				if add and choiceName == "Fight Route X" then
					local routes = {"Route 12 + 13", "Route 14 + 15"}
					local rInd = 1
					while rInd <= 2 and specialRedeems.internal[routes[rInd]] do
						rInd = rInd + 1
					end
					if rInd == 3 then
						add = false
					else
						choice = "Fight " .. routes[rInd] .. ": Treat the route as a segment. Keep items found."
						if rInd == 1 then
							choice = choice .. " (4 items, 1 TM)"
						end
						if rInd == 2 then
							choice = choice .. " (2 items, 1 TM)"
						end
					end
				end
				for _, v in pairs(choices) do
					if v == choice then
						add = false
					end
				end
				if add and choice then 
					choices[#choices + 1] = choice
					if healingPrize then
						healingPrizes = healingPrizes + 1
					else
						nonHealingPrizes = nonHealingPrizes + 1
					end
				end
				loopCount = loopCount + 1
			end

			local option1Split = Utils.split(choices[1], ":", true)
			option1 = option1Split[1]
			option1Desc = option1Split[2] or ""
			local option2Split = Utils.split(choices[2], ":", true)
			option2 = option2Split[1]
			option2Desc = option2Split[2] or ""
			if choiceCount < 3 then
				option3 = ""
				option3Desc = ""
			else
				local option3Split = Utils.split(choices[3], ":", true)
				option3 = option3Split[1]
				option3Desc = option3Split[2] or ""
			end

			descriptionText = ""

			if rerolled then
				Program.changeScreenView(self.RewardScreen)
			else
				self.readyScreen(self.RewardScreen)
			end
			Program.redraw(true)
		end

		if phases[self.baseMilestone(milestoneName)] then
			if phases[self.baseMilestone(milestoneName)].buy then
				needToBuy = true
			end
			needToCleanse = phases[self.baseMilestone(milestoneName)].cleansing and 1 or 2
		end

	end

	-- Select a particular reward option.
	function self.selectReward(option)
		runSummary[#runSummary + 1] = {
			type = "Prize",
			options = {option1, option2, option3},
			chosen = {[option] = true},
			title = self.baseMilestone(lastMilestone) .. " Prize"
		}

		local nextScreen = TrackerScreen -- by default we return to the main screen, unless the reward needs us to make another choice

		local rewards = Utils.split(option, '&', true) -- split the string up into its separate parts
		for _, reward in pairs(rewards) do
			-- Cover the route reward separately
			if string.sub(reward, 1, 11) == 'Fight Route' then
				local route = string.sub(reward, 7)
				specialRedeems.internal[route] = true
				if segmentStarted then
					table.insert(segmentOrder, currentSegment + 1, route)
				else
					table.insert(segmentOrder, currentSegment, route)
				end
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
					itemsFromPrize[#itemsFromPrize + 1] = reward
					self.AddItemImproved(reward, itemCount)
					if reward == "Max Revive" then
						self.removeSpecialRedeem("Revive")
						self.removeItem("Revive", 1)
					end
				end
				if reward == "Nature Mint" then
					additionalOptions = {"+Atk", "+Def", "+SpAtk", "+SpDef", "+Speed", "", "", ""}
					additionalOptionsRemaining = 1
					nextScreen = self.OptionSelectionScreen
					specialRedeems.internal["Nature Mint"] = true
				end
				if reward == "Ability Capsule" then
					self.flipAbility()
					specialRedeems.internal["Ability Capsule"] = true
				end
				if reward == "Found Item" then
					foundItemPrizeActive = true
				end
				if reward == "Clairvoyance" then
					specialRedeems.internal["Clairvoyance"] = true
				end
				if reward == "Ancestral Gift" then
					local pkmn = self.readLeadPokemonData()
		        	local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
					local itemChoices = {}
					for _,m in pairs(moves) do
						if MoveData.Moves[m].category ~= MoveData.Categories.STATUS then
							local type = MoveData.Moves[m].type
							itemChoices[ancestralItems[type]] = true
						end
					end
					specialRedeems.internal["Ancestral Gift"] = true
					local optIndex = 1
					for i,_ in pairs(itemChoices) do
						additionalOptions[optIndex] = i
						optIndex = optIndex + 1
					end
					while optIndex < 9 do
						additionalOptions[optIndex] = ""
						optIndex = optIndex + 1
					end
					additionalOptionsRemaining = 1
					nextScreen = self.OptionSelectionScreen
				end
				if reward == "Tera Orb" then
					local pkmn = self.readLeadPokemonData()
		        	local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
					local teraChoices = {}
					for _,m in pairs(moves) do
						local type = (MoveData.Moves[m].type:gsub("^%l", string.upper))
						teraChoices[type] = true
					end
					local optIndex = 1
					for i,_ in pairs(teraChoices) do
						additionalOptions[optIndex] = i
						optIndex = optIndex + 1
					end
					while optIndex < 9 do
						additionalOptions[optIndex] = ""
						optIndex = optIndex + 1
					end
					additionalOptionsRemaining = 1
					nextScreen = self.OptionSelectionScreen
				end
				if reward == "Artiste" then
					-- learn sketch
					self.triggerROMLearnMove(166)
				end
				if reward == "Starter Pack" then
					local starterPackMoves = {
						[PokemonData.Types.NORMAL] = 10, -- Scratch
						[PokemonData.Types.FIGHTING] = 183, -- Mach Punch
						[PokemonData.Types.FLYING] = 16, -- Gust
						[PokemonData.Types.POISON] = 51, -- Acid
						[PokemonData.Types.GROUND] = 91, -- Dig
						[PokemonData.Types.ROCK] = 88, -- Rock Throw
						[PokemonData.Types.BUG] = 318, -- Silver Wind
						[PokemonData.Types.GHOST] = 310, -- Astonish
						[PokemonData.Types.STEEL] = 232, -- Metal Claw
						[PokemonData.Types.FIRE] = 52, -- Ember
						[PokemonData.Types.WATER] = 55, -- Water Gun
						[PokemonData.Types.GRASS] = 22, -- Vine Whip
						[PokemonData.Types.ELECTRIC] = 84, -- Thunder Shock
						[PokemonData.Types.PSYCHIC] = 93, -- Confusion
						[PokemonData.Types.ICE] = 181, -- Powder Snow
						[PokemonData.Types.DRAGON] = 239, -- Twister
						[PokemonData.Types.DARK] = 228, -- Pursuit
						["fairy"] = 358 -- Fairy Wind
					}
					local monTypes = PokemonData.Pokemon[Tracker.getPokemon(1).pokemonID].types
					local validTypes = {}
					for val,type in pairs(PokemonData.TypeIndexMap) do
						if type ~= PokemonData.Types.UNKNOWN and type ~= monTypes[1] and type ~= monTypes[2] then
							validTypes[#validTypes + 1] = type
						end
					end
					self.triggerROMLearnMove(starterPackMoves[validTypes[math.random(#validTypes)]])
				end
				if reward == "Hyper Training" then
					local pkmn = self.readLeadPokemonData()
					local STATS_ORDERED = { "hp", "atk", "def", "spa", "spd", "spe"}
					local ivs = Utils.convertIVNumberToTable(pkmn.misc2)
					for i,stat in pairs(STATS_ORDERED) do
						local iv = ivs[stat]
						additionalOptions[i] = string.upper(stat) .. " (" .. iv .. ")"
					end
					additionalOptions[7] = ""
					additionalOptions[8] = ""
					additionalOptionsRemaining = 1
					nextScreen = self.OptionSelectionScreen
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
							nextScreen = self.OptionSelectionScreen
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
						if reward == "Fight first 5 wilds in Forest" then
							wildBattleCounter = 5
							wildBattlesStarted = false
						end
						if reward == "Fight wilds in Rts 1/2/22" then
							wildBattleCounter = 3
							wildBattlesStarted = false
						end
						if reward == "Temporary Found Item" then
							specialRedeems.consumable[reward] = 2
						end
					elseif specialRedeemInfo[reward].button == "Use" then
						-- Battle redeem
						specialRedeems.battle[reward] = true
						specialRedeems.battle[#specialRedeems.battle + 1] = reward
						if specialRedeemInfo[reward].charges then
							specialRedeems.battle[reward] = specialRedeemInfo[reward].charges
						end
					else
						specialRedeems.unlocks[reward] = true
						specialRedeems.unlocks[#specialRedeems.unlocks + 1] = reward
						if reward == "Midas Touch" then
							specialRedeems.unlocks["Midas Touch"] = 0
						end
						if reward == "Notetaker" then
							self.loadEvolutionTable()
						end
					end
				end
			end
		end

		descriptionText = ""

		self.updateCaps(false)

		if option ~= "Choose 2" and specialRedeems.consumable["Choose 2"] and not milestoneTrainers[self.baseMilestone(lastMilestone)] then
			self.removeSpecialRedeem("Choose 2")
			self.readyScreen(self.RewardScreen)
			if option1 == option then
				option1 = ""
				option1Desc = ""
			end
			if option2 == option then
				option2 = ""
				option2Desc = ""
			end
			if option3 == option then
				option3 = ""
				option3Desc = ""
			end
		else
			if milestonesByName[lastMilestone .. " 2"] then
				self.spinReward(lastMilestone .. " 2", false)
				milestone = milestone + 1
			end
		end

		if nextScreen == TrackerScreen then
			currentRoguemonScreen = self.RunSummaryScreen
			self.returnToHomeScreen()
		else
			currentRoguemonScreen = nextScreen
			Program.changeScreenView(nextScreen)
		end

		Program.redraw(true)

		self.saveData()
	end

	local prefixHandlers = {
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
	function self.selectAdditionalOption(rawOption)
		local option = self.splitOn(rawOption, "(")[1]  -- if a button has (), it's clarification text; we display it but don't read it
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
			self.recalculateStats()
			special = true
			additionalOptionsRemaining = additionalOptionsRemaining - 1
		end
		if option == "RogueStone" then
			-- Moon stone trade reduces HP cap
			local capReduced = 0
			if rawOption == "RogueStone (-50 HP Cap)" then
				capReduced = 50
			elseif rawOption == "RogueStone (-100 HP Cap)" then
				capReduced = 100
			end
			hpCapModifier = hpCapModifier - capReduced
			hpCap = hpCap - capReduced
			self.AddItemImproved("RogueStone", 1)
			additionalOptionsRemaining = additionalOptionsRemaining - 1
			special = true
		end
		local stats = {"HP", "ATK", "DEF", "SPA", "SPD", "SPE"}
		for i,s in pairs(stats) do
			if s == option then
				local pkmn = self.readLeadPokemonData()
				local ivs = Utils.convertIVNumberToTable(pkmn.misc2)
				ivs[string.lower(s)] = 31
				pkmn.misc2 = Utils.bit_lshift(Utils.getbits(pkmn.misc2, 30, 2), 30) +
					ivs['hp'] + Utils.bit_lshift(ivs['atk'], 5) + Utils.bit_lshift(ivs['def'], 10) + 
					Utils.bit_lshift(ivs['spe'], 15) + Utils.bit_lshift(ivs['spa'], 20) + Utils.bit_lshift(ivs['spd'], 25)
				self.writeLeadPokemonData(pkmn)
				self.recalculateStats()
				additionalOptionsRemaining = additionalOptionsRemaining - 1
				special = true
			end
		end
		if specialRedeems.battle["Tera Orb"] and not specialRedeems.internal["Tera Type"] then
			for tp,name in pairs(PokemonData.Types) do
				if string.lower(option) == string.lower(name) then
					specialRedeems.internal["Tera Type"] = PokemonData.TypeNameToIndexMap[name]
					additionalOptionsRemaining = additionalOptionsRemaining - 1
					special = true
				end
			end
		end
		-- Regular item option
		if not special and option ~= "" and additionalOptionsRemaining > 0 then
			self.AddItemImproved(option, 1)
			itemsFromPrize[#itemsFromPrize + 1] = option
			additionalOptionsRemaining = additionalOptionsRemaining - 1
			for _,item in pairs(ancestralItems) do
				if item == option then
					unlockedHeldItems[option] = true
				end
			end
			self.checkBagUpdates()
		end
		if additionalOptionsRemaining <= 0 then
			if string.sub(option, 1, 1) == "+" then
				additionalOptions = {"-Atk", "-Def", "-SpAtk", "-SpDef", "-Speed", "", "", ""}
				additionalOptionsRemaining = 1
				Program.redraw(true)
			else
				if currentRoguemonScreen == self.OptionSelectionScreen then
					currentRoguemonScreen = self.RunSummaryScreen
				end
				self.returnToHomeScreen()
			end
		end
		self.saveData()
	end

	-- CURSE RELATED FUNCTIONS -- 

	function self.determineCurses()
		local currentCurseCount = next(cursedSegments) == nil and 0 or #cursedSegments
		local intendedSegmentCurseCount = (self.ascensionLevel() > 1) and 5 or 1
		local intendedGymCurseCount = (self.ascensionLevel() > 2) and 2 or 0
		if currentCurseCount ~= intendedSegmentCurseCount + intendedGymCurseCount then
			cursedSegments = {}
			local segmentCurses = {}

			-- Segment curses
			local availableCurses = {}
			for c,d in pairs(curseInfo) do
				if d.segment then
					availableCurses[#availableCurses + 1] = c
				end
			end
			local added = 0
			while added < intendedSegmentCurseCount do
				local seg = segmentOrder[math.random(#segmentOrder)]
				if segments[seg]["cursable"] and not cursedSegments[seg] then
					local curseIndex = math.random(#availableCurses)
					local failsafeCount = 0
					while segments[seg]["bannedCurses"] and segments[seg]["bannedCurses"][availableCurses[curseIndex]] and failsafeCount < 99999 do
						curseIndex = math.random(#availableCurses)
						failsafeCount = failsafeCount + 1
					end
					if failsafeCount >= 99999 then
						cursedSegments[seg] = "Warded"
					else
						cursedSegments[seg] = table.remove(availableCurses, curseIndex)
						segmentCurses[cursedSegments[seg]] = true
					end
					added = added + 1
				end
			end

			-- Gym curses
			availableCurses = {}
			for c,d in pairs(curseInfo) do
				if d.gym and not segmentCurses[c] then
					availableCurses[#availableCurses + 1] = c
				end
			end
			added = 0
			while added < intendedGymCurseCount do
				local seg = segmentOrder[math.random(#segmentOrder)]
				if segments[seg]["gymCursable"] and not cursedSegments[seg] then
					local curseIndex = math.random(#availableCurses)
					while segments[seg]["bannedCurses"] and segments[seg]["bannedCurses"][availableCurses[curseIndex]] do
						curseIndex = math.random(#availableCurses)
					end
					cursedSegments[seg] = table.remove(availableCurses, curseIndex)
					added = added + 1
				end
			end

			-- Put them in order
			for _,seg in ipairs(segmentOrder) do
				if cursedSegments[seg] then
					cursedSegments[#cursedSegments + 1] = seg
				end
			end
		end
	end

	function self.getCurseDescription(curse)
		return curseInfo[curse].longDescription or curseInfo[curse].description
	end

	function self.getActiveCurse()
		if segmentStarted and not (cursedSegments[currentSegment] == "Warded") then
			return cursedSegments[segmentOrder[currentSegment]]
		end
	end

	function self.getAbility()
		local pkmn = Tracker.getPokemon(1)
		return AbilityData.Abilities[PokemonData.getAbilityId(pkmn.pokemonID, pkmn.abilityNum)].name
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

	function self.setStatStagesOnTeam(ownSide, stats)
		local baseIndex = ownSide and 0 or 1
		self.setStatStages(baseIndex, stats)
		if Battle.numBattlers == 4 then
			self.setStatStages(baseIndex + 2, stats)
		end
	end

	function self.setStatStages(index, stats)
		local startAddress = GameSettings.gBattleMons + Program.Addresses.sizeofBattlePokemon*index
		local statStageOffset = Program.Addresses.offsetBattlePokemonStatStages
		local hp_atk_def_speed = Memory.readdword(startAddress + statStageOffset)
		local spatk_spdef_acc_evasion = Memory.readdword(startAddress + statStageOffset + 4)
	
		local statStages = {
			["hp"] = stats["hp"] or Utils.getbits(hp_atk_def_speed, 0, 8),
			["atk"] = stats["atk"] or Utils.getbits(hp_atk_def_speed, 8, 8),
			["def"] = stats["def"] or Utils.getbits(hp_atk_def_speed, 16, 8),
			["spa"] = stats["spa"] or Utils.getbits(spatk_spdef_acc_evasion, 0, 8),
			["spd"] = stats["spd"] or Utils.getbits(spatk_spdef_acc_evasion, 8, 8),
			["spe"] = stats["spe"] or Utils.getbits(hp_atk_def_speed, 24, 8),
			["acc"] = stats["acc"] or Utils.getbits(spatk_spdef_acc_evasion, 16, 8),
			["eva"] = stats["eva"] or Utils.getbits(spatk_spdef_acc_evasion, 24, 8),
		}

		hp_atk_def_speed = statStages["hp"] + Utils.bit_lshift(statStages["atk"], 8)  + Utils.bit_lshift(statStages["def"], 16) + Utils.bit_lshift(statStages["spe"], 24)
		spatk_spdef_acc_evasion = statStages["spa"] + Utils.bit_lshift(statStages["spd"], 8)  + Utils.bit_lshift(statStages["acc"], 16) + Utils.bit_lshift(statStages["eva"], 24)
		Memory.writedword(startAddress + statStageOffset, hp_atk_def_speed)
		Memory.writedword(startAddress + statStageOffset + 4, spatk_spdef_acc_evasion)
	end

	function self.getStatStages(index)
		local startAddress = GameSettings.gBattleMons + Program.Addresses.sizeofBattlePokemon*index
		local statStageOffset = Program.Addresses.offsetBattlePokemonStatStages
		local hp_atk_def_speed = Memory.readdword(startAddress + statStageOffset)
		local spatk_spdef_acc_evasion = Memory.readdword(startAddress + statStageOffset + 4)
	
		local statStages = {
			["atk"] = Utils.getbits(hp_atk_def_speed, 8, 8),
			["def"] = Utils.getbits(hp_atk_def_speed, 16, 8),
			["spa"] = Utils.getbits(spatk_spdef_acc_evasion, 0, 8),
			["spd"] = Utils.getbits(spatk_spdef_acc_evasion, 8, 8),
			["spe"] = Utils.getbits(hp_atk_def_speed, 24, 8),
			["acc"] = Utils.getbits(spatk_spdef_acc_evasion, 16, 8),
			["eva"] = Utils.getbits(spatk_spdef_acc_evasion, 24, 8),
		}

		return statStages
	end

	function self.getEVs()
		local pkmn = self.readLeadPokemonData()
		local evs = {
			["hp"] = Utils.getbits(pkmn.effort1, 0, 8),
			["atk"] = Utils.getbits(pkmn.effort1, 8, 8),
			["def"] = Utils.getbits(pkmn.effort1, 16, 8),
			["spa"] = Utils.getbits(pkmn.effort2, 0, 8),
			["spd"] = Utils.getbits(pkmn.effort2, 8, 8),
			["spe"] = Utils.getbits(pkmn.effort1, 24, 8),
		}
		return evs
	end

	function self.setEVs(evs)
		local pkmn = self.readLeadPokemonData()
		pkmn.effort1 = evs["hp"] + Utils.bit_lshift(evs["atk"], 8)  + Utils.bit_lshift(evs["def"], 16) + Utils.bit_lshift(evs["spe"], 24)
		pkmn.effort2 = evs["spa"] + Utils.bit_lshift(evs["spd"], 8) + Utils.bit_lshift(Utils.getbits(pkmn.effort2, 16, 16), 16)
		self.writeLeadPokemonData(pkmn)
	end

	function self.getPPValues(pkmn)
		if not pkmn then
			pkmn = self.readLeadPokemonData()
		end
		return {Utils.getbits(pkmn.attack3, 0, 8), Utils.getbits(pkmn.attack3, 8, 8), Utils.getbits(pkmn.attack3, 16, 8), Utils.getbits(pkmn.attack3, 24, 8)}
	end

	function self.setMove(moveSlot, moveId, pp)
		local pkmn = self.readLeadPokemonData()
		local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
		moves[moveSlot] = moveId
		pkmn.attack1 = moves[1] + Utils.bit_lshift(moves[2], 16)
		pkmn.attack2 = moves[3] + Utils.bit_lshift(moves[4], 16)
		if not pp then
			pp = tonumber(MoveData.Moves[moveId].pp)
		end
		local pps = self.getPPValues()
		pps[moveSlot] = pp
		pkmn.attack3 = pps[1] + Utils.bit_lshift(pps[2], 8)  + Utils.bit_lshift(pps[3], 16) + Utils.bit_lshift(pps[4], 24)
		self.writeLeadPokemonData(pkmn)
	end

	function self.randomlyReplaceMove(moveIndex)
		local pkmn = self.readLeadPokemonData()
		local barredMoves = {[Utils.getbits(pkmn.attack1, 0, 16)] = true, 
						[Utils.getbits(pkmn.attack1, 16, 16)] = true, 
						[Utils.getbits(pkmn.attack2, 0, 16)] = true, 
						[Utils.getbits(pkmn.attack2, 16, 16)] = true,
					[165] = true, -- Struggle
					[15] = true, -- HMs
					[19] = true,
					[57] = true,
					[70] = true,
					[127] = true,
					[148] = true,
					[249] = true,
					[291] = true
				} 
		local moveNo = math.random(360)
		while barredMoves[moveNo] do
			moveNo = math.random(360)
		end
		self.setMove(moveIndex, moveNo)
	end

	function self.applyDecay()
		local pkmn = self.readLeadPokemonData()
		local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
		local move = moves[lastUsedMove]
		if MoveData.Moves[move].category == MoveData.Categories.SPECIAL then
			local evs = self.getEVs()
			if evs["spa"] > 0 then
				evs["spa"] = evs["spa"] - 1
			end
			self.setEVs(evs)
		elseif MoveData.Moves[move].category == MoveData.Categories.PHYSICAL then
			local evs = self.getEVs()
			if evs["atk"] > 0 then
				evs["atk"] = evs["atk"] - 1
			end
			self.setEVs(evs)
		end
	end

	function self.recalculateStats()
		local STATS = { "hp", "atk", "def", "spe", "spa", "spd"}
		local pkmn = self.readLeadPokemonData()
		local pkmnInfo = Tracker.getPokemon(1)

		local level = pkmnInfo.level
		local evs = self.getEVs()
		local ivs = Utils.convertIVNumberToTable(pkmn.misc2)
		local nature = pkmn.personality % 25
		local naturePlus = STATS[math.floor(nature/5) + 2]
		local natureMinus = STATS[nature % 5 + 2]
		local natureMod = {["atk"] = 1.0, 
			["def"] = 1.0, 
			["spe"] = 1.0, 
			["spa"] = 1.0, 
			["spd"] = 1.0}
		if naturePlus ~= natureMinus then
			natureMod[naturePlus] = 1.1
			natureMod[natureMinus] = 0.9
		end
		local baseStats = PokemonData.Pokemon[pkmnInfo.pokemonID].baseStats

		local calculatedStats = {}
		for _,s in pairs(STATS) do
			if s == "hp" then
				calculatedStats[s] = math.floor((2*baseStats[s] + ivs[s] + math.floor(evs[s] / 4)) * level / 100) + level + 10
			else
				calculatedStats[s] = math.floor((math.floor((2*baseStats[s] + ivs[s] + math.floor(evs[s] / 4)) * level / 100) + 5) * natureMod[s])
			end
		end

		Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk, calculatedStats["hp"] + Utils.bit_lshift(calculatedStats["atk"], 16))
		Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsDefSpe, calculatedStats["def"] + Utils.bit_lshift(calculatedStats["spe"], 16))
		Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsSpaSpd, calculatedStats["spa"] + Utils.bit_lshift(calculatedStats["spd"], 16))

		return calculatedStats
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
		thisFightFaintCount = 0
		lastUsedMove = nil
		if curse == "Tormented Soul" then
			self.applyStatusToTeam(true, 0x80000000)
		end
		if curse == "Clean Air" then
			self.applyStatusToSide(false, 0x0020, 6, 0xFF)
			self.applyStatusToSide(false, 0x0100, 4, 0xFF)
			self.applyStatusToTeam(false, 0x0400, true)
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
			local types = {}
			local pkmn = self.readLeadPokemonData()
			local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
			for val,type in pairs(PokemonData.TypeIndexMap) do
				if type ~= PokemonData.Types.UNKNOWN then
					local add = true
					for _,moveId in pairs(moves) do
						if MoveData.Moves[moveId].type == type then
							add = false
						end
					end
					if add then
						types[#types + 1] = val
					end
				end
			end
			local type1 = types[math.random(#types)]
			local type2 = type1
			if math.random(4) ~= 1 then
				type2 = types[math.random(#types)]
			end
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes, type1)
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + 1, type2)
		end
		if curse == "Headwind" then
			if math.random(2) == 1 then
				self.setStatStagesOnTeam(true, {["spe"] = 4})
			else
				self.setStatStagesOnTeam(true, {["spe"] = 5})
			end
		end
		if curse == "1000 Cuts" or curse == "Live Audience" then
			Program.addFrameCounter("Last Attack Damage", 10, self.getLastAttackDamage)
		end
		if curse == "Clouded Instincts" then
			local pkmn = self.readLeadPokemonData()
			local pps = self.getPPValues()
			local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
			for i = 1,4 do
				if pps[i] > 0 then
					self.setDisableStructWord(0, 0x06, moves[i])
					self.setDisableStructWord(0, 0x0C, i-1)
					self.setDisableStructWord(0, 0x0E, 1)
					break
				end
			end
		end
		if curse == "Unruly Spirit" then
			if math.random(10) <= 1 and self.getAbility() ~= "Inner Focus" then
				shouldFlinchFirstTurn = true
			end
		end
		if curse == "Unstable Ground" then
			if math.random(4) <= 3 and self.getAbility() ~= "Inner Focus" then
				shouldFlinchFirstTurn = true
			end
		end
		if curse == "Relay Race" then
			faintToProcess = false
			relayRaceStats = {atk = 6, def = 6, spa = 6, spd = 6, spe = 7, acc = 6, eva = 6}
			self.setStatStagesOnTeam(false, {["spe"] = 7})
			Program.addFrameCounter("Relay Race Stats", 5, function()
				local pm = Battle.BattleParties[1][Battle.Combatants.LeftOther]
				if pm then
					if Tracker.getPokemon(pm.transformData.slot, false).curHP > 0 and not faintToProcess then
						relayRaceStats = self.getStatStages(1)
					else
						faintToProcess = true
					end
				end
			end)
		end
		if curse == "Safety Zone" then
			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local currentHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp), 16, 16)
			if currentHP*4 < maxHP*3 and math.random(10) <= 3 then
				local itemOptions = {}
				for itemID, quantity in pairs(Program.GameData.Items.HPHeals or {}) do
					-- An arbitrary max value to prevent erroneous game data reads
					if quantity >= 0 and quantity <= 999 then
						for i = 1,quantity do
							itemOptions[#itemOptions + 1] = itemID
						end
					end
				end
				if #itemOptions > 0 then
					local toDelete = itemOptions[math.random(#itemOptions)]
					self.removeItem(TrackerAPI.getItemName(toDelete), 1)
				end
			end
		end
		if curse == "Backseating" then
			backseatingMove = math.random(4)
		end
		if curse == "Malware" then
			local enemyMon = Tracker.getPokemon(1, false)
			if enemyMon.stats["def"] > enemyMon.stats["spd"] then
				self.setStatStagesOnTeam(true, {["spa"] = 5})
			else
				self.setStatStagesOnTeam(true, {["atk"] = 5})
			end
		end
		if curse == "Conversion" then
			local types = {}
			local enemyMon = Battle.Combatants.LeftOther
			local mon = Tracker.getPokemon(Battle.Combatants.LeftOther, false)
			local moves = {mon.moves[1].id, mon.moves[2].id, mon.moves[3].id, mon.moves[4].id}
			for val,type in pairs(PokemonData.TypeIndexMap) do
				if type ~= PokemonData.Types.UNKNOWN then
					for _,moveId in pairs(moves) do
						if MoveData.Moves[moveId].type == type then
							types[#types + 1] = val
						end
					end
				end
			end
			local type = types[math.random(#types)]
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + Program.Addresses.sizeofBattlePokemon, type)
			Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + Program.Addresses.sizeofBattlePokemon + 1, type)
			currentEnemyMon = enemyMon
		end
	end

	function self.endOfBattleCurse(curse)
		local newPPValues = self.getPPValues()
		lastUsedMove = nil
		for i,val in pairs(newPPValues) do
			if val < ppValues[i] then
				lastUsedMove = i
				if curse == "Curse of Decay" then
					self.applyDecay()
				end
			end
		end
		if curse == "1000 Cuts" then
			if self.damageReceived > 0 then
				hpCapModifier = hpCapModifier - 5
				hpCap = hpCap - 5
				self.damageReceived = 0
			end
			Program.removeFrameCounter("Last Attack Damage")
		end
		if curse == "Live Audience" then
			Program.removeFrameCounter("Last Attack Damage")
		end
		if curse == "Narcolepsy" and self.getAbility() ~= "Vital Spirit" and self.getAbility() ~= "Insomnia" then
			local startAddress = GameSettings.pstats
			local status_aux = Memory.readdword(startAddress + Program.Addresses.offsetPokemonStatus)
			if math.random(10) <= 3 then
				local sleepTurns = math.random(4) + 1
				Memory.writedword(startAddress + Program.Addresses.offsetPokemonStatus, sleepTurns)
			end
		end
		if curse == "Unruly Spirit" or curse == "Unstable Ground" then
			flinchCheckFirstTurn = false
			shouldFlinchFirstTurn = false
		end
		if curse == "Relay Race" then
			Program.removeFrameCounter("Relay Race Stats")
		end
		if curse == "Forgetfulness" and not curseAppliedThisSegment then
			curseAppliedThisSegment = true
			self.randomlyReplaceMove(4)
		end
		if curse == "Resourceful" then
			local pkmn = self.readLeadPokemonData()
			local pps = self.getPPValues(pkmn)
			if lastUsedMove then
				pps[lastUsedMove] = math.max(pps[lastUsedMove] - (math.random(3)-1), 0)
			end
			pkmn.attack3 = pps[1] + Utils.bit_lshift(pps[2], 8)  + Utils.bit_lshift(pps[3], 16) + Utils.bit_lshift(pps[4], 24)
			self.writeLeadPokemonData(pkmn)
			for index,pp in pairs(pps) do
				if pp == 0 then
					self.randomlyReplaceMove(index)
				end
			end
		end
		if curse == "Backseating" then
			backseatingMove = nil
		end
		if curse == "Slot Machine" then
			local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local currentHP = math.floor(maxHP * math.random(4) / 4)
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
		end
	end

	function self.ongoingCurse(curse)
		local accurateTurnCount = Memory.readbyte(GameSettings.gBattleResults + Program.Addresses.offsetBattleResultsCurrentTurn)
		local address = (GameSettings.gBattleMons + BattleDetailsScreen.Addresses.offsetBattleMonsStatus2)
		local statusData = Memory.readdword(address)
		if curse == "Sharp Rocks" then
			self.applyStatusToTeam(false, 0x00100000)
		end
		if curse == "Heavy Fog" then
			for i = 1, Battle.numBattlers do
				if self.getStatStages(i-1)["acc"] > 5 then
					if not (i == 1 and self.getAbility() == "Keen Eye") then
						self.setStatStages(i-1, {["acc"] = 5})
					end
				end
			end
		end
		if curse == "Unruly Spirit" then
			if accurateTurnCount == 0 and shouldFlinchFirstTurn then
				self.applyStatusToTeam(true, 0x00000008)
			end
		end
		if curse == "Unstable Ground" and shouldFlinchFirstTurn then
			if accurateTurnCount == 0 and self.getAbility() ~= "Inner Focus" then
				self.applyStatusToTeam(true, 0x00000008)
			end
		end
		if curse == "Unruly Spirit" or curse == "Unstable Ground" then
			if accurateTurnCount == 1 and not flinchCheckFirstTurn then
				flinchCheckFirstTurn = true
				self.removeStatus(0, 0xFFFFFFF7)
			end
		end
	end

	function self.everyTurnCurse(curse)
		if curse == "1000 Cuts" and inBattleTurnCount > 0 and lastAttackDamage > 0 then
			hpCapModifier = hpCapModifier - 5
			hpCap = hpCap - 5
		end
		if curse == "Unruly Spirit" then
			if math.random(10) == 1 and self.getAbility() ~= "Inner Focus" then
				self.applyStatusToTeam(true, 0x00000008)
			end
		end
		if curse == "No Cover" then
			self.applyStatus(0, 0x00000018, true)
			self.setDisableStructByte(0, 0x15, 1)
		end
		if curse == "Relay Race" and faintToProcess then
			faintToProcess = false
			relayRaceStats.spe = relayRaceStats.spe + 1
			self.setStatStages(1, relayRaceStats)
		end
		local newPPValues = self.getPPValues()
		lastUsedMove = nil
		if inBattleTurnCount > 0 then
			for i,val in pairs(newPPValues) do
				if val < ppValues[i] then
					lastUsedMove = i
					if curse == "Curse of Decay" then
						self.applyDecay()
					end
				end
			end
		end
		ppValues = newPPValues
		if curse == "Live Audience" and inBattleTurnCount > 0 and lastAttackDamage > 0 and lastUsedMove and inBattleTurnCount > curseCooldown then
			local disableStructBase = GameSettings.gDisableStructs
			if Memory.readword(disableStructBase + 0x0E) == 0 then
				local pkmn = self.readLeadPokemonData()
				local moves = {Utils.getbits(pkmn.attack1, 0, 16), Utils.getbits(pkmn.attack1, 16, 16), Utils.getbits(pkmn.attack2, 0, 16), Utils.getbits(pkmn.attack2, 16, 16)}
				local encoreTurns = math.random(2,3)
				curseCooldown = inBattleTurnCount + encoreTurns
				self.setDisableStructWord(0, 0x06, moves[lastUsedMove])
				self.setDisableStructWord(0, 0x0C, lastUsedMove-1)
				self.setDisableStructWord(0, 0x0E, encoreTurns)
			end
		end
		if curse == "Clean Air" then
			self.applyStatusToTeam(false, 0x0400, true)
		end
		if curse == "Backseating" then
			if inBattleTurnCount > 0 and lastUsedMove then
				if lastUsedMove ~= backseatingMove then
					local stats = {"atk", "def", "spa", "spd", "spe", "acc", "eva"}
					local statDown = stats[math.random(#stats)]
					local stages = self.getStatStages(0)
					stages[statDown] = stages[statDown] - 1
					self.setStatStages(0, stages)
				end
			end
			backseatingMove = math.random(4)
		end
		if curse == "Conversion" then
			local enemyMon = Battle.Combatants.LeftOther
			if currentEnemyMon ~= enemyMon then
				currentEnemyMon = enemyMon
				local mon = Tracker.getPokemon(Battle.Combatants.LeftOther, false)
				local types = {}
				local moves = {mon.moves[1].id, mon.moves[2].id, mon.moves[3].id, mon.moves[4].id}
				for val,type in pairs(PokemonData.TypeIndexMap) do
					if type ~= PokemonData.Types.UNKNOWN then
						for _,moveId in pairs(moves) do
							if MoveData.Moves[moveId].type == type then
								types[#types + 1] = val
							end
						end
					end
				end
				local type = types[math.random(#types)]
				Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + Program.Addresses.sizeofBattlePokemon, type)
				Memory.writebyte(GameSettings.gBattleMons + Program.Addresses.offsetBattlePokemonTypes + Program.Addresses.sizeofBattlePokemon + 1, type)
			end
		end
	end

	function self.everyTurn()
		
	end

	function self.applySecretDex(id)
		local pokemon = PokemonData.Pokemon[id]
		local bst = tonumber(pokemon.bst)
		if bst and bst >= 570 then
			local STATS_ORDERED = { "hp", "atk", "def", "spa", "spd", "spe"}
			local lowThreshold = bst * 4/30
			local highThreshold = bst * 6/30
			for _, statKey in ipairs(STATS_ORDERED) do
				local stat = pokemon.baseStats[statKey]
				if stat < lowThreshold then
					Tracker.TrackStatMarking(id, statKey, 2)
				elseif stat > highThreshold then
					Tracker.TrackStatMarking(id, statKey, 1)
				else
					Tracker.TrackStatMarking(id, statKey, 3)
				end
			end
		end
	end

	function self.applySpecialInsight(id)
		local pokemon = PokemonData.Pokemon[id]
		local ability = pokemon.abilities[1]
		Tracker.TrackAbility(id, ability)
	end

	function self.checkInBattleEffectsAgainstMon(index)
		local id = Tracker.getPokemon(index, false).pokemonID
		local pokemon = PokemonData.Pokemon[id]
		if pokemon then
			if specialRedeems.unlocks["Secret Dex"] and not (Tracker.getOrCreateTrackedPokemon(id) and 
			Tracker.getOrCreateTrackedPokemon(id).sm and Tracker.getOrCreateTrackedPokemon(id).sm['hp'] and 
			Tracker.getOrCreateTrackedPokemon(id).sm['hp'] > 0 and Tracker.getOrCreateTrackedPokemon(id).sm['atk'] and Tracker.getOrCreateTrackedPokemon(id).sm['atk'] > 0) then
				self.applySecretDex(id)
			end
			if specialRedeems.unlocks["Special Insight"] and not (Tracker.getOrCreateTrackedPokemon(pokemonID) 
			and Tracker.getOrCreateTrackedPokemon(pokemonID).abilities and Tracker.getOrCreateTrackedPokemon(pokemonID).abilities[1]) then
				self.applySpecialInsight(id)
			end
			if specialRedeems.unlocks["Spidey Sense"] then
				local pkmn = Battle.getViewedPokemon(false)
				for _,mv in pairs(pkmn.moves) do
					if mv.id == 194 or mv.id == 243 or mv.id == 68 then
						Tracker.TrackMove(pkmn.pokemonID, mv.id, pkmn.level)
					end
				end
			end
			if specialRedeems.unlocks["Notetaker"] then
				local preEvo = evolutionTable[id]
				while preEvo ~= null do
					if Tracker.getOrCreateTrackedPokemon(preEvo) and Tracker.getOrCreateTrackedPokemon(preEvo).sm then
						for stat,marking in pairs(Tracker.getOrCreateTrackedPokemon(preEvo).sm) do
							if marking > 0 then
								Tracker.TrackStatMarking(id, stat, marking)
							end
						end
					end
					if Tracker.getOrCreateTrackedPokemon(preEvo) and Tracker.getOrCreateTrackedPokemon(preEvo).abilities then
						for id, abil in pairs(Tracker.getOrCreateTrackedPokemon(preEvo).abilities) do
							if abil > 0 then
								Tracker.TrackAbility(id, abil)
							end
						end
					end
					if Tracker.getOrCreateTrackedPokemon(preEvo) and Tracker.getOrCreateTrackedPokemon(preEvo).note then
						Tracker.TrackNote(id, Tracker.getOrCreateTrackedPokemon(preEvo).note)
					end
					preEvo = evolutionTable[preEvo]
				end
			end
		end
	end

	function self.checkInBattleEffects()
		if Battle.Combatants.LeftOther and not Battle.isWildEncounter and Tracker.getPokemon(Battle.Combatants.LeftOther, false) then
			self.checkInBattleEffectsAgainstMon(Battle.Combatants.LeftOther)
			if Battle.numBattlers == 4 and Battle.Combatants.RightOther then
				self.checkInBattleEffectsAgainstMon(Battle.Combatants.RightOther)
			end
			if haunted and haunted["Leech Seed"] then
				haunted["Leech Seed"] = nil
				self.applyStatus(0, 0x00000005, true)
			end
			if haunted and haunted["Confusion"] then
				haunted["Confusion"] = nil
				self.applyStatus(0, math.random(4) + 1, false)
			end
		end

		if currentRoguemonScreen ~= self.RunSummaryScreen then
			currentRoguemonScreen = self.RunSummaryScreen
		end
	end

	-- DISPLAY/NOTIFICATION FUNCTIONS -- 

	local screenPriorities = {
		[self.RunSummaryScreen] = 1,
		[self.ShopScreen] = 2,
		[self.OptionSelectionScreen] = 3,
		[self.RewardScreen] = 4
	}
	function self.setCurrentRoguemonScreen(newScreen)
		if (not screenPriorities[newScreen]) or (not screenPriorities[currentRoguemonScreen]) or 
		(screenPriorities[newScreen] > screenPriorities[currentRoguemonScreen]) then
			currentRoguemonScreen = newScreen
		end
	end

	-- Buy phase notification followed by cleansing phase notification, once the player leaves the gym and takes their prize
	function self.handleBuyCleanseNotifs(mapId)
		if Program.currentScreen == TrackerScreen and currentRoguemonScreen == self.RunSummaryScreen then
			if needToBuy then
				if not gymMapIds[mapId] then
					needToBuy = false
					self.addUpdateCounter("Buy Phase", 2, function() self.buyPhase() end, 1)
				end
			elseif needToCleanse > 0 and not needToBuy and not updateCounters["Buy Phase"] then
				self.cleansingPhase(needToCleanse == 2)
				needToCleanse = 0
			end
		end
	end

	-- Draw special redeem images on the main screen.
	function self.redrawScreenImages()
		if RoguemonOptions["Display prizes on screen"] and not self.isInAscensionTower() then
			local screen = Program.currentScreen
			--local dx = 180 - (#specialRedeems.unlocks + #specialRedeems.consumable)*30 - use this for top right display
			local dx = 0
			local dy = 0
			local imageSize = 32
			local imageGap = 30
			if RoguemonOptions["Display small prizes"] then
				imageSize = 20
				imageGap = 18
			end
			if screen ~= StartupScreen then
				for _,r in ipairs(specialRedeems.battle) do
					local imageButton = {
						type = Constants.ButtonTypes.IMAGE,
						box = {dx*imageGap, dy, imageSize, imageSize},
						onClick = function()
							specialRedeemToDescribe = r
							Program.changeScreenView(self.SpecialRedeemScreen)
						end
					}
					Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx*imageGap, dy, imageSize, imageSize)
					if screen.Buttons then
						screen.Buttons["RoguemonPrize" .. dx] = imageButton
					end
					local count = specialRedeems.battle[r]
					if count < 0 then
						count = count + 2
					end
					Drawing.drawText(dx*imageGap + imageSize - 7, dy + imageSize - 7, count, 0xFF000000)
					dx = dx + 1
				end
			end
			if not Battle.inBattle then
				if screen ~= StartupScreen then
					for _,r in ipairs(specialRedeems.unlocks) do
						local imageButton = {
							type = Constants.ButtonTypes.IMAGE,
							box = {dx*imageGap, dy, imageSize, imageSize},
							onClick = function()
								specialRedeemToDescribe = r
								Program.changeScreenView(self.SpecialRedeemScreen)
							end
						}
						Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx*imageGap, dy, imageSize, imageSize)
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
								Program.changeScreenView(self.SpecialRedeemScreen)
							end
						}
						Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. specialRedeemInfo[r].image, dx*imageGap, dy, imageSize, imageSize)
						if screen.Buttons then
							screen.Buttons["RoguemonPrize" .. dx] = imageButton
						end
						if r == "Fight wilds in Rts 1/2/22" or r == "Fight first 5 wilds in Forest" then
							Drawing.drawText(dx*imageGap + imageSize - 7, dy + imageSize - 7, wildBattleCounter, 0xFF000000)
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
	end

	function self.countStatusHealsIn(itemList)
		local statusBerries = {133, 134, 135, 136, 137, 140, 141}
		local statusHealsInBagCount = 0
		for id,ct in pairs(itemList) do
			if type(id) == "string" then
				id = self.getItemId(id)
			end
			if(MiscData.StatusItems[id] and ct <= 999) then
				if not (specialRedeems.unlocks["Berry Pouch"] and self.contains(statusBerries, id)) then
					statusHealsInBagCount = statusHealsInBagCount + ct
				end
			end
		end
		return statusHealsInBagCount
	end
	
	-- Count status heals, taking Berry Pouch into account.
	function self.countStatusHeals()
		return self.countStatusHealsIn(Program.GameData.Items.StatusHeals)
	end

	function self.countHealsIn(itemList)
		local leadPokemon = Tracker.getPokemon(1)
		local maxHP = leadPokemon and leadPokemon.stats and leadPokemon.stats.hp or 0

		local healingTotal = 0
		local healingPercentage = 0
		local healingValue = 0

		for itemID, quantity in pairs(itemList) do
			if type(itemID) == "string" then
				itemID = self.getItemId(itemID)
			end
			-- An arbitrary max value to prevent erroneous game data reads
			if quantity >= 0 and quantity <= 999 then
				local healItemData = MiscData.HealingItems[itemID] or {}
				local percentageAmt = 0
				if healItemData.type == MiscData.HealingType.Constant then
					-- Healing is in a percentage compared to the mon's max HP
					percentageAmt = quantity * math.min(healItemData.amount / maxHP * 100, 100) -- max of 100
				elseif healItemData.type == MiscData.HealingType.Percentage then
					percentageAmt = quantity * healItemData.amount
				end
				if not (specialRedeems.unlocks["Cooler Bag"] and (itemID == 26 or itemID == 27 or itemID == 28 or itemID == 29 or itemID == 44)) then
					healingTotal = healingTotal + quantity
					healingPercentage = healingPercentage + percentageAmt
					healingValue = healingValue + math.floor(percentageAmt * maxHP / 100 + 0.5)
				end
			end
		end
		return healingTotal, healingPercentage, healingValue
	end

	-- Count heals, applying any modifiers
	function self.countAdjustedHeals()
		Program.updateBagItems()
	
		local healingTotal = 0
		local healingPercentage = 0
		local healingValue = 0

		healingTotal, healingPercentage, healingValue = self.countHealsIn(Program.GameData.Items.HPHeals or {})

		adjustedHPVal = healingValue
		return healingTotal, healingPercentage, healingValue
	end

	-- Draw caps at a particular x,y
	function self.drawCapsAt(data, x, y, caps)
		local shadowcolor = Utils.calcShadowColor(Theme.COLORS["Upper box background"])
		-- these don't count as status heals if Berry Pouch is active
		local statusHealsInBagCount = self.countStatusHeals()
		self.countAdjustedHeals()
		
		local healVal = Options["Show heals as whole number"] and adjustedHPVal or data.x.healperc
		if caps then
			healVal = caps.hp
		end

		local healsTextColor = healVal > hpCap and Theme.COLORS["Negative text"] or Theme.COLORS["Default text"]

		local healsValueText
		if Options["Show heals as whole number"] then
			healsValueText = string.format("%.0f/%.0f %s (%s)", healVal, hpCap, Resources.TrackerScreen.HPAbbreviation, data.x.healnum)
		else
			healsValueText = string.format("%.0f%%/%.0f %s (%s)", healVal, hpCap, Resources.TrackerScreen.HPAbbreviation, data.x.healnum)
		end
		Drawing.drawText(x, y, healsValueText, healsTextColor, shadowcolor)

		local statusVal = statusHealsInBagCount
		if caps then
			statusVal = caps.status
		end

		local statusHealsTextColor = statusVal > statusCap and Theme.COLORS["Negative text"] or Theme.COLORS["Default text"]
		local statusHealsValueText = string.format("%.0f/%.0f %s", statusVal, statusCap, "Status")
		Drawing.drawText(x, y + 11, statusHealsValueText, statusHealsTextColor, shadowcolor)
		currentStatusVal = statusHealsInBagCount
	end

	function self.drawCapsAndRoguemonMenu()
		local data = DataHelper.buildTrackerScreenDisplay()
		if Program.currentScreen == TrackerScreen and Battle.isViewingOwn and data.p.id ~= 0 then
			gui.drawRectangle(Constants.SCREEN.WIDTH + 6, 58, Options["Show GachaMon stars on main Tracker Screen"] and 54 or 94, 21, Theme.COLORS["Upper box background"], Theme.COLORS["Upper box background"])
			self.drawCapsAt(data, Constants.SCREEN.WIDTH + 6, 57)
			TrackerScreen.Buttons.RogueMenuButton.textColor = (currentRoguemonScreen == self.RunSummaryScreen) and Theme.COLORS["Intermediate text"] or Theme.COLORS["Negative text"]
			if Options["Show GachaMon stars on main Tracker Screen"] then
				TrackerScreen.Buttons.RogueMenuButton.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - 14, Constants.SCREEN.MARGIN + 130, 10, 10}
				TrackerScreen.Buttons.CurseMenuButton.box = { Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - 14, Constants.SCREEN.MARGIN + 140, 10, 10}
				TrackerScreen.Buttons.RogueMenuButton.type = Constants.ButtonTypes.NO_BORDER
				TrackerScreen.Buttons.CurseMenuButton.iconColors = {Theme.COLORS["Default text"]}
				TrackerScreen.Buttons.RogueMenuButton.boxColors = {"Lower box border"}
			else
				TrackerScreen.Buttons.RogueMenuButton.box = { Constants.SCREEN.WIDTH + 90, 59, 6, 12}
				TrackerScreen.Buttons.CurseMenuButton.box = { Constants.SCREEN.WIDTH + 80, 59, 7, 12}
				TrackerScreen.Buttons.RogueMenuButton.type = Constants.ButtonTypes.FULL_BORDER
				TrackerScreen.Buttons.CurseMenuButton.iconColors = {Theme.COLORS["Default text"], Theme.COLORS["Upper box border"]}
				TrackerScreen.Buttons.RogueMenuButton.boxColors = {"Upper box border"}
			end
			
			Drawing.drawButton(TrackerScreen.Buttons.RogueMenuButton)
			Drawing.drawButton(TrackerScreen.Buttons.CurseMenuButton)
			if DEBUG_MODE then
				Drawing.drawButton(TrackerScreen.Buttons.DebugButton)
			end
		end
	end

	function self.returnToHomeScreen()
		if #screenQueue > 0  and currentRoguemonScreen == self.RunSummaryScreen then
			local s = table.remove(screenQueue, 1)
			Program.changeScreenView(s)
			if s == self.OptionSelectionScreen or s == self.RewardScreen then
				self.setCurrentRoguemonScreen(s)
			end
		elseif needToCleanse > 0 and not needToBuy and currentRoguemonScreen == self.RunSummaryScreen then
			if Program.currentScreen == self.OptionSelectionScreen then
				Program.changeScreenView(TrackerScreen)
			end
			self.cleansingPhase(needToCleanse == 2)
			needToCleanse = 0
		else
			Program.changeScreenView(TrackerScreen)
		end
	end

	function self.getSaveDataFilePath()
		local _, ascension, runIndex = self.getRomStamp()
		return self.Paths.SAVED_DATA_PREFIX .. self.getAscensionString(ascension, runIndex) .. ".tdat"
	end

	-- This is dependent on both Tracker and Randomization implementation
	-- details, which may change in the future.
	function self.getLogFilePath(postFix)
		postFix = postFix or FileManager.PostFixes.AUTORANDOMIZED
		local _, ascension, runTypeIndex = self.getRomStamp()
		local fileName = self.getAscensionString(ascension, runTypeIndex) .. " " ..
		                  postFix .. ".gba.log"
		return FileManager.prependDir(fileName)
	end

	-- Save roguemon data to file
	function self.saveData()
		if not loadedData then
			local saveDataCheck = FileManager.readTableFromFile(self.getSaveDataFilePath())
			if saveDataCheck and GameSettings.getRomHash() == saveDataCheck['romHash'] then
				self.loadData()
			end
		end
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
			['haunted'] = haunted,
			['previousTheme'] = previousTheme,
			['rivalCombined'] = rivalCombined,
			['savedIVs'] = savedIVs,
			['timeWarpedExp'] = timeWarpedExp,
			['runSummary'] = runSummary,
		}

		if not DEBUG_MODE then
			FileManager.writeTableToFile(saveData, self.getSaveDataFilePath())
		end

		FileManager.writeTableToFile(RoguemonOptions, self.Paths.SAVED_OPTIONS)
		loadedData = true
	end

	-- Load roguemon data from file
	function self.loadData()
		local saveData = FileManager.readTableFromFile(self.getSaveDataFilePath())
		if saveData and GameSettings.getRomHash() == saveData['romHash'] then
			loadedData = true
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
			haunted = saveData['haunted'] or haunted
			previousTheme = saveData['previousTheme'] or Theme.exportThemeToText()
			rivalCombined = saveData['rivalCombined'] or rivalCombined
			savedIVs = saveData['savedIVs'] or savedIVs
			timeWarpedExp = saveData['timeWarpedExp'] or timeWarpedExp
			runSummary = saveData['runSummary'] or runSummary
		end
		if rivalCombined then
			for _,tid in pairs(segments[segmentOrder[currentSegment-1]]["trainers"]) do
				segments[segmentOrder[currentSegment]]["trainers"][#segments[segmentOrder[currentSegment]]["trainers"] + 1] = tid
			end
			for _,tid in pairs(segments[segmentOrder[currentSegment-1]]["mandatory"]) do
				segments[segmentOrder[currentSegment]]["mandatory"][#segments[segmentOrder[currentSegment]]["mandatory"] + 1] = tid
			end
			for _,rid in pairs(segments[segmentOrder[currentSegment-1]]["routes"]) do
				segments[segmentOrder[currentSegment]]["routes"][#segments[segmentOrder[currentSegment]]["routes"] + 1] = rid
			end
			segments[segmentOrder[currentSegment]]["rival"] = true
		end
		if seedNumber == -1 then
			seedNumber = self.generateSeed()
		end
		math.randomseed(seedNumber)

		RoguemonOptions = {}
		for _,o in pairs(optionsList) do
			RoguemonOptions[o.text] = o.default
		end

		local readOptions = FileManager.readTableFromFile(self.Paths.SAVED_OPTIONS)
		if readOptions then
			for k,v in pairs(readOptions) do
				RoguemonOptions[k] = v
			end
		end

		centersUsed = Utils.getGameStat(Constants.GAME_STATS.USED_POKECENTER)

		if specialRedeems.unlocks["Notetaker"] then
			self.loadEvolutionTable()
		end
	end

	local rogueStoneThresholds = {
		{bst = 290, locations = {{map = 80, trainer = 414, amt = 50}, {map = 81, trainer = nil, amt = 0}}},
		{bst = 320, locations = {{map = 80, trainer = 414, amt = 100}, {map = 81, trainer = nil, amt = 50}, {map = 81, trainer = 415, amt = 0}}},
		{bst = 370, locations = {{map = 81, trainer = 415, amt = 100}, {map = 83, trainer = 416, amt = 50}, {map = 82, trainer = nil, amt = 0}}},
		{bst = 601, locations = {{map = 83, trainer = 416, amt = 100}, {map = 82, trainer = nil, amt = 50}, {map = 84, trainer = 417, amt = 0}}}
	}

	function self.checkRogueStoneOffers(mapId, pokemon)
		if pokemon and PokemonData.Pokemon[pokemon.pokemonID].evolution.detailed and self.contains(PokemonData.Pokemon[pokemon.pokemonID].evolution.detailed, "RogueStone") then
			local bst = PokemonData.Pokemon[pokemon.pokemonID].bst
			for _,info in pairs(rogueStoneThresholds) do
				if bst <= info.bst then
					local index = offeredMoonStoneFirst
					local loc = info.locations[index]
					while loc do
						if mapId == loc.map and (not loc.trainer or defeatedTrainerIds[loc.trainer]) then
							offeredMoonStoneFirst = index + 1
							if loc.amt > 0 then
								self.offerBinaryOption("RogueStone (-" .. loc.amt .. " HP Cap)", "Skip")
							else
								self.AddItemImproved("RogueStone", 1)
								self.displayNotification("A RogueStone has been added to your bag", "moon-stone.png", nil)
							end
							break
						end
						index = index + 1
						loc = info.locations[index]
					end
					break
				end
			end
		end
	end

	-- EXTENSION FUNCTIONS --

	function self.afterBattleEnds()
		if not loadedExtension then
			return
		end
		if TrackerAPI.getBattleOutcome() == 2 then
			-- We lost :(
			return
		end
		-- Determine if we have just defeated a trainer
		local trainerId = lastFoughtTrainerId
		if trainerId == 0 then
			self.errorLog("Battle ended but we don't know the trainerId. Please report to #bug-reporting on Roguemon discord.")
			return
		end
		if defeatedTrainerIds[trainerId] then
			-- Fought a wild
			if TrackerAPI.getBattleOutcome() == 1 or (wildBattlesStarted and TrackerAPI.getBattleOutcome() == 4) then
				-- Defeated/ran from a wild
				if wildBattleCounter > 0 and committed then
					wildBattlesStarted = true
					wildBattleCounter = wildBattleCounter - 1
					if wildBattleCounter <= 0 then
						self.removeSpecialRedeem("Fight wilds in Rts 1/2/22")
						self.removeSpecialRedeem("Fight first 5 wilds in Forest")
					end
				end
			end
			return
		else
			defeatedTrainerIds[trainerId] = true
		end

		-- Attempt to true-up any defeated trainers which we somehow missed.
		local segInfo = segments[segmentOrder[currentSegment]]
		for _,t in pairs(segInfo["trainers"]) do
			if TrackerAPI.hasDefeatedTrainer(t) and not defeatedTrainerIds[t] then
				local warningMsg = "Missed that we defeated trainer %d. Fixing. " ..
				                   "Please report to #bug-reporting on Roguemon Discord."
				self.warningLog(warningMsg, t)
				defeatedTrainerIds[t] = true
				trainersDefeated = trainersDefeated + 1
				for _,tr in pairs(segInfo["mandatory"]) do
					if tr == t then
						mandatoriesDefeated = mandatoriesDefeated + 1
					end
				end
			end
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
			if specialRedeems.consumable["Temporary Found Item"] then
				specialRedeems.consumable["Temporary Found Item"] = specialRedeems.consumable["Temporary Found Item"] - 1
				if specialRedeems.consumable["Temporary Found Item"] == 0 then
					self.removeSpecialRedeem("Temporary Found Item")
				end
			end
		end

		-- Add 4 potions after rival 1
		if trainerId >= 326 and trainerId <= 328 then
			self.AddItemImproved("Potion", 4)
			self.AddItemImproved("Lucky Egg", 1)
			if RoguemonOptions["Show reminders"] then
				self.displayNotification("4 Potions and a nice egg have been added to your bag", "4potegg.png", function()
					local mapId = TrackerAPI.getMapId()
					return (mapId == 78)
				end)
			end
		end

		-- Show the pretty stat screen immediately if it needs to be shown
		if #screenQueue > 0 and screenQueue[1] == self.PrettyStatScreen then
			local s = table.remove(screenQueue, 1)
			Program.changeScreenView(s)
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
				if trainersDefeated >= self.getSegmentTrainerCount(currentSegment) and not 
					((self.ascensionLevel() > 2) and segmentOrder[currentSegment + 1] and string.sub(segmentOrder[currentSegment + 1], 1, 5) == "Rival" and not self.isNextSegmentRivalDefeated()) then
					self.nextSegment()
				end
			end
		end

		if specialRedeems.unlocks["Regenerator"] then
			local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
			local lvCurHp = Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp)
			local currentHP = Utils.getbits(lvCurHp, 16, 16)
			currentHP = currentHP + math.floor(maxHP * 3 / 100 + 0.5)
			if currentHP > maxHP then
				currentHP = maxHP
			end
			Memory.writedword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp, Utils.getbits(lvCurHp, 0, 16) + Utils.bit_lshift(currentHP, 16))
		end

		self.saveData()
	end
	
	self.configureOptions = function()
		Program.changeScreenView(self.RoguemonOptionsScreen)
	end
	
	function self.createAccessButtonsAndCarousel()
		-- Helper function to draw the carousel item, overriding normal Tracker's carousel draw
		local _drawRogueCarouselBottom = function(button, shadowcolor)
			local gachaOn = Options["Show GachaMon stars on main Tracker Screen"]
			-- Check if curse theme is in effect
			local bgColor = Theme.COLORS["Lower box background"]
			-- Set lower box color to purple if the next segment is cursed
			if not segmentStarted and cursedSegments[segmentOrder[currentSegment]] and cursedSegments[currentSegment] ~= "Warded" and RoguemonOptions["Alternate Curse theme"] then
				bgColor = 0xFF510080
			end
			-- Set lower box color to green if the current segment has a full clear prize
			if segmentStarted and milestoneTrainers[segmentOrder[currentSegment]] then
				bgColor = 0xFF63DB60
			end
			gui.drawRectangle(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 136, Constants.SCREEN.RIGHT_GAP - (2 * Constants.SCREEN.MARGIN), 19, Theme.COLORS["Lower box border"], bgColor)
			if gachaOn then
				gui.drawLine(Constants.SCREEN.WIDTH + 134, 136, Constants.SCREEN.WIDTH + 134, 155, Theme.COLORS["Lower box border"])
			end

			-- Draw the item count section
			gui.drawLine(Constants.SCREEN.WIDTH + (gachaOn and 122 or 134), 136, Constants.SCREEN.WIDTH + (gachaOn and 122 or 134), 155, Theme.COLORS["Lower box border"])
			local colorList = TrackerScreen.PokeBalls.ColorList
			Drawing.drawImageAsPixels(Constants.PixelImages.POKEBALL_SMALL, Constants.SCREEN.WIDTH + (gachaOn and 124 or 136), Constants.SCREEN.MARGIN + 132, colorList)
			local itemCt = self.getItemsInCurrentSegment()
			Drawing.drawText(Constants.SCREEN.WIDTH + (gachaOn and 122 or 133) + ((itemCt >= 10) and 0 or 3), Constants.SCREEN.MARGIN + 140, itemCt, Theme.COLORS["Lower box text"])

			-- Draw the word-wrapped text, if any
			local btnText = button:getCustomText()
			local wrappedText = self.wrapPixelsInline(btnText, gachaOn and 113 or 125, 2, Utils.replaceText(btnText, "mandatory", "mand."))
			if not string.find(wrappedText, "%\n") then
				Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 140, wrappedText, Theme.COLORS["Lower box text"], shadowcolor)
			else
				Drawing.drawText(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 1, 136, wrappedText, Theme.COLORS["Lower box text"], shadowcolor)
				gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 155, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 155, Theme.COLORS["Lower box border"])
				gui.drawLine(Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 156, Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - Constants.SCREEN.MARGIN, 156, Theme.COLORS["Main background"])
			end

			-- Then finally draw the access buttons
			Drawing.drawButton(TrackerScreen.Buttons.CurseMenuButton, shadowcolor)
			Drawing.drawButton(TrackerScreen.Buttons.RogueMenuButton, shadowcolor)
		end

		TrackerScreen.Buttons.RogueSegmentCarousel = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getCustomText = function(this) return this.updatedText or "" end,
			textColor = "Lower box text",
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 136, 129, 18 },
			isVisible = function() return TrackerScreen.carouselIndex == self.SEGMENT_CAROUSEL_INDEX end,
			onClick = function(this)
				-- Optional code if you want, for when the main area of this carousel button is clicked
			end,
			draw = function(this, shadowcolor)
				_drawRogueCarouselBottom(this, shadowcolor)
			end,
			boxColors = {"Default text"}
		}
		TrackerScreen.Buttons.RogueCurseCarousel = {
			type = Constants.ButtonTypes.FULL_BORDER,
			getCustomText = function(this) return this.updatedText or "" end,
			textColor = "Lower box text",
			box = { Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN, 136, 129, 18 },
			isVisible = function() return TrackerScreen.carouselIndex == self.CURSE_CAROUSEL_INDEX end,
			onClick = function(this)
				-- Optional code if you want, for when the main area of this carousel button is clicked
			end,
			draw = function(this, shadowcolor)
				_drawRogueCarouselBottom(this, shadowcolor)
			end,
			boxColors = {"Default text"}
		}

		-- Add the segment & curse carousel item
		self.SEGMENT_CAROUSEL_INDEX = #TrackerScreen.CarouselTypes + 1
		TrackerScreen.CarouselItems[self.SEGMENT_CAROUSEL_INDEX] = {
			type = self.SEGMENT_CAROUSEL_INDEX,
			framesToShow = 240,
			canShow = function(this)
				return true
			end,
			getContentList = function(this)
				local segmentName = segmentOrder[currentSegment]
				if segmentOrder[currentSegment + 1] and string.sub(segmentOrder[currentSegment + 1], 1, 5) == "Rival" and (self.ascensionLevel() > 2) then
					segmentName = segmentName .. " (+ Rival?)"
				end
				if rivalCombined then
					segmentName = "Rival + " .. segmentName
				end
				local text
				if segmentStarted then
					text = segmentName .. ": " .. mandatoriesDefeated .. "/" .. self.getSegmentMandatoryCount(currentSegment) .. " mandatory, " ..
					trainersDefeated .. "/" .. self.getSegmentTrainerCount(currentSegment) .. " total"
					if milestoneTrainers[segmentOrder[currentSegment]] then
						text = text .. " [FC Prize]"
					end
				else
					text = 'Next Segment: ' .. segmentName
					if segmentName == "Congratulations!" then
						text = "Congratulations!"
					end
				end
				TrackerScreen.Buttons.RogueSegmentCarousel.updatedText = text
				if Main.IsOnBizhawk() then
					-- Return the entire button to allow for it to be clickable
					return { TrackerScreen.Buttons.RogueSegmentCarousel }
				else
					return text
				end
			end,
		}

		self.CURSE_CAROUSEL_INDEX = #TrackerScreen.CarouselTypes + 2
		TrackerScreen.CarouselItems[self.CURSE_CAROUSEL_INDEX] = {
			type = self.CURSE_CAROUSEL_INDEX,
			framesToShow = 240,
			canShow = function(this)
				-- this disables the curse carousel. swap this return line to bring it back
				return false
				-- return segmentStarted and self.getActiveCurse()
			end,
			getContentList = function(this)
				local curse = self.getActiveCurse()
				local text = "> " .. curse .. ": " .. curseInfo[curse].description
				if curse == "Acid Rain" and weatherApplied then
					text = text .. " (" .. weatherApplied .. ")"
				end
				if curse == "Safety Zone" then
					local maxHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsMaxHpAtk), 0, 16)
					local currentHP = Utils.getbits(Memory.readdword(GameSettings.pstats + Program.Addresses.offsetPokemonStatsLvCurHp), 16, 16)
					text = text .. " (" ..  math.floor(currentHP / maxHP * 100 + 0.5) .. "%)"
				end
				TrackerScreen.Buttons.RogueCurseCarousel.updatedText = text
				if Main.IsOnBizhawk() then
					-- Return the entire button to allow for it to be clickable
					return { TrackerScreen.Buttons.RogueCurseCarousel }
				else
					return text
				end
			end,
		}

		-- I set the border to use a different color. Search Tracker code code for examples of how pixel images can use an icon color set
		-- For now, no border is drawn as no color for it is defined (intentional)
		-- Also, no reason to have defined this as a core tracker "Constants", just store it in your extension (change applied below)
		self.SKULL_ICON = {
			{2,2,2,2,2,2,2,2,2},
			{2,0,0,0,0,0,0,0,2},
			{2,0,0,0,0,0,0,0,2},
			{2,0,0,1,1,1,0,0,2},
			{2,0,1,1,1,1,1,0,2},
			{2,0,1,0,1,0,1,0,2},
			{2,0,1,1,1,1,1,0,2},
			{2,0,0,1,0,1,0,0,2},
			{2,0,0,1,0,1,0,0,2},
			{2,0,0,0,0,0,0,0,2},
			{2,0,0,0,0,0,0,0,2},
			{2,0,0,0,0,0,0,0,2},
			{2,2,2,2,2,2,2,2,2},
		}

		-- Add the buttons to access the Roguemon screens
		TrackerScreen.Buttons.RogueMenuButton = {
			type = Options["Show GachaMon stars on main Tracker Screen"] and Constants.ButtonTypes.NO_BORDER or Constants.ButtonTypes.FULL_BORDER,
			getText = function() return "!" end,
			box = Options["Show GachaMon stars on main Tracker Screen"] and 
			{ Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - 14, Constants.SCREEN.MARGIN + 130, 10, 10} or 
			{ Constants.SCREEN.WIDTH + 90, 59, 6, 12},
			onClick = function()
				specialRedeemToDescribe = nil
				Program.changeScreenView(currentRoguemonScreen)
			end,
			isVisible = function()
				if Options["Show GachaMon stars on main Tracker Screen"] then
					local rogueCarouselVisible = TrackerScreen.carouselIndex == self.SEGMENT_CAROUSEL_INDEX or TrackerScreen.carouselIndex == self.CURSE_CAROUSEL_INDEX
					return Program.currentScreen == TrackerScreen and rogueCarouselVisible
				else
					return Program.currentScreen == TrackerScreen and Battle.isViewingOwn
				end
			end,
			textColor = "Intermediate text",
			boxColors = {"Upper box border"}
		}

		TrackerScreen.Buttons.CurseMenuButton = {
			type = Constants.ButtonTypes.PIXELIMAGE,
			image = self.SKULL_ICON,
			box = Options["Show GachaMon stars on main Tracker Screen"] and 
			{ Constants.SCREEN.WIDTH + Constants.SCREEN.RIGHT_GAP - 14, Constants.SCREEN.MARGIN + 140, 10, 10} or 
			{ Constants.SCREEN.WIDTH + 80, 59, 7, 12},
			onClick = function()
				local curseInfoText = ""
				for _,seg in ipairs(cursedSegments) do
					if not (self.reachedSegment(seg) and not (segmentOrder[currentSegment] == seg) and not (cursedSegments[seg] == "Warded")) then
						curseInfoText = curseInfoText .. seg .. (specialRedeems.internal["Clairvoyance"] and ": " .. cursedSegments[seg] or "") .. " @ "
					end
				end
				if self.getActiveCurse() then
					self.NotificationScreen.auxiliaryButtonInfo["CurseList"][1].name = "Curse: " .. self.getActiveCurse()
					self.NotificationScreen.queuedAuxiliary = self.NotificationScreen.auxiliaryButtonInfo["CurseList"]
				end
				self.displayNotification(curseInfoText, "Curse.png", nil)
			end,
			iconColors = Options["Show GachaMon stars on main Tracker Screen"] and {Theme.COLORS["Default text"]} or {Theme.COLORS["Default text"], Theme.COLORS["Upper box border"]}, 
			isVisible = function()
				if Options["Show GachaMon stars on main Tracker Screen"] then
					local rogueCarouselVisible = TrackerScreen.carouselIndex == self.SEGMENT_CAROUSEL_INDEX or TrackerScreen.carouselIndex == self.CURSE_CAROUSEL_INDEX
					return Program.currentScreen == TrackerScreen and rogueCarouselVisible
				else
					return Program.currentScreen == TrackerScreen and Battle.isViewingOwn
				end
			end
		}
	end

	function self.isNatDexLoaded()
		-- This is a setting that IronmonTracker will set to one thing,
		-- and NatDex will set to another. Critically, that application
		-- will happen in that order (Tracker, then NatDex), on every
		-- re-execution of Main.Run, every time.
		--
		-- We use this as a sentinel to determine if NatDex has loaded or not.
		return GameSettings.gameStatsOffset == 0x1394
	end


	local startupTries = 0
	local maxTries = 10
	local startupCounterLabel = "Startup RoguemonTracker"
	function self.startup()
		local bizhawkVersion = client.getversion()
		if Utils.isNewerVersion(REQUIRED_BIZHAWK_VERSION, bizhawkVersion) then
			self.errorLog("This extension does not support BizHawk %s. " ..
			              "Please update to BizHawk %s or newer.",
			              bizhawkVersion, REQUIRED_BIZHAWK_VERSION)
			return
		end

		if self.tryPatchVanillaROM() ~= nil then
			return
		end

		startupTries = startupTries + 1
		if not self.isNatDexLoaded() then
			if startupTries >= maxTries then
				self.errorLog("NatDex Tracker Extension appears to be missing. Cannot start Roguemon Tracker.")
				Program.removeFrameCounter(startupCounterLabel)
				return
			end

			print("> Waiting on NatDex Tracker Extension before starting Roguemon Tracker...")
			Program.addFrameCounter(startupCounterLabel, 60, function () self.startup() end)
			return
		end

		Program.removeFrameCounter(startupCounterLabel)
		print("> Roguemon Tracker starting")

		self.overrideCoreTrackerFunctions()
		self.updateGameSettings()
		self.checkPatchVersion()

		local romCompatVersion = self.getROMCompatVersion()
		if romCompatVersion ~= trackerCompatVersion then
			self.errorLog("This tracker does not support this ROM. " ..
			              "Either the ROM or the tracker needs an update.\n" ..
			              "romCompatVersion: %d, trackerCompatVersion: %d",
			              romCompatVersion, trackerCompatVersion)
			return
		end

		self.setupRunProfile()

		-- Read & populate configuration info
		self.readConfig()
		self.populateSegmentData()

		itemsPocket = {}
		berryPocket = {}

		self.createAccessButtonsAndCarousel()

		-- this button is only for debugging
		if DEBUG_MODE then
			TrackerScreen.Buttons.DebugButton = {
				type = Constants.ButtonTypes.FULL_BORDER,
				getText = function() return ":" end,
				box = { Constants.SCREEN.WIDTH + 93, 43, 6, 12},
				onClick = function()
					Program.changeScreenView(self.RewardScreen)
				end,
				textColor = Drawing.Colors.GREEN,
				boxColors = {"Default text"}
			}
		end

		currentRoguemonScreen = self.RunSummaryScreen

		-- Load data from file if it exists
		self.loadData()

		local curse = self.getActiveCurse()
		if curse then
			if RoguemonOptions["Alternate Curse theme"] then
				previousTheme = Theme.exportThemeToText()
				Theme.importThemeFromText(CURSE_THEME, true)
			end
		end

		-- Set up a frame counter to save the roguemon data every 30 seconds
		self.addUpdateCounter("Roguemon Saving", 30, self.saveData)

		-- Write ascension data to the ROM regularly, as loaded saves may overwrite it
		self.addUpdateCounter("Set ROM Ascension", 30, self.setROMAscension)

		-- User may toggle this in the options menu of the game
		self.addUpdateCounter("Get Rules Enforcement", 6, self.getRulesEnforcement)

		-- Set tracker to use whole number heal value
		hpHealsSetting = TrackerAPI.getOption("Show heals as whole number")
		TrackerAPI.setOption("Show heals as whole number", true)

		-- Update RogueStone name
		MiscData.Items[94] = "RogueStone"
		MiscData.EvolutionStones[94].name = "RogueStone"

		loadedExtension = true
	end

	function self.unload()
		local curse = self.getActiveCurse()
		if curse then
			self.resetTheme()
		end
		if self.SEGMENT_CAROUSEL_INDEX then
			TrackerScreen.CarouselItems[self.SEGMENT_CAROUSEL_INDEX] = nil
		end
		if self.CURSE_CAROUSEL_INDEX then
			TrackerScreen.CarouselItems[self.CURSE_CAROUSEL_INDEX] = nil
		end
		TrackerScreen.Buttons.RogueMenuButton = nil
		TrackerScreen.Buttons.CurseMenuButton = nil
		self.removeUpdateCounter("Roguemon Saving")
		QuickloadScreen.SettingsKeywordToGameOverMap["Roguemon"] = nil
		-- Update RogueStone name back to normal
		MiscData.Items[94] = "Moon Stone"
		MiscData.EvolutionStones[94].name = "Moon Stone"
		TrackerAPI.setOption("Show heals as whole number", hpHealsSetting)

		self.restoreCoreTrackerFunctions()
	end

	function self.inputCheckBizhawk()
		if Program.currentScreen == self.NotificationScreen or Program.currentScreen == self.PrettyStatScreen then
			local joypad = Input.getJoypadInputFormatted()
			CustomCode.inputCheckMGBA()
			local nextBtn = Options.CONTROLS["Next page"] or ""
			if joypad[nextBtn] then
				self.returnToHomeScreen()
			end
		elseif Program.currentScreen == self.OptionSelectionScreen then
			local joypad = Input.getJoypadInputFormatted()
			CustomCode.inputCheckMGBA()
			local nextBtn = Options.CONTROLS["Next page"] or ""
			if joypad[nextBtn] then
				for _,a in pairs(additionalOptions) do
					if a == "Skip" or a == "Wait" then
						self.returnToHomeScreen()
						currentRoguemonScreen = self.RunSummaryScreen
					end
				end
			end
		end
	end

	function self.afterRedraw()
		if not loadedExtension then
			return
		end
		self.redrawScreenImages()
		self.drawCapsAndRoguemonMenu()
		if LogOverlay.isGameOver and self.getActiveCurse() then
			self.resetTheme()
			self.undoCurse(self.getActiveCurse())
		end
		if Program.currentScreen == TrackerScreen and Battle.isViewingOwn and backseatingMove then
			Drawing.drawImage(self.Paths.IMAGES_DIRECTORY .. "Chatting.png", Constants.SCREEN.WIDTH + Constants.SCREEN.MARGIN + 2, 86 + 10 * backseatingMove)
		end
	end

	function self.afterProgramDataUpdate()
		if not loadedExtension then
			return
		end

		-- Check if NatDex has swapped GameSettings out from under us.
		self.updateGameSettings()

		if self.checkAwaitingRandomization() and not randomizingROM then
			-- Trigger the main loop to LoadNextRom
			randomizingROM = true
			Main.loadNextSeed = true
			return
		end
		randomizingROM = false

		if self.isInAscensionTower() then
			return
		end

		for name,counter in pairs(updateCounters) do
			counter.currentUpdateCount = counter.currentUpdateCount - 1
			if counter.currentUpdateCount == 0 then
				counter.functionToUse()
				counter.currentUpdateCount = counter.updateCount
				counter.executionCount = counter.executionCount - 1
				if counter.executionCount == 0 then
					updateCounters[name] = nil
				end
			end
		end
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
		if not segmentStarted and committed then
			for _,r in pairs(segments[segmentOrder[currentSegment]]["routes"]) do
				if mapId == r then
					self.startSegment()
					self.saveData()
				end
			end
		end
		-- Check if a pokemon has been caught (for determining if the player has committed)
		if not caughtSomethingYet and #Program.GameData.PlayerTeam > 1 then
			caughtSomethingYet = true
		end
		if not committed and self.readGameVar(GameSettings.roguemon.varMilestone) >= 2 then
			committed = true
			if RoguemonOptions["Egg reminders"] and Tracker.getPokemon(1, true) and Tracker.getPokemon(1, true).heldItem ~= 197 and not self.itemNotPresent(197) then
				self.NotificationScreen.queuedAuxiliary = self.NotificationScreen.auxiliaryButtonInfo["EquipPickup"]
				self.NotificationScreen.itemInQuestion = "Lucky Egg"
				self.displayNotification("Use the Egg, Luke!", "lucky-egg.png", function()
					return Tracker.getPokemon(1, true).heldItem == 197
				end)
			end
		end
		-- Check if we are in a Pokemon Center/Pokemon League with full HP when all mandatory trainers in the current segment are defeated.
		-- If so, the segment is assumed to be finished.
		-- local pokemon = TrackerAPI.getPlayerPokemon()
		-- if pokemon and pokemon.curHP == pokemon.stats.hp and (mapId == 8 or mapId == 212) and segmentStarted and mandatoriesDefeated >= self.getSegmentMandatoryCount(currentSegment) then
		-- 	self.nextSegment()
		-- 	self.saveData()
		-- end
		local centerCt = Utils.getGameStat(Constants.GAME_STATS.USED_POKECENTER)
		if centerCt > centersUsed then
			centersUsed = centerCt
			if segmentStarted and mandatoriesDefeated >= self.getSegmentMandatoryCount(currentSegment) then
				self.nextSegment()
				self.saveData()
			end
		end

		local pokemon = TrackerAPI.getPlayerPokemon()

		-- RogueStone offer checks
		self.checkRogueStoneOffers(mapId, pokemon)

		-- Check if NatDex is loaded and we haven't yet changed everything's evo method to RogueStone and update some evo levels & friendship values
		if not patchedChangedEvos and PokemonData.Pokemon[412] ~= nil then
			self.patchChangedEvos()
			self.updateFriendshipValues()
		end

		if not syncedAttempts then
			syncedAttempts = self.syncAttempts()
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
					self.everyTurn()
				end
			else
				weatherApplied = nil
				curseAppliedThisFight = false
				inBattleTurnCount = -1
				curseCooldown = 0
			end
		else
			if Battle.inBattle then
				if inBattleTurnCount ~= Battle.turnCount then
					inBattleTurnCount = Battle.turnCount
					self.everyTurn()
				end
			else
				inBattleTurnCount = -1
			end
		end
		if Battle.inBattle then
			self.checkInBattleEffects()
			lastFoughtTrainerId = TrackerAPI.getOpponentTrainerId()
		end

		-- Check updates to bag items and pokemon info
		self.checkBagUpdates()

		-- Check if we have an Item Voucher and are currently holding an illegal item
		if pokemon then
			local heldItem = TrackerAPI.getItemName(pokemon.heldItem, true)
			if not Battle.inBattle and heldItem and not allowedHeldItems[heldItem] and not unlockedHeldItems[heldItem] then
				if heldItem == "Leftovers" then
					self.displayNotification("Reminder that Leftovers is banned in all ascensions.", "supernerd.png", nil)
				else
					local hadV = false
					if foundItemPrizeActive then
						hadV = true
						foundItemPrizeActive = false
					else
						hadV = self.removeSpecialRedeem("Temporary Item Voucher")
					end
					if not hadV then
						hadV = self.removeSpecialRedeem("Item Voucher")
					end
					if hadV then
						unlockedHeldItems[heldItem] = true
						self.saveData()
					end
				end
			end
		end

		-- Check if the notification should be dismissed
		if Program.currentScreen == self.NotificationScreen then
			if shouldDismissNotification and shouldDismissNotification() then
				self.returnToHomeScreen()
			end
		end

		-- Reset queuedAuxiliary for NotificationScreen
		if Program.currentScreen ~= self.NotificationScreen then
			self.NotificationScreen.queuedAuxiliary = nil
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
		if committed and lastMilestone == nil and Program.currentScreen == TrackerScreen then
			if #suppressedNotifications > 0 then
				local n = table.remove(suppressedNotifications, 1)
				self.NotificationScreen.queuedAuxiliary = n.queuedAuxiliary
				self.NotificationScreen.itemInQuestion = n.itemInQuestion
				self.displayNotification(n.message, n.image, n.dismissFunction)
			else
				self.spinReward("Rival 1", false)
			end
		end

		-- if we haven't yet chosen the curses for this seed, choose them now
		self.determineCurses()

		-- Display any queued screens
		if Program.currentScreen == TrackerScreen and currentRoguemonScreen == self.RunSummaryScreen then
			if #screenQueue > 0 then
				local s = table.remove(screenQueue, 1)
				Program.changeScreenView(s)
				if s == self.OptionSelectionScreen or s == self.RewardScreen or s == self.ShopScreen then
					self.setCurrentRoguemonScreen(s)
				end
			else
				self.handleBuyCleanseNotifs(mapId)
			end
		end

		-- if defeatedTrainerIds[414] and not needToBuy and not (needToCleanse > 0) and Program.currentScreen == TrackerScreen and not showedEggReminderAfterBrock 
		-- and RoguemonOptions["Egg reminders"] and (previousMap == 10) and Tracker.getPokemon(1, true) and Tracker.getPokemon(1, true).heldItem == 197 then
		-- 	showedEggReminderAfterBrock = true
		-- 	self.displayNotification("Your free Egg trial has expired", "lucky-egg.png", function()
		-- 		return (Tracker.getPokemon(1, true).heldItem ~= 197 and self.itemNotPresent(197))
		-- 	end)
		-- end

		if defeatedTrainerIds[414] and not showedEggReminderAfterBrock and RoguemonOptions["Egg reminders"] and 
		Tracker.getPokemon(1, true) and Tracker.getPokemon(1, true).heldItem == 197 then
			showedEggReminderAfterBrock = true
			local pkmn = self.readLeadPokemonData()
			-- delete lucky egg
			pkmn.growth1 = Utils.getbits(pkmn.growth1, 0, 16) + Utils.bit_lshift(0x0, 16)
			self.writeLeadPokemonData(pkmn)
		end

		if previousMap ~= mapId then
			if previousMap == 51 and mapId == 85 and segmentOrder[currentSegment] == "Safari Zone" then
				-- Went from Safari Gate to Fuchsia City
				self.nextSegment()
				self.saveData()
			end
			previousMap = mapId
		end

		if Program.currentScreen == TrackerScreen then
			itemsFromPrize = {}
		end
	end

	function self.checkForUpdates()
		local versionResponsePattern = '"tag_name":%s+"%w+(%d+%.%d+%.%d[%d%w%-%+]*)"' -- matches "1.0.1-label+build" in "tag_name": "v1.0.1-label+build"
		local versionCheckUrl = string.format("https://api.github.com/repos/%s/releases/latest", self.github or "")
		local downloadUrl = string.format("%s/releases/latest", self.url or "")
		local compareFunc = function(a, b) return a ~= b and RoguemonUtils.compare_semver(a, b) == -1 end -- if current version is *older* than online version
		local isUpdateAvailable = Utils.checkForVersionUpdate(versionCheckUrl, self.version, versionResponsePattern, compareFunc)
		return isUpdateAvailable, downloadUrl
	end

	-- Helper function for accessing roguemon data from the console
	function RoguemonObj()
		return self
	end

	-- FORM FUNCTIONS --

	-- Calls callbackFunc with true if we want to patch, and false if we don't.
	function self.patchVanillaROMPrompt(callbackFunc)
		local profile = QuickloadScreen.getActiveProfile()
		local lastPlayedRomPath
		if profile and not Utils.isNilOrEmpty(profile.Paths.CurrentRom) then
			lastPlayedRomPath = profile.Paths.CurrentRom
		end

		local _failSafe = function()
			callbackFunc(false)
		end
		local form = ExternalUI.BizForms.createForm("RogueMon Patch", 480, 100, 100, 20, _failSafe)

		local x = 15
		local iy = 10
		form:createLabel("Would you like to create the RogueMon ROM using this Vanilla FireRed ROM?", x, iy)
		iy = iy + 22
		form.Controls.labelStopIt = form:createLabel("(Note: If you want to stop this from popping up, simply disable the RogueMon tracker extension.)", x, iy)
		ExternalUI.BizForms.setProperty(form.Controls.labelStopIt, ExternalUI.BizForms.Properties.FORE_COLOR, "blue")
		iy = iy + 28

		form.Controls.patchIt = form:createButton("Patch", 145, iy, function()
			if type(callbackFunc) == "function" then
				callbackFunc(true)
			end
			form:destroy()
		end, 75, 25)
		form.Controls.buttonDismiss = form:createButton("Dismiss", 260, iy, function()
			if type(callbackFunc) == "function" then
				callbackFunc(false)
			end
			form:destroy()
		end, 75, 25)
	end

	-- Informs the player that patching is complete and the RogueMon ROM is ready to launch.
	function self.patchCompletePrompt(callbackFunc)
		local form = ExternalUI.BizForms.createForm("RogueMon Patch Complete", 320, 100, 100, 20, callbackFunc)

		local x = 15
		local iy = 10
		form:createLabel("Vanilla FireRed ROM successfully patched!", x, iy)
		iy = iy + 22
		form:createLabel("Simply open 'roguemon.gba' from now on.", x, iy)
		iy = iy + 28

		form.Controls.close = form:createButton("Launch RogueMon", 108, iy, function()
			form:destroy()
		end, 105, 25)
	end

	function self.pleasePatchPrompt()
		local form = ExternalUI.BizForms.createForm("New RogueMon Patch", 320, 100, 100, 20)

		local x = 15
		local iy = 10
		form:createLabel("There is a new RogueMon ROM patch.", x, iy)
		iy = iy + 22
		form:createLabel("Please open Vanilla FireRed 1.1 to patch your ROM.", x, iy)
		iy = iy + 28

		form.Controls.close = form:createButton("Dismiss", 108, iy, function()
			form:destroy()
		end, 105, 25)
	end

	function self.editWinsForm()
		local complete = false
		local _failSafe = function()
			complete = true
		end
		local form = ExternalUI.BizForms.createForm("Edit Wins", 260, 170, 100, 20, _failSafe)

		local ascensions = {"1", "2", "3"}
		local x = 25
		local iy = 8
		form:createLabel("Use this to manually set win count in the ROM.", x, iy)
		iy = iy + 18

		local labelNote = form:createLabel("Note: You must save the game to persist these.", x, iy)
		iy = iy + 24
		ExternalUI.BizForms.setProperty(labelNote, ExternalUI.BizForms.Properties.FORE_COLOR, "red")

		form:createLabel("Ascension:", x, iy)
		x = x + 70
		local ascensionDropdown = form:createDropdown(ascensions, x, iy-4, 40, 1)
		iy = iy + 24

		local types = {}
		local typeNameToIndex = {}

		for i, name in pairs(PokemonData.TypeIndexMap) do
			types[i] = name:gsub("^%l", string.upper)
			typeNameToIndex[types[i]] = i
		end
		types[9] = "Typeless"
		typeNameToIndex[types[9]] = 9

		x = 25
		form:createLabel("Type:", x, iy)
		x = x + 70
		local typeDropdown = form:createDropdown(types, x, iy-4, 80, 1)
		iy = iy + 24

		x = 25
		form:createLabel("Wins:", x, iy)
		x = x + 70
		local winsBox = form:createTextBox("", x, iy-4, 30, 1, "UNSIGNED")
		iy = iy + 30


		form.Controls.buttonSubmit = form:createButton("Submit", 60, iy, function()
			local ascension = tonumber(ExternalUI.BizForms.getText(ascensionDropdown))
			local type = typeNameToIndex[ExternalUI.BizForms.getText(typeDropdown)]
			local wins = tonumber(ExternalUI.BizForms.getText(winsBox))

			if ascension == nil or type == nil or wins == nil then
				-- pass - something not set
			elseif not (ascension > 0 and ascension <= 3 and type >= 0 and type <= 18) then
				Utils.printDebug("Invalid data - wins not updated.")
			else
				self.writeROMWins(ascension, type, wins)
			end
			complete = true
			form:destroy()
		end, 50, 25)
		form.Controls.buttonCancel = form:createButton("Cancel", 115, iy, function()
			form:destroy()
		end, 50, 25)


		while not complete do
			Main.frameAdvance()
		end
	end

	function self.editAttemptsForm()
		local complete = false
		local _failSafe = function()
			complete = true
		end
		local form = ExternalUI.BizForms.createForm("Edit Attempts", 330, 170, 100, 20, _failSafe)

		local ascensions = {"1", "2", "3"}
		local x = 25
		local iy = 8
		form:createLabel("Use this to manually set attempts in the ROM and the Tracker.", x, iy)
		iy = iy + 18

		local labelNote = form:createLabel("Note: You must save the game to persist these in the ROM.", x, iy)
		iy = iy + 24
		ExternalUI.BizForms.setProperty(labelNote, ExternalUI.BizForms.Properties.FORE_COLOR, "red")

		x = 35
		form:createLabel("Ascension:", x, iy)
		x = x + 70
		local ascensionDropdown = form:createDropdown(ascensions, x, iy-4, 40, 1)
		iy = iy + 24

		local types = {}
		local typeNameToIndex = {}

		for i, name in pairs(PokemonData.TypeIndexMap) do
			types[i] = name:gsub("^%l", string.upper)
			typeNameToIndex[types[i]] = i
		end
		types[9] = "Typeless"
		typeNameToIndex[types[9]] = 9

		x = 35
		form:createLabel("Type:", x, iy)
		x = x + 70
		local typeDropdown = form:createDropdown(types, x, iy-4, 80, 1)
		iy = iy + 24

		x = 35
		form:createLabel("Attempts:", x, iy)
		x = x + 70
		local attemptsBox = form:createTextBox("", x, iy-4, 30, 1, "UNSIGNED")
		iy = iy + 30


		form.Controls.buttonSubmit = form:createButton("Submit", 102, iy, function()
			local ascension = tonumber(ExternalUI.BizForms.getText(ascensionDropdown))
			local type = typeNameToIndex[ExternalUI.BizForms.getText(typeDropdown)]
			local attempts = tonumber(ExternalUI.BizForms.getText(attemptsBox))

			if ascension == nil or type == nil or attempts == nil then
				-- pass - something not set
			elseif not (ascension > 0 and ascension <= 3 and type >= 0 and type <= 18) then
				Utils.printDebug("Invalid data - attempts not updated.")
			else
				self.writeROMAttempts(ascension, type, attempts)
				Main.WriteAttemptsCountToFile(self.getAttemptsFilePath(ascension, type), attempts)
			end
			complete = true
			form:destroy()
		end, 50, 25)
		form.Controls.buttonCancel = form:createButton("Cancel", 157, iy, function()
			form:destroy()
		end, 50, 25)


		while not complete do
			Main.frameAdvance()
		end
	end


	-- ROM READING/WRITING FUNCTIONS --

	-- Takes the offset of a known game var offset and returns the current value of
	-- that variable from the ROM. All ROM game vars are u16.
	function self.readGameVar(offset)
		return Memory.readword(Utils.getSaveBlock1Addr() + GameSettings.gameVarsOffset + offset)
	end

	-- Takes the offset of a known game var offset and a value, and writes that
	-- value to the ROM. All ROM game vars are u16.
	function self.writeGameVar(offset, value)
		return Memory.writeword(Utils.getSaveBlock1Addr() + GameSettings.gameVarsOffset + offset, value)
	end

	function self.getROMRunType()
		return self.readGameVar(GameSettings.roguemon.varType)
	end

	function self.getROMAscension()
		return self.readGameVar(GameSettings.roguemon.varAscension)
	end

	-- Returns True if we're currently in the ascension tower, or if we've been sent there.
	function self.isInAscensionTower()
		local inTower = TrackerAPI.getMapId() >= 298 and TrackerAPI.getMapId() <= 300
		if inTower then
			return true
		end

		local mask = 1 << GameSettings.roguemon.flagSentToTower
		local sentToTower = Memory.readbyte(GameSettings.sSpecialFlags) & mask ~= 0

		return sentToTower
	end

	-- Synchronizes the tracker attempt counts with the ROM.
	function self.syncAttempts()
		-- We backup the the original seed since Main.ReadAttemptsCount will update
		-- it. Note that the "currentSeed" is just a count of attempts.
		local backupSeed = Main.currentSeed
		local backupSettingsFile = Options.FILES["Settings File"]

		-- for each ascension/type pair, read the current attempts count from the
		-- tracker and from the ROM. If the tracker is higher, write to the ROM.
		for typeIndex, type in pairs(PokemonData.TypeIndexMap) do
			for _, ascension in ipairs({1, 2, 3}) do
				local settingsFile = self.getSettingsFilePath(ascension, typeIndex)

				Options.FILES["Settings File"] = settingsFile
				-- reads the attempts into Main.currentSeed
				Main.ReadAttemptsCount(true)
				local trackerAttempts = Main.currentSeed

				local romAttempts = self.getROMAttempts(ascension, typeIndex)

				if trackerAttempts > romAttempts then
					self.writeROMAttempts(ascension, typeIndex, trackerAttempts)
				end
			end
		end

		Main.currentSeed = backupSeed
		Options.FILES["Settings File"] = backupSettingsFile

		return true
	end

	function self.getAscensionString(ascension, typeIndex)
		local typeName = PokemonData.TypeIndexMap[typeIndex]
		if typeName == 'unknown' then
			typeName = 'typeless'
		end
		typeName = typeName:gsub("^%l", string.upper)
		return string.format("Ascension %d %s", ascension, typeName)
	end

	function self.getAttemptsFilePath(ascension, typeIndex)
		local directory = FileManager.getPathOverride("Attempt Counts") or FileManager.dir
		local fileName = string.format("%s%s", self.getAscensionString(ascension, typeIndex), FileManager.Extensions.ATTEMPTS)
		return directory .. fileName
	end

	function self.getSettingsFilePath(ascension, typeIndex)
		local directory = FileManager.getCustomFolderPath() .. FileManager.slash .. "roguemon" .. FileManager.slash .. "Roguemon Settings Files" .. FileManager.slash
		return string.format("%s%s.rnqs", directory, self.getAscensionString(ascension, typeIndex))
	end

	-- Fetches the Roguemon stamp from the running ROM. The stamp includes
	-- a UID, and the ascension and type that the ROM was randomized with.
	-- Returns a table of {uid, ascension, typeIndex}.
	function self.getRomStamp()
		-- ROM header struct fields:
		-- u32 roguemonUidStamp;
		-- u8 roguemonAscensionStamp:3;
		-- u8 roguemonTypeStamp:5;

		local uid = Memory.readdword(GameSettings.roguemon.romUid)
		local ascensionTypeByte = Memory.readbyte(GameSettings.roguemon.romUid+4)

		local ascension = ascensionTypeByte >> 5
		local typeMask = 0x1f -- 0b11111
		local typeIndex = ascensionTypeByte & typeMask

		return uid, ascension, typeIndex
	end


	-- ROM RANDOMIZATION FUNCTIONS --


	-- Returns true if the current running ROM seems to be Vanilla
	-- FireRed 1.1.
	function self.isROMVanilla()
		if gameinfo.getromhash():lower() == FIRERED_11_SHA1SUM:lower() then
			return true
		end

		-- todo: Some people use binpatch-safe changes like sprite swaps that
		-- we should allow. Use less stringent checks to determine if this is
		-- a Vanilla ROM that we can patch.

		return false
	end

	-- Stores the Vanilla FireRed ROM in a known location, then applies the
	-- RogueMon BPS patch against it to generate the ROM.
	function self.patchVanillaROM()
		if not FileManager.fileExists(self.Paths.PATCHER_JAR) then
			self.errorLog("Cannot patch ROM: JBPS JAR not found.")
			return false
		end
		if not FileManager.fileExists(self.Paths.ROM_BPS) then
			self.errorLog("Cannot patch ROM: RogueMon BPS not found.")
			return false
		end

		-- TODO - Skip this if there is a matching ROM at the expected path?
		local out = assert(io.open(self.Paths.VANILLA_ROM, "wb"))
		if out == nil then
			return false
		end

		local data = memory.read_bytes_as_array(0x08000000, FIRERED_11_SIZE)
		for _, byte in ipairs(data) do
			out:write(string.char(byte))
		end
		io.close(out)

		-- let this 16MB array get GCd
		data = nil

		local javaPath = Options.PATHS["Java Path"]
		if Utils.isNilOrEmpty(javaPath) then
			javaPath = "java" -- Default for most operating systems
		end

		local javacommand = string.format(
			'%s -jar "%s" "%s" "%s" "%s"',
			javaPath,
			self.Paths.PATCHER_JAR,
			self.Paths.ROM_BPS,
			self.Paths.VANILLA_ROM,
			self.Paths.ROGUEMON_UNRAND_ROM
		)

		local success, outputLines = FileManager.tryOsExecute(javacommand)
		if not success then
			self.errorLog("Failed to patch")
			Utils.printDebug(javacommand)
		end

		success = FileManager.CopyFile(self.Paths.ROGUEMON_UNRAND_ROM, self.Paths.ROGUEMON_ROM, 'overwrite')
		if not success then
			self.errorLog("Failed to copy ROM")
		end
		return success
	end


	-- If we appear to be running a Vanilla FireRed ROM, prompt the user if they'd like to
	-- patch it. If they accept, patch the ROM and prompt them to launch RogueMon.
	-- Returns nil if this isn't a FireRed ROM.
	-- Returns true if we tried to patch and succeeded.
	-- Returns false if we tried to patch and failed.
	function self.tryPatchVanillaROM()
		if not self.isROMVanilla() then
			return nil
		end

		local result = nil
		local complete = false
		local _completePromptCB = function()
			client.openrom(self.Paths.ROGUEMON_ROM)
			Main.forceRestart = true
			complete = true
		end

		local _patchPromptCB = function(shouldPatch)
			if shouldPatch then
				result = self.patchVanillaROM()
				if result then
					self.patchCompletePrompt(_completePromptCB)
					return
				end
			end

			complete = true
		end

		self.patchVanillaROMPrompt(_patchPromptCB)

		while not complete do
			Main.frameAdvance()
		end

		return result
	end

	-- Returns the string for `roguemonVersionStr` in the ROM header.
	function self.getROMRoguemonVersion()
		local romVersionAddr = GameSettings.roguemon.romUid+6 & 0xFFFFFF
		local versionBytes = memory.read_bytes_as_array(romVersionAddr, 12, "ROM")

		local versionStr = ""

		for _, b in ipairs(versionBytes) do
			if b >= 32 and b < 127 then
				versionStr = versionStr .. string.char(b)
			end
		end

		return versionStr
	end

	-- Checks if the ROM's patch version matches the patch we were bundled
	-- with. If the ROM's version is older, prompt the user to re-open
	-- Vanilla FireRed.
	function self.checkPatchVersion()
		local romVersion = self.getROMRoguemonVersion()

		-- check if the romVersion looks like a semver
		if not romVersion:find("^(%d+)%.(%d+)%.(%d+)(%-?[%w%-%.]*)(%+?[%w%.%-]*)") then
			return
		end

		if RoguemonUtils.compare_semver(romVersion, bundledRomPatchVersion) == -1 then
			self.pleasePatchPrompt()
		end
	end


	function self.checkAwaitingRandomization()
		return Utils.getbits(Memory.readbyte(GameSettings.sSpecialFlags), GameSettings.roguemon.flagAwaitingRandomization, 1) == 1
	end

	function self.markRandomizationComplete()
		local flagBit = 1 << GameSettings.roguemon.flagAwaitingRandomization
		local newFlags = Memory.readbyte(GameSettings.sSpecialFlags) & ~flagBit
		Memory.writebyte(GameSettings.sSpecialFlags, newFlags)
	end

	function self.sendPlayerToTower()
		local flagBit = 1 << GameSettings.roguemon.flagBackToTower
		local newFlags = Memory.readbyte(GameSettings.sSpecialFlags) | flagBit
		Memory.writebyte(GameSettings.sSpecialFlags, newFlags)
	end

	-- Override of Main.LoadNextRom. Generates a new ROM and swaps it into
	-- the running ROM, then restarts the tracker.
	function self.LoadNextRom(v1, v2)
		Main.loadNextSeed = false

		-- In this case, someone used the New Run Combo buttons. We don't
		-- actually want to randomize in this case. Instead, tell the
		-- ROM to ship the player to the ascension tower so they can
		-- pick a new run.
		if not randomizingROM then
			self.sendPlayerToTower()
			Main.ExitSafely(false)
			Main.Run()
			return
		end

		Program.GameTimer:reset()
		Utils.tempDisableBizhawkSound()

		if Main.IsOnBizhawk() then
			Drawing.clearImageCache()
			Utils.printDebug("--------Randomizing--------")
		else
			MGBA.clearConsole()
		end

		local ascension = self.getROMAscension()
		local runType = self.getROMRunType()

		local settingsFile = self.getSettingsFilePath(ascension, runType)
		Options.FILES["Settings File"] = settingsFile

		local nextRomInfo = Main.GenerateNextRom()

		if nextRomInfo == nil then
			self.markRandomizationComplete()
		end

		Main.ExitSafely(false)

		if nextRomInfo ~= nil then
			Main.ReadAttemptsCount(true)
			Main.currentSeed = Main.currentSeed + 1
			Main.WriteAttemptsCountToFile(nextRomInfo.attemptsFilePath)
			QuickloadScreen.afterNewRunProfileCheckup(nextRomInfo.filePath)
			Tracker.clearTrackerNotesAndFile()

			local successStamp = self.stampRomFile(nextRomInfo.filePath, ascension, runType)
			local successOverwrite = FileManager.CopyFile(nextRomInfo.filePath, self.Paths.ROGUEMON_ROM, 'overwrite')
			if successStamp and successOverwrite then
				savestate.save(self.Paths.RANDOMIZING_STATE, true)
				client.openrom(self.Paths.ROGUEMON_ROM)
				savestate.load(self.Paths.RANDOMIZING_STATE, true)
				self.markRandomizationComplete()

				if not Main.IsOnBizhawk() then
					-- MGBA is ready to restart, no other code needs to run
					return
				end
			else
				print(string.format('> ERROR: Unable to load generated ROM: %s', nextRomInfo.fileName or "N/A"))
			end
		end

		Utils.tempEnableBizhawkSound()

		Main.Run()
	end

	-- This overrides LogOverlay.getLogFileAutodetected.
	function self.getLogFileAutodetected(postFix)
		local logPath = self.getLogFilePath(postFix)
		if FileManager.fileExists(logPath) then
			return logPath
		else
			return nil
		end
	end


	-- Takes a ROM file path and dynamically writes it into the running
	-- memory of the current ROM.
	function self.rewriteRom(romFilePath)
		local file = assert(io.open(romFilePath, "rb"))
		if file == nil then
			return false
		end

		local t = {}
		repeat
			local str = file:read(4*1024)
			for c in (str or ''):gmatch'.' do
			byte = c:byte()
				t[#t+1] = byte
			end
		until not str

		file:close()

		memory.write_bytes_as_array(0x0, t, "ROM")
		return true
	end

	-- Stamps the header of the rom at the given file path with
	-- variables indicating the ascension and runType, along with
	-- a unique ID that will be used as our ROM "hash".
	function self.stampRomFile(romFilePath, ascension, runType)
		local file = assert(io.open(romFilePath, "r+b"))
		if file == nil then
			return false
		end

		local uid = math.random(0, 2^32 - 1)

		local stampAddress = GameSettings.roguemon.romUid - 0x08000000
		file:seek('set', stampAddress)

		-- ROM header struct fields:
		-- u8 roguemonAscensionStamp:3;
		-- u8 roguemonTypeStamp:5;
		local ascensionTypeStamp = (ascension << 5) | runType

		for _, b in ipairs(RoguemonUtils.uint32_to_bytes(uid)) do
			file:write(string.char(b))
		end

		file:write(string.char(ascensionTypeStamp))
		file:close()

		return true
	end

	-- we use this to track the original function call so we can restore them during `unload()`.
	local originalCoreFunctions = {}

	-- The core Tracker code ignores io.open errors in most cases, which
	-- can make diagnosing certain bugs difficult. This function can be
	-- used as an override for io.open to print all io.open errors other
	-- than "No such file".
	function self.noisyIOOpen(...)
		local f, errMsg, errNo = originalCoreFunctions.io.open(...)
		if f == nil and errMsg ~= nil then
			if errMsg:find("No such file or directory") == nil then
				Utils.printDebug("Error opening %s - code %d", errMsg, errNo)
			end
		end
		return f, errMsg, errNo
	end

	-- Overrides the given function from the given module with `newFunc`.
	-- `moduleName` and `funcName` are used to track what was overridden so
	-- we can restore it later.
	local function overrideFunction(module, moduleName, funcName, newFunc)
		if originalCoreFunctions[moduleName] == nil then
			originalCoreFunctions[moduleName] = {}
		end
		originalCoreFunctions[moduleName][funcName] = module[funcName]
		module[funcName] = newFunc
	end

	local function restoreFunctions(module, moduleName)
		local funcs = originalCoreFunctions[moduleName]
		if funcs == nil then
			return
		end
		for name, func in pairs(funcs) do
			if type(func) == "function" then
				module[name] = func
			end
		end
		originalCoreFunctions[moduleName] = nil
	end

	function self.overrideCoreTrackerFunctions()
		event.onexit(self.restoreCoreTrackerFunctions, "restoreCoreTrackerFunctions")
		event.onconsoleclose(self.restoreCoreTrackerFunctions, "restoreCoreTrackerFunctions")
		overrideFunction(Main, "Main", "LoadNextRom", self.LoadNextRom)
		overrideFunction(LogOverlay, "LogOverlay", "getLogFileAutodetected", self.getLogFileAutodetected)

		if self.DEBUG_IO_OPEN_ERRORS then
			overrideFunction(io, "io", "open", self.noisyIOOpen)
		end
	end

	-- restores overridden functions. Called when we unload(), or when the
	-- console exits or closes.
	function self.restoreCoreTrackerFunctions()
		restoreFunctions(Main, "Main")
		restoreFunctions(FileManager, "FileManager")
		restoreFunctions(GameSettings, "GameSettings")
		restoreFunctions(LogOverlay, "LogOverlay")
		restoreFunctions(io, "io")
	end

	return self
end
return RoguemonTracker
