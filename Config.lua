-- Config.lua: Configuration management for SnowtUI with user profiles and settings UI
-- Manages settings storage, persistence, validation, profiles, and a visual settings panel
-- Dependencies: Core.lua, Theme.lua, Elements.lua, Notifications.lua
local Config = {}
Config.Version = "1.1.0"
Config.Dependencies = { "Core", "Theme", "Elements", "Notifications" }

-- Services
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Internal state
Config.Settings = {} -- Current settings (active profile)
Config.Profiles = {} -- All user profiles
Config.ActiveProfile = "Default" -- Current profile name
Config.Defaults = {} -- Default settings from modules
Config.Validators = {} -- Validation rules for settings
Config.EventCallbacks = {} -- Event callbacks for config changes
Config.DataStore = nil -- DataStore instance
Config.DataStoreKey = "SnowtUI_Config_%s" -- Key format for profiles
Config.IsStudio = RunService:IsStudio() -- Check if running in Studio
Config.SettingsUI = nil -- Settings panel instance
Config.AnimationCache = {} -- Cached tweens for UI animations
Config.EventLog = {} -- Log of config changes

-- Default configurations
Config.Defaults.Global = {
    Theme = "Dark",
    Scale = 1,
    GamepadEnabled = true,
    Accessibility = {
        HighContrast = false,
        ReducedMotion = false
    }
}

-- Validation rules
Config.Validators.Global = {
    Theme = function(value)
        if not SnowtUI or not SnowtUI.Modules.Theme then
            return false, "Theme module not loaded"
        end
        local themes = SnowtUI.Modules.Theme.Themes
        if not themes[value] then
            return false, "Invalid theme: " .. tostring(value)
        end
        return true
    end,
    Scale = function(value)
        if type(value) ~= "number" or value < 0.5 or value > 2 then
            return false, "Scale must be a number between 0.5 and 2"
        end
        return true
    end,
    GamepadEnabled = function(value)
        if type(value) ~= "boolean" then
            return false, "GamepadEnabled must be a boolean"
        end
        return true
    end,
    Accessibility = {
        HighContrast = function(value)
            if type(value) ~= "boolean" then
                return false, "HighContrast must be a boolean"
            end
            return true
        end,
        ReducedMotion = function(value)
            if type(value) ~= "boolean" then
                return false, "ReducedMotion must be a boolean"
            end
            return true
        end
    }
}

-- Utility function to create tweens
local function CreateTween(obj, props, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        easingStyle or Enum.EasingStyle.Sine,
        easingDirection or Enum.EasingDirection.InOut
    )
    local tween = Config.AnimationCache[obj] or TweenService:Create(obj, tweenInfo, props)
    Config.AnimationCache[obj] = tween
    tween:Play()
    return tween
end

-- Utility function to deep copy a table
local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Utility function to merge tables
local function MergeTables(base, override)
    local result = DeepCopy(base)
    if type(override) == "table" then
        for k, v in pairs(override) do
            if type(v) == "table" and type(result[k]) == "table" then
                result[k] = MergeTables(result[k], v)
            else
                result[k] = v
            end
        end
    end
    return result
end

-- Utility function to validate settings
local function ValidateSetting(path, value, validators)
    local keys = {}
    for key in path:gmatch("[^.]+") do
        table.insert(keys, key)
    end
    local current = validators
    for i, key in ipairs(keys) do
        if not current[key] then
            return false, "No validator for " .. path
        end
        if i == #keys then
            if type(current[key]) == "function" then
                return current[key](value)
            else
                return false, "Invalid validator for " .. path
            end
        else
            current = current[key]
        end
    end
    return false, "Invalid path: " .. path
end

-- Log config changes
local function LogEvent(eventType, details)
    table.insert(Config.EventLog, {
        Timestamp = os.clock(),
        Type = eventType,
        Details = details
    })
    if #Config.EventLog > 100 then
        table.remove(Config.EventLog, 1)
    end
end

