local Theme = {}
Theme.Version = "1.0.0"
Theme.Dependencies = { "Core" }

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

Theme.Config = {
    ThemeFolder = "SnowtUI/themes",
    DefaultTheme = "Dark",
    AnimationSpeed = 0.3,
    ContrastLevel = 1,
    GradientAnimation = true,
    MobileScaling = true,
    HighDPI = true
}

Theme.Palettes = {
    Dark = { Base = Color3.fromRGB(32, 30, 38), Accent = Color3.fromRGB(60, 58, 66), Text = Color3.fromRGB(200, 200, 200) },
    Light = { Base = Color3.fromRGB(240, 240, 245), Accent = Color3.fromRGB(200, 200, 205), Text = Color3.fromRGB(50, 50, 50) },
    Neon = { Base = Color3.fromRGB(20, 20, 30), Accent = Color3.fromRGB(0, 255, 200), Text = Color3.fromRGB(220, 220, 220) },
    Pastel = { Base = Color3.fromRGB(240, 230, 230), Accent = Color3.fromRGB(180, 200, 220), Text = Color3.fromRGB(80, 80, 80) }
}

Theme.Themes = {
    Dark = {
        MainFrame = { BackgroundColor3 = Theme.Palettes.Dark.Base, Transparency = 0.1 },
        TopBar = { BackgroundColor3 = Theme.Palettes.Dark.Base, Transparency = 0.2 },
        NavPanel = { BackgroundColor3 = Theme.Palettes.Dark.Base, Transparency = 0.2 },
        ContentFrame = { BackgroundColor3 = Theme.Palettes.Dark.Base, Transparency = 0 },
        StatusBar = { BackgroundColor3 = Theme.Palettes.Dark.Base, Transparency = 0.3 },
        Button = { BackgroundColor3 = Theme.Palettes.Dark.Accent, TextColor3 = Theme.Palettes.Dark.Text, HoverColor = Color3.fromRGB(80, 78, 86) },
        Text = { TextColor3 = Theme.Palettes.Dark.Text, Font = Enum.Font.SourceSans },
        Stroke = { Color = Color3.fromRGB(64, 61, 76), Thickness = 1, Transparency = 0.5 },
        Corner = { Radius = UDim.new(0, 8) },
        Gradient = { Enabled = false, Colors = { Theme.Palettes.Dark.Base, Theme.Palettes.Dark.Accent }, Rotation = 45 }
    },
    Light = {
        MainFrame = { BackgroundColor3 = Theme.Palettes.Light.Base, Transparency = 0.1 },
        TopBar = { BackgroundColor3 = Theme.Palettes.Light.Base, Transparency = 0.2 },
        NavPanel = { BackgroundColor3 = Theme.Palettes.Light.Base, Transparency = 0.2 },
        ContentFrame = { BackgroundColor3 = Theme.Palettes.Light.Base, Transparency = 0 },
        StatusBar = { BackgroundColor3 = Theme.Palettes.Light.Base, Transparency = 0.3 },
        Button = { BackgroundColor3 = Theme.Palettes.Light.Accent, TextColor3 = Theme.Palettes.Light.Text, HoverColor = Color3.fromRGB(170, 170, 175) },
        Text = { TextColor3 = Theme.Palettes.Light.Text, Font = Enum.Font.SourceSans },
        Stroke = { Color = Color3.fromRGB(180, 180, 185), Thickness = 1, Transparency = 0.5 },
        Corner = { Radius = UDim.new(0, 8) },
        Gradient = { Enabled = true, Colors = { Theme.Palettes.Light.Base, Theme.Palettes.Light.Accent }, Rotation = 45 }
    },
    Neon = {
        MainFrame = { BackgroundColor3 = Theme.Palettes.Neon.Base, Transparency = 0.1 },
        TopBar = { BackgroundColor3 = Theme.Palettes.Neon.Base, Transparency = 0.2 },
        NavPanel = { BackgroundColor3 = Theme.Palettes.Neon.Base, Transparency = 0.2 },
        ContentFrame = { BackgroundColor3 = Theme.Palettes.Neon.Base, Transparency = 0 },
        StatusBar = { BackgroundColor3 = Theme.Palettes.Neon.Base, Transparency = 0.3 },
        Button = { BackgroundColor3 = Theme.Palettes.Neon.Accent, TextColor3 = Theme.Palettes.Neon.Text, HoverColor = Color3.fromRGB(0, 200, 150) },
        Text = { TextColor3 = Theme.Palettes.Neon.Text, Font = Enum.Font.SourceSans },
        Stroke = { Color = Theme.Palettes.Neon.Accent, Thickness = 1, Transparency = 0.5 },
        Corner = { Radius = UDim.new(0, 8) },
        Gradient = { Enabled = true, Colors = { Theme.Palettes.Neon.Base, Theme.Palettes.Neon.Accent }, Rotation = 90 }
    },
    Pastel = {
        MainFrame = { BackgroundColor3 = Theme.Palettes.Pastel.Base, Transparency = 0.1 },
        TopBar = { BackgroundColor3 = Theme.Palettes.Pastel.Base, Transparency = 0.2 },
        NavPanel = { BackgroundColor3 = Theme.Palettes.Pastel.Base, Transparency = 0.2 },
        ContentFrame = { BackgroundColor3 = Theme.Palettes.Pastel.Base, Transparency = 0 },
        StatusBar = { BackgroundColor3 = Theme.Palettes.Pastel.Base, Transparency = 0.3 },
        Button = { BackgroundColor3 = Theme.Palettes.Pastel.Accent, TextColor3 = Theme.Palettes.Pastel.Text, HoverColor = Color3.fromRGB(160, 180, 200) },
        Text = { TextColor3 = Theme.Palettes.Pastel.Text, Font = Enum.Font.SourceSans },
        Stroke = { Color = Theme.Palettes.Pastel.Accent, Thickness = 1, Transparency = 0.5 },
        Corner = { Radius = UDim.new(0, 8) },
        Gradient = { Enabled = true, Colors = { Theme.Palettes.Pastel.Base, Theme.Palettes.Pastel.Accent }, Rotation = 0 }
    }
}

