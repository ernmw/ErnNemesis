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
local aux_util   = require('openmw_aux.util')


local FollowerDetectionUtil = interfaces.FollowerDetectionUtil

-- be noisy if followerUtil is missing.
if not FollowerDetectionUtil then
    local ui = require('openmw.ui')
    local localization = core.l10n(MOD_NAME)
    ui.showMessage(localization("missingFollowerDetectionUtilError"))
    print(localization("missingFollowerDetectionUtilError"))
    return {}
end

local combatTracker = {}

local clearCombatant = async:registerTimerCallback('clearCombatant', function(id)
    combatTracker[id] = nil
end)

local function OMWMusicCombatTargetsChanged(incomingTargetData)
    if next(incomingTargetData.targets) == nil then
        -- delay removal.
        async:newSimulationTimer(2, clearCombatant, incomingTargetData.actor.id)
    else
        combatTracker[incomingTargetData.actor.id] = incomingTargetData.actor
    end
end

local function validOpponent(followers, actor)
    return actor:isValid() and not types.Actor.isDead(actor) and not followers[actor.id]
end

--- onDied is called -after- combat ends.
local function onDied()
    local opponents = {}
    local followers = FollowerDetectionUtil.getFollowerList()
    for _, actor in pairs(combatTracker) do
        if validOpponent(followers, actor) then
            table.insert(opponents, actor.id)
        end
    end
    core.sendGlobalEvent(MOD_NAME .. "onPlayerDied", {
        player = pself.object,
        opponents = opponents,
    })
end

local function onConsoleCommand(mode, command, selectedObject)
    if command:lower() == "lua nemesis clear" then
        core.sendGlobalEvent(MOD_NAME .. "onClearState", {
            player = pself.object,
        })
    end
end

return {
    eventHandlers = {
        OMWMusicCombatTargetsChanged = OMWMusicCombatTargetsChanged,
        Died = onDied,
    },
    engineHandlers = {
        onConsoleCommand = onConsoleCommand,
    }
}
