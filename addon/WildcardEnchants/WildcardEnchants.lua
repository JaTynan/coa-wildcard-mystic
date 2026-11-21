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

-- Speed (21 Nov): opening the window, turning a page or changing a filter used to
-- look up all 6,440 enchants (name and info each) and sort them every time, which
-- froze the game for a moment. Names, order and the fixed filters are now worked
-- out once; known/unknown is checked only when that filter is on (otherwise only
-- for the page shown); and the same query repeated within 2 seconds (the window
-- asks several times while opening) reuses the last answer.
local index            -- every enchant with its name, sorted best quality first, then by name
local lastKey, lastTime, lastResults, lastMaxPage

local function Index()
	if index then
		return index
	end
	index = {}
	for _, entry in ipairs(WildcardEnchantsData or {}) do
		local name = GetSpellInfo(entry[1])
		if name then
			index[#index + 1] = { spell = entry[1], quality = entry[2], worldforged = entry[3] == 1,
				mask = entry[4], name = name, lower = name:lower() }
		end
	end
	table.sort(index, function(a, b)
		if a.quality ~= b.quality then
			return a.quality > b.quality
		end
		return a.name < b.name
	end)
	return index
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
	table.sort(active)
	local key = perPage .. "|" .. page .. "|" .. search .. "|" .. table.concat(active, ",")
	if key == lastKey and GetTime() - lastTime < 2 then
		return lastResults, lastMaxPage
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
	local checkKnown = wantKnown ~= wantUnknown

	local matches = {}
	for _, enchant in ipairs(Index()) do
		local keep = (not anyQuality or qualities[enchant.quality])
			and not (wantWorldforged and not enchant.worldforged)
			and not (wantNotWorldforged and enchant.worldforged)
			and (search == "" or enchant.lower:find(search, 1, true) ~= nil)
		if keep and anyClass then
			keep = false
			for _, classID in ipairs(classes) do
				if HasClass(enchant.mask, classID) then
					keep = true
					break
				end
			end
		end
		if keep and checkKnown then
			local info = C_MysticEnchant.GetEnchantInfoBySpell(enchant.spell)
			keep = info ~= nil and (info.Known and true or false) == wantKnown
		end
		if keep then
			matches[#matches + 1] = enchant
		end
	end

	local maxPage = #matches > 0 and math.ceil(#matches / perPage) or 0
	page = math.min(page, math.max(maxPage, 1))
	local results = {}
	for i = (page - 1) * perPage + 1, math.min(page * perPage, #matches) do
		local info = C_MysticEnchant.GetEnchantInfoBySpell(matches[i].spell)
		if info then
			results[#results + 1] = info
		end
	end
	lastKey, lastTime, lastResults, lastMaxPage = key, GetTime(), results, maxPage
	return results, maxPage
end

-- An enchant learned or applied changes what the list shows: forget the last answer.
local function Forget()
	lastKey = nil
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
			-- The client numbers slots 1-17, the server 0-16 (client slot i is server slot i - 1).
			return activeSlots[(tonumber(slot) or 0) - 1] or 0
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
for _, event in ipairs({ "MYSTIC_ENCHANT_LEARNED", "MYSTIC_ENCHANT_SLOT_UPDATE", "MYSTIC_ENCHANT_PRESET_SET_ACTIVE_RESULT" }) do
	pcall(events.RegisterEvent, events, event)   -- names from the Ascension client; skipped if absent
end
events:SetScript("OnEvent", function(_, event, name, message, channel, sender)
	if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" and event ~= "PLAYER_ENTERING_WORLD"
		and event ~= "CHAT_MSG_ADDON" then
		Forget()   -- MYSTIC_ENCHANT_* events
		return
	end
	if event == "CHAT_MSG_ADDON" then
		if name == PREFIX and channel == "WHISPER" and sender == UnitName("player") then
			local slots = ParseSlots(message or "")
			if slots then
				activeSlots = slots
				Forget()
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
