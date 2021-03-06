--- ============================ HEADER ============================
--- ======= LOCALIZE =======
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
-- Lua
local pairs = pairs;
local select = select;

Player.CSPrediction = {
    CritCount = 0;
};

local ChaosStrikeMHDamageID = 222031;
local AnnihilationMHDamageID = 227518;
local ChaosStrikeEnergizeId = 193840;

-- Return CS adjusted Fury Predicted
function Player:FuryWithCSRefund()
    return math.min(Player:Fury() + Player.CSPrediction.CritCount * 20, Player:FuryMax());
end

-- Return CS adjusted Fury Deficit Predicted
function Player:FuryDeficitWithCSRefund()
    return math.max(Player:FuryDeficit() - Player.CSPrediction.CritCount * 20, 0);
end

-- Zero CSPrediction after receiving any Chaos Strike energize
AC:RegisterForSelfCombatEvent(function(...)
    local rsspellid = select(12, ...)
    if (rsspellid == ChaosStrikeEnergizeId) then
        Player.CSPrediction.CritCount = 0;
        --AC.Print("Refund!");
    end
end, "SPELL_ENERGIZE");

-- Set CSPrediction on the MH impact from Chaos Strike or Annihilation
AC:RegisterForSelfCombatEvent(function(...)
    local spellID = select(12, ...)
    local spellCrit = select(21, ...)
    if (spellCrit and (spellID == ChaosStrikeMHDamageID or spellID == AnnihilationMHDamageID)) then
        Player.CSPrediction.CritCount = Player.CSPrediction.CritCount + 1;
        --AC.Print("Crit!");
    end
end, "SPELL_DAMAGE");
--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Spells
if not Spell.DemonHunter then
    Spell.DemonHunter = {};
end
Spell.DemonHunter.Havoc = {
    -- Racials
    ArcaneTorrent = Spell(80483),
    Shadowmeld = Spell(58984),
    -- Abilities
    Annihilation = Spell(201427),
    BladeDance = Spell(188499),
    ConsumeMagic = Spell(183752),
    ChaosStrike = Spell(162794),
    ChaosNova = Spell(179057),
    DeathSweep = Spell(210152),
    DemonsBite = Spell(162243),
    EyeBeam = Spell(198013),
    FelRush = Spell(195072),
    Metamorphosis = Spell(191427),
    MetamorphosisImpact = Spell(200166),
    MetamorphosisBuff = Spell(162264),
    ThrowGlaive = Spell(185123),
    VengefulRetreat = Spell(198793),
    -- Talents
    BlindFury = Spell(203550),
    Bloodlet = Spell(206473),
    ChaosBlades = Spell(247938),
    ChaosCleave = Spell(206475),
    DemonBlades = Spell(203555),
    Demonic = Spell(213410),
    DemonicAppetite = Spell(206478),
    DemonReborn = Spell(193897),
    FelBarrage = Spell(211053),
    Felblade = Spell(232893),
    FelEruption = Spell(211881),
    FelMastery = Spell(192939),
    FirstBlood = Spell(206416),
    MasterOfTheGlaive = Spell(203556),
    Momentum = Spell(206476),
    MomentumBuff = Spell(208628),
    Nemesis = Spell(206491),
    Prepared = Spell(203551),
    PreparedBuff = Spell(203650),
    -- Artifact
    FuryOfTheIllidari = Spell(201467),
    -- Set Bonuses
    T21_4pc_Buff = Spell(252165),
    -- Misc
    PoolEnergy = Spell(9999000010),
};
-- Items
if not Item.DemonHunter then
    Item.DemonHunter = {};
end
Item.DemonHunter.Havoc = {
    -- Legendaries
    AngerOfTheHalfGiants = Item(137038, { 11, 12 }),
    DelusionsOfGrandeur = Item(144279, { 3 }),
    -- Trinkets
    ConvergenceofFates = Item(140806, { 13, 14 }),
    KiljaedensBurningWish = Item(144259, { 13, 14 }),
    DraughtofSouls = Item(140808, { 13, 14 }),
    VialofCeaselessToxins = Item(147011, { 13, 14 }),
    UmbralMoonglaives = Item(147012, { 13, 14 }),
    SpecterofBetrayal = Item(151190, { 13, 14 }),
    VoidStalkersContract = Item(151307, { 13, 14 }),
    ForgefiendsFabricator = Item(151963, { 13, 14 }),
    -- Potion
    ProlongedPower = Item(142117),
};
local I = Item.DemonHunter.Havoc;
local S = Spell.DemonHunter.Havoc;

