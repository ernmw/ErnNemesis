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

return {
    NEMESIS_SPELL_1 = "ErnNemesis1",
    NEMESIS_KILLED_GVAR = "x32_ErnNemesisKilled",
    MAX_NEGLECT_BONUS = 5,
    MAX_QUALITY = 9,
    --- don't upgrade items at all.
    UPGRADE_DISABLED = "disabled",
    --- replace items with better items in the allowlist.
    UPGRADE_ALLOWLIST = "allowList",
    --- replace items with any better items, including unique ones.
    UPGRADE_ALL = "all",
    --- replace items with improved versions of themselves instead of wholly-different items.
    UPGRADE_IMPROVE = "improve",
}
