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
local interfaces = require("openmw.interfaces")
local storage    = require("openmw.storage")
local MOD_NAME   = require("scripts.ErnNemesis.ns")
local async      = require("openmw.async")

local function groupKey(groupName)
    return 'Settings/' .. MOD_NAME .. '/' .. groupName
end

local adminGroupKey    = groupKey("Admin")
local gameplayGroupKey = groupKey("Gameplay")

local function playerInit()
    interfaces.Settings.registerPage {
        key = MOD_NAME,
        l10n = MOD_NAME,
        name = "name",
        description = "description"
    }
end

local function globalInit()
    interfaces.Settings.registerGroup {
        key = adminGroupKey,
        l10n = MOD_NAME,
        name = "modSettingsAdminTitle",
        page = MOD_NAME,
        permanentStorage = true,
        order = 15,
        settings = { {
            key = "disable",
            name = "disable_name",
            description = "disable_description",
            default = false,
            renderer = "checkbox"
        }, {
            key = "debugMode",
            name = "debugMode_name",
            description = "debugMode_description",
            default = false,
            renderer = "checkbox"
        }
        }
    }

    interfaces.Settings.registerGroup {
        key = gameplayGroupKey,
        l10n = MOD_NAME,
        name = "modSettingsGameplayTitle",
        page = MOD_NAME,
        permanentStorage = true,
        order = 10,
        settings = {
            {
                key = "healthScaling",
                name = "healthScaling_name",
                description = "healthScaling_description",
                default = 5,
                renderer = "number",
                argument = {
                    integer = true,
                    min = 0
                }
            }, {
            key = "fatigueScaling",
            name = "fatigueScaling_name",
            description = "fatigueScaling_description",
            default = 5,
            renderer = "number",
            argument = {
                integer = true,
                min = 0
            }
        }, {
            key = "magickaScaling",
            name = "magickaScaling_name",
            description = "magickaScaling_description",
            default = 5,
            renderer = "number",
            argument = {
                integer = true,
                min = 0
            }
        }, {
            key = "attributeScaling",
            name = "attributeScaling_name",
            description = "attributeScaling_description",
            default = 5,
            renderer = "number",
            argument = {
                integer = true,
                min = 0
            }
        }, {
            key = "skillScaling",
            name = "skillScaling_name",
            description = "skillScaling_description",
            default = 5,
            renderer = "number",
            argument = {
                integer = true,
                min = 0
            }
        }, {
            key = "equipmentScaling",
            name = "equipmentScaling_name",
            description = "equipmentScaling_description",
            default = true,
            renderer = "checkbox"
        }, {
            key = "spellScaling",
            name = "spellScaling_name",
            description = "spellScaling_description",
            default = true,
            renderer = "checkbox"
        },
        }
    }
end

local lookupFuncTable = {
    __index = function(table, key)
        if not rawget(table, "section") then
            table.section = storage.globalSection(table.groupKey)
            table.cached = table.section:asTable()

            table.section:subscribe(async:callback(function(_, key)
                table.cached[key] = table.section:get(key)
            end))
        end

        if key == "subscribe" then
            return function(callback)
                print("Subscribed to " .. tostring(table.groupKey) .. ".")
                return table.section.subscribe(table.section, callback)
            end
        elseif key == "section" then
            return table.section
        elseif key == "groupKey" then
            return table.groupKey
        end
        -- fall through to cached settings section
        local val = table.cached[key]
        if val ~= nil then
            return val
        else
            --print("cached settings: " .. aux_util.deepToString(table.cached, 3))
            --print("current settings: " .. aux_util.deepToString(table.section:asTable(), 3))
            error("unknown setting: " .. tostring(table.groupKey) .. " - " .. tostring(key))
            return nil
        end
    end,
}

--- lazilly-inited cached settings container
---@param groupKeyParam string
---@return table
local function newContainer(groupKeyParam)
    local container = {
        groupKey = groupKeyParam,
    }
    setmetatable(container, lookupFuncTable)
    return container
end

local gameplayContainer = newContainer(gameplayGroupKey)
local adminContainer = newContainer(adminGroupKey)

local function debugPrint(str, ...)
    if adminContainer.debugMode then
        local arg = { ... }
        if arg ~= nil then
            print(string.format("DEBUG: " .. str, unpack(arg)))
        else
            print("DEBUG: " .. str)
        end
    end
end

---@alias SettingContainer table

---@class Settings
---@field playerInit fun()
---@field globalInit fun()
---@field admin SettingContainer
---@field gameplay SettingContainer

---@type Settings
return {
    playerInit = playerInit,
    globalInit = globalInit,
    gameplay = gameplayContainer,
    admin = adminContainer,
    debugPrint = debugPrint,
}
