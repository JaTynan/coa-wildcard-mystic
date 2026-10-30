-- Wildcard Mystic Enchants
-- The Collections window hides its Mystic Enchant tab in Wildcard mode and sends
-- requests for it to Character Advancement instead. This keeps the tab available
-- for Wildcard characters. The enchant UI already has a Wildcard layout; only the
-- entrance was closed. It changes nothing for other characters.

local function IsWildcard()
	return C_GameMode and Enum and Enum.GameMode and C_GameMode:IsGameModeActive(Enum.GameMode.WildCard)
end

local function Applies()
	return IsWildcard() and not IsCustomClass()
end

local function Patch()
	local frame = Collections
	if not frame or frame.wildcardEnchantsPatched or not frame.Tabs or not frame.Tabs.MysticEnchants then
		return
	end
	frame.wildcardEnchantsPatched = true

	-- Opening the enchant tab (scrolls, altars, buttons) goes through GoToTab.
	local originalGoToTab = frame.GoToTab
	frame.GoToTab = function(self, id)
		if id and id == self.Tabs.MysticEnchants and Applies() then
			ShowUIPanel(self)
			self:ShowTabID(id)
			self:SelectTabID(id)
			UpdateMicroButtons()
			return
		end
		return originalGoToTab(self, id)
	end

	-- The window's own OnShow hides the tab in Wildcard; show it again afterwards.
	frame:HookScript("OnShow", function(self)
		if Applies() then
			self:ShowTabID(self.Tabs.MysticEnchants)
		end
	end)
end

-- Objections that do not apply to Wildcard: the Wildcard block itself, and the
-- essence investment requirements (Wildcard builds come from rolls, not trees;
-- the server ignores them for Wildcard characters too).
local WILDCARD_ONLY = { "_DISABLED_IN_WILDCARD$", "_REQUIRED_AE_INVESTMENT$", "_REQUIRED_TE_INVESTMENT$" }

local function WildcardOnly(errorStr)
	for _, pattern in ipairs(WILDCARD_ONLY) do
		if errorStr:find(pattern) then
			return true
		end
	end
	return false
end

