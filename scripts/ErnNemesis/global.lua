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
local MOD_NAME   = require("scripts.ErnNemesis.ns")
local interfaces = require('openmw.interfaces')
local storage    = require('openmw.storage')
local world      = require('openmw.world')
local types      = require('openmw.types')
local aux_util   = require('openmw_aux.util')
local settings   = require("scripts.ErnNemesis.settings.settings")
local itemutil   = require("scripts.ErnNemesis.itemutil")

local function getRecord(obj)
    return obj.type.record(obj)
end

---@class Nemisis
---@field actorID string
---@field kills number

local nemesisData = storage.globalSection(MOD_NAME .. "NemesisData")

local function onActive(data)
    --settings.debugPrint("Global onActive: " .. aux_util.deepToString(data, 3))

    local kills = 0
    for _, player in ipairs(world.players) do
        local snapshot = nemesisData:asTable()[getRecord(player).name]
        if snapshot[data.actor.id] then
            kills = kills + snapshot[data.actor.id]
        end
    end

    if kills > data.kills then
        --- some buffs must be applied in global context

        --- Persist kill count on actor
        data.actor:sendEvent(MOD_NAME .. "onKillCountUpdate", { kills = kills })
    end
end

local function onNemesisDied(data)
    settings.debugPrint("Global onNemesisDied: " .. aux_util.deepToString(data, 3))
    for _, player in ipairs(world.players) do
        local key = getRecord(player).name
        local snapshot = nemesisData:asTable()[key]
        if snapshot[data.actor.id] then
            snapshot[data.actor.id] = nil
        end
        settings.debugPrint("New nemesis data: " .. aux_util.deepToString(snapshot, 3))
        nemesisData:set(key, snapshot)
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


---@class UpgradeGearCompletedData
---@field newIDsBySlot {[number]: string}
---@field newConsumableIDs string[]

---@param data UpgradeGearData
local function onUpgradeGear(data)
    --- 1. delete the old gear
    --- 2. spawn in new gear
    --- 3. get the npc to equip it
    itemutil.build()

    -- delete old items
    for _, item in ipairs(data.oldGear) do
    end

    ---@type UpgradeGearCompletedData
    local newData = {
        newIDsBySlot = {},
        newConsumableIDs = {},
    }

    local inventory = types.Actor.inventory(data.actor)

    local upgradeWeapon = function(slot)
        local oldItem = types.Actor.getEquipment(data.actor, slot)
        if oldItem then
            local oldItemRecord = getRecord(oldItem)
            local oldItemScore = itemutil.weaponValue(oldItemRecord)
            local betterItemRecord = itemutil.getWeaponWithScore(oldItemRecord.type,
                oldItemScore + (settings.gameplay.weaponScaling * data.totalKills))
            if oldItemRecord.id ~= betterItemRecord.id then
                local newItemInstance = world.createObject(betterItemRecord.id)
                newItemInstance:moveInto(inventory)
                newData.newIDsBySlot[slot] = newItemInstance.id
            end
        end
    end

    if settings.gameplay.weaponScaling > 0 then
        upgradeWeapon(types.Actor.EQUIPMENT_SLOT.CarriedRight)
        upgradeWeapon(types.Actor.EQUIPMENT_SLOT.Ammunition)
    end

    data.actor:sendEvent(MOD_NAME .. "onUpgradeGearCompleted", newData)
    settings.debugPrint("Nemesis gear for " .. getRecord(data.actor).id .. ": " .. aux_util.deepToString(newData, 3))
end

return {
    eventHandlers = {
        [MOD_NAME .. "onActive"] = onActive,
        [MOD_NAME .. "onPlayerDied"] = onPlayerDied,
        [MOD_NAME .. "onNemesisDied"] = onNemesisDied,
        [MOD_NAME .. "onClearState"] = onClearState,
        [MOD_NAME .. "onUpgradeGear"] = onUpgradeGear,
    },
}