Theme.StyleCache = {}
Theme.AnimationPool = {}

local function Tween(obj, props, duration)
    duration = duration or Theme.Config.AnimationSpeed
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = Theme.AnimationPool[obj] or TweenService:Create(obj, tweenInfo, props)
    Theme.AnimationPool[obj] = tween
    tween:Play()
    return tween
end

local function ApplyGradient(frame, colors, rotation)
    local gradient = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
    gradient.Color = ColorSequence.new(colors[1], colors[2])
    gradient.Rotation = rotation or 45
    gradient.Parent = frame
    if Theme.Config.GradientAnimation then
        local tween = Tween(gradient, { Offset = Vector2.new(0.5, 0.5) }, 2)
        tween.Completed:Connect(function()
            Tween(gradient, { Offset = Vector2.new(0, 0) }, 2)
        end)
    end
end

local function RemoveGradient(frame)
    local gradient = frame:FindFirstChildOfClass("UIGradient")
    if gradient then
        gradient:Destroy()
    end
end

local function GeneratePalette(baseColor)
    local h, s, v = Color3.toHSV(baseColor)
    return {
        Base = baseColor,
        Accent = Color3.fromHSV(h, s * 0.8, v * 1.2),
        Text = v > 0.5 and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(200, 200, 200)
    }
end

local function AdjustContrast(color, level)
    local r, g, b = color.R * 255, color.G * 255, color.B * 255
    local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    if luminance < 0.5 then
        return Color3.fromRGB(math.min(r * level, 255), math.min(g * level, 255), math.min(b * level, 255))
    else
        return Color3.fromRGB(math.max(r / level, 0), math.max(g / level, 0), math.max(b / level, 0))
    end
end

local function ApplyStyle(element, style)
    if Theme.StyleCache[element] then return end
    for prop, value in pairs(style) do
        if prop == "Transparency" then
            element.BackgroundTransparency = value
        elseif prop == "TextColor3" then
            element.TextColor3 = value
        elseif prop == "Font" then
            element.Font = value
        else
            element[prop] = value
        end
    end
    Theme.StyleCache[element] = true
