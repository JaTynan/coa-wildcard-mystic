-- Wildcard Combat Log Fix (game version 3.3.5).
-- The 3.3.5 client's combat log gets stuck when a lot happens around you (on Wildcard, hundreds of bots): it stops
-- passing events on, so damage meters (Details!, Skada, Recount) record nothing and the Combat Log tab stays empty
-- until it is cleared. This clears it:
--   * when you change zone type (world, dungeon, raid, battleground), where it most often breaks;
--   * when one of your own spells that costs mana, rage, energy or runic power succeeds and no combat log event at
--     all arrives within a second of it: the log is stuck, so it is cleared (at most once every 5 seconds).
-- The same approach as Shadowed's CombatLogFix, written fresh for Wildcard. /clf shows how often it has cleared.

local ADDON = "WildcardCombatLogFix"
local frame = CreateFrame("Frame")
local lastEvent = 0      -- GetTime() of the last combat log event seen
local waiting = nil      -- seconds left to see an event after one of our casts
local lastClear = 0
local instanceType = nil
local clears = 0

local function Print(text)
    local chat = DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then
        chat:AddMessage("|cff33ff99Combat Log Fix|r: " .. text)
    end
end

local function Clear(reason)
    local now = GetTime()
    if now - lastClear < 5 then return end
    lastClear = now
    clears = clears + 1
    CombatLogClearEntries()
    if WildcardCombatLogFixDB and WildcardCombatLogFixDB.report then
        Print("cleared the combat log (" .. reason .. ").")
    end
end

-- Spells that cost power always make a combat log entry when they succeed.
local costs = setmetatable({}, { __index = function(cache, name)
    local cost = select(4, GetSpellInfo(name))
    local known = cost ~= nil and cost > 0
    rawset(cache, name, known)
    return known
end })

local handlers = {}

function handlers.ADDON_LOADED(addon)
    if addon ~= ADDON then return end
    frame:UnregisterEvent("ADDON_LOADED")
    WildcardCombatLogFixDB = WildcardCombatLogFixDB or { report = false }
end

function handlers.PLAYER_ENTERING_WORLD()
    local _, kind = IsInInstance()
    if instanceType and kind ~= instanceType then
        Clear("new zone type")
    end
    instanceType = kind
end
handlers.ZONE_CHANGED_NEW_AREA = handlers.PLAYER_ENTERING_WORLD

function handlers.COMBAT_LOG_EVENT_UNFILTERED()
    lastEvent = GetTime()
end

function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, name)
    if unit == "player" and name and costs[name] then
        waiting = 1
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    handlers[event](...)
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    if not waiting then return end
    waiting = waiting - elapsed
    if waiting > 0 then return end
    waiting = nil
    if GetTime() - lastEvent > 1.5 then
        Clear("it had stopped")
    end
end)

for event in pairs(handlers) do
    frame:RegisterEvent(event)
end

SLASH_WILDCARDCOMBATLOGFIX1 = "/clf"
SlashCmdList.WILDCARDCOMBATLOGFIX = function(msg)
    msg = string.lower(msg or "")
    if msg == "report" then
        WildcardCombatLogFixDB.report = not WildcardCombatLogFixDB.report
        Print("a message on each clear is " .. (WildcardCombatLogFixDB.report and "on" or "off") .. ".")
    elseif msg == "clear" then
        lastClear = 0
        Clear("by hand")
    else
        Print("cleared " .. clears .. " time(s) this session. /clf report: a message on each clear; /clf clear: clear now.")
    end
end
