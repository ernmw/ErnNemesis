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
local core = require("openmw.core")
local types = require("openmw.types")

---Performs a binary search on a list sorted in ascending order by valueFn,
---returning the index at which an item with the given score should be inserted.
---@generic T
---@param list T[] A list already sorted in ascending order by valueFn
---@param score number The score to find the insertion index for
---@param valueFn fun(record: table): number Returns the score to sort by
---@return number index
local function binarySearchInsertIndex(list, score, valueFn)
    local low = 1
    local high = #list

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local midValue = valueFn(list[mid])

        if midValue <= score then
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return low
end

---Inserts item into list to keep it sorted in ascending order by valueFn(item).
---@generic T
---@param list T[] A list already sorted in ascending order by valueFn
---@param item T The item to insert
---@param valueFn fun(record: table): number Returns the score to sort by
---@return number index The index the item was inserted at
local function binaryInsert(list, item, valueFn)
    local index = binarySearchInsertIndex(list, valueFn(item), valueFn)
    table.insert(list, index, item)
    return index
end

local armorWeightGMST = {
    [types.Armor.TYPE.Helmet]    = core.getGMST("iHelmWeight"),
    [types.Armor.TYPE.Cuirass]   = core.getGMST("iCuirassWeight"),
    [types.Armor.TYPE.LPauldron] = core.getGMST("iPauldronWeight"),
    [types.Armor.TYPE.RPauldron] = core.getGMST("iPauldronWeight"),
    [types.Armor.TYPE.Greaves]   = core.getGMST("iGreavesWeight"),
    [types.Armor.TYPE.Boots]     = core.getGMST("iBootsWeight"),
    [types.Armor.TYPE.LGauntlet] = core.getGMST("iGauntletWeight"),
    [types.Armor.TYPE.RGauntlet] = core.getGMST("iGauntletWeight"),
    [types.Armor.TYPE.Shield]    = core.getGMST("iShieldWeight"),
    [types.Armor.TYPE.LBracer]   = core.getGMST("iGauntletWeight"),
    [types.Armor.TYPE.RBracer]   = core.getGMST("iGauntletWeight"),
}

local fLightMaxMod = core.getGMST("fLightMaxMod")
local fMedMaxMod = core.getGMST("fMedMaxMod")

---@param record any recordId of an Armor item
---@return string|nil skill "lightarmor" | "mediumarmor" | "heavyarmor"
local function getArmorSkill(record)
    local baseWeight = armorWeightGMST[record.type]
    if not baseWeight then
        return nil -- unknown/unsupported armor type
    end

    local lightMax = baseWeight * fLightMaxMod
    local medMax = baseWeight * fMedMaxMod

    if record.weight <= lightMax then
        return "lightarmor"
    elseif record.weight <= medMax then
        return "mediumarmor"
    else
        return "heavyarmor"
    end
end

---@type {[string]: number}
local valueCache = {}

---Return a stable score for an armor piece.
---@param record table
---@return number
local function armorValue(record)
    if valueCache[record.id] then
        return valueCache[record.id]
    end
    local score = record.mwscript and -100 or record.value
    valueCache[record.id] = score
    return score
end

---Return a stable score for a weapon piece.
---@param record table
---@return number
local function weaponValue(record)
    if valueCache[record.id] then
        return valueCache[record.id]
    end
    local score = record.mwscript and -100 or record.value
    valueCache[record.id] = score
    return score
end

