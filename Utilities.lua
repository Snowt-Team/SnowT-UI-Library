-- Utilities.lua: Helper functions for SnowtUI
-- Provides common utilities for table, UI, math, string, and debug operations
-- Dependencies: Core.lua, Theme.lua, Config.lua, Icons.lua, Animations.lua
local Utilities = {}
Utilities.Version = "1.0.0"
Utilities.Dependencies = { "Core", "Theme", "Config", "Icons", "Animations" }

-- Services
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

-- Initialize module with SnowtUI context
function Utilities.init(params)
    local SnowtUI = params.SnowtUIInstance
    Utilities.SnowtUI = SnowtUI
    Utilities.Theme = SnowtUI:GetModule("Theme")
    Utilities.Config = SnowtUI:GetModule("Config")
    Utilities.Icons = SnowtUI:GetModule("Icons")
    Utilities.Animations = SnowtUI:GetModule("Animations")
end

-- Table Utilities

-- Deep copy a table
function Utilities.deep_copy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = Utilities.deep_copy(v)
    end
    return copy
end

-- Merge two tables (shallow merge)
function Utilities.merge_tables(t1, t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then
        warn("Utilities.merge_tables: Arguments must be tables")
        return t1 or {}
    end
    local merged = Utilities.deep_copy(t1)
    for k, v in pairs(t2) do
        merged[k] = v
    end
    return merged
end

-- Find value in table
function Utilities.table_find(tbl, value)
    if type(tbl) ~= "table" then
        return nil
    end
    for i, v in ipairs(tbl) do
        if v == value then
            return i
        end
    end
    return nil
end

-- UI Utilities

-- Create a UI element with properties
function Utilities.create_ui(className, properties, parent)
    if not className or type(className) ~= "string" then
        warn("Utilities.create_ui: Invalid className")
        return nil
    end

    local element = Instance.new(className)
    properties = properties or {}

    -- Apply theme defaults if applicable
    if Utilities.Theme then
        local themeProps = Utilities.Theme:get(className .. "Defaults", {})
        properties = Utilities.merge_tables(themeProps, properties)
    end

    -- Apply properties
    for prop, value in pairs(properties) do
        if prop == "Icon" and Utilities.Icons then
            Utilities.Icons:apply_to(element, value, "Material", { theme = properties.Theme })
        elseif prop == "Animation" and Utilities.Animations then
            Utilities.Animations.tween(element, value.properties, value.duration, value.easingStyle, value.easingDirection)
        else
            pcall(function()
                element[prop] = value
            end)
        end
    end

    if parent then
        element.Parent = parent
    end

    return element
end

-- Apply properties to an existing UI element
function Utilities.apply_properties(element, properties)
    if not element or not properties then
        warn("Utilities.apply_properties: Missing element or properties")
        return
    end

    for prop, value in pairs(properties) do
        if prop == "Icon" and Utilities.Icons then
            Utilities.Icons:apply_to(element, value, "Material", { theme = properties.Theme })
        elseif prop == "Animation" and Utilities.Animations then
            Utilities.Animations.tween(element, value.properties, value.duration, value.easingStyle, value.easingDirection)
        else
            pcall(function()
                element[prop] = value
            end)
        end
    end
end

-- Math Utilities

-- Clamp a value between min and max
function Utilities.clamp(value, min, max)
    if type(value) ~= "number" or type(min) ~= "number" or type(max) ~= "number" then
        warn("Utilities.clamp: Arguments must be numbers")
        return value
    end
    return math.max(min, math.min(max, value))
end

-- Linear interpolation
function Utilities.lerp(a, b, t)
    if type(a) ~= "number" or type(b) ~= "number" or type(t) ~= "number" then
        warn("Utilities.lerp: Arguments must be numbers")
        return a
    end
    return a + (b - a) * Utilities.clamp(t, 0, 1)
end

-- String Utilities

-- Trim whitespace from string
function Utilities.trim(str)
    if type(str) ~= "string" then
        warn("Utilities.trim: Argument must be a string")
        return str
    end
    return str:match("^%s*(.-)%s*$")
end

-- Format string with arguments
function Utilities.format(str, ...)
    if type(str) ~= "string" then
        warn("Utilities.format: First argument must be a string")
        return str
    end
    local success, result = pcall(function(...)
        return string.format(str, ...)
    end, ...)
    if success then
        return result
    else
        warn("Utilities.format: Invalid format string or arguments")
        return str
    end
end

-- Debug Utilities

-- Log message with configurable verbosity
function Utilities.log(message, level)
    level = level or "Info"
    local debugMode = Utilities.Config and Utilities.Config:get("DebugMode", false)

    if debugMode then
        local prefix = Utilities.format("[%s] SnowtUI: ", level)
        if level == "Error" then
            error(prefix .. message, 0)
        elseif level == "Warn" then
            warn(prefix .. message)
        else
            print(prefix .. message)
        end
    end
end

-- Assert condition with custom message
function Utilities.assert(condition, message)
    if not condition then
        Utilities.log(message or "Assertion failed", "Error")
    end
    return condition
end

-- Input Utilities

-- Check if key is pressed
function Utilities.is_key_pressed(keyCode)
    if not keyCode or not keyCode:IsA("Enum.KeyCode") then
        warn("Utilities.is_key_pressed: Invalid keyCode")
        return false
    end
    return UserInputService:IsKeyDown(keyCode)
end

-- Connect to SnowtUI lifecycle
function Utilities.connect_lifecycle()
    if Utilities.SnowtUI then
        Utilities.SnowtUI:OnModuleLoaded("Theme", function(theme)
            Utilities.Theme = theme
        end)
        Utilities.SnowtUI:OnModuleLoaded("Config", function(config)
            Utilities.Config = config
        end)
        Utilities.SnowtUI:OnModuleLoaded("Icons", function(icons)
            Utilities.Icons = icons
        end)
        Utilities.SnowtUI:OnModuleLoaded("Animations", function(animations)
            Utilities.Animations = animations
        end)
    end
end

-- Initialize lifecycle connections
Utilities.connect_lifecycle()

return Utilities