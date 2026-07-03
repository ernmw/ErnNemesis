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
local core        = require('openmw.core')
local types       = require('openmw.types')
local pself       = require('openmw.self')
local async       = require('openmw.async')
local MOD_NAME    = require("scripts.ErnNemesis.ns")
local interfaces  = require('openmw.interfaces')
local storage     = require('openmw.storage')
local nearby      = require('openmw.nearby')
local aux_util    = require('openmw_aux.util')

local nemesisData = storage.globalSection(MOD_NAME .. "NemesisData")

local function getRecord(obj)
    return obj.type.record(obj)
end

local function onActive()
    --print("onActive: " .. getRecord(pself.object).name)
    local kills = 0
    for _, player in ipairs(nearby.players) do
        local snapshot = nemesisData:asTable()[getRecord(player).name]
        if snapshot[pself.object.id] then
            kills = kills + snapshot[pself.object.id]
        end
    end

    if kills > 0 then
        local eventData = {
            opponent = pself,
            kills = kills,
        }
        print("Nemesis Activated: " .. aux_util.deepToString(eventData))
        core.sendGlobalEvent(MOD_NAME .. "onNemesisActive", eventData)
    end
end


return {
    engineHandlers = {
        onActive = onActive,
    },
}
