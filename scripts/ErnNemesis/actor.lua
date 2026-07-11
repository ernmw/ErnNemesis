--[[
ErnNemesis for OpenMW.
Copyright (C) 2026 Erin Pentecost

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]
local core      = require('openmw.core')
local types     = require('openmw.types')
local pself     = require('openmw.self')
local MOD_NAME  = require("scripts.ErnNemesis.ns")
local aux_util  = require('openmw_aux.util')
local settings  = require("scripts.ErnNemesis.settings.settings")
local shuffle   = require("scripts.ErnNemesis.shuffle")
local animation = require('openmw.animation')
local const     = require("scripts.ErnNemesis.const")
local vfs = require('openmw.vfs')

local vfxID     = "nemesis_crown"

---@class Persist
---@field kills number Number of persisted kills.
---@field gearIDs string[] List of item IDs for items added by Nemesis.
---@field originalEquipmentBySlot {[number]: string} slot to item ID

---@return {[number]: string}
local function equipmentSnapshot()
    local out = {}
    for slot, item in pairs(pself.type.getEquipment(pself)) do
        out[slot] = item.id
    end
    return out
end

local defaultCrownPath = "Meshes\\ErnNemesis\\nemesis_crown.nif"
local crownPath = defaultCrownPath

local persist = {
    lastKillGameTime = 0,
    kills = 0,
    appliedNeglectBonus = 0,
    gearIDs = {},
    originalEquipmentBySlot = equipmentSnapshot(),
    playersInCombat = {},
}

local function getRecord(obj)
    return obj.type.record(obj)
end

---@class DynStat
---@field Name string
---@field GetSetting fun():number

---@type DynStat[]
local dynStats = {
    {
        Name = "health",
        GetSetting = function()
            return settings.gameplay.healthScaling
        end,
    },
    {
        Name = "magicka",
        GetSetting = function()
            return settings.gameplay.magickaScaling
        end,
    },
    {
        Name = "fatigue",
        GetSetting = function()
            return settings.gameplay.fatigueScaling
        end,
    },
}

local function handleDynStats(oldKills, newKills)
    for _, s in ipairs(dynStats) do
        if s.GetSetting() > 0 then
            local buff = (newKills - oldKills) * s.GetSetting()
            local stat = pself.type.stats.dynamic[s.Name](pself)
            stat.base = math.max(stat.base, stat.base + buff)
            stat.current = math.max(stat.current, stat.current + buff)
            settings.debugPrint(getRecord(pself.object).name .. " " .. s.Name .. " increased by " .. tostring(buff))
        end
    end
end

local function forceSumInValues(collection, desiredSum)
    if math.ceil(desiredSum) ~= desiredSum then
        error("desiredSum must be whole number")
    end
    local out = collection
    local findSum = function()
        local checkCount = 0
        for _, count in pairs(out) do
            if math.ceil(count) ~= count then
                error("count must be whole number")
            end
            checkCount = checkCount + count
        end
        return checkCount
    end
    while true do
        local sum = findSum()
        if sum == desiredSum then
            break
        end
        if sum > desiredSum then
            -- get positive list
            local positiveKeys = {}
            for key, count in pairs(out) do
                if count > 0 then
                    table.insert(positiveKeys, key)
                end
            end
            local toReduce = positiveKeys[math.random(#positiveKeys)]
            out[toReduce] = out[toReduce] - 1
        elseif sum < desiredSum then
            -- get all keys
            local keys = {}
            for key, count in pairs(out) do
                table.insert(keys, key)
            end
            local toIncrease = keys[math.random(#keys)]
            out[toIncrease] = out[toIncrease] + 1
        end
    end
    return out
end

---@return {[string]:number}
local function getPreferredAttributes(totalDesiredIncrease)
    -- this function needs to return a map of attribute name to some number.
    local isCreature = types.Creature.objectIsInstance(pself)
    if isCreature then
        local baseCount = math.floor(totalDesiredIncrease / 8)
        local out = {
            agility = baseCount,
            endurance = baseCount,
            intelligence = baseCount,
            luck = baseCount,
            personality = baseCount,
            speed = baseCount,
            strength = baseCount,
            willpower = baseCount,
        }
        return forceSumInValues(out, totalDesiredIncrease)
    else
        --- the class's preferred attributes should have a sum which is 0.5.
        local classRecord = types.NPC.classes.record(getRecord(pself.object).class)
        local classAttribCount = math.ceil(8 * 0.5 / #(classRecord.attributes))
        local minorAttributesCount = math.floor(8 * 0.5 / (8 - #(classRecord.attributes)))
        local out = {
            agility = minorAttributesCount,
            endurance = minorAttributesCount,
            intelligence = minorAttributesCount,
            luck = minorAttributesCount,
            personality = minorAttributesCount,
            speed = minorAttributesCount,
            strength = minorAttributesCount,
            willpower = minorAttributesCount,
        }
        for _, attributeName in ipairs(classRecord.attributes) do
            out[attributeName] = classAttribCount
        end
        return forceSumInValues(out, totalDesiredIncrease)
    end
end

local function handleAttributes(oldKills, newKills)
    if settings.gameplay.attributeScaling > 0 then
        for attribName, count in pairs(getPreferredAttributes(settings.gameplay.attributeScaling * (newKills - oldKills))) do
            local attribute = pself.type.stats.attributes[attribName](pself)
            attribute.base = math.max(attribute.base, attribute.base + count)
            settings.debugPrint(getRecord(pself.object).name ..
                " " .. attribName .. " increased by " .. tostring(count))
        end
    end
end

---@return {[string]:number}
local function getPreferredClassSkills(totalDesiredIncrease)
    local classRecord = types.NPC.classes.record(getRecord(pself.object).class)
    local out = {}
    for _, skillName in ipairs(classRecord.majorSkills) do
        out[skillName] = math.ceil(0.7 * totalDesiredIncrease / #(classRecord.majorSkills))
    end
    for _, skillName in ipairs(classRecord.minorSkills) do
        out[skillName] = math.floor(0.3 * totalDesiredIncrease / #(classRecord.minorSkills))
    end

    return forceSumInValues(out, totalDesiredIncrease)
end

local function handleSkills(oldKills, newKills)
    if settings.gameplay.skillScaling > 0 then
        local scaleAmount = settings.gameplay.skillScaling * (newKills - oldKills)
        local isCreature = types.Creature.objectIsInstance(pself)
        if not isCreature then
            local skillCounts = getPreferredClassSkills(scaleAmount)
            for skillName, count in pairs(skillCounts) do
                local skill = pself.type.stats.skills[skillName](pself)
                skill.base = math.max(skill.base, skill.base + count)
                settings.debugPrint(getRecord(pself.object).name ..
                    " " .. skillName .. " increased by " .. tostring(count))
            end
        end
    end
end

local function learnRandomSpells(count)
    local allSpells = core.magic.spells.records
    local spells = {}
    local actorSpells = types.Actor.spells(pself)
    for i = 1, #allSpells, 1 do
        local spell = allSpells[i]
        if (not spell.isAutocalc or spell.cost > 10) and (not spell.alwaysSucceedFlag) and (spell.type == core.magic.SPELL_TYPE.Spell) and (actorSpells[spell.id] == nil) then
            --- TODO: only consider spells that have an effect with a class major magical skill
            table.insert(spells, spell)
        end
    end
    spells = shuffle(spells)
    --settings.debugPrint("Potential spells: " .. aux_util.deepToString(spells, 3))
    for i = 1, math.min(count, #spells), 1 do
        actorSpells:add(spells[i])
        settings.debugPrint(getRecord(pself.object).name ..
            " learned " ..
            tostring(spells[i].name))
    end
end

local function handleSpells(oldKills, newKills)
    if settings.gameplay.spellScaling <= 0 then
        return
    end
    local isCreature = types.Creature.objectIsInstance(pself)
    if isCreature then
        return
    end
    local classRecord = types.NPC.classes.record(getRecord(pself.object).class)
    if classRecord.specialization ~= "magic" then
        return
    end
    learnRandomSpells(math.ceil(settings.gameplay.spellScaling * (newKills - oldKills)))
end

---@return string|nil
local function getBestArmorSkill()
    local isCreature = types.Creature.objectIsInstance(pself)
    if isCreature then
        return nil
    end
    local armorSkills = {
        heavyarmor = pself.type.stats.skills.heavyarmor(pself),
        mediumarmor = pself.type.stats.skills.mediumarmor(pself),
        lightarmor = pself.type.stats.skills.lightarmor(pself),
        unarmored = pself.type.stats.skills.unarmored(pself),
    }
    local skillName = nil
    local highestScore = -100
    for name, skill in pairs(armorSkills) do
        if highestScore < skill.base then
            highestScore = skill.base
            skillName = name
        end
    end
    return skillName
end

local function getItemsByIDMap()
    local itemsByID = {}
    for _, item in ipairs(pself.type.inventory(pself):getAll()) do
        if item and item:isValid() then
            itemsByID[item.id] = item
        end
    end
    return itemsByID
end

---@class UpgradeGearData
---@field actor table
---@field oldGear {[string]:table}
---@field deltaKills number
---@field armorSkill string?
---@field originalGear {[number]:string}

local function handleGear(oldKills, newKills)
    -- hand this all off to the global script
    if settings.equipment.weaponScaling > 0 or settings.equipment.armorScaling > 0 then
        local itemsByID = getItemsByIDMap()
        local oldGear = {}
        for _, id in ipairs(persist.gearIDs or {}) do
            oldGear[id] = itemsByID[id]
        end
        ---@type UpgradeGearData
        local data = {
            actor = pself.object,
            oldGear = oldGear,
            deltaKills = newKills - oldKills,
            armorSkill = getBestArmorSkill(),
            originalGear = persist.originalEquipmentBySlot,
        }

        core.sendGlobalEvent(MOD_NAME .. "onUpgradeGear", data)
    end
end

---@param data UpgradeGearCompletedData
local function onUpgradeGearCompleted(data)
    settings.debugPrint("onUpgradeGearCompleted for " ..
        getRecord(pself.object).id .. ": " .. aux_util.deepToString(data, 5))
    --- equip / persist new items we got from global
    local itemsByID = getItemsByIDMap()

    ---@type {[number]:table}
    local equipped = {}
    for key, val in pairs(persist.originalEquipmentBySlot) do
        equipped[key] = itemsByID[val]
    end

    --- this is called after global has inserted new gear
    --- persist the new gear IDs so we can delete them later, if needed.
    local newIDs = {}
    for slot, item in pairs(data.newItemsBySlot) do
        if item:isValid() then
            table.insert(newIDs, item.id)
            equipped[slot] = item

            settings.debugPrint(getRecord(pself.object).name ..
                " equipped new item " ..
                tostring(getRecord(item).name) .. " in slot " .. tostring(slot))
        else
            settings.debugPrint(getRecord(pself.object).name ..
                " failed to equip new item " ..
                tostring(getRecord(item).name) .. " in slot " .. tostring(slot))
        end
    end

    -- equip!
    pself.type.setEquipment(pself, equipped)

    -- consumables, too!
    for _, id in ipairs(data.newConsumableIDs) do
        table.insert(newIDs, id)
    end

    persist.gearIDs = newIDs
end

local function applyCrown()
    if settings.gameplay.showCrown then
        if animation.hasBone(pself, "bip01 head") then
            animation.addVfx(pself, crownPath,
                { loop = true, boneName = "bip01 head", vfxId = vfxID, useAmbientLight = true })
        end
    end
end

local blockedClasses = {
    guard = true,
    slave = true
}

local function allowed()
    if settings.gameplay.ignoreNPCBlocklist then
        return true
    end
    local selfRecord = getRecord(pself.object)
    local actors = require("scripts.ErnNemesis.actors.load")

    if actors.allow[selfRecord.id:lower()] then
        settings.debugPrint(selfRecord.name ..
            " is force-allowed")
        return true
    end

    if blockedClasses[selfRecord.class] then
        settings.debugPrint(selfRecord.name ..
            " has a blocked class: " .. selfRecord.class)
        return false
    end

    if actors.block[selfRecord.id:lower()] then
        settings.debugPrint(selfRecord.name ..
            " is blocked")
        return false
    end

    if types.Actor.stats.ai.fight(pself).base >= 40 then
        settings.debugPrint(selfRecord.name ..
            " is aggressive")
        return true
    end

    return false
end

local function onActive()
    if settings.admin.disable then
        return
    end
    if not allowed() then
        return
    end
    if pself.object:isValid() and not types.Actor.isDead(pself.object) then
        if persist.kills > 0 then
            applyCrown()
        end
        --local neglectDuration = math.max(0, core.getGameTime()-(persist.lastKillGameTime or math.huge))
        core.sendGlobalEvent(MOD_NAME .. "onActive",
            { actor = pself.object, kills = persist.kills, lastKillGameTime=persist.lastKillGameTime or 0})
    end
end

local function onKillCountUpdate(data)
    settings.debugPrint(getRecord(pself.object).name ..
        " has killed the player " ..
        tostring(data.kills) .. " total times, up from " .. tostring(persist.kills) .. " times. Neglect bonus: "..tostring(data.neglectBonus))
    applyCrown()
    local wasRealKill = data.kills > persist.kills
    -- previousEffective includes any neglect bonus already folded into stats/level,
    -- so re-syncing (e.g. on cell reload) doesn't reapply the same bonus again.
    local previousEffective = persist.kills + persist.appliedNeglectBonus
    -- A real kill resets the neglect clock (data.neglectBonus drops back near 0), so
    -- data.kills + data.neglectBonus alone could dip below what's already been applied.
    -- Never let the effective total go backwards.
    local newKills = math.max(previousEffective, data.kills + data.neglectBonus)
    handleDynStats(previousEffective, newKills)
    handleAttributes(previousEffective, newKills)
    handleSkills(previousEffective, newKills)
    handleSpells(previousEffective, newKills)
    handleGear(previousEffective, newKills)

    --- apply the nemesis ability when they first become a nemesis
    --- test with:
    --[[
    for _, effect in pairs(types.Actor.activeEffects(self)) do print(effect.name or effect.id, "Mag:", effect.magnitude, "Dur:", effect.durationLeft) end
    ]] --
    if persist.kills == 0 and data.kills > 0 then
        local actorSpells = types.Actor.spells(pself)
        actorSpells:add(core.magic.spells.records[const.NEMESIS_SPELL_1])
    end

    if settings.gameplay.levelScaling then
        local levelStat = pself.type.stats.level(pself)
        levelStat.current = levelStat.current + (newKills - previousEffective)
        settings.debugPrint(getRecord(pself.object).name ..
            " leveled up to " ..
            tostring(levelStat.current))
    end

    persist.kills = data.kills
    persist.appliedNeglectBonus = newKills - data.kills
    -- only the actor actually killing the player should move this timestamp forward
    if wasRealKill then
        persist.lastKillGameTime = core.getGameTime()
    end
end

local function onDied()
    if settings.equipment.upgradeStrategy == "ephemeral" and persist.kills > 0 then
        settings.debugPrint(getRecord(pself.object).name ..
            " deleting Nemesis equipment")
        local itemsByID = getItemsByIDMap()
        ---@type {[number]:table}
        local equipped = {}
        for key, val in pairs(persist.originalEquipmentBySlot) do
            equipped[key] = itemsByID[val]
        end
        pself.type.setEquipment(pself, equipped)

        local itemsToDelete = {}
        for _, key in ipairs(persist.gearIDs or {}) do
            itemsToDelete[key] = itemsByID[key]
        end

        local data = {
            actor = pself.object,
            items = itemsToDelete,
        }

        core.sendGlobalEvent(MOD_NAME .. "onDeleteItems", data)
    end
    if persist.kills > 0 then
        settings.debugPrint(getRecord(pself.object).name ..
            " died.")
        for _, player in pairs(persist.playersInCombat) do
        core.sendGlobalEvent(MOD_NAME .. "onNemesisKilled", { actor = pself, kills = persist.kills, player=player})
        end
    end

    animation.removeVfx(pself, vfxID)
end

local function onCombatChange(data)
    if not persist.playersInCombat then
        persist.playersInCombat = {}
    end
    settings.debugPrint(getRecord(pself.object).name ..
        " combat status changed: ".. aux_util.deepToString(data, 5))
    for _, player in ipairs(data.added or {}) do
        local key = getRecord(player).name
        persist.playersInCombat[key] = player
    end
    for _, player in ipairs(data.removed or {}) do
        local key = getRecord(player).name
        persist.playersInCombat[key] = nil
    end
end

local function onLoad(data)
    if data then
        persist = data
        persist.appliedNeglectBonus = persist.appliedNeglectBonus or 0
        persist.lastKillGameTime = persist.lastKillGameTime or 0
    end
end
local function onSave()
    return persist
end

local function setCrownMeshPath(path)
    if path then
        if vfs.fileExists(path) then
            crownPath = path
        else
            crownPath = defaultCrownPath
            settings.debugPrint("setCrownMeshPath: can't find " .. tostring(path))
        end
    else
        crownPath = defaultCrownPath
    end
end

local function getNemesisLevel()
    return persist.kills
end

return {
    interfaceName = MOD_NAME,
    interface = {
        version = 1,
        setCrownMeshPath = setCrownMeshPath,
        getNemesisLevel = getNemesisLevel,
    },
    engineHandlers = {
        onActive = onActive,
        onLoad = onLoad,
        onSave = onSave,
    },
    eventHandlers = {
        [MOD_NAME .. "onKillCountUpdate"] = onKillCountUpdate,
        [MOD_NAME .. "onUpgradeGearCompleted"] = onUpgradeGearCompleted,
        [MOD_NAME .. "onCombatChange"] = onCombatChange,
        Died = onDied,
    },
}