-- The client carries its own copy of the enchant rules (C_MysticEnchant.Can...),
-- which answers every check with *_DISABLED_IN_WILDCARD for Wildcard characters:
-- it blocks requests before they are sent and marks active enchants as broken.
-- When a check's only objection is one of the above, report it as passed. The
-- server checks every request again with the real rules
-- (CoA.MysticEnchants.AllowWildcard), rarity limits included, and grants the
-- enchant effects itself.
local function PatchChecks()
	local api = C_MysticEnchant
	if not api or api.wildcardEnchantsPatched then
		return
	end
	api.wildcardEnchantsPatched = true

	local names = {}
	for name, fn in pairs(api) do
		if type(fn) == "function" and name:find("^Can") then
			names[#names + 1] = name
		end
	end
	for _, name in ipairs(names) do
		local original = api[name]
		api[name] = function(...)
			local success, errorStr = original(...)
			if not success and Applies() and type(errorStr) == "string" and WildcardOnly(errorStr) then
				return true
			end
			return success, errorStr
		end
	end
end

-- The client's enchant list (C_MysticEnchant.QueryEnchants) returns nothing at all
-- for Wildcard characters. For them, build the list from EnchantData.lua instead,
-- asking the client about each enchant and applying the collection tab's filters.
local QUALITY_FILTERS = {
	RE_FILTER_UNCOMMON = 2, RE_FILTER_RARE = 3, RE_FILTER_EPIC = 4,
	RE_FILTER_LEGENDARY = 5, RE_FILTER_ARTIFACT = 6,
}
local CLASS_FILTERS = {
	RE_FILTER_CLASS_WARRIOR = 1, RE_FILTER_CLASS_PALADIN = 2, RE_FILTER_CLASS_HUNTER = 3,
	RE_FILTER_CLASS_ROGUE = 4, RE_FILTER_CLASS_PRIEST = 5, RE_FILTER_CLASS_DEATH_KNIGHT = 6,
	RE_FILTER_CLASS_SHAMAN = 7, RE_FILTER_CLASS_MAGE = 8, RE_FILTER_CLASS_WARLOCK = 9,
	RE_FILTER_CLASS_HERO = 10, RE_FILTER_CLASS_DRUID = 11,
}

local function HasClass(mask, classID)
	return mask == 0 or math.floor(mask / 2 ^ (classID - 1)) % 2 == 1
end

local function QueryEnchants(perPage, page, search, filters)
	perPage = math.max(1, tonumber(perPage) or 1)
	page = math.max(1, tonumber(page) or 1)
	search = type(search) == "string" and search:lower():match("^%s*(.-)%s*$") or ""

	local wantKnown, wantUnknown, wantWorldforged, wantNotWorldforged = false, false, false, false
	local qualities, classes, anyQuality, anyClass = {}, {}, false, false
	-- The collection tab passes a set ({RE_FILTER_KNOWN = true, ...}); other callers
	-- pass a list ({"RE_FILTER_KNOWN"}). Accept both.
	local active = {}
	for key, value in pairs(type(filters) == "table" and filters or {}) do
		if type(key) == "string" and value then
			active[#active + 1] = key
		elseif type(value) == "string" then
			active[#active + 1] = value
		end
	end
	for _, filter in ipairs(active) do
		if filter == "RE_FILTER_KNOWN" then wantKnown = true
		elseif filter == "RE_FILTER_UNKNOWN" then wantUnknown = true
		elseif filter == "RE_FILTER_WORLDFORGED" then wantWorldforged = true
		elseif filter == "RE_FILTER_NOT_WORLDFORGED" then wantNotWorldforged = true
		elseif QUALITY_FILTERS[filter] then qualities[QUALITY_FILTERS[filter]] = true; anyQuality = true
		elseif CLASS_FILTERS[filter] then classes[#classes + 1] = CLASS_FILTERS[filter]; anyClass = true
		end
	end

	local matches = {}
	for _, entry in ipairs(WildcardEnchantsData or {}) do
		local spellID, quality, worldforged, mask = entry[1], entry[2], entry[3] == 1, entry[4]
		local keep = (not anyQuality or qualities[quality])
			and not (wantWorldforged and not worldforged)
			and not (wantNotWorldforged and worldforged)
		if keep and anyClass then
			keep = false
			for _, classID in ipairs(classes) do
				if HasClass(mask, classID) then
					keep = true
					break
				end
			end
		end
		if keep then
			local info = C_MysticEnchant.GetEnchantInfoBySpell(spellID)
			if info then
				if wantKnown ~= wantUnknown then
					keep = (info.Known and true or false) == wantKnown
				end
				local name = GetSpellInfo(spellID)
				if keep and name and (search == "" or name:lower():find(search, 1, true)) then
					matches[#matches + 1] = { info = info, quality = quality, name = name }
				end
			end
		end
	end

	table.sort(matches, function(a, b)
		if a.quality ~= b.quality then
			return a.quality > b.quality
		end
		return a.name < b.name
	end)

	local maxPage = #matches > 0 and math.ceil(#matches / perPage) or 0
	page = math.min(page, math.max(maxPage, 1))
	local results = {}
	for index = (page - 1) * perPage + 1, math.min(page * perPage, #matches) do
		results[#results + 1] = matches[index].info
	end
	return results, maxPage
end

local function PatchQuery()
	local api = C_MysticEnchant
	if not api or api.wildcardEnchantsQueryPatched or not api.QueryEnchants then
		return
	end
	api.wildcardEnchantsQueryPatched = true
	local original = api.QueryEnchants
	api.QueryEnchants = function(...)
		if Applies() then
			return QueryEnchants(...)
		end
		return original(...)
	end
end

-- The client also keeps no record of a Wildcard character's active slots
-- (GetAppliedEnchant answers 0 for every slot). The patched server sends them as
-- an addon whisper, "WCME" / "S:<slot 0>,<slot 1>,...", on login and on every
-- change; the addon asks again after loading, since it misses the login send.
local PREFIX = "WCME"
local activeSlots

local function ParseSlots(message)
	local list = message:match("^S:(.*)$")
	if not list then
		return nil
	end
	local slots, slot = {}, 0
	for spell in list:gmatch("[^,]+") do
		slots[slot] = tonumber(spell) or 0
		slot = slot + 1
	end
	return slots
end

local function RefreshWindow()
	local frame = EnchantCollection
	if frame and frame:IsShown() and frame.GetSlotTab then
		pcall(function()
			frame:GetSlotTab():MYSTIC_ENCHANT_SLOT_UPDATE()
		end)
	end
end

local function PatchApplied()
	local api = C_MysticEnchant
	if not api or api.wildcardEnchantsAppliedPatched or not api.GetAppliedEnchant then
		return
	end
	api.wildcardEnchantsAppliedPatched = true
	local original = api.GetAppliedEnchant
	api.GetAppliedEnchant = function(unit, slot, ...)
		if activeSlots and Applies() and (unit == "player" or UnitIsUnit(unit, "player")) then
			return activeSlots[tonumber(slot) or -1] or 0
		end
		return original(unit, slot, ...)
	end
end

local function RequestSlots()
	if Applies() then
		SendAddonMessage(PREFIX, "REQ", "WHISPER", UnitName("player"))
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, event, name, message, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if name == PREFIX and channel == "WHISPER" and sender == UnitName("player") then
			local slots = ParseSlots(message or "")
			if slots then
				activeSlots = slots
				RefreshWindow()
			end
		end
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		RequestSlots()
		return
	end
	if event == "PLAYER_LOGIN" then
		PatchChecks()
		PatchQuery()
		PatchApplied()
	end
	if event == "PLAYER_LOGIN" or name == "Ascension_Collections" then
		Patch()
	end
end)