-- Initialize DataStore
local function InitializeDataStore()
    if Config.IsStudio then
        SnowtUI.Debug("Running in Studio, using mock DataStore")
        Config.DataStore = {
            GetAsync = function()
                return nil
            end,
            SetAsync = function() end
        }
    else
        local success, result = pcall(function()
            return DataStoreService:GetDataStore("SnowtUI")
        end)
        if success then
            Config.DataStore = result
        else
            SnowtUI.Debug("Failed to initialize DataStore: " .. result, "error")
            Config.DataStore = {
                GetAsync = function()
                    return nil
                end,
                SetAsync = function() end
            }
        end
    end
end

-- Load profile settings
function Config:LoadProfile(profileName)
    if not Config.DataStore then
        InitializeDataStore()
    end
    local key = string.format(Config.DataStoreKey, profileName)
    local success, savedSettings = pcall(function()
        return Config.DataStore:GetAsync(key)
    end)
    if success and savedSettings then
        local decodedSettings = HttpService:JSONDecode(savedSettings)
        Config.Profiles[profileName] = decodedSettings
        for module, settings in pairs(decodedSettings) do
            for key, value in pairs(settings) do
                local path = module .. "." .. key
                local isValid, errorMsg = ValidateSetting(path, value, Config.Validators)
                if not isValid then
                    SnowtUI.Debug("Invalid setting " .. path .. " in profile " .. profileName .. ": " .. errorMsg, "warning")
                    Config.Profiles[profileName][module][key] = Config.Defaults[module][key]
                end
            end
        end
    else
        Config.Profiles[profileName] = DeepCopy(Config.Defaults)
        SnowtUI.Debug("No saved settings for profile " .. profileName, "info")
    end
    Config.Settings = DeepCopy(Config.Profiles[profileName])
    Config.ActiveProfile = profileName
    SnowtUI.FireEvent("ProfileLoaded", profileName)
    LogEvent("ProfileLoaded", { Profile = profileName })
end

-- Save profile settings
function Config:SaveProfile(profileName)
    if not Config.DataStore then
        InitializeDataStore()
    end
    local key = string.format(Config.DataStoreKey, profileName)
    local success, errorMsg = pcall(function()
        local serialized = HttpService:JSONEncode(Config.Profiles[profileName] or Config.Settings)
        Config.DataStore:SetAsync(key, serialized)
    end)
    if not success then
        SnowtUI.Debug("Failed to save profile " .. profileName .. ": " .. errorMsg, "error")
    else
        SnowtUI.FireEvent("ProfileSaved", profileName)
        LogEvent("ProfileSaved", { Profile = profileName })
    end
end

-- Create a new profile
function Config:CreateProfile(profileName)
    if Config.Profiles[profileName] then
        SnowtUI.Debug("Profile already exists: " .. profileName, "error")
        return false
    end
    Config.Profiles[profileName] = DeepCopy(Config.Defaults)
    self:SaveProfile(profileName)
    self:LoadProfile(profileName)
    SnowtUI.FireEvent("ProfileCreated", profileName)
    LogEvent("ProfileCreated", { Profile = profileName })
    return true
end

-- Delete a profile
function Config:DeleteProfile(profileName)
    if profileName == "Default" then
        SnowtUI.Debug("Cannot delete default profile", "error")
        return false
    end
    if not Config.Profiles[profileName] then
        SnowtUI.Debug("Profile not found: " .. profileName, "error")
        return false
    end
    Config.Profiles[profileName] = nil
    if Config.ActiveProfile == profileName then
        self:LoadProfile("Default")
    end
    local key = string.format(Config.DataStoreKey, profileName)
    pcall(function()
        Config.DataStore:RemoveAsync(key)
    end)
    SnowtUI.FireEvent("ProfileDeleted", profileName)
    LogEvent("ProfileDeleted", { Profile = profileName })
    return true
end

-- Rename a profile
function Config:RenameProfile(oldName, newName)
    if oldName == "Default" then
        SnowtUI.Debug("Cannot rename default profile", "error")
        return false
    end
    if not Config.Profiles[oldName] or Config.Profiles[newName] then
        SnowtUI.Debug("Invalid rename: " .. oldName .. " to " .. newName, "error")
        return false
    end
    Config.Profiles[newName] = DeepCopy(Config.Profiles[oldName])
    Config.Profiles[oldName] = nil
    if Config.ActiveProfile == oldName then
        Config.ActiveProfile = newName
        Config.Settings = DeepCopy(Config.Profiles[newName])
    end
    self:SaveProfile(newName)
    pcall(function()
        Config.DataStore:RemoveAsync(string.format(Config.DataStoreKey, oldName))
    end)
    SnowtUI.FireEvent("ProfileRenamed", oldName, newName)
    LogEvent("ProfileRenamed", { OldName = oldName, NewName = newName })
    return true
