--- Localize Vars
local RubimRH = LibStub("AceAddon-3.0"):GetAddon("RubimRH")
-- Addon
local addonName, addonTable = ...;
-- AethysCore
local AC = AethysCore;
local Cache = AethysCache;
local Unit = AC.Unit;
local Player = Unit.Player;
local Target = Unit.Target;
local Spell = AC.Spell;
local Item = AC.Item;

--- APL Local Vars
-- Spells
if not Spell.Warrior then Spell.Warrior = {}; end
Spell.Warrior.Protection = {
    -- Racials
    ArcaneTorrent = Spell(69179),
    Berserking = Spell(26297),
    BloodFury = Spell(20572),
    Shadowmeld = Spell(58984),
    -- Abilities
    BattleCry = Spell(1719),
    BerserkerRage = Spell(18499),
    Charge = Spell(100),
    DemoralizingShout = Spell(1160),
    Devastate = Spell(20243),
    FuriousSlash = Spell(100130),
    HeroicLeap = Spell(6544),
    HeroicThrow = Spell(57755),
    Revenge = Spell(6572),
    RevengeB = Spell(5302),
    ShieldSlam = Spell(23922),
    ThunderClap = Spell(6343),
    VictoryRush = Spell(34428),
    Victorious = Spell(32216),
    -- Talents
    ImpendingVictory = Spell(202168),
    Shockwave = Spell(46968),
    Vengeance = Spell(202572),
    VegeanceIP = Spell(202574),
    VegeanceRV = Spell(202573),
    -- Artifact
    NeltharionsFury = Spell(203524),
    -- Defensive
    IgnorePain = Spell(190456),
    LastStand = Spell(12975),
    Pummel = Spell(6552),
    ShieldBlock = Spell(2565),
    ShieldBlockB = Spell(132404),
    Avatar = Spell(107574),
};
local S = Spell.Warrior.Protection;
-- Items
if not Item.Warrior then Item.Warrior = {}; end
Item.Warrior.Portection = {};
local I = Item.Warrior.Protection;

local T202PC, T204PC = AC.HasTier("T20");
local T212PC, T214PC = AC.HasTier("T21");

local function AoE()
    if S.IgnorePain:IsReady() and Player:RageDeficit() <= 50 and not Player:Buff(S.IgnorePain) and S.IgnorePain:TimeSinceLastCast() >= 1.5 and IsTanking then
        return S.IgnorePain:ID()
    end

    if S.Revenge:IsReady() and S.Revenge:IsReady() and Player:RageDeficit() <= 30 then
        return S.Revenge:ID()
    end

    if S.ThunderClap:IsReady() and Cache.EnemiesCount[12] >= 1 then
        return S.ThunderClap:ID()
    end

    if S.ShieldSlam:IsReady("Melee") then
        return S.ShieldSlam:ID()
    end

    if S.Devastate:IsReady() then
        return S.Devastate:ID()
    end
end

local function Vengeance()
	if not Player:Buff(S.VegeanceIP) and not Player:Buff(S.VegeanceRV) and S.Revenge:IsReady() then
		return S.Revenge:ID()
	end

	if Player:Buff(S.VegeanceRV) and S.Revenge:IsReady() then
		return S.Revenge:ID()
	end	
	
	if Player:Buff(S.VegeanceIP) and S.IgnorePain:IsReady() then
		return S.IgnorePain:ID()
	end	
end

function WarriorProt()
    if not Player:AffectingCombat() then
        return 0, 462338
    end

    AC.GetEnemies("Melee");
    AC.GetEnemies(8, true);
    AC.GetEnemies(10, true);
    AC.GetEnemies(12, true);

    local IsTanking = Player:IsTankingAoE(8) or Player:IsTanking(Target);
    LeftCtrl = IsLeftControlKeyDown();
    LeftShift = IsLeftShiftKeyDown();
    if LeftCtrl and LeftShift and S.Shockwave:IsReady() then
        return S.Shockwave:ID()
    end

    if CDsON() and S.BattleCry:IsReady() and Cache.EnemiesCount[8] >= 1 then
        return S.BattleCry:ID()
    end

    if CDsON() and S.Avatar:IsAvailable() and S.Avatar:IsReady() and Cache.EnemiesCount[8] >= 1 then
        return S.Avatar:ID()
    end

	if Vengeance() ~= nil and S.Vengeance:IsAvailable() then
		return Vengeance()
	end	
	
    if S.IgnorePain:IsReady() and Player:RageDeficit() <= 50 and not Player:Buff(S.IgnorePain) and S.IgnorePain:TimeSinceLastCast() >= 1.5 and IsTanking then
        return S.IgnorePain:ID()
    end

    if S.ShieldBlock:IsReady("Melee") and Player:Rage() >= 15 and not Player:Buff(S.ShieldBlockB) and IsTanking and S.ShieldBlock:ChargesFractional() >= 1.8 then
        return S.ShieldBlock:ID()
    end

    if S.ImpendingVictory:IsAvailable() and S.ImpendingVictory:IsReady() and Player:HealthPercentage() <= 85 then
        return S.VictoryRush:ID()
    end

    if Player:Buff(S.Victorious) and S.VictoryRush:IsReady() and Player:HealthPercentage() <= 85 then
        return S.VictoryRush:ID()
    end

    if Player:Buff(S.Victorious) and Player:BuffRemains(S.Victorious) <= 2 and S.VictoryRush:IsReady() then
        return S.VictoryRush:ID()
    end

    if Player:Buff(S.Victorious) and S.ImpendingVictory:IsReady() and Player:HealthPercentage() <= 85 then
        return S.VictoryRush:ID()
    end

    if Player:Buff(S.Victorious) and Player:BuffRemains(S.Victorious) <= 2 and S.ImpendingVictory:IsReady() then
        return S.VictoryRush:ID()
    end

    if S.Revenge:IsReady() and Player:RageDeficit() <= 30 and Cache.EnemiesCount[8] >= 1 then
        return S.Revenge:ID()
    end

    if Cache.EnemiesCount[12] >= 3 and RubimRH.useAoE then
        if AoE() ~= nil then
            return AoE()
        end
    end

    if S.ShieldSlam:IsReady("Melee") then
        return S.ShieldSlam:ID()
    end

    if S.ThunderClap:IsReady() and Cache.EnemiesCount[12] >= 1 then
        return S.ThunderClap:ID()
    end

    if not S.Vengeance:IsAvailable() and S.Revenge:IsReady() and Player:Buff(S.RevengeB) and Cache.EnemiesCount[8] >= 1 then
        return S.Revenge:ID()
    end

    if S.Devastate:IsReady() then
        return S.Devastate:ID()
    end
    return "0, 975743"
end