end

local function ApplyTransition(window, transition)
    if transition == "Fade" then
        Tween(window.MainFrame, { BackgroundTransparency = 1 })
        task.wait(Theme.Config.AnimationSpeed)
        Tween(window.MainFrame, { BackgroundTransparency = 0.1 })
    elseif transition == "Slide" then
        local origPos = window.MainFrame.Position
        window.MainFrame.Position = UDim2.new(0.5, -300, 1, 0)
        Tween(window.MainFrame, { Position = origPos })
    elseif transition == "Scale" then
        local origSize = window.MainFrame.Size
        window.MainFrame.Size = UDim2.new(0, 0, 0, 0)
        Tween(window.MainFrame, { Size = origSize })
    end
end

local function ApplyAdaptiveStyle(element, style)
    if Theme.Config.MobileScaling and not UserInputService.KeyboardEnabled then
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            element.TextSize = element.TextSize * 1.2
        end
        if element:IsA("Frame") or element:IsA("TextButton") then
            element.Size = UDim2.new(element.Size.X.Scale, element.Size.X.Offset * 1.1, element.Size.Y.Scale, element.Size.Y.Offset * 1.1)
        end
    end
    if Theme.Config.HighDPI then
        local dpiScale = GuiService:GetGuiInset().Y / 36
        if element:IsA("Frame") or element:IsA("TextButton") then
            element.Size = UDim2.new(element.Size.X.Scale, element.Size.X.Offset * dpiScale, element.Size.Y.Scale, element.Size.Y.Offset * dpiScale)
        end
    end
end

function Theme:ApplyTheme(window, themeName, transition)
    local theme = self.Themes[themeName] or self.Themes[self.Config.DefaultTheme]
    SnowtUI.Debug("Applying theme: " .. themeName)
    Theme.StyleCache = {}

    local mainFrame = window.MainFrame
    local topBar = mainFrame:FindFirstChild("TopBar", true)
    local navPanel = window.NavPanel
    local contentFrame = window.ContentFrame
    local statusBar = mainFrame:FindFirstChild("StatusBar", true)

    ApplyStyle(mainFrame, theme.MainFrame)
    ApplyStyle(topBar, theme.TopBar)
    ApplyStyle(navPanel, theme.NavPanel)
    ApplyStyle(contentFrame, theme.ContentFrame)
    ApplyStyle(statusBar, theme.StatusBar)

    ApplyAdaptiveStyle(mainFrame, theme.MainFrame)
    ApplyAdaptiveStyle(topBar, theme.TopBar)
    ApplyAdaptiveStyle(navPanel, theme.NavPanel)
    ApplyAdaptiveStyle(contentFrame, theme.ContentFrame)
    ApplyAdaptiveStyle(statusBar, theme.StatusBar)

    if theme.Gradient.Enabled then
        ApplyGradient(mainFrame, theme.Gradient.Colors, theme.Gradient.Rotation)
        ApplyGradient(topBar, theme.Gradient.Colors, theme.Gradient.Rotation)
    else
        RemoveGradient(mainFrame)
        RemoveGradient(topBar)
    end

    for _, button in ipairs(mainFrame:GetDescendants()) do
        if button:IsA("TextButton") then
            ApplyStyle(button, theme.Button)
            ApplyAdaptiveStyle(button, theme.Button)
            button.MouseEnter:Connect(function()
                Tween(button, { BackgroundColor3 = theme.Button.HoverColor })
            end)
            button.MouseLeave:Connect(function()
                Tween(button, { BackgroundColor3 = theme.Button.BackgroundColor3 })
            end)
        end
    end

    for _, label in ipairs(mainFrame:GetDescendants()) do
        if label:IsA("TextLabel") then
            ApplyStyle(label, theme.Text)
            ApplyAdaptiveStyle(label, theme.Text)
        end
    end

    for _, stroke in ipairs(mainFrame:GetDescendants()) do
        if stroke:IsA("UIStroke") then
            ApplyStyle(stroke, theme.Stroke)
        end
    end

    for _, corner in ipairs(mainFrame:GetDescendants()) do
        if corner:IsA("UICorner") then
            ApplyStyle(corner, theme.Corner)
        end
    end

    if transition then
        ApplyTransition(window, transition)
    end

    self:SaveTheme(themeName)
    SnowtUI.FireEvent("ThemeChanged", themeName)
