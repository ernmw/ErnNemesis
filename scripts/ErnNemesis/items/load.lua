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

--[[
Dump levelled lists notes:
tes3cmd dump --type levi './Morrowind/Data Files/Morrowind.esm' | grep Item_ID | awk -F: '{print $NF}' | sort -u >> items.txt
tes3cmd dump --type levi './Morrowind/Data Files/Tribunal.esm' | grep Item_ID | awk -F: '{print $NF}' | sort -u >> items.txt
tes3cmd dump --type levi './Morrowind/Data Files/Bloodmoon.esm' | grep Item_ID | awk -F: '{print $NF}' | sort -u >> items.txt
tes3cmd dump --type levi './mods/ModdingResources/TamrielData/00 Data Files/Tamriel_Data.esm' | grep Item_ID | awk -F: '{print $NF}' | sort -u >> items.txt
sed 's/^/  - /' items.txt | sort -u
]]

local dict = {}

local function load()
    local merged = {}

    local function hasSuffix(str, suffix)
        if #suffix == 0 then return true end
        return str:sub(- #suffix) == suffix
    end

    local function loadFile(fileName)
        local result = markup.loadYaml(fileName)
        for k, v in pairs(result) do
            merged[k] = v
        end
    end


    for fileName in vfs.pathsWithPrefix("scripts\\" .. MOD_NAME .. "\\items") do
        if hasSuffix(fileName:lower(), ".yaml") then
            loadFile(fileName)
        end
    end

    for _, id in pairs(merged.items) do
        dict[id] = true
    end

    settings.debugPrint("Loaded " .. tostring(#merged.items) .. " items.")
end

load()

return dict
