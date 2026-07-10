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
local MOD_NAME = require("scripts.ErnNemesis.ns")
local vfs      = require('openmw.vfs')
local markup   = require('openmw.markup')
local settings = require("scripts.ErnNemesis.settings.settings")

local block    = {}
local allow     = {}

local function load()
    local count = 0
    local function hasSuffix(str, suffix)
        if #suffix == 0 then return true end
        return str:sub(- #suffix) == suffix
    end

    local function loadFile(fileName)
        local result = markup.loadYaml(fileName)
        for _, v in ipairs(result.block) do
            block[v:lower()] = true
            count = count + 1
        end
        for _, v in ipairs(result.allow) do
            allow[v:lower()] = true
            count = count + 1
        end
    end


    for fileName in vfs.pathsWithPrefix("scripts\\" .. MOD_NAME .. "\\items") do
        if hasSuffix(fileName:lower(), ".yaml") then
            loadFile(fileName)
        end
    end

    settings.debugPrint("Loaded " .. tostring(count) .. " items into blocklist.")
end

load()

return {
    block = block,
    allow = allow
}