end

-- Export profile as JSON
function Config:ExportProfile(profileName)
    if not Config.Profiles[profileName] then
        SnowtUI.Debug("Profile not found: " .. profileName, "error")
        return nil
    end
    local success, result = pcall(function()
        return HttpService:JSONEncode(Config.Profiles[profileName])
    end)
    if success then
        LogEvent("ProfileExported", { Profile = profileName })
        return result
    else
        SnowtUI.Debug("Failed to export profile: " .. result, "error")
        return nil
    end
end

-- Import profile from JSON
function Config:ImportProfile(profileName, jsonString)
    local success, decoded = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    if not success then
        SnowtUI.Debug("Invalid JSON for profile import: " .. decoded, "error")
        return false
    end
    for module, settings in pairs(decoded) do
        for key, value in pairs(settings) do
            local path = module .. "." .. key
            local isValid, errorMsg = ValidateSetting(path, value, Config.Validators)
            if not isValid then
                SnowtUI.Debug("Invalid setting " .. path .. ": " .. errorMsg, "warning")
                decoded[module][key] = Config.Defaults[module][key]
            end
        end
    end
    Config.Profiles[profileName] = decoded
    self:SaveProfile(profileName)
    self:LoadProfile(profileName)
    LogEvent("ProfileImported", { Profile = profileName })
    return true
end

-- Register module defaults and validators
function Config:RegisterModule(moduleName, defaults, validators)
    if not moduleName or type(defaults) ~= "table" or type(validators) ~= "table" then
        SnowtUI.Debug("Invalid module registration: " .. tostring(moduleName), "error")
        return
    end
    Config.Defaults[moduleName] = DeepCopy(defaults)
    Config.Validators[moduleName] = DeepCopy(validators)
    for profileName, profile in pairs(Config.Profiles) do
        if not profile[moduleName] then
            profile[moduleName] = DeepCopy(defaults)
        else
            profile[moduleName] = MergeTables(defaults, profile[moduleName])
        end
    end
    if not Config.Settings[moduleName] then
        Config.Settings[moduleName] = DeepCopy(defaults)
    else
        Config.Settings[moduleName] = MergeTables(defaults, Config.Settings[moduleName])
    end
    SnowtUI.Debug("Registered module config: " .. moduleName)
end

-- Get a setting value
function Config:Get(moduleName, key)
    if not Config.Settings[moduleName] then
        SnowtUI.Debug("Module not found: " .. moduleName, "error")
        return nil
    end
    return Config.Settings[moduleName][key]
end

-- Set a setting value
function Config:Set(moduleName, key, value)
    if not Config.Validators[moduleName] then
        SnowtUI.Debug("No validators for module: " .. moduleName, "error")
        return false
    end
    local path = moduleName .. "." .. key
    local isValid, errorMsg = ValidateSetting(path, value, Config.Validators)
    if not isValid then
        SnowtUI.Debug("Invalid setting " .. path .. ": " .. errorMsg, "error")
        return false
    end
    if not Config.Settings[moduleName] then
        Config.Settings[moduleName] = {}
    end
    Config.Settings[moduleName][key] = value
    Config.Profiles[Config.ActiveProfile][moduleName][key] = value
    SnowtUI.FireEvent("SettingChanged", moduleName, key, value)
    self:SaveProfile(Config.ActiveProfile)
    LogEvent("SettingChanged", { Module = moduleName, Key = key, Value = value })
    return true
end

-- Reset settings to defaults
function Config:Reset(moduleName)
    if moduleName then
        if Config.Defaults[moduleName] then
            Config.Settings[moduleName] = DeepCopy(Config.Defaults[moduleName])
            Config.Profiles[Config.ActiveProfile][moduleName] = DeepCopy(Config.Defaults[moduleName])
            SnowtUI.FireEvent("SettingsReset", moduleName)
            self:SaveProfile(Config.ActiveProfile)
            LogEvent("SettingsReset", { Module = moduleName })
        else
            SnowtUI.Debug("Module not found: " .. moduleName, "error")
        end
    else
        Config.Settings = DeepCopy(Config.Defaults)
        Config.Profiles[Config.ActiveProfile] = DeepCopy(Config.Defaults)
        SnowtUI.FireEvent("SettingsReset")
        self:SaveProfile(Config.ActiveProfile)
        LogEvent("SettingsReset", { Scope = "All" })
    end
