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
local MOD_NAME                     = require("scripts.ErnNemesis.ns")
local content                      = require('openmw.content')

content.spells.records.ErnNemesis1 = {
    name = 'Nemesis',
    type = content.spells.TYPE.Ability,
    cost = 0,
    starterSpellFlag = false,
    isAutocalc = false,
    effects = { { id = 'Feather', magnitudeMin = 75, magnitudeMax = 75 } }
}
