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
local core       = require('openmw.core')
local types      = require('openmw.types')
local pself      = require('openmw.self')
local async      = require('openmw.async')
local MOD_NAME   = require("scripts.ErnNemesis.ns")
local interfaces = require('openmw.interfaces')
local storage    = require('openmw.storage')
local nearby     = require('openmw.nearby')
local aux_util   = require('openmw_aux.util')
local settings   = require("scripts.ErnNemesis.settings.settings")

-- shouldn't pull in global storage in non-global contexts.
--local nemesisData = storage.globalSection(MOD_NAME .. "NemesisData")

local persist    = {
    kills = 0
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

---@class AttributePreferences
---@field count number
---@field name string

---@return AttributePreferences[]
local function getPreferredAttributes()
    local isCreature = types.Creature.objectIsInstance(pself)
    if isCreature then
        return {
            { count = 1 / 8, name = "agility" },
            { count = 1 / 8, name = "endurance" },
            { count = 1 / 8, name = "intelligence" },
            { count = 1 / 8, name = "luck" },
            { count = 1 / 8, name = "personality" },
            { count = 1 / 8, name = "speed" },
            { count = 1 / 8, name = "strength" },
            { count = 1 / 8, name = "willpower" },
        }
    else
        local classRecord = types.NPC.classes.record(getRecord(pself.object).class)
        local classAttribCount = #(classRecord.attributes)
        local out = {}
        for _, attributeName in ipairs(classRecord.attributes) do
            table.insert(out,
                { count = 1 / classAttribCount, name = attributeName })
        end
        return out
    end
end

local function handleAttributes(oldKills, newKills)
    if settings.gameplay.attributeScaling > 0 then
        for _, attrib in ipairs(getPreferredAttributes()) do
            local increase = math.ceil(settings.gameplay.attributeScaling * attrib.count) * (newKills - oldKills)
            local attribute = pself.type.stats.attributes[attrib.name](pself)
            attribute.base = math.max(attribute.base, attribute.base + increase)
            settings.debugPrint(getRecord(pself.object).name ..
                " " .. attrib.name .. " increased by " .. tostring(increase))
        end
    end
end


local function handleSkills(oldKills, newKills)
    local isCreature = types.Creature.objectIsInstance(pself)
    if isCreature then
    else
        local className = types.NPC.classes.record(getRecord(pself.object).class).name
    end
end

local function onActive()
    if pself.object:isValid() and not types.Actor.isDead(pself.object) then
        core.sendGlobalEvent(MOD_NAME .. "onActive",
            { actor = pself.object, kills = persist.kills })
    end
end

local function onDied()
    core.sendGlobalEvent(MOD_NAME .. "onNemesisDied",
        { actor = pself.object, kills = persist.kills })
end

local function onKillCountUpdate(data)
    handleDynStats(persist.kills, data.kills)
    handleAttributes(persist.kills, data.kills)

    persist.kills = data.kills
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
    engineHandlers = {
        onActive = onActive,
        onLoad = onLoad,
        onSave = onSave,
    },
    eventHandlers = {
        [MOD_NAME .. "onKillCountUpdate"] = onKillCountUpdate,
        Died = onDied,
    },
}
