---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by 
--- DateTime: 19/06/2018 09:18
---
--- Imported
local CombatTracker = {}
local Data = {}
local Listener = {}
local listeners = {}

local frame = CreateFrame('Frame', 'return 0, 236353')
frame:SetScript('OnEvent', function(_, event, ...)
    if not listeners[event] then return end
    for k in pairs(listeners[event]) do
        listeners[event][k](...)
    end
end)

function Listener.Add(_, name, event, callback)
    if not listeners[event] then
        frame:RegisterEvent(event)
        listeners[event] = {}
    end
    listeners[event][name] = callback
end

function Listener.Remove(_, name, event)
    if listeners[event] then
        listeners[event][name] = nil
    end
end

function Listener.Trigger(_, event, ...)
    onEvent(nil, event, ...)
end

-- Thse are Mixed Damage types (magic and pysichal)
local Doubles = {
    [3]   = 'Holy + Physical',
    [5]   = 'Fire + Physical',
    [9]   = 'Nature + Physical',
    [17]  = 'Frost + Physical',
    [33]  = 'Shadow + Physical',
    [65]  = 'Arcane + Physical',
    [127] = 'Arcane + Shadow + Frost + Nature + Fire + Holy + Physical',
}

local function addToData(GUID)
    if not Data[GUID] then
        Data[GUID] = {
            -- Damage Taken
            dmgTaken = 0,
            dmgTaken_P = 0,
            dmgTaken_M = 0,
            hits_taken = 0,
            lastHit_taken = 0,
            -- Damage Done
            dmgDone = 0,
            dmgDone_P = 0,
            dmgDone_M = 0,
            hits_done = 0,
            lastHit_done = 0,
            -- Healing taken
            heal_taken = 0,
            heal_hits_taken = 0,
            -- Healing Done
            heal_done = 0,
            heal_hits_done = 0,
            --shared
            combat_time = GetTime(),
            spell_value = {}
        }
    end
end

--[[ This Logs the damage done for every unit ]]
local logDamage = function(...)
    local _,_,_, SourceGUID, _,_,_, DestGUID, _,_,_, spellID, _, school, Amount, a, b, c = ...
    -- Chat Output for Debugging
    --	if SourceGUID == UnitGUID('player') then
    --		print(spellID)
    --	end
    -- Mixed
    if Doubles[school] then
        Data[DestGUID].dmgTaken_P = Data[DestGUID].dmgTaken_P + Amount
        Data[DestGUID].dmgTaken_M = Data[DestGUID].dmgTaken_M + Amount
        Data[SourceGUID].dmgDone_P = Data[SourceGUID].dmgDone_P + Amount
        Data[SourceGUID].dmgDone_M = Data[SourceGUID].dmgDone_M + Amount
        -- Pysichal
    elseif school == 1  then
        Data[DestGUID].dmgTaken_P = Data[DestGUID].dmgTaken_P + Amount
        Data[SourceGUID].dmgDone_P = Data[SourceGUID].dmgDone_P + Amount
        -- Magic
    else
        Data[DestGUID].dmgTaken_M = Data[DestGUID].dmgTaken_M + Amount
        Data[SourceGUID].dmgDone_M = Data[SourceGUID].dmgDone_M + Amount
    end
    -- Totals
    Data[DestGUID].dmgTaken = Data[DestGUID].dmgTaken + Amount
    Data[DestGUID].hits_taken = Data[DestGUID].hits_taken + 1
    Data[SourceGUID].dmgDone = Data[SourceGUID].dmgDone + Amount
    Data[DestGUID].hits_done = Data[DestGUID].hits_done + 1
    Data[SourceGUID][spellID] = ((Data[SourceGUID][spellID] or Amount) + Amount) / 2
end

--[[ This Logs the swings (damage) done for every unit ]]
local logSwing = function(...)
    local _,_,_, SourceGUID, _,_,_, GUID, _,_,_, Amount = ...
    Data[GUID].dmgTaken_P = Data[GUID].dmgTaken_P + Amount
    Data[GUID].dmgTaken = Data[GUID].dmgTaken + Amount
    Data[GUID].hits_taken = Data[GUID].hits_taken + 1
    Data[SourceGUID].dmgDone_P = Data[SourceGUID].dmgDone_P + Amount
    Data[SourceGUID].dmgDone = Data[SourceGUID].dmgDone + Amount
    Data[SourceGUID].hits_done = Data[SourceGUID].hits_done + 1
end

--[[ This Logs the healing done for every unit
		 !!~counting selfhealing only for now~!!]]
