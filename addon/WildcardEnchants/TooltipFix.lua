-- Some broken enchants were restored by giving them a working twin (another realm type's version of the
-- same enchant). Where the twin works differently, the old tooltip would mislead, so this shows the twin's
-- text instead: in spell tooltips, links and the scroll item tooltips, anywhere the old text appears.

local scan = CreateFrame("GameTooltip", "WildcardEnchantsScanTooltip", nil, "GameTooltipTemplate")
scan:SetOwner(UIParent, "ANCHOR_NONE")

-- The description is the first real line under the name. Enchant tooltips can add more below it (a separator
-- and the buff they grant, with its own text), so the last line is not always the description. Many enchants
-- start with a "Requires <spell>" line; that is not the description and must never be used as one, or the
-- swap below would rewrite "Requires Level 60" on every item tooltip.
local MIN_LENGTH = 30

local function Description(spellID)
	scan:SetOwner(UIParent, "ANCHOR_NONE")
	scan:ClearLines()
	scan:SetHyperlink("spell:" .. spellID)
	for i = 2, scan:NumLines() do
		local line = _G["WildcardEnchantsScanTooltipTextLeft" .. i]
		local text = line and line:GetText()
		if text and string.len(text) >= MIN_LENGTH and not string.find(text, "^Requires") then
			return text
		end
	end
end

local replacements
local function Replacements()
	if not replacements then
		replacements = {}
		for spellID, twinID in pairs(WildcardEnchantsTooltipTwin or {}) do
			local old, new = Description(spellID), Description(twinID)
			if old and new and old ~= new then
				replacements[old] = new
			end
		end
	end
	return replacements
end

-- Only text that is plainly an enchant description is touched: a whole line equal to the old text, or a line
-- that contains it (scroll items quote the description inside a longer line). Requirement lines never change.
local function Fix(tooltip)
	local list = Replacements()
	if not next(list) then
		return
	end
	local name = tooltip:GetName()
	local changed = false
	for i = 2, tooltip:NumLines() do
		local line = _G[name .. "TextLeft" .. i]
		local text = line and line:GetText()
		if text and not string.find(text, "^Requires") and not string.find(text, "Requires Level") then
			local new = list[text]
			if not new then
				for old, replacement in pairs(list) do
					local first, last = string.find(text, old, 1, true)
					if first then
						new = string.sub(text, 1, first - 1) .. replacement .. string.sub(text, last + 1)
						break
					end
				end
			end
			if new then
				line:SetText(new)
				changed = true
			end
		end
	end
	if changed then
		tooltip:Show()
	end
end

for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
	tooltip:HookScript("OnTooltipSetSpell", Fix)
	tooltip:HookScript("OnTooltipSetItem", Fix)
end
