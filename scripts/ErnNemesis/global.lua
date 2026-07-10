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
local MOD_NAME          = require("scripts.ErnNemesis.ns")
local const = require("scripts.ErnNemesis.const")
local storage  = require('openmw.storage')
local world    = require('openmw.world')
local async    = require('openmw.async')
local types    = require('openmw.types')
local aux_util = require('openmw_aux.util')
local settings = require("scripts.ErnNemesis.settings.settings")
local itemutil = require("scripts.ErnNemesis.itemutil")

local function getRecord(obj)
    return obj.type.record(obj)
end

---@class Nemisis
---@field actorID string
---@field kills number

local nemesisData = storage.globalSection(MOD_NAME .. "NemesisData")

local function onActive(data)
    local kills = 0
    for _, player in ipairs(world.players) do
        local snapshot = nemesisData:asTable()[getRecord(player).name]
        if not snapshot then
            snapshot = {}
        end
        if not snapshot[data.actor.id] then
            snapshot[data.actor.id] = 0
        end
        if snapshot[data.actor.id] then
            kills = kills + snapshot[data.actor.id]
        end
    end

    local neglectBonus = 0
    if settings.gameplay.neglectDayPenalty > 0 then
        neglectBonus = math.floor(data.neglectDuration / (60*60*24*settings.gameplay.neglectDayPenalty))
    end

    if (kills > data.kills) or (neglectBonus > 0) then
        --- some buffs must be applied in global context

        --- Persist kill count on actor
        data.actor:sendEvent(MOD_NAME .. "onKillCountUpdate", { kills = kills, neglectBonus =  neglectBonus})
    end
end

local function onPlayerDied(data)
    settings.debugPrint("Global onPlayerDied: " .. aux_util.deepToString(data, 3))
    local key = getRecord(data.player).name
    local snapshot = nemesisData:asTable()[key] or {}
    settings.debugPrint("Old nemesis data: " .. aux_util.deepToString(snapshot, 3))
    for _, opponent in ipairs(data.opponents) do
        local originalCount = snapshot[opponent] or 0
        snapshot[opponent] = originalCount + 1
    end
    settings.debugPrint("New nemesis data: " .. aux_util.deepToString(snapshot, 3))
    nemesisData:set(key, snapshot)
end

local function onClearState()
    settings.debugPrint("Global onClearState.")
    nemesisData:reset()
end


local sendGearNotification = async:registerTimerCallback('sendGearNotification', function(data)
    data.actor:sendEvent(MOD_NAME .. "onUpgradeGearCompleted", data.newData)
    settings.debugPrint("Nemesis gear for " .. getRecord(data.actor).id .. ": " .. aux_util.deepToString(data.newData, 3))
end)

---@class UpgradeGearCompletedData
---@field newItemsBySlot {[number]: table}
---@field newConsumableIDs string[]

local function getItemsByIDMap(actor)
    local itemsByID = {}
    for _, item in ipairs(actor.type.inventory(actor):getAll()) do
        if item and item:isValid() then
            itemsByID[item.id] = item
        end
    end
    return itemsByID
end