local logHealing = function(...)
    local _,_,_, SourceGUID, _,_,_, DestGUID, _,_,_, spellID, _,_, Amount = ...
    Data[DestGUID].heal_taken = Data[DestGUID].heal_taken + Amount
    Data[DestGUID].heal_hits_taken = Data[DestGUID].heal_hits_taken + 1
    Data[SourceGUID].heal_done = Data[SourceGUID].heal_done + Amount
    Data[SourceGUID].heal_hits_done = Data[SourceGUID]  .heal_hits_done + 1
    Data[SourceGUID][spellID] = ((Data[SourceGUID][spellID] or Amount) + Amount) / 2
end

--[[ This Logs the last action done for every unit ]]
local addAction = function(...)
    local _,_,_, sourceGUID, _,_,_,_, destName, _,_,_, spellName = ...
    if not spellName then return end
    if sourceGUID == UnitGUID('player') then
        --local icon = select(3, GetSpellInfo(spellName))
        --ActionLog:Add('Spell Cast Succeed', spellName, icon, destName)
    end
    Data[sourceGUID].lastcast = spellName
end

--[[ These are the events we're looking for and its respective action ]]
local EVENTS = {
    ['SPELL_DAMAGE'] = logDamage,
    ['DAMAGE_SHIELD'] = logDamage,
    ['SPELL_PERIODIC_DAMAGE']	= logDamage,
    ['SPELL_BUILDING_DAMAGE']	= logDamage,
    ['RANGE_DAMAGE'] = logDamage,
    ['SWING_DAMAGE'] = logSwing,
    ['SPELL_HEAL'] = logHealing,
    ['SPELL_PERIODIC_HEAL'] = logHealing,
    ['UNIT_DIED'] = function(...) Data[select(8, ...)] = nil end,
    --['SPELL_CAST_SUCCESS'] = addAction
}

--[[ Returns the total ammount of time a unit is in-combat for ]]
function CombatTime(UNIT)
    local GUID = UnitGUID(UNIT)
    if Data[GUID] and InCombatLockdown() then
        local combatTime = (GetTime()-Data[GUID].combat_time)
        return combatTime
    end
    return 0
end

function getDMG(UNIT)
    local total, Hits, phys, magic = 0, 0, 0, 0
    local GUID = UnitGUID(UNIT)
    if Data[GUID] then
        local time = GetTime()
        -- Remove a unit if it hasnt recived dmg for more then 5 sec
        if (time-Data[GUID].lastHit_taken) > 5 then
            Data[GUID] = nil
        else
            local combatTime = CombatTime(UNIT)
            total = Data[GUID].dmgTaken / combatTime
            phys = Data[GUID].dmgTaken_P / combatTime
            magic = Data[GUID].dmgTaken_M / combatTime
            Hits = Data[GUID].hits_taken
        end
    end
    return total, Hits, phys, magic
end

function TimeToDie(unit)
    local ttd = 0
    local DMG, Hits = self:getDMG(unit)
    if DMG >= 1 and Hits > 1 then
        ttd = UnitHealth(unit) / DMG
    end
    return ttd or 8675309
end

function LastCast(_, unit)
    local GUID = UnitGUID(unit)
    if Data[GUID] then
        return Data[GUID].lastcast
    end
end

function SpellDamage(_, unit, spellID)
    local GUID = UnitGUID(unit)
    return Data[GUID] and Data[GUID][spellID] or 0
end

Listener:Add('return 0, 236353', 'COMBAT_LOG_EVENT_UNFILTERED', function(...)
    local _, EVENT, _, SourceGUID, _,_,_, DestGUID = ...
    -- Add the unit to our data if we dont have it
    addToData(SourceGUID)
    addToData(DestGUID)
    -- Update last  hit time
    Data[DestGUID].lastHit_taken = GetTime()
    Data[SourceGUID].lastHit_done = GetTime()
    -- Add the amount of dmg/heak
    if EVENTS[EVENT] then EVENTS[EVENT](...) end
end)

Listener:Add('return 0, 236353', 'PLAYER_REGEN_ENABLED', function()
    wipe(Data)
end)

Listener:Add('return 0, 236353', 'PLAYER_REGEN_DISABLED', function()
    wipe(Data)
end)

function incdmg(unit)
    if UnitExists(unit) then
        local pDMG = select(1, getDMG(unit))
        return pDMG
    end
    return 0
end

function incdmgphys(unit)
    if UnitExists(unit) then
        local pDMG = select(3, getDMG(unit))
        return pDMG
    end
    return 0
end

function incdmgmagic(unit)
    if UnitExists(unit) then
        local mDMG = select(4, getDMG(unit))
        return mDMG
    end
    return 0
end
