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
local MOD_NAME              = require("scripts.ErnNemesis.ns")
local const = require("scripts.ErnNemesis.const")
local core  = require('openmw.core')
local localization = core.l10n(MOD_NAME)

local globalVarAchievements = {
    {
        type = "global_variable",
        name = localization("revengeAchievementName"),
        description = localization("revengeAchievementDescription"),
        variable = const.NEMESIS_KILLED_GVAR,
        value = 6,
        operator = function(self, givenValue)
            return givenValue >= self.value
        end,
        enableProgress = true,
        icon = "Icons\\ErnNemesis\\revenge.tga",
        bgColor = "red",
        id = const.NEMESIS_KILLED_GVAR,
        hidden = false
    },
}

return globalVarAchievements