end

-- Reset all profiles to factory defaults
function Config:FactoryReset()
    Config.Profiles = { Default = DeepCopy(Config.Defaults) }
    Config.Settings = DeepCopy(Config.Defaults)
    Config.ActiveProfile = "Default"
    local success, errorMsg = pcall(function()
        for profileName, _ in pairs(Config.Profiles) do
            local key = string.format(Config.DataStoreKey, profileName)
            Config.DataStore:RemoveAsync(key)
        end
        Config.DataStore:SetAsync(string.format(Config.DataStoreKey, "Default"), HttpService:JSONEncode(Config.Defaults))
    end)
    if not success then
        SnowtUI.Debug("Failed to perform factory reset: " .. errorMsg, "error")
    end
    SnowtUI.FireEvent("FactoryReset")
    LogEvent("FactoryReset", {})
end

-- Create settings UI
function Config:CreateSettingsUI()
    if Config.SettingsUI then
        Config.SettingsUI.Frame:Destroy()
    end
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = UDim2.new(0, 500, 0, 400)
    frame.Position = UDim2.new(0.5, -250, 0.5, -200)
    frame.BackgroundTransparency = 1
    frame.Parent = SnowtUI.ScreenGui
    frame.Name = "SettingsPanel"
    frame.ZIndex = 3000
    frame.ClipsDescendants = true

    local title = SnowtUI:GetPooledObject("TextLabel")
    title.Size = UDim2.new(1, -20, 0, 30)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "SnowtUI Settings"
    title.TextSize = 18
    title.Font = Enum.Font.SourceSansBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local closeButton = SnowtUI:GetPooledObject("TextButton")
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -40, 0, 10)
    closeButton.Text = "X"
    closeButton.TextSize = 14
    closeButton.BackgroundTransparency = 0
    closeButton.AutoButtonColor = false
    closeButton.Parent = frame

    local content = SnowtUI:GetPooledObject("ScrollingFrame")
    content.Size = UDim2.new(1, -20, 1, -50)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 6
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.Parent = frame

    local listLayout = SnowtUI:GetPooledObject("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = content

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    SnowtUI.Modules.Theme:ApplyThemeStyle(frame, theme, "Button")
    SnowtUI.Modules.Theme:ApplyThemeStyle(title, theme, "Text")
    SnowtUI.Modules.Theme:ApplyThemeStyle(closeButton, theme, "Button")
    SnowtUI.Modules.Theme:ApplyThemeStyle(content, theme, "Button")
    SnowtUI.Modules.Theme:CreateStroke(frame, theme)
    SnowtUI.Modules.Theme:CreateCorner(frame, theme)
    SnowtUI.Modules.Theme:CreateCorner(closeButton, theme)

    Config.SettingsUI = { Frame = frame, Content = content, Elements = {} }

    -- Add settings sections
    local function addSection(titleText)
        local section = SnowtUI:GetPooledObject("Frame")
        section.Size = UDim2.new(1, 0, 0, 200)
        section.BackgroundTransparency = 1
        section.Parent = content
        local sectionTitle = SnowtUI:GetPooledObject("TextLabel")
        sectionTitle.Size = UDim2.new(1, 0, 0, 20)
        sectionTitle.BackgroundTransparency = 1
        sectionTitle.Text = titleText
        sectionTitle.TextSize = 16
        sectionTitle.Font = Enum.Font.SourceSansBold
        sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
        sectionTitle.Parent = section
        local sectionContent = SnowtUI:GetPooledObject("Frame")
        sectionContent.Size = UDim2.new(1, -10, 1, -30)
        sectionContent.Position = UDim2.new(0, 5, 0, 25)
        sectionContent.BackgroundTransparency = 1
        sectionContent.Parent = section
        local sectionList = SnowtUI:GetPooledObject("UIListLayout")
        sectionList.FillDirection = Enum.FillDirection.Vertical
        sectionList.Padding = UDim.new(0, 5)
        sectionList.Parent = sectionContent
        SnowtUI.Modules.Theme:ApplyThemeStyle(sectionTitle, theme, "Text")
        return sectionContent
    end

    -- Global settings section
    local globalSection = addSection("Global Settings")
    local themeDropdown = SnowtUI.Modules.Elements:CreateDropdown(globalSection, {
        Label = "Theme",
        Options = (function()
            local themes = {}
            for themeName, _ in pairs(SnowtUI.Modules.Theme.Themes) do
                table.insert(themes, themeName)
            end
            return themes
        end)(),
        Selected = Config:Get("Global", "Theme"),
        Callback = function(value)
            Config:Set("Global", "Theme", value)
        end
    })
    local scaleSlider = SnowtUI.Modules.Elements:CreateSlider(globalSection, {
        Label = "UI Scale",
        Min = 0.5,
        Max = 2,
        Value = Config:Get("Global", "Scale"),
        Step = 0.1,
        Callback = function(value)
            Config:Set("Global", "Scale", value)
        end
    })
    local gamepadToggle = SnowtUI.Modules.Elements:CreateToggle(globalSection, {
        Label = "Gamepad Support",
        Value = Config:Get("Global", "GamepadEnabled"),
        Callback = function(value)
            Config:Set("Global", "GamepadEnabled", value)
        end
    })
    local highContrastToggle = SnowtUI.Modules.Elements:CreateToggle(globalSection, {
        Label = "High Contrast Mode",
        Value = Config:Get("Global", "Accessibility.HighContrast"),
        Callback = function(value)
            Config:Set("Global", "Accessibility.HighContrast", value)
        end
    })
    local reducedMotionToggle = SnowtUI.Modules.Elements:CreateToggle(globalSection, {
        Label = "Reduced Motion",
        Value = Config:Get("Global", "Accessibility.ReducedMotion"),
        Callback = function(value)
            Config:Set("Global", "Accessibility.ReducedMotion", value)
        end
    })

    -- Notifications settings section
    local notificationsSection = addSection("Notifications Settings")
    local stackDirectionDropdown = SnowtUI.Modules.Elements:CreateDropdown(notificationsSection, {
        Label = "Toast Stack Direction",
        Options = { "TopRight", "BottomRight", "TopLeft", "BottomLeft" },
        Selected = Config:Get("Notifications", "Toast.StackDirection"),
        Callback = function(value)
            Config:Set("Notifications", "Toast.StackDirection", value)
        end
    })
    local toastDurationSlider = SnowtUI.Modules.Elements:CreateSlider(notificationsSection, {
        Label = "Toast Duration (seconds)",
        Min = 1,
        Max = 30,
        Value = Config:Get("Notifications", "Toast.Duration"),
        Step = 1,
        Callback = function(value)
            Config:Set("Notifications", "Toast.Duration", value)
        end
    })

    -- Profile management section
    local profileSection = addSection("Profile Management")
    local profileDropdown = SnowtUI.Modules.Elements:CreateDropdown(profileSection, {
        Label = "Active Profile",
        Options = (function()
            local profiles = {}
            for profileName, _ in pairs(Config.Profiles) do
                table.insert(profiles, profileName)
            end
            return profiles
        end)(),
        Selected = Config.ActiveProfile,
        Callback = function(value)
            Config:LoadProfile(value)
        end
    })
    local createProfileButton = SnowtUI.Modules.Elements:CreateButton(profileSection, {
        Text = "Create New Profile",
        Callback = function()
            SnowtUI.Prompt("Enter profile name", function(name)
                if name then
                    Config:CreateProfile(name)
                    profileDropdown:UpdateOptions((function()
                        local profiles = {}
                        for profileName, _ in pairs(Config.Profiles) do
                            table.insert(profiles, profileName)
                        end
                        return profiles
                    end)())
                    profileDropdown:SetSelected(name)
                end
            end)
        end
    })
    local renameProfileButton = SnowtUI.Modules.Elements:CreateButton(profileSection, {
        Text = "Rename Profile",
        Callback = function()
            SnowtUI.Prompt("Enter new profile name", function(newName)
                if newName then
                    Config:RenameProfile(Config.ActiveProfile, newName)
                    profileDropdown:UpdateOptions((function()
                        local profiles = {}
                        for profileName, _ in pairs(Config.Profiles) do
                            table.insert(profiles, profileName)
                        end
                        return profiles
                    end)())
                    profileDropdown:SetSelected(newName)
                end
            end)
        end
    })
    local deleteProfileButton = SnowtUI.Modules.Elements:CreateButton(profileSection, {
        Text = "Delete Profile",
        Callback = function()
            SnowtUI.Modules.Notifications:CreateConfirmation({
                Title = "Delete Profile",
                Message = "Are you sure you want to delete profile " .. Config.ActiveProfile .. "?"
            }, function(confirmed)
                if confirmed then
                    Config:DeleteProfile(Config.ActiveProfile)
                    profileDropdown:UpdateOptions((function()
                        local profiles = {}
                        for profileName, _ in pairs(Config.Profiles) do
                            table.insert(profiles, profileName)
                        end
                        return profiles
                    end)())
                    profileDropdown:SetSelected(Config.ActiveProfile)
                end
            end)
        end
    })
    local exportProfileButton = SnowtUI.Modules.Elements:CreateButton(profileSection, {
        Text = "Export Profile",
        Callback = function()
            local json = Config:ExportProfile(Config.ActiveProfile)
            if json then
                setclipboard(json)
                SnowtUI.Modules.Notifications:CreateToast({ Message = "Profile exported to clipboard" })
            end
        end
    })
    local importProfileButton = SnowtUI.Modules.Elements:CreateButton(profileSection, {
        Text = "Import Profile",
        Callback = function()
            SnowtUI.Prompt("Enter profile name for import", function(name)
                if name then
                    SnowtUI.Prompt("Paste JSON settings", function(json)
                        if json and Config:ImportProfile(name, json) then
                            profileDropdown:UpdateOptions((function()
                                local profiles = {}
                                for profileName, _ in pairs(Config.Profiles) do
                                    table.insert(profiles, profileName)
                                end
                                return profiles
                            end)())
                            profileDropdown:SetSelected(name)
                            SnowtUI.Modules.Notifications:CreateToast({ Message = "Profile imported successfully" })
                        else
                            SnowtUI.Modules.Notifications:CreateToast({ Message = "Failed to import profile" })
                        end
                    end)
                end
            end)
        end
    })

    -- Factory reset button
    local resetButton = SnowtUI.Modules.Elements:CreateButton(globalSection, {
        Text = "Factory Reset",
        Callback = function()
            SnowtUI.Modules.Notifications:CreateConfirmation({
                Title = "Factory Reset",
                Message = "Reset all settings and profiles to defaults?"
            }, function(confirmed)
                if confirmed then
                    Config:FactoryReset()
                    profileDropdown:UpdateOptions({ "Default" })
                    profileDropdown:SetSelected("Default")
                    themeDropdown:SetSelected(Config:Get("Global", "Theme"))
                    scaleSlider:SetValue(Config:Get("Global", "Scale"))
                    gamepadToggle:SetValue(Config:Get("Global", "GamepadEnabled"))
                    highContrastToggle:SetValue(Config:Get("Global", "Accessibility.HighContrast"))
                    reducedMotionToggle:SetValue(Config:Get("Global", "Accessibility.ReducedMotion"))
                    stackDirectionDropdown:SetSelected(Config:Get("Notifications", "Toast.StackDirection"))
                    toastDurationSlider:SetValue(Config:Get("Notifications", "Toast.Duration"))
                end
            end)
        end
    })

    -- Update canvas size
    content.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)

    -- Animations and interactions
    CreateTween(frame, { BackgroundTransparency = 0 }, 0.3):Play()
    closeButton.MouseButton1Click:Connect(function()
        CreateTween(frame, { BackgroundTransparency = 1 }, 0.3):Play()
        task.delay(0.3, function()
            frame:Destroy()
            Config.SettingsUI = nil
        end)
    end)
    closeButton.MouseEnter:Connect(function()
        SnowtUI.Modules.Theme:ApplyThemeStyle(closeButton, theme, "Button", { BackgroundColor3 = theme.Button.HoverColor })
    end)
    closeButton.MouseLeave:Connect(function()
        SnowtUI.Modules.Theme:ApplyThemeStyle(closeButton, theme, "Button")
    end)

    -- Gamepad navigation
    local focusable = { themeDropdown.Button, scaleSlider.Slider, gamepadToggle.Button, highContrastToggle.Button, reducedMotionToggle.Button, stackDirectionDropdown.Button, toastDurationSlider.Slider, createProfileButton.Button, renameProfileButton.Button, deleteProfileButton.Button, exportProfileButton.Button, importProfileButton.Button, resetButton.Button, closeButton }
    for _, element in ipairs(focusable) do
        SnowtUI:AddFocusableElement(frame, element)
    end

    SnowtUI.FireEvent("SettingsUIOpened")
    return frame