end

function Theme:SaveTheme(themeName)
    local success, err = pcall(function()
        if not isfolder(self.Config.ThemeFolder) then
            makefolder(self.Config.ThemeFolder)
        end
        local config = { CurrentTheme = themeName, ContrastLevel = self.Config.ContrastLevel }
        writefile(self.Config.ThemeFolder .. "/theme.json", HttpService:JSONEncode(config))
    end)
    if not success then
        SnowtUI.Debug("Failed to save theme: " .. err, "error")
    end
end

function Theme:LoadTheme()
    local success, config = pcall(function()
        if isfile(self.Config.ThemeFolder .. "/theme.json") then
            return HttpService:JSONDecode(readfile(self.Config.ThemeFolder .. "/theme.json"))
        end
        return nil
    end)
    if success and config and config.CurrentTheme then
        self.Config.ContrastLevel = config.ContrastLevel or 1
        return config.CurrentTheme
    end
    return self.Config.DefaultTheme
end

function Theme:AddCustomTheme(themeName, themeData)
    if not themeData.MainFrame or not themeData.Button then
        SnowtUI.Debug("Invalid theme data for: " .. themeName, "error")
        return
    end
    self.Themes[themeName] = themeData
    SnowtUI.Debug("Added custom theme: " .. themeName)
end

function Theme:ExportTheme(themeName)
    local theme = self.Themes[themeName]
    if not theme then return nil end
    return HttpService:JSONEncode(theme)
end

function Theme:ImportTheme(themeName, jsonData)
    local success, themeData = pcall(function()
        return HttpService:JSONDecode(jsonData)
    end)
    if success then
        self:AddCustomTheme(themeName, themeData)
        return true
    end
    SnowtUI.Debug("Failed to import theme: " .. themeName, "error")
    return false
end

function Theme:SetContrastLevel(level)
    self.Config.ContrastLevel = math.clamp(level, 0.5, 2)
    SnowtUI.Debug("Contrast level set to: " .. level)
    SnowtUI.FireEvent("StyleUpdated", "Contrast")
end

function Theme:GenerateThemeFromColor(baseColor)
    local palette = GeneratePalette(baseColor)
    local theme = {
        MainFrame = { BackgroundColor3 = palette.Base, Transparency = 0.1 },
        TopBar = { BackgroundColor3 = palette.Base, Transparency = 0.2 },
        NavPanel = { BackgroundColor3 = palette.Base, Transparency = 0.2 },
        ContentFrame = { BackgroundColor3 = palette.Base, Transparency = 0 },
        StatusBar = { BackgroundColor3 = palette.Base, Transparency = 0.3 },
        Button = { BackgroundColor3 = palette.Accent, TextColor3 = palette.Text, HoverColor = AdjustContrast(palette.Accent, 1.2) },
        Text = { TextColor3 = palette.Text, Font = Enum.Font.SourceSans },
        Stroke = { Color = palette.Accent, Thickness = 1, Transparency = 0.5 },
        Corner = { Radius = UDim.new(0, 8) },
        Gradient = { Enabled = true, Colors = { palette.Base, palette.Accent }, Rotation = 45 }
    }
    return theme
end

function Theme:Init(core)
    SnowtUI = core
    local themeName = self:LoadTheme()
    SnowtUI.Debug("Theme module initialized with theme: " .. themeName)
    SnowtUI:RegisterEvent("WindowOpened", function(window)
        self:ApplyTheme(window, themeName, "Fade")
    end)
    SnowtUI:RegisterEvent("ScaleAdjusted", function()
        for _, window in ipairs(SnowtUI.Windows) do
            self:ApplyTheme(window, themeName)
        end
    end)
end

return Theme