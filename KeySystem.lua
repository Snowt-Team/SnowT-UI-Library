-- KeySystem.lua: Key-based authentication system for SnowtUI
-- Provides a UI for key input and validation with local or remote checks
-- Dependencies: Core.lua, Theme.lua, Config.lua, Icons.lua, Animations.lua, Utilities.lua
local KeySystem = {}
KeySystem.Version = "1.0.0"
KeySystem.Dependencies = { "Core", "Theme", "Config", "Icons", "Animations", "Utilities" }

-- Services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

-- Internal state
local isAuthenticated = false
local keyInputUI = nil
local validationCallbacks = {}

-- Initialize module with SnowtUI context
function KeySystem.init(params)
    local SnowtUI = params.SnowtUIInstance
    KeySystem.SnowtUI = SnowtUI
    KeySystem.Theme = SnowtUI:GetModule("Theme")
    KeySystem.Config = SnowtUI:GetModule("Config")
    KeySystem.Icons = SnowtUI:GetModule("Icons")
    KeySystem.Animations = SnowtUI:GetModule("Animations")
    KeySystem.Utilities = SnowtUI:GetModule("Utilities")

    -- Configuration defaults
    KeySystem.settings = {
        KeyLength = KeySystem.Config:get("KeyLength", 16),
        ValidationEndpoint = KeySystem.Config:get("ValidationEndpoint", nil), -- nil for local validation
        MaxAttempts = KeySystem.Config:get("MaxAttempts", 3),
        LockoutDuration = KeySystem.Config:get("LockoutDuration", 300), -- Seconds
    }
end

-- Mock local key database (for demonstration)
local mockKeyDatabase = {
    ["ABCD-1234-EFGH-5678"] = true,
    ["WXYZ-9876-MNOP-4321"] = true,
}

-- Validate key locally
function KeySystem.validate_local(key)
    if not key or type(key) ~= "string" or #key ~= KeySystem.settings.KeyLength then
        return false, "Invalid key format"
    end
    return mockKeyDatabase[key] or false, mockKeyDatabase[key] and "Success" or "Invalid key"
end

-- Validate key remotely (mock implementation)
function KeySystem.validate_remote(key)
    if not KeySystem.settings.ValidationEndpoint then
        return false, "No validation endpoint configured"
    end

    local success, response = pcall(function()
        -- Mock HTTP request
        local mockResponse = {
            success = mockKeyDatabase[key] or false,
            message = mockKeyDatabase[key] and "Success" or "Invalid key"
        }
        return mockResponse
    end)

    if success then
        return response.success, response.message
    else
        return false, "Network error: " .. tostring(response)
    end
end

-- Validate key (chooses local or remote based on config)
function KeySystem.validate_key(key)
    if KeySystem.settings.ValidationEndpoint then
        return KeySystem.validate_remote(key)
    else
        return KeySystem.validate_local(key)
    end
end