-- Rotation Var
local ShouldReturn; -- Used to get the return string
local CleaveRangeID = tostring(S.ConsumeMagic:ID()); -- 20y range

-- Melee Is In Range w/ Movement Handlers
local function IsInMeleeRange()
    if S.Felblade:TimeSinceLastCast() < Player:GCD() then
        return true;
    elseif S.Metamorphosis:TimeSinceLastCast() < Player:GCD() then
        return true;
    end

    return Target:IsInRange("Melee");
end

-- Special Havoc Functions
local function IsMetaExtendedByDemonic()
    if not Player:BuffP(S.MetamorphosisBuff) then
        return false;
    elseif (S.EyeBeam:TimeSinceLastCast() < S.MetamorphosisImpact:TimeSinceLastCast()) then
        return true;
    end

    return false;
end

local function MetamorphosisCooldownAdjusted()
    -- TODO: Make this better by sampling the Fury expenses over time instead of approximating
    if I.ConvergenceofFates:IsEquipped() and I.DelusionsOfGrandeur:IsEquipped() then
        return S.Metamorphosis:CooldownRemainsP() * 0.56;
    elseif I.ConvergenceofFates:IsEquipped() then
        return S.Metamorphosis:CooldownRemainsP() * 0.78;
    elseif I.DelusionsOfGrandeur:IsEquipped() then
        return S.Metamorphosis:CooldownRemainsP() * 0.67;
    end

    return S.Metamorphosis:CooldownRemainsP()
end

-- Variables
-- variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
local function WaitingForNemesis()
    return not (not S.Nemesis:IsAvailable() or S.Nemesis:IsReady() or S.Nemesis:CooldownRemainsP() > Target:TimeToDie() or S.Nemesis:CooldownRemainsP() > 60);
end

-- variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
local function WaitingForChaosBlades()
    return not (not S.ChaosBlades:IsAvailable() or S.ChaosBlades:IsReady() or S.ChaosBlades:CooldownRemainsP() > Target:TimeToDie()
            or S.ChaosBlades:CooldownRemainsP() > 60);
end

-- variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
local function PoolingForMeta()
    if not CDsON() then
        return false;
    end ;
    return not S.Demonic:IsAvailable() and S.Metamorphosis:CooldownRemainsP() < 6 and Player:FuryDeficitWithCSRefund() > 30
            and (not WaitingForNemesis() or S.Nemesis:CooldownRemainsP() < 10) and (not WaitingForChaosBlades() or S.ChaosBlades:CooldownRemainsP() < 6);
end

-- variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
local function BladeDance()
    return S.FirstBlood:IsAvailable() or AC.Tier20_4Pc or (Cache.EnemiesCount[8] >= 3 + (S.ChaosCleave:IsAvailable() and 3 or 0));
end

-- variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
local function PoolingForBladeDance()
    return BladeDance() and (Player:FuryWithCSRefund() < (75 - (S.FirstBlood:IsAvailable() and 20 or 0)));
end

-- variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
local function PoolingForChaosStrike()
    return false;
end