local armorTypeToSlot = {
    [types.Armor.TYPE.Helmet]    = types.Actor.EQUIPMENT_SLOT.Helmet,
    [types.Armor.TYPE.Cuirass]   = types.Actor.EQUIPMENT_SLOT.Cuirass,
    [types.Armor.TYPE.Greaves]   = types.Actor.EQUIPMENT_SLOT.Greaves,
    [types.Armor.TYPE.Boots]     = types.Actor.EQUIPMENT_SLOT.Boots,
    [types.Armor.TYPE.LPauldron] = types.Actor.EQUIPMENT_SLOT.LeftPauldron,
    [types.Armor.TYPE.RPauldron] = types.Actor.EQUIPMENT_SLOT.RightPauldron,
    [types.Armor.TYPE.LGauntlet] = types.Actor.EQUIPMENT_SLOT.LeftGauntlet,
    [types.Armor.TYPE.RGauntlet] = types.Actor.EQUIPMENT_SLOT.RightGauntlet,
    [types.Armor.TYPE.Shield]    = types.Actor.EQUIPMENT_SLOT.CarriedLeft,
    [types.Armor.TYPE.LBracer]   = types.Actor.EQUIPMENT_SLOT.LeftGauntlet,
    [types.Armor.TYPE.RBracer]   = types.Actor.EQUIPMENT_SLOT.RightGauntlet,
}

local function allSlots()
    local out = {}
    for _, slot in pairs(armorTypeToSlot) do
        out[slot] = {}
    end
    return out
end

--- Sorted armor records, first split by armor skill, and then by slot.
---@type {[string]: {[number]: table}}
local armorBySlotBySkill = {
    lightarmor = allSlots(),
    mediumarmor = allSlots(),
    heavyarmor = allSlots(),
}

local function buildArmorLists()
    for _, record in ipairs(types.Armor.records) do
        local skill = getArmorSkill(record)
        if not skill then
            error("no skill for " .. record.id)
        end
        local slot = armorTypeToSlot[record.type]
        if not slot then
            error("no slot for " .. record.id)
        end
        binaryInsert(armorBySlotBySkill[skill][slot], record, armorValue)
    end
end

--- Sorted weapon records, split by skill.
---@type {[number]: table}
local weaponsByType = {
    [types.Weapon.TYPE.AxeOneHand]        = {},
    [types.Weapon.TYPE.AxeTwoHand]        = {},
    [types.Weapon.TYPE.BluntOneHand]      = {},
    [types.Weapon.TYPE.BluntTwoClose]     = {},
    [types.Weapon.TYPE.BluntTwoWide]      = {},
    [types.Weapon.TYPE.LongBladeOneHand]  = {},
    [types.Weapon.TYPE.LongBladeTwoHand]  = {},
    [types.Weapon.TYPE.ShortBladeOneHand] = {},
    [types.Weapon.TYPE.SpearTwoWide]      = {},
    [types.Weapon.TYPE.MarksmanBow]       = {},
    [types.Weapon.TYPE.MarksmanCrossbow]  = {},
    [types.Weapon.TYPE.MarksmanThrown]    = {},
    [types.Weapon.TYPE.Arrow]             = {},
    [types.Weapon.TYPE.Bolt]              = {},
}

local function buildWeaponsLists()
    for _, record in ipairs(types.Weapon.records) do
        binaryInsert(weaponsByType[record.type], record, weaponValue)
    end
end

local built = false
local function build()
    if not built then
        built = true
        buildArmorLists()
        buildWeaponsLists()
    end
end

local function getWeaponWithScore(weaponType, score)
    local idx = binarySearchInsertIndex(weaponsByType[weaponType], score, weaponValue)
    if idx > #weaponsByType[weaponType] then
        idx = #weaponsByType[weaponType]
    end
    return weaponsByType[weaponType][idx]
end

local function getArmorWithScore(skill, slot, score)
    local idx = binarySearchInsertIndex(armorBySlotBySkill[skill][slot], score, armorValue)
    if idx > #armorBySlotBySkill[skill][slot] then
        idx = #armorBySlotBySkill[skill][slot]
    end
    return armorBySlotBySkill[skill][slot][idx]
end

return {
    getArmorSkill = getArmorSkill,
    armorBySlotBySkill = armorBySlotBySkill,
    weaponsByType = weaponsByType,
    build = build,
    armorValue = armorValue,
    weaponValue = weaponValue,
    getWeaponWithScore = getWeaponWithScore,
    getArmorWithScore = getArmorWithScore,
    armorTypeToSlot = armorTypeToSlot,
}