-- Create key input UI
function KeySystem.create_ui()
    if keyInputUI then
        return keyInputUI
    end

    local screenGui = KeySystem.Utilities.create_ui("ScreenGui", {
        Name = "SnowtUI_KeySystem",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, Players.LocalPlayer:WaitForChild("PlayerGui"))

    local frame = KeySystem.Utilities.create_ui("Frame", {
        Name = "KeyInputFrame",
        Size = UDim2.new(0, 300, 0, 200),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = KeySystem.Theme:get_color("BackgroundColor"),
        BorderSizePixel = 0,
        Animation = { properties = { BackgroundTransparency = 0 }, duration = 0.5 },
    }, screenGui)

    local title = KeySystem.Utilities.create_ui("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 30),
        Position = UDim2.new(0, 0, 0, 10),
        BackgroundTransparency = 1,
        Text = "Enter Access Key",
        TextColor3 = KeySystem.Theme:get_color("TextColor"),
        TextSize = 18,
        Font = Enum.Font.SourceSansBold,
    }, frame)

    local icon = KeySystem.Utilities.create_ui("ImageLabel", {
        Name = "LockIcon",
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Icon = "lock",
    }, frame)

    local textBox = KeySystem.Utilities.create_ui("TextBox", {
        Name = "KeyInput",
        Size = UDim2.new(0.8, 0, 0, 30),
        Position = UDim2.new(0.1, 0, 0, 50),
        BackgroundColor3 = KeySystem.Theme:get_color("InputBackgroundColor"),
        TextColor3 = KeySystem.Theme:get_color("TextColor"),
        PlaceholderText = "XXXX-XXXX-XXXX-XXXX",
        TextSize = 16,
        Font = Enum.Font.SourceSans,
        ClearTextOnFocus = false,
    }, frame)

    local statusLabel = KeySystem.Utilities.create_ui("TextLabel", {
        Name = "Status",
        Size = UDim2.new(0.8, 0, 0, 20),
        Position = UDim2.new(0.1, 0, 0, 90),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = KeySystem.Theme:get_color("ErrorColor"),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
    }, frame)

    local submitButton = KeySystem.Utilities.create_ui("TextButton", {
        Name = "Submit",
        Size = UDim2.new(0.4, 0, 0, 30),
        Position = UDim2.new(0.3, 0, 0, 120),
        BackgroundColor3 = KeySystem.Theme:get_color("ButtonColor"),
        Text = "Submit",
        TextColor3 = KeySystem.Theme:get_color("TextColor"),
        TextSize = 16,
        Font = Enum.Font.SourceSansBold,
    }, frame)

    keyInputUI = {
        ScreenGui = screenGui,
        Frame = frame,
        TextBox = textBox,
        StatusLabel = statusLabel,
        SubmitButton = submitButton,
    }

    -- Connect submit logic
    local attempts = 0
    local isLocked = false

    local function onSubmit()
        if isLocked then
            keyInputUI.StatusLabel.Text = "Locked out. Try again later."
            return
        end

        local key = KeySystem.Utilities.trim(keyInputUI.TextBox.Text)
        local success, message = KeySystem.validate_key(key)

        if success then
            isAuthenticated = true
            keyInputUI.StatusLabel.TextColor3 = KeySystem.Theme:get_color("SuccessColor")
            keyInputUI.StatusLabel.Text = "Access Granted!"
            KeySystem.Icons:apply_to(keyInputUI.StatusLabel, "check", "Material", { theme = "Success" })
            KeySystem.Animations.tween(keyInputUI.Frame, { BackgroundTransparency = 1 }, 0.5, nil, nil, function()
                keyInputUI.ScreenGui:Destroy()
                keyInputUI = nil
                for _, callback in ipairs(validationCallbacks) do
                    callback(true)
                end
            end)
        else
            attempts = attempts + 1
            keyInputUI.StatusLabel.Text = message
            KeySystem.Animations.tween(keyInputUI.Frame, { Position = UDim2.new(0.5, -5, 0.5, 0) }, 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, function()
                KeySystem.Animations.tween(keyInputUI.Frame, { Position = UDim2.new(0.5, 5, 0.5, 0) }, 0.05, nil, nil, function()
                    KeySystem.Animations.tween(keyInputUI.Frame, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.05)
                end)
            end)

            if attempts >= KeySystem.settings.MaxAttempts then
                isLocked = true
                keyInputUI.StatusLabel.Text = "Too many attempts. Locked out."
                wait(KeySystem.settings.LockoutDuration)
                isLocked = false
                attempts = 0
                keyInputUI.StatusLabel.Text = ""
            end
        end
    end

    submitButton.MouseButton1Click:Connect(onSubmit)
    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            onSubmit()
        end
    end)

    return keyInputUI
end

-- Show key input UI
function KeySystem.show()
    if isAuthenticated then
        for _, callback in ipairs(validationCallbacks) do
            callback(true)
        end
        return
    end
    KeySystem.create_ui()
end

-- Check authentication status
function KeySystem.is_authenticated()
    return isAuthenticated
end

-- Register callback for validation result
function KeySystem.on_validated(callback)
    if type(callback) == "function" then
        table.insert(validationCallbacks, callback)
    end
end

-- Handle theme updates
function KeySystem.on_theme_update()
    if keyInputUI then
        KeySystem.Utilities.apply_properties(keyInputUI.Frame, {
            BackgroundColor3 = KeySystem.Theme:get_color("BackgroundColor"),
        })
        KeySystem.Utilities.apply_properties(keyInputUI.TextBox, {
            BackgroundColor3 = KeySystem.Theme:get_color("InputBackgroundColor"),
            TextColor3 = KeySystem.Theme:get_color("TextColor"),
        })
        KeySystem.Utilities.apply_properties(keyInputUI.SubmitButton, {
            BackgroundColor3 = KeySystem.Theme:get_color("ButtonColor"),
            TextColor3 = KeySystem.Theme:get_color("TextColor"),
        })
        KeySystem.Utilities.apply_properties(keyInputUI.StatusLabel, {
            TextColor3 = KeySystem.Theme:get_color("ErrorColor"),
        })
    end
end

-- Connect to SnowtUI lifecycle
function KeySystem.connect_lifecycle()
    if KeySystem.SnowtUI then
        KeySystem.SnowtUI:OnModuleLoaded("Theme", function(theme)
            KeySystem.Theme = theme
            theme:Subscribe("ThemeUpdated", KeySystem.on_theme_update)
        end)
        KeySystem.SnowtUI:OnModuleLoaded("Config", function(config)
            KeySystem.Config = config
            KeySystem.settings.KeyLength = config:get("KeyLength", 16)
            KeySystem.settings.ValidationEndpoint = config:get("ValidationEndpoint", nil)
            KeySystem.settings.MaxAttempts = config:get("MaxAttempts", 3)
            KeySystem.settings.LockoutDuration = config:get("LockoutDuration", 300)
        end)
        KeySystem.SnowtUI:OnModuleLoaded("Icons", function(icons)
            KeySystem.Icons = icons
        end)
        KeySystem.SnowtUI:OnModuleLoaded("Animations", function(animations)
            KeySystem.Animations = animations
        end)
        KeySystem.SnowtUI:OnModuleLoaded("Utilities", function(utilities)
            KeySystem.Utilities = utilities
        end)
    end
end

-- Initialize lifecycle connections
KeySystem.connect_lifecycle()

return KeySystem