local T202PC, T204PC = AC.HasTier("T20");
local T212PC, T214PC = AC.HasTier("T21");
-- Main APL
function HavocRotation()
    if not Player:AffectingCombat() then
        return 0, 462338
    end

    if Player:IsChanneling(S.EyeBeam) then
        return 0, "Interface\\Addons\\Rubim-RH\\Media\\channel.tga"
    end

    local function Cooldown()
        -- Locals for tracking if we should display these suggestions together

        -- metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
        if S.Metamorphosis:IsReady("Melee")
                and (not (S.Demonic:IsAvailable() or PoolingForMeta() or WaitingForNemesis() or WaitingForChaosBlades()) or Target:TimeToDie() < 25) then
            return 187827

        end
        -- metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up
        if S.Metamorphosis:IsReady("Melee") and (S.Demonic:IsAvailable() and Player:BuffP(S.MetamorphosisBuff)) then
            return 187827

        end
        -- chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=duration
        if S.ChaosBlades:IsReady("Melee")
                and (Player:BuffP(S.MetamorphosisBuff) or MetamorphosisCooldownAdjusted() > 60 or Target:TimeToDie() <= 18) then
            return S.ChaosBlades:ID()

        end
        -- nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
        if S.Nemesis:IsReady("Melee") and ((Player:BuffP(S.ChaosBlades)
                or Player:BuffP(S.MetamorphosisBuff) or MetamorphosisCooldownAdjusted() < 20 or Target:TimeToDie() <= 60)) then
            return S.Nemesis:ID()

        end
        -- potion,if=buff.metamorphosis.remains>25|target.time_to_die<60
    end

    local function Demonic()
        local InMeleeRange = IsInMeleeRange()

        -- vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
        if S.VengefulRetreat:IsReady("Melee", true)
                and ((S.Prepared:IsAvailable() or S.Momentum:IsAvailable()) and Player:BuffDownP(S.PreparedBuff) and Player:BuffDownP(S.MomentumBuff)) then
            return S.VengefulRetreat:ID()

        end
        -- fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
        if classSpell[1].isActive and S.FelRush:IsReady(20, true) and ((S.Momentum:IsAvailable() or S.FelMastery:IsAvailable())
                and (not S.Momentum:IsAvailable() or (S.FelRush:ChargesP() == 2 or S.VengefulRetreat:CooldownRemainsP() > 4) and Player:BuffDownP(S.MomentumBuff))) then
            return S.FelRush:ID()

        end
        -- throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
        if S.ThrowGlaive:IsReady(S.ThrowGlaive)
                and (S.Bloodlet:IsAvailable() and (not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)) and S.ThrowGlaive:ChargesP() == 2) then
            return S.ThrowGlaive:ID()

        end
        -- death_sweep,if=variable.blade_dance
        if S.DeathSweep:IsReady(8, true) and Player:FuryWithCSRefund() >= S.DeathSweep:Cost() and BladeDance() then
            return 199552

        end
        -- fel_eruption
        if S.FelEruption:IsReady() then
            return S.FelEruption:ID()

        end
        -- fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up))
        if lastMoved() > 0.2 and S.FuryOfTheIllidari:IsReady() and Cache.EnemiesCount[6] >= 1 and (S.FuryOfTheIllidari:IsReady(6, true) and (Cache.EnemiesCount[6] > 1) or (not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
            return S.FuryOfTheIllidari:ID()

        end
        -- blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
        if S.BladeDance:IsReady(8, true) and Player:FuryWithCSRefund() >= S.BladeDance:Cost()
                and (BladeDance() and S.EyeBeam:CooldownRemainsP() > 5 and not S.Metamorphosis:IsReady()) then
            return S.BladeDance:ID()

        end
        -- throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
        if  S.ThrowGlaive:IsReady(S.ThrowGlaive) and (S.Bloodlet:IsAvailable() and (Cache.EnemiesCount[CleaveRangeID] >= 2) and
                (not S.MasterOfTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
            return S.ThrowGlaive:ID()

        end
        -- felblade,if=fury.deficit>=30&(fury<40|buff.metamorphosis.down)
        if S.Felblade:IsReady(S.Felblade) and Player:FuryDeficitWithCSRefund() >= 30
                and (Player:FuryWithCSRefund() < 40 or not Player:BuffP(S.MetamorphosisBuff)) then
            return S.Felblade:ID()

        end
        -- eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(!talent.blind_fury.enabled|fury.deficit>=70)&(!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>16))
        if (classSpell[2].isActive and lastMoved() > 0.2 and S.EyeBeam:IsReady(20, true)) and ((Cache.EnemiesCount[CleaveRangeID] > 1)
                or ((not S.BlindFury:IsAvailable() or Player:FuryDeficitWithCSRefund() >= 70) and
                (not IsMetaExtendedByDemonic() or (AC.Tier21_4Pc and Player:BuffRemainsP(S.MetamorphosisBuff) > 16)))) then
            return S.EyeBeam:ID()

        end
        -- annihilation,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
        if InMeleeRange and S.Annihilation:IsReady() and Player:FuryWithCSRefund() >= S.Annihilation:Cost()
                and ((not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff) or Player:FuryDeficitWithCSRefund() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0)
                or Player:BuffRemainsP(S.MetamorphosisBuff) < 5) and not PoolingForBladeDance()) then
            return 204317

        end
        -- throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
        if S.ThrowGlaive:IsReady(S.ThrowGlaive)
                and (S.Bloodlet:IsAvailable() and (not S.MasterOfTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
            return S.ThrowGlaive:ID()

        end
        -- chaos_strike,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
        if (InMeleeRange and S.ChaosStrike:IsReady()) and Player:FuryWithCSRefund() >= S.ChaosStrike:Cost()
                and ((not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff) or Player:FuryDeficitWithCSRefund() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0))
                and not PoolingForChaosStrike() and not PoolingForMeta() and not PoolingForBladeDance()) then
            return S.ChaosStrike:ID()

        end
        -- fel_rush,if=!talent.momentum.enabled&talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
        if classSpell[1].isActive and lastMoved() > 0.2 and S.FelRush:IsReady(20, true) and not S.Momentum:IsAvailable() and S.DemonBlades:IsAvailable() and not S.EyeBeam:IsReady() then
            return S.FelRush:ID()

        end
        -- demons_bite
        if InMeleeRange and S.DemonsBite:IsReady() then
            return S.DemonsBite:ID()

        end
        -- throw_glaive,if=buff.out_of_range.up|!talent.bloodlet.enabled
        if S.ThrowGlaive:IsReady(S.ThrowGlaive) and (not IsInMeleeRange() or not S.Bloodlet:IsAvailable()) then
            return S.ThrowGlaive:ID()

        end
        -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
        if classSpell[1].isActive and S.FelRush:IsReady(20) and (not IsInMeleeRange() and not S.Momentum:IsAvailable()) then
            return S.FelRush:ID()

        end
    end

    local function Normal()
        local InMeleeRange = IsInMeleeRange()

        -- vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
        if S.VengefulRetreat:IsReady("Melee", true)
                and ((S.Prepared:IsAvailable() or S.Momentum:IsAvailable()) and Player:BuffDownP(S.PreparedBuff) and Player:BuffDownP(S.MomentumBuff)) then
            return S.VengefulRetreat:ID()

        end
        -- fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
        if classSpell[1].isActive and S.FelRush:IsReady(20, true) and ((S.Momentum:IsAvailable() or S.FelMastery:IsAvailable())
                and (not S.Momentum:IsAvailable() or (S.FelRush:ChargesP() == 2 or S.VengefulRetreat:CooldownRemainsP() > 4) and Player:BuffDownP(S.MomentumBuff))
                and (not S.FelMastery:IsAvailable() or Player:FuryDeficitWithCSRefund() >= 25)) then
            return S.FelRush:ID()

        end
        -- fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
        if classSpell[3].isActive and S.FelBarrage:IsReady(S.FelBarrage) and ((Player:BuffP(S.MomentumBuff) or not S.Momentum:IsAvailable())) then
            return S.FelBarrage:ID()

        end
        -- throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
        if S.ThrowGlaive:IsReady(S.ThrowGlaive)
                and (S.Bloodlet:IsAvailable() and (not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)) and S.ThrowGlaive:ChargesP() == 2) then
            return S.ThrowGlaive:ID()

        end
        -- felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
        if S.Felblade:IsReady(S.Felblade) and (Player:FuryWithCSRefund() < 15 and (S.DeathSweep:CooldownRemainsP() < 2 * Player:GCD()
                or S.BladeDance:CooldownRemainsP() < 2 * Player:GCD())) then
            return S.Felblade:ID()

        end
        -- death_sweep,if=variable.blade_dance
        if S.DeathSweep:IsReady(8, true) and Player:FuryWithCSRefund() >= S.DeathSweep:Cost() and BladeDance() then
            return 199552

        end
        -- fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled&!buff.metamorphosis.up&talent.demon_blades.enabled
        if classSpell[1].isActive and S.FelRush:IsReady(20, true) and (S.FelRush:ChargesP() == 2 and not S.Momentum:IsAvailable() and not S.FelMastery:IsAvailable()
                and not Player:BuffP(S.MetamorphosisBuff) and S.DemonBlades:IsAvailable()) then
            return S.FelRush:ID()

        end
        -- fel_eruption
        if S.FelEruption:IsReady() then
            return S.FelEruption:ID()

        end
        -- fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
        if lastMoved() > 0.2 and (S.FuryOfTheIllidari:IsReady()) and Cache.EnemiesCount[6] >= 1 and (S.FuryOfTheIllidari:IsReady(6, true) and (Cache.EnemiesCount[6] > 1) or ((not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))
                and (not S.ChaosBlades:IsAvailable() or Player:BuffP(S.ChaosBlades) or S.ChaosBlades:CooldownRemainsP() > 30
                or Target:TimeToDie() < S.ChaosBlades:CooldownRemainsP()))) then
            return S.FuryOfTheIllidari:ID()

        end
        -- blade_dance,if=variable.blade_dance
        if S.BladeDance:IsReady(8, true) and Player:FuryWithCSRefund() >= S.BladeDance:Cost() and BladeDance() then
            return S.BladeDance:ID()

        end
        -- throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
        if S.ThrowGlaive:IsReady(S.ThrowGlaive) and (S.Bloodlet:IsAvailable() and Cache.EnemiesCount[CleaveRangeID] >= 2
                and (not S.MasterOfTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
            return S.ThrowGlaive:ID()

        end
        -- felblade,if=fury.deficit>=30+buff.prepared.up*8
        if S.Felblade:IsReady(S.Felblade) and (Player:FuryDeficitWithCSRefund() >= 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0)) then
            return S.Felblade:ID()

        end
        -- eye_beam,if=spell_targets.eye_beam_tick>desired_targets|buff.havoc_t21_4pc.remains<2&(!talent.blind_fury.enabled|fury.deficit>=70)&((spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|talent.blind_fury.enabled|set_bonus.tier21_2pc)
        if classSpell[2].isActive and lastMoved() > 0.2 and S.EyeBeam:IsReady(20, true) then
            if (Cache.EnemiesCount[CleaveRangeID] > 1) or (Player:BuffP(S.T21_4pc_Buff) and ((not S.BlindFury:IsAvailable() or Player:FuryDeficitWithCSRefund() >= 70)
                    and ((S.BlindFury:IsAvailable() and Player:FuryDeficitWithCSRefund() >= 35) or AC.Tier21_2Pc))) then
                return S.EyeBeam:ID()
            end
        end
        --    if (classSpell[2].isActive and lastMoved() > 0.2 and S.EyeBeam:IsReady(20, true)) and (Cache.EnemiesCount[CleaveRangeID] > 1)
        --            or (Player:BuffP(S.T21_4pc_Buff) and ((not S.BlindFury:IsAvailable() or Player:FuryDeficitWithCSRefund() >= 70)
        --            and ((S.BlindFury:IsAvailable() and Player:FuryDeficitWithCSRefund() >= 35) or AC.Tier21_2Pc))) then
        --      return S.EyeBeam:ID()
        --    end
        -- annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
        if InMeleeRange and S.Annihilation:IsReady() and Player:FuryWithCSRefund() >= S.Annihilation:Cost()
                and ((S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)
                or Player:FuryDeficitWithCSRefund() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0) or Player:BuffRemainsP(S.MetamorphosisBuff) < 5)
                and not PoolingForBladeDance()) then
            return 204317

        end
        -- throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
        if S.ThrowGlaive:IsReady(S.ThrowGlaive)
                and (S.Bloodlet:IsAvailable() and (not S.MasterOfTheGlaive:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff))) then
            return S.ThrowGlaive:ID()

        end

        -- throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
        if 
            S.ThrowGlaive:IsReady(S.ThrowGlaive)
                and (not S.Bloodlet:IsAvailable() and Player:BuffDownP(S.MetamorphosisBuff) and Cache.EnemiesCount[CleaveRangeID] >= 3) then
            return S.ThrowGlaive:ID()

        end

        -- chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
        if (InMeleeRange and S.ChaosStrike:IsReady()) and Player:FuryWithCSRefund() >= S.ChaosStrike:Cost()
                and ((S.DemonBlades:IsAvailable() or not S.Momentum:IsAvailable() or Player:BuffP(S.MomentumBuff)
                or Player:FuryDeficitWithCSRefund() < 30 + (Player:BuffP(S.PreparedBuff) and 8 or 0))
                and not PoolingForChaosStrike() and not PoolingForMeta() and not PoolingForBladeDance()) then
            return S.ChaosStrike:ID()

        end
        -- fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&(talent.demon_blades.enabled|buff.metamorphosis.down)
        if classSpell[1].isActive and S.FelRush:IsReady(20, true) and (not S.Momentum:IsAvailable() and (S.DemonBlades:IsAvailable() or Player:BuffDownP(S.MetamorphosisBuff))) then
            return S.FelRush:ID()

        end
        -- demons_bite
        if InMeleeRange and S.DemonsBite:IsReady() then
            return S.DemonsBite:ID()

        end
        -- felblade,if=movement.distance>15|buff.out_of_range.up
        if S.Felblade:IsReady(S.Felblade) and (not IsInMeleeRange()) then
            return S.Felblade:ID()

        end
        -- fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
        if classSpell[1].isActive and S.FelRush:IsReady(20) and (not IsInMeleeRange() and not S.Momentum:IsAvailable()) then
            return S.FelRush:ID()

        end
        -- throw_glaive,if=!talent.bloodlet.enabled&talent.demon_blades.enabled
        if S.ThrowGlaive:IsReady(S.ThrowGlaive) and (not S.Bloodlet:IsAvailable() and S.DemonBlades:IsAvailable()) then
            return S.ThrowGlaive:ID()

        end
    end

    -- Unit Update
    AC.GetEnemies(6, true); -- Fury of the Illidari
    AC.GetEnemies(8, true); -- Blade Dance/Chaos Nova
    AC.GetEnemies(S.ConsumeMagic, true); -- 20y, use for TG Bounce and Eye Beam
    AC.GetEnemies("Melee"); -- Melee

    -- call_action_list,name=cooldown,if=gcd.remains=0
    if CDsON() then
        if Cooldown() ~= nil then
            return Cooldown()
        end
    end

    -- actions+=/pick_up_fragment,if=fury.deficit>=35&((cooldown.eye_beam.remains>5|!talent.blind_fury.enabled&!set_bonus.tier21_4pc)|(buff.metamorphosis.up&!set_bonus.tier21_4pc))
    -- TODO: Can't detect when orbs actually spawn, we could possibly show a suggested icon when we DON'T want to pick up souls so people can avoid moving?

    -- run_action_list,name=demonic,if=talent.demonic.enabled
    -- run_action_list,name=normal
    if (S.Demonic:IsAvailable()) then
        if Demonic() ~= nil then
            return Demonic()
        end
    end
    if Normal() ~= nil then
        return Normal()
    end
    return 0, 975743
