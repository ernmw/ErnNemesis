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
local core         = require("openmw.core")
local types     = require("openmw.types")
local storage        = require("openmw.storage")
local itemLists    = require("scripts.ErnNemesis.items.load")
local shuffle = require("scripts.ErnNemesis.shuffle")
local settings     = require("scripts.ErnNemesis.settings.settings")
local MOD_NAME  = require("scripts.ErnNemesis.ns")
local localization       = core.l10n(MOD_NAME)

local MAX_QUALITY = 9

--- This tracks records for "improved" items, which are dynamically generated records
--- that clone items in the allowlist and tweak them to be stronger.
--- This list is generated lazilly.
--- There are 9 quality levels for every item.
--- All items of the same quality should re-use the same record.
--- I need a map of original_item_record_id -> upgrade table.
--- the upgrade table is a map of quality level (a number) to a generated item record id.
--- quality 0 should point back at the original_item_record_id.
--- I also need the reverse lookup: a generated item record id back to the original_item_record_id.
--- that will allow me to upgrade items sequentially.
---
--- potential weapon stats to modify:
--- * max damage
--- * min damage (maybe skip this one, since it is not independent of max damage)
--- * condition (health)
--- * enchantcapacity?
--- * weight
--- * value (this should always go up)
--- * speed
---
--- potential armor stats to modify:
--- * baseArmor
--- * condition (health)
--- * enchantcapacity?
--- * weight
--- * value (this should always go up)
---
--- This is saved onLoad because it must follow the savegame.
--- Dynamically generated records are not valid across differenct characters,
--- and may not be valid across different saves of the same character.
---@class Persisted
---@field upgradeMap {[string]: string | {[number]: string}}
---@field improvementMap {[string]: number}

---@type Persisted
local persist      = {
    upgradeMap = {},
    improvementMap = {}
}


---@alias UpgradeTable {[number]: string}

---@param itemRecordID string
---@return UpgradeTable?
local function getUpgradeTable(itemRecordID)
    --- get the value. if it's a string, do another lookup.
    local lookup = persist.upgradeMap[itemRecordID]
    if not lookup then
        return
    end
    if type(lookup) == "string" then
        -- this branch happens if itemRecordID was for an upgraded version.
        return getUpgradeTable(lookup)
    end
    return lookup
end

---@param itemRecordID string
---@param newTable UpgradeTable
local function setUpgradeTable(itemRecordID, newTable)
    local lookup = persist.upgradeMap[itemRecordID]
    if not lookup then
        persist.upgradeMap[lookup] = newTable
        return
    end
    if type(lookup) == "string" then
        -- this branch happens if itemRecordID was for an upgraded version.
        -- we need the root ID.
        lookup = getUpgradeTable(lookup)[0]
        if not lookup then
            error("invalid lookup table for " .. tostring(itemRecordID))
        end
    end
    persist.upgradeMap[lookup] = newTable
end

---@enum WeaponImprovements
local WEAPON_IMPROVEMENTS = {
    health = 1,
    enchantCapacity = 2,
    weight = 3,
    speed = 5,
    maxDamage = 6,
}

---@enum ArmorImprovements
local ARMOR_IMPROVEMENTS = {
    health = 1,
    enchantCapacity = 2,
    weight = 3,
    speed = 4,
}


---Return a random list of improvements, with an even-ish distribution.
---TODO: This isn't stable for a given baseItemRecordID; it must be preserved. use persist table as cache
---@param baseItemRecordID string
---@return WeaponImprovements[]
local function weaponImprovementsByLevel(baseItemRecordID)
    local rand = shuffle(ARMOR_IMPROVEMENTS)
    while #rand < MAX_QUALITY do
        for _, v in ipairs(shuffle(ARMOR_IMPROVEMENTS)) do
            if #rand < MAX_QUALITY then
                rand[#rand +1] = v
            end
        end
    end
    return rand
end

---Returns the new name of an item with an adjective.
---@param baseItemRecord table
---@param quality number
local function getNewName(baseItemRecord, quality)
    if quality < 1 then
        return baseItemRecord.name
    end
    if quality > MAX_QUALITY then
        quality = MAX_QUALITY
    end

    localization("quality"..tostring(quality), {baseItemRecord.name})
end

local function onLoad(data)
    if data then
        persist = data
    end
end
local function onSave()
    return persist
end

return {
    interfaceName = MOD_NAME.."_Upgrade",
    interface = {
        version = 1,
        getUpgradeTable = getUpgradeTable,
        setUpgradeTable = setUpgradeTable,
    },
    engineHandlers = {
        onLoad = onLoad,
        onSave = onSave,
    },
}
