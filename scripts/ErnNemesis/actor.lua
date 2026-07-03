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

local function increaseDynamicStat(stat, oldKills, newKills)
    local buff = (newKills - oldKills) * 5
    settings.debugPrint("increase stat by " .. tostring(buff))
    stat.base = math.max(stat.base, stat.base + buff)
    stat.current = math.max(stat.current, stat.current + buff)
end

local function buffHealth(actor, oldKills, newKills)
    if settings.gameplay.healthScaling then
        local stat = actor.type.stats.dynamic.health(actor)
        increaseDynamicStat(stat, oldKills, newKills)
    end
end

local function buffFatigue(actor, oldKills, newKills)
    if settings.gameplay.healthScaling then
        local stat = actor.type.stats.dynamic.fatigue(actor)
        increaseDynamicStat(stat, oldKills, newKills)
    end
end

local function buffMagicka(actor, oldKills, newKills)
    if settings.gameplay.healthScaling then
        local stat = actor.type.stats.dynamic.magicka(actor)
        increaseDynamicStat(stat, oldKills, newKills)
    end
end

local function getRecord(obj)
    return obj.type.record(obj)
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
    buffHealth(pself, persist.kills, data.kills)
    buffFatigue(pself, persist.kills, data.kills)
    buffMagicka(pself, persist.kills, data.kills)

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