---@param data UpgradeGearData
local function onUpgradeGear(data)
    --- 1. delete the old gear
    --- 2. spawn in new gear
    --- 3. get the npc to equip it
    itemutil.build()

    settings.debugPrint("Upgrading gear for " .. getRecord(data.actor).id .. ": " .. aux_util.deepToString(data, 3))

    -- delete old items
    for _, item in pairs(data.oldGear) do
        item:remove()
    end

    ---@type UpgradeGearCompletedData
    local newData = {
        newItemsBySlot = {},
        newConsumableIDs = {},
    }

    local inventory = types.Actor.inventory(data.actor)

    local itemsByID = getItemsByIDMap(data.actor)

    local handleOriginalGearInSlot = function(slot)
        local oldGear = itemsByID[data.originalGear[slot]]
        if not oldGear then
            settings.debugPrint("No original gear in slot " .. tostring(slot))
            return
        end
        local oldGearRecordID = getRecord(oldGear).id
        if settings.equipment.upgradeStrategy == "permanent" and oldGear then
            if itemutil.allowed(oldGearRecordID) then
                settings.debugPrint("Deleting original gear from " ..
                    getRecord(data.actor).id .. ": " .. oldGearRecordID)
                oldGear:remove()
            end
        end
    end

    local upgradeWeapon = function(slot)
        local oldItem = types.Actor.getEquipment(data.actor, slot)
        if oldItem then
            local oldItemRecord = getRecord(oldItem)
            local oldItemScore = itemutil.weaponValue(oldItemRecord)
            local betterItemRecord = itemutil.getWeaponWithScore(oldItemRecord.type,
                oldItemScore + (settings.equipment.weaponScaling * data.deltaKills))
            if betterItemRecord and (oldItemRecord.id ~= betterItemRecord.id) then
                local betterItemScore = itemutil.weaponValue(betterItemRecord)
                if betterItemScore > oldItemScore then
                    -- we are doing a replacement
                    local newItemInstance = world.createObject(betterItemRecord.id)
                    newItemInstance:moveInto(inventory)
                    newData.newItemsBySlot[slot] = newItemInstance
                    handleOriginalGearInSlot(slot)
                end
            end
        end
    end

    local upgradeArmor = function(skill, slot)
        local oldItem = types.Actor.getEquipment(data.actor, slot)
        if oldItem then
            local oldItemRecord = getRecord(oldItem)
            local oldItemScore = itemutil.armorValue(oldItemRecord)
            local betterItemRecord = itemutil.getArmorWithScore(skill, slot,
                oldItemScore + (settings.equipment.armorScaling * data.deltaKills))
            if betterItemRecord and (oldItemRecord.id ~= betterItemRecord.id) then
                local betterItemScore = itemutil.armorValue(betterItemRecord)
                if betterItemScore > oldItemScore then
                    local newItemInstance = world.createObject(betterItemRecord.id)
                    newItemInstance:moveInto(inventory)
                    newData.newItemsBySlot[slot] = newItemInstance
                    handleOriginalGearInSlot(slot)
                end
            end
        end
    end

    if settings.equipment.weaponScaling > 0 then
        upgradeWeapon(types.Actor.EQUIPMENT_SLOT.CarriedRight)
        upgradeWeapon(types.Actor.EQUIPMENT_SLOT.Ammunition)
    end

    if settings.equipment.armorScaling > 0 and data.armorSkill and data.armorSkill ~= "unarmored" then
        local isBeast = types.NPC.races.records[getRecord(data.actor).race].isBeast
        local slots = {
            types.Actor.EQUIPMENT_SLOT.Cuirass,
            types.Actor.EQUIPMENT_SLOT.Greaves,
            types.Actor.EQUIPMENT_SLOT.LeftPauldron,
            types.Actor.EQUIPMENT_SLOT.RightPauldron,
            types.Actor.EQUIPMENT_SLOT.LeftGauntlet,
            types.Actor.EQUIPMENT_SLOT.RightGauntlet,
            types.Actor.EQUIPMENT_SLOT.CarriedLeft,
        }
        if not isBeast then
            table.insert(slots, types.Actor.EQUIPMENT_SLOT.Helmet)
            table.insert(slots, types.Actor.EQUIPMENT_SLOT.Boots)
        end
        for _, slot in ipairs(slots) do
            upgradeArmor(data.armorSkill, slot)
        end
    end
    -- this event needs to be delayed by 1 frame.
    async:newSimulationTimer(0.001, sendGearNotification, { actor = data.actor, newData = newData })
end

local function onDeleteItems(data)
    for _, item in pairs(data.items) do
        item:remove()
    end
end

local function onNemesisKilled(data)
    local gvs = world.mwscript.getGlobalVariables(data.player)
    gvs[const.NEMESIS_KILLED_GVAR] = gvs[const.NEMESIS_KILLED_GVAR] + 1
    local playerName = getRecord(data.player).name
    settings.debugPrint("Nemesis revenge count for " .. playerName .. ": "..tostring(gvs[const.NEMESIS_KILLED_GVAR]))
end

return {
    eventHandlers = {
        [MOD_NAME .. "onActive"] = onActive,
        [MOD_NAME .. "onPlayerDied"] = onPlayerDied,
        [MOD_NAME .. "onClearState"] = onClearState,
        [MOD_NAME .. "onUpgradeGear"] = onUpgradeGear,
        [MOD_NAME .. "onDeleteItems"] = onDeleteItems,
        [MOD_NAME .. "onNemesisKilled"] = onNemesisKilled,
    },
}
