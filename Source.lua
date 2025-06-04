-- Source.lua: Main entry point for SnowtUI library
-- Unifies all modules and provides public API for UI creation and management
-- Dependencies: Core.lua, Config.lua, Theme.lua, LoadingScreen.lua, KeySystem.lua, Utilities.lua, Animations.lua, Icons.lua, Notifications.lua, Tabs.lua, Elements.lua
local SnowtUI = {}
SnowtUI.Version = "1.0.0"
SnowtUI.Modules = {}

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Module definitions (in dependency order)
local moduleDefinitions = {
    {
        Name = "Core",
        Dependencies = {},
        Load = function()
            local Core = {
                SnowtUIInstance = SnowtUI,
                Modules = {},
                ModuleLoaded = Instance.new("BindableEvent"),
                GetModule = function(self, name)
                    return self.Modules[name]
                end,
                OnModuleLoaded = function(self, name, callback)
                    if self.Modules[name] then
                        callback(self.Modules[name])
                    else
                        local connection
                        connection = self.ModuleLoaded.Event:Connect(function(loadedName, module)
                            if loadedName == name then
                                callback(module)
                                connection:Disconnect()
                            end
                        end)
                    end
                end,
            }
            return Core
        end,
    },
    {
        Name = "Config",
        Dependencies = { "Core" },
        Load = function()
            local Config = {
                settings = {},
                ConfigUpdated = Instance.new("BindableEvent"),
                init = function(self, params)
                    self.SnowtUI = params.SnowtUIInstance
                end,
                get = function(self, key, default)
                    return self.settings[key] or default
                end,
                set = function(self, key, value)
                    self.settings[key] = value
                    self.ConfigUpdated:Fire(key, value)
                end,
                Subscribe = function(self, key, callback)
                    self.ConfigUpdated.Event:Connect(function(updatedKey, value)
                        if updatedKey == key then
                            callback(value)
                        end
                    end)
                end,
            }
            Config:init({ SnowtUIInstance = SnowtUI })
            return Config
        end,
    },
    {
        Name = "Theme",
        Dependencies = { "Core", "Config" },
        Load = function()
            local Theme = {
                themes = {},
                currentTheme = "Default",
                ThemeUpdated = Instance.new("BindableEvent"),
                Init = function(self, params)
                    self.SnowtUI = params.SnowtUIInstance
                    self.themes["Default"] = {
                        BackgroundColor = Color3.fromRGB(30, 30, 30),
                        TextColor = Color3.fromRGB(255, 255, 255),
                        ButtonColor = Color3.fromRGB(50, 50, 50),
                        InputBackgroundColor = Color3.fromRGB(40, 40, 40),
                        ErrorColor = Color3.fromRGB(255, 100, 100),
                        SuccessColor = Color3.fromRGB(100, 255, 100),
                        IconColor = Color3.fromRGB(200, 200, 200),
                        AnimationDuration = 0.3,
                        AnimationEasingStyle = Enum.EasingStyle.Quad,
                        AnimationEasingDirection = Enum.EasingDirection.InOut,
                    }
                end,
                get = function(self, key, default)
                    return self.themes[self.currentTheme][key] or default
                end,
                get_color = function(self, key, default)
                    return self:get(key, default)
                end,
                set_theme = function(self, themeName)
                    if self.themes[themeName] then
                        self.currentTheme = themeName
                        self.ThemeUpdated:Fire()
                    end
                end,
                Subscribe = function(self, eventName, callback)
                    if eventName == "ThemeUpdated" then
                        self.ThemeUpdated.Event:Connect(callback)
                    end
                end,
            }
            Theme:Init({ SnowtUIInstance = SnowtUI })
            return Theme
        end,
    },
    {
        Name = "Utilities",
        Dependencies = { "Core", "Config", "Theme" },
        Load = function()
            local Utilities = require(script.Parent.Utilities)
            Utilities.init({ SnowtUIInstance = SnowtUI })
            return Utilities
        end,
    },
    {
        Name = "Icons",
        Dependencies = { "Core", "Config", "Theme", "Utilities" },
        Load = function()
            local Icons = require(script.Parent.Icons)
            Icons.init({ SnowtUIInstance = SnowtUI })
            return Icons
        end,
    },
    {
        Name = "Animations",
        Dependencies = { "Core", "Config", "Theme", "Utilities", "Icons" },
        Load = function()
            local Animations = require(script.Parent.Animations)
            Animations.init({ SnowtUIInstance = SnowtUI })
            return Animations
        end,
    },
    {
        Name = "LoadingScreen",
        Dependencies = { "Core", "Config", "Theme", "Utilities", "Icons", "Animations" },
        Load = function()
            local LoadingScreen = {
                screenGui = nil,
                spinner = nil,
                init = function(self, params)
                    self.SnowtUI = params.SnowtUIInstance
                end,
                Show = function(self)
                    local Utilities = self.SnowtUI:GetModule("Utilities")
                    local Icons = self.SnowtUI:GetModule("Icons")
                    local Animations = self.SnowtUI:GetModule("Animations")

                    self.screenGui = Utilities.create_ui("ScreenGui", {
                        Name = "SnowtUI_LoadingScreen",
                        ResetOnSpawn = false,
                    }, Players.LocalPlayer:WaitForChild("PlayerGui"))

                    self.spinner = Utilities.create_ui("ImageLabel", {
                        Name = "Spinner",
                        Size = UDim2.new(0, 50, 0, 50),
                        Position = UDim2.new(0.5, 0, 0.5, 0),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Icon = "hourglass_top",
                    }, self.screenGui)

                    Animations.apply_loading_spinner(self.spinner, 180)
                end,
                Hide = function(self)
                    if self.screenGui then
                        self.screenGui:Destroy()
                        self.screenGui = nil
                        self.spinner = nil
                    end
                end,
                SetSpinnerIcon = function(self, iconUrl)
                    if self.spinner then
                        self.spinner.Image = iconUrl
                    end
                end,
                OnShow = function(self, callback)
                    callback(self.spinner)
                end,
            }
            LoadingScreen:init({ SnowtUIInstance = SnowtUI })
            return LoadingScreen
        end,
    },
    {
        Name = "KeySystem",
        Dependencies = { "Core", "Config", "Theme", "Utilities", "Icons", "Animations" },
        Load = function()
            local KeySystem = require(script.Parent.KeySystem)
            KeySystem.init({ SnowtUIInstance = SnowtUI })
            return KeySystem
        end,
    },
    {
        Name = "Notifications",
        Dependencies = { "Core", "Config", "Theme", "Utilities", "Icons", "Animations" },
        Load = function()
            local Notifications = {
                notifications = {},
                init = function(self, params)
                    self.SnowtUI = params.SnowtUIInstance
                end,
                create = function(self, options)
                    local Utilities = self.SnowtUI:GetModule("Utilities")
                    local Animations = self.SnowtUI:GetModule("Animations")
                    local Theme = self.SnowtUI:GetModule("Theme")

                    local notification = Utilities.create_ui("Frame", {
                        Size = UDim2.new(0, 200, 0, 50),
                        Position = UDim2.new(1, -210, 0, 10 + (#self.notifications * 60)),
                        BackgroundColor3 = Theme:get_color("BackgroundColor"),
                        Animation = { properties = { Position = UDim2.new(1, 0, 0, 10 + (#self.notifications * 60)) }, duration = 0.3 },
                    }, Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("SnowtUI_Notifications") or Utilities.create_ui("ScreenGui", { Name = "SnowtUI_Notifications" }, Players.LocalPlayer.PlayerGui))

                    Utilities.create_ui("TextLabel", {
                        Size = UDim2.new(1, 0, 1, 0),
                        Text = options.text or "Notification",
                        TextColor3 = Theme:get_color("TextColor"),
                        BackgroundTransparency = 1,
                    }, notification)

                    table.insert(self.notifications, notification)
                    delay(options.duration or 3, function()
                        Animations.tween(notification, { Position = UDim2.new(1, -210, 0, notification.Position.Y.Offset) }, 0.3, nil, nil, function()
                            notification:Destroy()
                            table.remove(self.notifications, table.find(self.notifications, notification))
                            for i, notif in ipairs(self.notifications) do
                                Animations.tween(notif, { Position = UDim2.new(1, 0, 0, 10 + ((i-1) * 60)) }, 0.3)
                            end
                        end)
                    end)
                end,
            }
            Notifications:init({ SnowtUIInstance = SnowtUI })
            return Notifications
        end,
    },
    {
        Name = "Tabs",
        Dependencies = { "Core", "Config", "Theme", "Utilities", "Icons", "Animations", "Notifications" },
        Load = function()
            local Tabs = {
                tabs = {},
                init = function(self, params)
                    self.SnowtUI = params.SnowtUIInstance
                end,
                create_tab = function(self, options)
                    local Utilities = self.SnowtUI:GetModule("Utilities")
                    local Theme = self.SnowtUI:GetModule("Theme")
                    local Animations = self.SnowtUI:GetModule("Animations")

                    local tab = Utilities.create_ui("Frame", {
                        Size = UDim2.new(0, 100, 0, 30),
                        BackgroundColor3 = Theme:get_color("ButtonColor"),
                    }, options.parent)

                    Utilities.create_ui("TextLabel", {
                        Size = UDim2.new(1, 0, 1, 0),
                        Text = options.name or "Tab",
                        TextColor3 = Theme:get_color("TextColor"),
                        BackgroundTransparency = 1,
                    }, tab)

                    tab.MouseButton1Click:Connect(function()
                        for _, t in ipairs(self.tabs) do
                            Animations.tween(t, { BackgroundColor3 = Theme:get_color("ButtonColor") }, 0.2)
                        end
                        Animations.tween(tab, { BackgroundColor3 = Theme:get_color("SuccessColor") }, 0.2)
                        if options.callback then
                            options.callback()
                        end
                    end)

                    table.insert(self.tabs, tab)
                    return tab
                end,
            }
            Tabs:init({ SnowtUIInstance = SnowtUI })
            return Tabs
        end,
    },
    {
        Name = "Elements",
        Dependencies = { "Core", "Config", "Theme", "Utilities", "Icons", "Animations", "Notifications", "Tabs" },
        Load = function()
            local Elements = {
                elements = {},
                init = function(self, params)
                    self.SnowtUI = params.SnowtUIInstance
                end,
                create_button = function(self, options)
                    local Utilities = self.SnowtUI:GetModule("Utilities")
                    local Theme = self.SnowtUI:GetModule("Theme")
                    local Animations = self.SnowtUI:GetModule("Animations")
                    local Notifications = self.SnowtUI:GetModule("Notifications")

                    local button = Utilities.create_ui("TextButton", {
                        Size = UDim2.new(0, 100, 0, 30),
                        Position = options.position or UDim2.new(0, 0, 0, 0),
                        BackgroundColor3 = Theme:get_color("ButtonColor"),
                        Text = options.text or "Button",
                        TextColor3 = Theme:get_color("TextColor"),
                        Icon = options.icon,
                    }, options.parent)

                    button.MouseButton1Click:Connect(function()
                        Animations.tween(button, { BackgroundColor3 = Theme:get_color("SuccessColor") }, 0.1, nil, nil, function()
                            Animations.tween(button, { BackgroundColor3 = Theme:get_color("ButtonColor") }, 0.1)
                        end)
                        Notifications.create({ text = options.text .. " clicked!" })
                        if options.callback then
                            options.callback()
                        end
                    end)

                    table.insert(self.elements, button)
                    return button
                end,
            }
            Elements:init({ SnowtUIInstance = SnowtUI })
            return Elements
        end,
    },
}

-- Load module with error handling
local function loadModule(moduleDef)
    local success, result = pcall(moduleDef.Load)
    if success then
        SnowtUI.Modules[moduleDef.Name] = result
        SnowtUI:GetModule("Core").Modules[moduleDef.Name] = result
        SnowtUI:GetModule("Core").ModuleLoaded:Fire(moduleDef.Name, result)
        return true
    else
        warn(string.format("SnowtUI: Failed to load module %s: %s", moduleDef.Name, tostring(result)))
        return false
    end
end

-- Check if dependencies are loaded
local function areDependenciesLoaded(moduleDef)
    for _, dep in ipairs(moduleDef.Dependencies) do
        if not SnowtUI.Modules[dep] then
            return false
        end
    end
    return true
end

-- Initialize library
function SnowtUI:Init()
    if self.initialized then
        return
    end

    -- Show loading screen
    local LoadingScreen = loadModule(moduleDefinitions[7]) and SnowtUI.Modules.LoadingScreen
    if LoadingScreen then
        LoadingScreen:Show()
    end

    -- Load modules in dependency order
    local loaded = {}
    local attempts = 0
    local maxAttempts = #moduleDefinitions * 2

    while #loaded < #moduleDefinitions and attempts < maxAttempts do
        for _, moduleDef in ipairs(moduleDefinitions) do
            if not loaded[moduleDef.Name] and areDependenciesLoaded(moduleDef) then
                if loadModule(moduleDef) then
                    loaded[moduleDef.Name] = true
                end
            end
        end
        attempts = attempts + 1
    end

    if #loaded < #moduleDefinitions then
        warn("SnowtUI: Some modules failed to load due to unresolved dependencies or errors")
    end

    -- Initialize key system
    local KeySystem = SnowtUI.Modules.KeySystem
    if KeySystem then
        KeySystem.on_validated(function(success)
            if success then
                self.initialized = true
                if LoadingScreen then
                    LoadingScreen:Hide()
                end
                self:FireEvent("Initialized")
            end
        end)
        KeySystem.show()
    else
        warn("SnowtUI: KeySystem module failed to load, bypassing authentication")
        self.initialized = true
        if LoadingScreen then
            LoadingScreen:Hide()
        end
        self:FireEvent("Initialized")
    end
end

-- Get module by name
function SnowtUI:GetModule(name)
    return self.Modules[name]
end

-- Create a new UI instance
function SnowtUI:CreateUI(config)
    if not self.initialized then
        error("SnowtUI: Library not initialized. Call SnowtUI:Init() first.")
    end

    config = config or {}
    local Elements = self:GetModule("Elements")
    local Tabs = self:GetModule("Tabs")
    local Utilities = self:GetModule("Utilities")
    local Theme = self:GetModule("Theme")

    local screenGui = Utilities.create_ui("ScreenGui", {
        Name = "SnowtUI_" .. HttpService:GenerateGUID(false),
        ResetOnSpawn = false,
    }, Players.LocalPlayer:WaitForChild("PlayerGui"))

    local mainFrame = Utilities.create_ui("Frame", {
        Size = UDim2.new(0, 400, 0, 300),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Theme:get_color("BackgroundColor"),
    }, screenGui)

    local tabContainer = Utilities.create_ui("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, mainFrame)

    local contentContainer = Utilities.create_ui("Frame", {
        Size = UDim2.new(1, 0, 1, -30),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundTransparency = 1,
    }, mainFrame)

    local uiInstance = {
        ScreenGui = screenGui,
        MainFrame = mainFrame,
        TabContainer = tabContainer,
        ContentContainer = contentContainer,
        Tabs = {},
        AddTab = function(self, name, callback)
            local tab = Tabs.create_tab({
                name = name,
                parent = tabContainer,
                callback = function()
                    for _, content in ipairs(self.Tabs) do
                        content.Frame.Visible = false
                    end
                    self.Tabs[name].Frame.Visible = true
                    if callback then
                        callback()
                    end
                end,
            })
            local contentFrame = Utilities.create_ui("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Visible = false,
            }, contentContainer)
            self.Tabs[name] = { Tab = tab, Frame = contentFrame }
            return contentFrame
        end,
        AddButton = function(self, tabName, options)
            if self.Tabs[tabName] then
                return Elements.create_button({
                    text = options.text,
                    icon = options.icon,
                    callback = options.callback,
                    parent = self.Tabs[tabName].Frame,
                    position = options.position,
                })
            end
        end,
        Destroy = function(self)
            if self.ScreenGui then
                self.ScreenGui:Destroy()
            end
        end,
    }

    return uiInstance
end

-- Register event listener
function SnowtUI:OnEvent(eventName, callback)
    local Events = self:GetModule("Events")
    if Events then
        Events:subscribe(eventName, callback)
    else
        warn("SnowtUI: Events module not available, using fallback event system")
        self.eventListeners = self.eventListeners or {}
        self.eventListeners[eventName] = self.eventListeners[eventName] or {}
        table.insert(self.eventListeners[eventName], callback)
    end
end

-- Fire event
function SnowtUI:FireEvent(eventName, ...)
    local Events = self:GetModule("Events")
    if Events then
        Events:publish(eventName, ...)
    else
        warn("SnowtUI: Events module not available, using fallback event system")
        if self.eventListeners and self.eventListeners[eventName] then
            for _, callback in ipairs(self.eventListeners[eventName]) do
                callback(...)
            end
        end
    end
end

-- Shutdown library
function SnowtUI:Shutdown()
    if not self.initialized then
        return
    end

    local LoadingScreen = self:GetModule("LoadingScreen")
    if LoadingScreen then
        LoadingScreen:Hide()
    end

    for _, module in pairs(self.Modules) do
        if module.Destroy then
            pcall(module.Destroy)
        end
    end

    self.initialized = false
    self:FireEvent("Shutdown")
end

-- Get library version
function SnowtUI:GetVersion()
    return self.Version
end

return SnowtUI