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
local types      = require('openmw.types')
local aux_util   = require('openmw_aux.util')

local function getRecord(obj)
    return obj.type.record(obj)
end

---@class Nemisis
---@field actorID string
---@field kills number

local nemesisData = storage.globalSection(MOD_NAME .. "NemesisData")

local function onNemesisActive(data)
    print("Global onNemesisActive: " .. aux_util.deepToString(data, 3))
end

local function onPlayerDied(data)
    print("Global onPlayerDied: " .. aux_util.deepToString(data, 3))
    local key = getRecord(data.player).name
    local snapshot = nemesisData:asTable()[key] or {}
    print("Old nemesis data: " .. aux_util.deepToString(snapshot, 3))
    for _, opponent in ipairs(data.opponents) do
        local originalCount = snapshot[opponent] or 0
        snapshot[opponent] = originalCount + 1
    end
    print("New nemesis data: " .. aux_util.deepToString(snapshot, 3))
    nemesisData:set(key, snapshot)
end

local function onClearState()
    print("Global onClearState.")
    nemesisData:reset()
end

return {
    eventHandlers = {
        [MOD_NAME .. "onNemesisActive"] = onNemesisActive,
        [MOD_NAME .. "onPlayerDied"] = onPlayerDied,
        [MOD_NAME .. "onClearState"] = onClearState,
    },
}
