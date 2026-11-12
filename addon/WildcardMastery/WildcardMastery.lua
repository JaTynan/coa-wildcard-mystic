-- Wildcard Profession Mastery: shows the Mastery the server tracks past skill 300.
-- The server whispers the data to the player as an addon message:
--   prefix "WCMM", "M:<skill>,<level>,<max>,<into level>,<level needs>,<bonus x100>,<G|C>;..."
-- and this addon asks for it again with "REQ" after loading. Without the server part, nothing shows.

local PREFIX = "WCMM"
local GOLD = "|cffffd100"

-- Skill line ids the server uses, and their English names in the Skills tab and profession windows.
local NAMES = {
	[186] = "Mining", [182] = "Herbalism", [393] = "Skinning", [356] = "Fishing",
	[755] = "Jewelcrafting", [773] = "Inscription", [164] = "Blacksmithing", [165] = "Leatherworking",
	[197] = "Tailoring", [202] = "Engineering",
}
local BY_NAME = {}
for id, name in pairs(NAMES) do BY_NAME[name] = id end

local mastery = {} -- skill id -> { level, max, into, span, bonus, kind }

local function Parse(message)
	local body = message:match("^M:(.*)$")
	if not body then return end
	wipe(mastery)
	for entry in body:gmatch("[^;]+") do
		local skill, level, max, into, span, bonus, kind = entry:match("^(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),(%a)$")
		if skill then
			mastery[tonumber(skill)] = { level = tonumber(level), max = tonumber(max), into = tonumber(into),
				span = tonumber(span), bonus = tonumber(bonus) / 100, kind = kind }
		end
	end
end

local function BonusText(m)
	if m.kind == "C" then
		return string.format("x%.2f bonus-roll chance on crafted gear", m.bonus)
	end
	return string.format("x%.2f materials", m.bonus)
end

local function Summary(m)
	local next = m.span > 0 and string.format(", %d / %d to next", m.into, m.span) or ", maxed"
	return string.format("Mastery %d / %d: %s%s", m.level, m.max, BonusText(m), next)
end

local function ForName(name)
	local id = name and BY_NAME[name]
	return id and mastery[id]
end

-------------------------------------------------------------------------- Skills tab (character window)
local function DecorateSkillBar(statusBarID, skillIndex)
	local name = GetSkillLineInfo(skillIndex)
	local rank = _G["SkillRankFrame" .. statusBarID .. "SkillRank"]
	local m = ForName(name)
	if rank and m and m.level > 0 then
		local text = rank:GetText() or ""
		if not text:find("M%d") then
			rank:SetText(text .. "  " .. GOLD .. "M" .. m.level .. "|r")
		end
	end
end

local detail
local function DecorateSkillDetail(skillIndex)
	local bar = SkillDetailStatusBar
	if not bar then return end
	if not detail then
		detail = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		detail:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -4)
		detail:SetJustifyH("LEFT")
	end
	local m = ForName(GetSkillLineInfo(skillIndex))
	detail:SetText(m and (GOLD .. Summary(m) .. "|r") or "")
end

local function RefreshSkills()
	if SkillFrame and SkillFrame:IsShown() and SkillFrame_UpdateSkills then
		SkillFrame_UpdateSkills()
	end
end

-------------------------------------------------------------------------- Profession windows
local tradeText
local function RefreshTrade()
	if not TradeSkillFrame or not TradeSkillRankFrame then return end
	if not tradeText then
		tradeText = TradeSkillFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		tradeText:SetPoint("TOPLEFT", TradeSkillRankFrame, "BOTTOMLEFT", 0, -3)
		tradeText:SetJustifyH("LEFT")
	end
	local m = ForName(GetTradeSkillLine())
	tradeText:SetText(m and (GOLD .. Summary(m) .. "|r") or "")
end

-------------------------------------------------------------------------- Wiring
local hooked = false
local function Hook()
	if hooked then return end
	if SkillFrame_SetStatusBar then
		hooksecurefunc("SkillFrame_SetStatusBar", function(statusBarID, skillIndex) DecorateSkillBar(statusBarID, skillIndex) end)
	end
	if SkillDetailFrame_SetStatusBar then
		hooksecurefunc("SkillDetailFrame_SetStatusBar", function(skillIndex) DecorateSkillDetail(skillIndex) end)
	end
	hooked = true
end

local function Request()
	SendAddonMessage(PREFIX, "REQ", "WHISPER", UnitName("player"))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("TRADE_SKILL_SHOW")
events:RegisterEvent("TRADE_SKILL_UPDATE")
events:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
	if event == "CHAT_MSG_ADDON" then
		if prefix == PREFIX and channel == "WHISPER" and sender == UnitName("player") then
			Parse(message or "")
			RefreshSkills()
			RefreshTrade()
		end
	elseif event == "PLAYER_LOGIN" then
		Hook()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Request()
	else
		RefreshTrade()
	end
end)

SLASH_WILDCARDMASTERY1 = "/mastery"
SlashCmdList.WILDCARDMASTERY = function()
	local any = false
	for id, name in pairs(NAMES) do
		local m = mastery[id]
		if m then
			any = true
			DEFAULT_CHAT_FRAME:AddMessage(GOLD .. name .. "|r: " .. Summary(m))
		end
	end
	if not any then
		DEFAULT_CHAT_FRAME:AddMessage(GOLD .. "Profession Mastery|r: nothing yet. Mastery starts once a profession reaches 300.")
		Request()
	end
end