end

--- ======= SIMC =======
--- Last Update: 12/16/2017

--[[
# Executed before combat begins. Accepts non-harmful actions only.
actions.precombat=flask
actions.precombat+=/augmentation
actions.precombat+=/food
# Snapshot raid buffed stats before combat begins and pre-potting is done.
actions.precombat+=/snapshot_stats
actions.precombat+=/potion
actions.precombat+=/metamorphosis,if=!(talent.demon_reborn.enabled&(talent.demonic.enabled|set_bonus.tier21_4pc))

# Executed every time the actor is available.
actions=auto_attack
actions+=/variable,name=waiting_for_nemesis,value=!(!talent.nemesis.enabled|cooldown.nemesis.ready|cooldown.nemesis.remains>target.time_to_die|cooldown.nemesis.remains>60)
actions+=/variable,name=waiting_for_chaos_blades,value=!(!talent.chaos_blades.enabled|cooldown.chaos_blades.ready|cooldown.chaos_blades.remains>target.time_to_die|cooldown.chaos_blades.remains>60)
# "Getting ready to use meta" conditions, this is used in a few places.
actions+=/variable,name=pooling_for_meta,value=!talent.demonic.enabled&cooldown.metamorphosis.remains<6&fury.deficit>30&(!variable.waiting_for_nemesis|cooldown.nemesis.remains<10)&(!variable.waiting_for_chaos_blades|cooldown.chaos_blades.remains<6)
# Blade Dance conditions. Always if First Blood is talented or the T20 4pc set bonus, otherwise at 6+ targets with Chaos Cleave or 3+ targets without.
actions+=/variable,name=blade_dance,value=talent.first_blood.enabled|set_bonus.tier20_4pc|spell_targets.blade_dance1>=3+(talent.chaos_cleave.enabled*3)
# Blade Dance pooling condition, so we don't spend too much fury on Chaos Strike when we need it soon.
actions+=/variable,name=pooling_for_blade_dance,value=variable.blade_dance&(fury<75-talent.first_blood.enabled*20)
# Chaos Strike pooling condition, so we don't spend too much fury when we need it for Chaos Cleave AoE
actions+=/variable,name=pooling_for_chaos_strike,value=talent.chaos_cleave.enabled&fury.deficit>40&!raid_event.adds.up&raid_event.adds.in<2*gcd
actions+=/consume_magic
actions+=/call_action_list,name=cooldown,if=gcd.remains=0
actions+=/pick_up_fragment,if=fury.deficit>=35&((cooldown.eye_beam.remains>5|!talent.blind_fury.enabled&!set_bonus.tier21_4pc)|(buff.metamorphosis.up&!set_bonus.tier21_4pc))
actions+=/run_action_list,name=demonic,if=talent.demonic.enabled
actions+=/run_action_list,name=normal

# Use Metamorphosis when we are done pooling Fury and when we are not waiting for other cooldowns to sync.
actions.cooldown=metamorphosis,if=!(talent.demonic.enabled|variable.pooling_for_meta|variable.waiting_for_nemesis|variable.waiting_for_chaos_blades)|target.time_to_die<25
actions.cooldown+=/metamorphosis,if=talent.demonic.enabled&buff.metamorphosis.up
# If adds are present, use Nemesis on the lowest HP add in order to get the Nemesis buff for AoE
actions.cooldown+=/nemesis,target_if=min:target.time_to_die,if=raid_event.adds.exists&debuff.nemesis.down&(active_enemies>desired_targets|raid_event.adds.in>60)
actions.cooldown+=/nemesis,if=!raid_event.adds.exists&(buff.chaos_blades.up|buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains<20|target.time_to_die<=60)
actions.cooldown+=/chaos_blades,if=buff.metamorphosis.up|cooldown.metamorphosis.adjusted_remains>60|target.time_to_die<=duration
actions.cooldown+=/potion,if=buff.metamorphosis.remains>25|target.time_to_die<60

# Specific APL for the Blind Fury+Demonic Appetite+Demonic build
# Vengeful Retreat backwards through the target to minimize downtime.
actions.demonic=vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
# Fel Rush for Momentum.
actions.demonic+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
actions.demonic+=/death_sweep,if=variable.blade_dance
actions.demonic+=/fel_eruption
actions.demonic+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up))
actions.demonic+=/blade_dance,if=variable.blade_dance&cooldown.eye_beam.remains>5&!cooldown.metamorphosis.ready
actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
actions.demonic+=/felblade,if=fury.deficit>=30&(fury<40|buff.metamorphosis.down)
actions.demonic+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|(!talent.blind_fury.enabled|fury.deficit>=70)&(!buff.metamorphosis.extended_by_demonic|(set_bonus.tier21_4pc&buff.metamorphosis.remains>16))
actions.demonic+=/annihilation,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
actions.demonic+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
actions.demonic+=/chaos_strike,if=(!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
actions.demonic+=/fel_rush,if=!talent.momentum.enabled&talent.demon_blades.enabled&!cooldown.eye_beam.ready&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
actions.demonic+=/demons_bite
actions.demonic+=/throw_glaive,if=buff.out_of_range.up|!talent.bloodlet.enabled
actions.demonic+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
actions.demonic+=/vengeful_retreat,if=movement.distance>15

# General APL for Non-Demonic Builds
# Vengeful Retreat backwards through the target to minimize downtime.
actions.normal=vengeful_retreat,if=(talent.prepared.enabled|talent.momentum.enabled)&buff.prepared.down&buff.momentum.down
# Fel Rush for Momentum and for fury from Fel Mastery.
actions.normal+=/fel_rush,if=(talent.momentum.enabled|talent.fel_mastery.enabled)&(!talent.momentum.enabled|(charges=2|cooldown.vengeful_retreat.remains>4)&buff.momentum.down)&(!talent.fel_mastery.enabled|fury.deficit>=25)&(charges=2|(raid_event.movement.in>10&raid_event.adds.in>10))
# Use Fel Barrage at max charges, saving it for Momentum and adds if possible.
actions.normal+=/fel_barrage,if=(buff.momentum.up|!talent.momentum.enabled)&(active_enemies>desired_targets|raid_event.adds.in>30)
actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.momentum.enabled|buff.momentum.up)&charges=2
actions.normal+=/felblade,if=fury<15&(cooldown.death_sweep.remains<2*gcd|cooldown.blade_dance.remains<2*gcd)
actions.normal+=/death_sweep,if=variable.blade_dance
actions.normal+=/fel_rush,if=charges=2&!talent.momentum.enabled&!talent.fel_mastery.enabled&!buff.metamorphosis.up&talent.demon_blades.enabled
actions.normal+=/fel_eruption
actions.normal+=/fury_of_the_illidari,if=(active_enemies>desired_targets)|(raid_event.adds.in>55&(!talent.momentum.enabled|buff.momentum.up)&(!talent.chaos_blades.enabled|buff.chaos_blades.up|cooldown.chaos_blades.remains>30|target.time_to_die<cooldown.chaos_blades.remains))
actions.normal+=/blade_dance,if=variable.blade_dance
actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&spell_targets>=2&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&(spell_targets>=3|raid_event.adds.in>recharge_time+cooldown)
actions.normal+=/felblade,if=fury.deficit>=30+buff.prepared.up*8
actions.normal+=/eye_beam,if=spell_targets.eye_beam_tick>desired_targets|buff.havoc_t21_4pc.remains<2&(!talent.blind_fury.enabled|fury.deficit>=70)&((spell_targets.eye_beam_tick>=3&raid_event.adds.in>cooldown)|talent.blind_fury.enabled|set_bonus.tier21_2pc)
actions.normal+=/annihilation,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8|buff.metamorphosis.remains<5)&!variable.pooling_for_blade_dance
actions.normal+=/throw_glaive,if=talent.bloodlet.enabled&(!talent.master_of_the_glaive.enabled|!talent.momentum.enabled|buff.momentum.up)&raid_event.adds.in>recharge_time+cooldown
actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled&buff.metamorphosis.down&spell_targets>=3
actions.normal+=/chaos_strike,if=(talent.demon_blades.enabled|!talent.momentum.enabled|buff.momentum.up|fury.deficit<30+buff.prepared.up*8)&!variable.pooling_for_chaos_strike&!variable.pooling_for_meta&!variable.pooling_for_blade_dance
actions.normal+=/fel_rush,if=!talent.momentum.enabled&raid_event.movement.in>charges*10&talent.demon_blades.enabled
actions.normal+=/demons_bite
actions.normal+=/felblade,if=movement.distance>15|buff.out_of_range.up
actions.normal+=/fel_rush,if=movement.distance>15|(buff.out_of_range.up&!talent.momentum.enabled)
actions.normal+=/vengeful_retreat,if=movement.distance>15
actions.normal+=/throw_glaive,if=!talent.bloodlet.enabled&talent.demon_blades.enabled
]]