end

-- Initialize the Config module
function Config:Init(core)
    SnowtUI = core
    SnowtUI.Debug("Config module initialized")

    -- Register global settings
    self:RegisterModule("Global", Config.Defaults.Global, Config.Validators.Global)

    -- Register module settings
    if SnowtUI.Modules.Elements then
        self:RegisterModule("Elements", SnowtUI.Modules.Elements.Defaults, {
            Button = {
                Size = function(value)
                    return type(value) == "UDim2", "Size must be a UDim2"
                end,
                TextSize = function(value)
                    return type(value) == "number" and value >= 8 and value <= 48, "TextSize must be a number between 8 and 48"
                end
            }
        })
    end
    if SnowtUI.Modules.Tabs then
        self:RegisterModule("Tabs", SnowtUI.Modules.Tabs.Defaults, {
            TabContainer = {
                TabBarHeight = function(value)
                    return type(value) == "number" and value >= 20 and value <= 100, "TabBarHeight must be a number between 20 and 100"
                end,
                ScrollSpeed = function(value)
                    return type(value) == "number" and value >= 10 and value <= 200, "ScrollSpeed must be a number between 10 and 200"
                end
            },
            TabButton = {
                Size = function(value)
                    return type(value) == "UDim2", "Size must be a UDim2"
                end
            }
        })
    end
    if SnowtUI.Modules.Notifications then
        self:RegisterModule("Notifications", SnowtUI.Modules.Notifications.Defaults, {
            Toast = {
                StackDirection = function(value)
                    local valid = { "TopRight", "BottomRight", "TopLeft", "BottomLeft" }
                    for _, dir in ipairs(valid) do
                        if dir == value then return true end
                    end
                    return false, "Invalid StackDirection: " .. tostring(value)
                end,
                Duration = function(value)
                    return type(value) == "number" and value >= 1 and value <= 30, "Duration must be a number between 1 and 30"
                end
            }
        })
    end

    -- Load default profile
    self:LoadProfile("Default")

    -- Handle setting changes
    SnowtUI:RegisterEvent("SettingChanged", function(moduleName, key, value)
        if moduleName == "Global" then
            if key == "Theme" then
                SnowtUI.Modules.Theme:LoadTheme(value)
            elseif key == "Scale" then
                SnowtUI.FireEvent("ScaleAdjusted")
            elseif key == "Accessibility.HighContrast" then
                SnowtUI.Modules.Theme:ToggleHighContrast(value)
            elseif key == "Accessibility.ReducedMotion" then
                SnowtUI.Config.ReducedMotion = value
            elseif key == "GamepadEnabled" then
                SnowtUI.Config.GamepadEnabled = value
            end
        elseif moduleName == "Notifications" and key == "Toast.StackDirection" then
            if SnowtUI.Modules.Notifications then
                SnowtUI.Modules.Notifications.Defaults.Toast.StackDirection = value
                local updatePositions = SnowtUI.Modules.Notifications.UpdateNotificationPositions
                if updatePositions then
                    updatePositions()
                end
            end
        end
    end)

    -- Handle theme changes
    SnowtUI:RegisterEvent("ThemeChanged", function(themeName)
        self:Set("Global", "Theme", themeName)
    end)

    -- Handle profile changes
    SnowtUI:RegisterEvent("ProfileLoaded", function(profileName)
        if Config.SettingsUI then
            Config:CreateSettingsUI() -- Refresh UI
        end
    end)
end

return Config