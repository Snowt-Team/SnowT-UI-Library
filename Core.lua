local SnowtUI = {}
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

SnowtUI.Config = {
    Version = "1.0.0",
    ConfigFolder = "SnowtUI",
    DebugMode = true,
    DefaultBind = Enum.KeyCode.RightShift,
    ZIndexBase = 1000,
    Language = "en_US",
    Scale = 1,
    LogFile = "SnowtUI/logs.json",
    AnimationProfile = "Default",
    SupportedLanguages = { "en_US", "ru_RU", "es_ES" },
    AnimationSpeed = 1,
    MaxWindows = 5,
    HotkeysEnabled = true,
    FocusEnabled = true,
    GamepadEnabled = true
}

SnowtUI.Modules = {}
SnowtUI.Events = {}
SnowtUI.Hotkeys = {}
SnowtUI.ObjectPool = {}
SnowtUI.ModalStack = {}
SnowtUI.Profiling = {}

SnowtUI.Localization = {
    en_US = {
        WindowTitle = "SnowtUI",
        CloseButton = "Close",
        MinimizeButton = "Minimize",
        MobileButton = "UI",
        DebugConsole = "Debug Console",
        StatusReady = "Ready",
        ContextMenu = "Context Menu",
        Tooltip = "Tooltip",
        ModalConfirm = "Confirm",
        ModalCancel = "Cancel"
    },
    ru_RU = {
        WindowTitle = "SnowtUI",
        CloseButton = "Закрыть",
        MinimizeButton = "Свернуть",
        MobileButton = "Интерфейс",
        DebugConsole = "Консоль отладки",
        StatusReady = "Готово",
        ContextMenu = "Контекстное меню",
        Tooltip = "Подсказка",
        ModalConfirm = "Подтвердить",
        ModalCancel = "Отмена"
    },
    es_ES = {
        WindowTitle = "SnowtUI",
        CloseButton = "Cerrar",
        MinimizeButton = "Minimizar",
        MobileButton = "Interfaz",
        DebugConsole = "Consola de depuración",
        StatusReady = "Listo",
        ContextMenu = "Menú contextual",
        Tooltip = "Tooltip",
        ModalConfirm = "Confirmar",
        ModalCancel = "Cancelar"
    }
}

SnowtUI.AnimationProfiles = {
    Default = { Style = Enum.EasingStyle.Sine, Direction = Enum.EasingDirection.InOut, Duration = 0.5 },
    Elastic = { Style = Enum.EasingStyle.Elastic, Direction = Enum.EasingDirection.Out, Duration = 0.8 },
    Bounce = { Style = Enum.EasingStyle.Bounce, Direction = Enum.EasingDirection.Out, Duration = 0.6 },
    Smooth = { Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.InOut, Duration = 0.4 }
}

local function Debug(msg, level)
    if not SnowtUI.Config.DebugMode then return end
    level = level or "info"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local prefix = string.format("[SnowtUI Core %s %s]", level:upper(), timestamp)
    local logMsg = string.format("%s %s", prefix, tostring(msg))
    print(logMsg)
    LogToConsole(logMsg)
    if not RunService:IsStudio() then
        local success, err = pcall(function()
            if not isfolder("SnowtUI") then makefolder("SnowtUI") end
            local logEntry = { timestamp = timestamp, level = level, message = msg }
            local logs = isfile(SnowtUI.Config.LogFile) and HttpService:JSONDecode(readfile(SnowtUI.Config.LogFile)) or {}
            table.insert(logs, logEntry)
            writefile(SnowtUI.Config.LogFile, HttpService:JSONEncode(logs))
        end)
        if not success then
            print("[SnowtUI Core ERROR] Failed to write log: " .. err)
        end
    end
    if level == "error" then
        Tween(StatusBar, { BackgroundColor3 = Color3.fromRGB(100, 30, 30) }, 0.3)
        task.wait(1)
        Tween(StatusBar, { BackgroundColor3 = Color3.fromRGB(28, 26, 34) }, 0.3)
    end
end

local function Tween(obj, props, profile)
    profile = profile or SnowtUI.Config.AnimationProfile
    local anim = SnowtUI.AnimationProfiles[profile] or SnowtUI.AnimationProfiles.Default
    local duration = anim.Duration * SnowtUI.Config.AnimationSpeed
    local tweenInfo = TweenInfo.new(duration, anim.Style, anim.Direction)
    local tween = TweenService:Create(obj, tweenInfo, props)
    tween:Play()
    return tween
end

local function Sequence(tweens)
    for i, tween in ipairs(tweens) do
        tween:Play()
        if i < #tweens then
            tween.Completed:Wait()
        end
    end
end

local function DelayedTween(obj, props, delay, profile)
    task.wait(delay)
    return Tween(obj, props, profile)
end

local function FireEvent(eventName, ...)
    if SnowtUI.Events[eventName] then
        for priority = 1, 10 do
            if SnowtUI.Events[eventName][priority] then
                for _, callback in ipairs(SnowtUI.Events[eventName][priority]) do
                    local success, err = pcall(callback, ...)
                    if not success then
                        Debug("Event callback error: " .. eventName .. ": " .. err, "error")
                    end
                end
            end
        end
    end
end

local function BindEvent(eventName, callback, priority)
    priority = priority or 5
    SnowtUI.Events[eventName] = SnowtUI.Events[eventName] or {}
    SnowtUI.Events[eventName][priority] = SnowtUI.Events[eventName][priority] or {}
    table.insert(SnowtUI.Events[eventName][priority], callback)
    Debug("Bound event: " .. eventName .. " (priority " .. priority .. ")")
end

local function BindOnce(eventName, callback, priority)
    local function wrappedCallback(...)
        callback(...)
        UnbindEvent(eventName, wrappedCallback)
    end
    BindEvent(eventName, wrappedCallback, priority)
end

local function UnbindEvent(eventName, callback)
    if SnowtUI.Events[eventName] then
        for priority = 1, 10 do
            if SnowtUI.Events[eventName][priority] then
                for i, cb in ipairs(SnowtUI.Events[eventName][priority]) do
                    if cb == callback then
                        table.remove(SnowtUI.Events[eventName][priority], i)
                        Debug("Unbound event: " .. eventName .. " (priority " .. priority .. ")")
                        break
                    end
                end
            end
        end
    end
end

local function RegisterHotkey(key, modifiers, callback)
    modifiers = modifiers or {}
    local hotkeyId = HttpService:GenerateGUID(false)
    SnowtUI.Hotkeys[hotkeyId] = {
        Key = key,
        Modifiers = modifiers,
        Callback = callback
    }
    Debug("Registered hotkey: " .. key.Name .. " (ID: " .. hotkeyId .. ")")
    return hotkeyId
end

local function UnregisterHotkey(hotkeyId)
    if SnowtUI.Hotkeys[hotkeyId] then
        SnowtUI.Hotkeys[hotkeyId] = nil
        Debug("Unregistered hotkey: " .. hotkeyId)
    end
end

local function GetPooledObject(className)
    if SnowtUI.ObjectPool[className] and #SnowtUI.ObjectPool[className] > 0 then
        return table.remove(SnowtUI.ObjectPool[className])
    end
    return Instance.new(className)
end

local function ReturnPooledObject(obj)
    local className = obj.ClassName
    SnowtUI.ObjectPool[className] = SnowtUI.ObjectPool[className] or {}
    table.insert(SnowtUI.ObjectPool[className], obj)
    obj.Parent = nil
end

local function StartProfiling(name)
    SnowtUI.Profiling[name] = { Start = tick(), Calls = 0 }
end

local function EndProfiling(name)
    if SnowtUI.Profiling[name] then
        SnowtUI.Profiling[name].Calls = SnowtUI.Profiling[name].Calls + 1
        SnowtUI.Profiling[name].Duration = tick() - SnowtUI.Profiling[name].Start
        Debug(string.format("Profile %s: %.2fms (%d calls)", name, SnowtUI.Profiling[name].Duration * 1000, SnowtUI.Profiling[name].Calls), "debug")
    end
end

local ScreenGui = GetPooledObject("ScreenGui")
ScreenGui.Name = "SnowtUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Enabled = true
ScreenGui.ZIndex = SnowtUI.Config.ZIndexBase
Debug("ScreenGui created")

local UIScale = GetPooledObject("UIScale")
UIScale.Scale = SnowtUI.Config.Scale
UIScale.Parent = ScreenGui

local Windows = {}
local FocusIndex = 0

local function CreateMainFrame(settings)
    local MainFrame = GetPooledObject("Frame")
    MainFrame.Size = UDim2.new(0, 600, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(32, 30, 38)
    MainFrame.BackgroundTransparency = 1
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    MainFrame.ClipsDescendants = true
    MainFrame.Name = "MainFrame_" .. (#Windows + 1)
    Debug("MainFrame created: " .. MainFrame.Name)

    local UICorner = GetPooledObject("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = MainFrame

    local UIStroke = GetPooledObject("UIStroke")
    UIStroke.Color = Color3.fromRGB(64, 61, 76)
    UIStroke.Thickness = 1
    UIStroke.Transparency = 0.5
    UIStroke.Parent = MainFrame

    return MainFrame
end

local function CreateTopBar(parent, settings)
    local TopBar = GetPooledObject("Frame")
    TopBar.Size = UDim2.new(1, 0, 0, 40)
    TopBar.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
    TopBar.BackgroundTransparency = 0.2
    TopBar.Parent = parent

    local Title = GetPooledObject("TextLabel")
    Title.Size = UDim2.new(0.5, 0, 1, 0)
    Title.BackgroundTransparency = 1
    Title.Text = settings.Name or SnowtUI.Localization[SnowtUI.Config.Language].WindowTitle
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextYAlignment = Enum.TextYAlignment.Center
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.Parent = TopBar

    local CloseButton = GetPooledObject("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -35, 0, 5)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Text = SnowtUI.Localization[SnowtUI.Config.Language].CloseButton
    CloseButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    CloseButton.Font = Enum.Font.SourceSans
    CloseButton.TextSize = 16
    CloseButton.Parent = TopBar

    local MinimizeButton = GetPooledObject("TextButton")
    MinimizeButton.Size = UDim2.new(0, 30, 0, 30)
    MinimizeButton.Position = UDim2.new(1, -70, 0, 5)
    MinimizeButton.BackgroundTransparency = 1
    MinimizeButton.Text = SnowtUI.Localization[SnowtUI.Config.Language].MinimizeButton
    MinimizeButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    MinimizeButton.Font = Enum.Font.SourceSans
    MinimizeButton.TextSize = 16
    MinimizeButton.Parent = TopBar

    return TopBar, CloseButton, MinimizeButton
end

local function CreateToolbar(parent)
    local Toolbar = GetPooledObject("Frame")
    Toolbar.Size = UDim2.new(1, 0, 0, 30)
    Toolbar.Position = UDim2.new(0, 0, 0, 40)
    Toolbar.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
    Toolbar.BackgroundTransparency = 0.3
    Toolbar.Parent = parent

    local ToolbarList = GetPooledObject("UIListLayout")
    ToolbarList.FillDirection = Enum.FillDirection.Horizontal
    ToolbarList.Padding = UDim.new(0, 5)
    ToolbarList.Parent = Toolbar

    return Toolbar
end

local function CreateNavPanel(parent)
    local NavPanel = GetPooledObject("Frame")
    NavPanel.Size = UDim2.new(0, 200, 1, -70)
    NavPanel.Position = UDim2.new(0, 0, 0, 70)
    NavPanel.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
    NavPanel.BackgroundTransparency = 0.2
    NavPanel.BorderSizePixel = 0
    NavPanel.Parent = parent

    local NavList = GetPooledObject("UIListLayout")
    NavList.FillDirection = Enum.FillDirection.Vertical
    NavList.Padding = UDim.new(0, 5)
    NavList.Parent = NavPanel

    return NavPanel
end

local function CreateContentFrame(parent)
    local ContentFrame = GetPooledObject("Frame")
    ContentFrame.Size = UDim2.new(1, -200, 1, -70)
    ContentFrame.Position = UDim2.new(0, 200, 0, 70)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = parent

    local ContentCanvas = GetPooledObject("ScrollingFrame")
    ContentCanvas.Size = UDim2.new(1, -10, 1, -10)
    ContentCanvas.Position = UDim2.new(0, 5, 0, 5)
    ContentCanvas.BackgroundTransparency = 1
    ContentCanvas.CanvasSize = UDim2.new(0, 0, 0, 0)
    ContentCanvas.ScrollBarThickness = 4
    ContentCanvas.Parent = ContentFrame

    local ContentList = GetPooledObject("UIListLayout")
    ContentList.FillDirection = Enum.FillDirection.Vertical
    ContentList.Padding = UDim.new(0, 10)
    ContentList.Parent = ContentCanvas

    return ContentFrame, ContentCanvas
end

local function CreateStatusBar(parent)
    local StatusBar = GetPooledObject("Frame")
    StatusBar.Size = UDim2.new(1, 0, 0, 20)
    StatusBar.Position = UDim2.new(0, 0, 1, -20)
    StatusBar.BackgroundColor3 = Color3.fromRGB(28, 26, 34)
    StatusBar.BackgroundTransparency = 0.3
    StatusBar.Parent = parent

    local StatusLabel = GetPooledObject("TextLabel")
    StatusLabel.Size = UDim2.new(1, -10, 1, 0)
    StatusLabel.Position = UDim2.new(0, 5, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = SnowtUI.Localization[SnowtUI.Config.Language].StatusReady
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.Font = Enum.Font.SourceSans
    StatusLabel.TextSize = 12
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusBar

    return StatusBar, StatusLabel
end

local function CreateModalWindow(title, message, buttons)
    local ModalFrame = GetPooledObject("Frame")
    ModalFrame.Size = UDim2.new(0, 300, 0, 200)
    ModalFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
    ModalFrame.BackgroundColor3 = Color3.fromRGB(32, 30, 38)
    ModalFrame.BackgroundTransparency = 0.2
    ModalFrame.Parent = ScreenGui
    ModalFrame.ZIndex = SnowtUI.Config.ZIndexBase + 100

    local ModalTitle = GetPooledObject("TextLabel")
    ModalTitle.Size = UDim2.new(1, 0, 0, 30)
    ModalTitle.BackgroundTransparency = 1
    ModalTitle.Text = title
    ModalTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    ModalTitle.Font = Enum.Font.SourceSansBold
    ModalTitle.TextSize = 16
    ModalTitle.TextXAlignment = Enum.TextXAlignment.Center
    ModalTitle.Parent = ModalFrame

    local ModalMessage = GetPooledObject("TextLabel")
    ModalMessage.Size = UDim2.new(1, -20, 0, 100)
    ModalMessage.Position = UDim2.new(0, 10, 0, 40)
    ModalMessage.BackgroundTransparency = 1
    ModalMessage.Text = message
    ModalMessage.TextColor3 = Color3.fromRGB(200, 200, 200)
    ModalMessage.Font = Enum.Font.SourceSans
    ModalMessage.TextSize = 14
    ModalMessage.TextWrapped = true
    ModalMessage.Parent = ModalFrame

    local ButtonContainer = GetPooledObject("Frame")
    ButtonContainer.Size = UDim2.new(1, 0, 0, 40)
    ButtonContainer.Position = UDim2.new(0, 0, 1, -40)
    ButtonContainer.BackgroundTransparency = 1
    ButtonContainer.Parent = ModalFrame

    local ButtonList = GetPooledObject("UIListLayout")
    ButtonList.FillDirection = Enum.FillDirection.Horizontal
    ButtonList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    ButtonList.Padding = UDim.new(0, 10)
    ButtonList.Parent = ButtonContainer

    for _, button in ipairs(buttons) do
        local Btn = GetPooledObject("TextButton")
        Btn.Size = UDim2.new(0, 100, 0, 30)
        Btn.BackgroundColor3 = Color3.fromRGB(40, 38, 46)
        Btn.Text = button.Text
        Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Btn.Font = Enum.Font.SourceSans
        Btn.TextSize = 14
        Btn.Parent = ButtonContainer
        Btn.MouseButton1Click:Connect(function()
            button.Callback()
            ModalFrame:Destroy()
            table.remove(SnowtUI.ModalStack, #SnowtUI.ModalStack)
        end)
    end

    table.insert(SnowtUI.ModalStack, ModalFrame)
    return ModalFrame
end

local ContextMenu = GetPooledObject("Frame")
ContextMenu.Size = UDim2.new(0, 150, 0, 0)
ContextMenu.BackgroundColor3 = Color3.fromRGB(32, 30, 38)
ContextMenu.BackgroundTransparency = 0.2
ContextMenu.Visible = false
ContextMenu.Parent = ScreenGui

local ContextMenuList = GetPooledObject("UIListLayout")
ContextMenuList.FillDirection = Enum.FillDirection.Vertical
ContextMenuList.Padding = UDim.new(0, 2)
ContextMenuList.Parent = ContextMenu

local TooltipContainer = GetPooledObject("Frame")
TooltipContainer.Size = UDim2.new(0, 200, 0, 50)
TooltipContainer.BackgroundColor3 = Color3.fromRGB(32, 30, 38)
TooltipContainer.BackgroundTransparency = 0.2
TooltipContainer.Visible = false
TooltipContainer.Parent = ScreenGui

local TooltipLabel = GetPooledObject("TextLabel")
TooltipLabel.Size = UDim2.new(1, -10, 1, -10)
TooltipLabel.Position = UDim2.new(0, 5, 0, 5)
TooltipLabel.BackgroundTransparency = 1
TooltipLabel.Text = ""
TooltipLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TooltipLabel.Font = Enum.Font.SourceSans
TooltipLabel.TextSize = 14
TooltipLabel.TextWrapped = true
TooltipLabel.Parent = TooltipContainer

local DebugConsole = GetPooledObject("Frame")
DebugConsole.Size = UDim2.new(0, 400, 0, 250)
DebugConsole.Position = UDim2.new(0, 10, 0, 10)
DebugConsole.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
DebugConsole.BackgroundTransparency = 0.2
DebugConsole.Visible = false
DebugConsole.Parent = ScreenGui

local DebugConsoleTitle = GetPooledObject("TextLabel")
DebugConsoleTitle.Size = UDim2.new(1, 0, 0, 20)
DebugConsoleTitle.BackgroundTransparency = 1
DebugConsoleTitle.Text = SnowtUI.Localization[SnowtUI.Config.Language].DebugConsole
DebugConsoleTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
DebugConsoleTitle.Font = Enum.Font.SourceSansBold
DebugConsoleTitle.TextSize = 14
DebugConsoleTitle.Parent = DebugConsole

local DebugConsoleOutput = GetPooledObject("TextLabel")
DebugConsoleOutput.Size = UDim2.new(1, -10, 1, -30)
DebugConsoleOutput.Position = UDim2.new(0, 5, 0, 25)
DebugConsoleOutput.BackgroundTransparency = 1
DebugConsoleOutput.Text = ""
DebugConsoleOutput.TextColor3 = Color3.fromRGB(200, 200, 200)
DebugConsoleOutput.Font = Enum.Font.SourceSans
DebugConsoleOutput.TextSize = 12
DebugConsoleOutput.TextXAlignment = Enum.TextXAlignment.Left
DebugConsoleOutput.TextYAlignment = Enum.TextYAlignment.Top
DebugConsoleOutput.TextWrapped = true
DebugConsoleOutput.Parent = DebugConsole

local OverlayLayer = GetPooledObject("Frame")
OverlayLayer.Size = UDim2.new(1, 0, 1, 0)
OverlayLayer.BackgroundTransparency = 1
OverlayLayer.Parent = "Frame"
OverlayLayer.ZIndex = SnowtUI.Config.ZIndex + 50

local MobileButton = GetPooledObject("TextButton")
MobileButton.Size = UDim2.new(0, 50, 0, 50)
MobileButton.Position = UDim2.new(0, 10, 1, -60)
MobileButton.BackgroundColor3 = Color3.fromRGB(32, 30, 38)
MobileButton.Text = SnowtUI.Localization[SnowtUI.ConfigSettings.ConfigSettings.ConfigSettings.ConfigSettings.ConfigLanguage].MobileButton
MobileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MobileButton.Font = Enum.Font.SourceSans
MobileButton.TextSize = 16
MobileButton.Parent = ScreenGui
MobileButton.Visible = false UserInputService.KeyboardEnabled

local MobileCorner = GetPooledObject("UICorner")
MobileCorner.CornerRadius = UDim.new(0, 8)
MobileCorner.Parent = MobileButton

local function AdjustScale()
    local screenSize = GuiService:GetScreenResolution()
    local baseScale = SnowtUI.Config.Scale
    local dpiScale = GuiService:GetGuiInset().Y / 36
    if screenSize.X < 800 then
        UIScale.Scale = baseScale * 0.8 * dpiScale
    elseif screenSize.X > 1920 then
        UIScale = baseScale * 1.2 * dpiScale
    else
        Scale = baseScale * dpiScale
    end
    Debug("Adjusted UI UI: " .. UI UI Scale)
    FireEvent("ScaleChanged", UI Scale)
end

local function UpdateStatus(msg)
    for _, window in ipairs(Windows)
        window.StatusLabel.Text = msg
    end
    Debug("Status updated: " .. msg)
end

local function LogToConsole(msg)
    DebugConsoleOutput.Text = DebugConsoleOutput.Text .. "\n" .. msg
    if #DebugConsoleOutput.Text > 2500 then
        DebugConsoleOutput.Text = string.sub(DebugConsoleOutput.Text, -2500)
    end
end

local function ShowTooltip(text, position)
    TooltipLabel.Text = text
    TooltipContainer.Position = position
    TooltipContainer.Visible = true
    Tween(TooltipContainer, { BackgroundTransparency = 0.2 })
end

local function HideTooltip()
    Tween(TooltipContainer, { BackgroundTransparency = 1 })
    task.wait(0.3)
    TooltipContainer.Visible = false
end

local function ShowContextMenu(items, position)
    for _, child in ipairs(ContextMenu:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    for _, item in ipairs(items) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -10, 0, 30)
        button.Position = UDim2.new(0, 5, 0, 0)
        button.BackgroundTransparency = 0.5
        button.BackgroundColor3 = Color3.fromRGB(40, 38, 46)
        button.Text = item.Name
        button.TextColor3 = Color3.fromRGB(200, 200, 200)
        button.Font = Enum.Font.SourceSans
        button.TextSize = 14
        button.Parent = ContextMenu

        button.MouseButton1Click:Connect(function()
            item.Callback()
            ContextMenu.Visible = false
        end)
    end

    ContextMenu.Size = UDim2.new(0, 150, 0, #items * 32)
    ContextMenu.Position = position
    ContextMenu.Visible = true
end

local function SetFocus(window)
    if Windows[FocusIndex] then
        Windows[FocusIndex].MainFrame.ZIndex = SnowtUI.Config.ZIndexBase
    end
    for i, win in ipairs(Windows) do
        if win == window then
            FocusIndex = i
            window.MainFrame.ZIndex = SnowtUI.Config.ZIndexBase + 10
            Debug("Focus set to window: " .. (window.MainFrame.Name or " .. " .. Frame"))
            FireEvent("FocusChanged", window.Name))
        end
    end
end

local function CreateWindow(settings)
    StartProfiling("CreateWindow")
    if #Windows >= SnowtUI.Config.MaxWindows then
        Debug("Maximum window limit reached", "error")
        return nil
    end

    Debug("Creating window: " .. (settings.Name or "Window"))
    local window = {
        Tabs = {},
        CurrentTab = nil,
        State = false,
        Minimized = false,
        Dragging = false,
        Bind = settings.Bind or SnowtUI.Config.DefaultBind,
        ConfigSettings = settings.Config or { ConfigFolder = SnowtUI.Config.ConfigFolder },
        FocusableElements = {},
        LastClickTime = 0
    }

    local MainFrame = CreateMainFrame()
    local TopBar, CloseButton, MinimizeButton = CreateTopBar(MainFrame, settings)
    local Toolbar = CreateToolbar(MainFrame)
    local NavPanel = CreateNavPanel(MainFrame)
    local ContentFrame, ContentCanvas = CreateContentFrame(MainFrame)
    local StatusBar, StatusLabel = CreateStatusBar(MainFrame)

    window.MainFrame = MainFrame
    window.StatusLabel = StatusLabel
    window.NavPanel = NavPanel
    window.ContentFrame = ContentFrame

    table.insert(Windows, window)

    local function toggle()
        if window.Minimized then return end
        window.State = not window.State
        Debug("Toggling UI: " .. tostring(window.State))
        if window.State then
            MainFrame.Visible = true
            local t1 = Tween(MainFrame, { BackgroundTransparency = 0.1, Size = UDim2.new(0, 600, 0, 400), Rotation = 0 })
            local t2 = Tween(TopBar, { BackgroundTransparency = 0.2 })
            local t3 = Tween(NavPanel, { BackgroundTransparency = 0.2 })
            Sequence({t1, t2, t3})
            MobileButton.Visible = not UserInputService.KeyboardEnabled
            UpdateStatus("Window opened")
            SetFocus(window)
            FireEvent("WindowOpened", window)
        else
            local t1 = Tween(MainFrame, { BackgroundTransparency = 1, Size = UDim2.new(0, 600, 0, 0), Rotation = 5 })
            local t2 = Tween(TopBar, { BackgroundTransparency = 1 })
            local t3 = Tween(NavPanel, { BackgroundTransparency = 1 })
            Sequence({ t1, t2, t3 })
            task.wait(0.5)
            MainFrame.Visible = false
            if not UserInputService.KeyboardEnabled then
                MobileButton.Visible = true
            end
            UpdateStatus("Window closed")
            FireEvent("WindowClosed", window)
        end
    end

    local function minimize()
        window.Minimized = not window.Minimized
        Debug("Minimizing UI: " .. tostring(window.Minimized))
        if window.Minimized then
            Tween(MainFrame, { Size = UDim2.new(0, 600, 0, 40) })
            NavPanel.Visible = false
            ContentFrame.Visible = false
            StatusBar.Visible = false
            UpdateStatus("Window minimized")
            FireEvent("WindowMinimized", window)
        else
            Tween(MainFrame, { Size = UDim2.new(0, 600, 0, 400) })
            NavPanel.Visible = true
            ContentFrame.Visible = true
            StatusBar.Visible = true
            UpdateStatus("Window restored")
            FireEvent("WindowRestored", window)
        end
    end

    local dragStart = nil
    local startPos = nil
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local currentTime = tick()
            if currentTime - window.LastClickTime < 0.3 then
                minimize()
            else
                window.Dragging = true
                dragStart = input.Position
                startPos = MainFrame.Position
                SetFocus(window)
            end
            window.LastClickTime = currentTime
        end
    end)

    TopBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            window.Dragging = false
        end
    end)

    RunService.RenderStepped:Connect(function()
        if window.Dragging then
            local mouse = UserInputService:GetMouseLocation()
            local delta = Vector2.new(mouse.X, mouse.Y) - Vector2.new(dragStart.X, dragStart.Y)
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y, startPos.Y.Offset + delta.Y,
            )
            MainFrame.Position = newPos
        end
    )

    CloseButton.MouseButton1Click:Connect(toggle)
    CloseButton.MouseEnter:Connect(function()
        Tween(CloseButton, { TextColor3 = Color3.fromRGB(255, 255, 255) })
        ShowTooltip("Close window", " UDim2.new(0, CloseButton.Position.X, 0, CloseButton.Position.Y + 30))
    end)
    CloseButton.MouseLeave:Connect(function()
        Tween(CloseButton, { TextColor3 = Color3.fromRGB(200, 200, 200) })
        HideTooltip()
    end)

    MinimizeButton.MouseButton1Click:Connect(minimize)
    MinimizeButton.MouseEnter:Connect(function()
        Tween(MinimizeButton, { TextColor3 = Color3.fromRGB(255, 255, 255) })
        ShowTooltip("Minimize window", " UDim2.new(0, MinimizeButton.BackgroundPosition.X, 0, MinimizeButton.BackgroundPosition.Y + 30))
    end)

    MinimizeButton.MouseLeave:Connect(function()
        Tween(MinimizeButton, { TextColor3 = Color3.fromRGB(200, 200, 200) })
        HideTooltip()
    end)

    MobileButton.MouseButton1Click:Connect(toggle)

    MainFrame.InputBegan:Connect(function(input))
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            ShowContextMenu({
                { Name = "Close", Callback = toggle },
                { Name = "Minimize", Callback = minimize },
                { Name = "Modal Test", "Callback(" function()
                    SnowtUI:ShowModal("Test Modal", "This is a test modal", {
                        { Text = "OK", Callback = function() Debug("Modal OK") end },
                        { Text = "Cancel", Callback = function() Debug("Modal Cancel") end }
                    })
                })
            }, UDim2.new(0, input.Position.X, input.Position.Y))
        end)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
            SetFocus(window)
        end
    end)

    if input.UserInputService then
        local success, err = pcall(function()
            if not isfolder(folder) then
                makefolder(folder)
                Debug("Created config folder: " .. folder)
            end
            if not isfolder(folder .. "/settings") then
                makefolder(folder .. "/settings")
                Debug("Created settings folder: " .. folder .. "/settings")
            end
            local configData = { Language = SnowtUI.Config.Language, Scale = SnowtUI.Config.Scale }
            writefile(folder .. "/settings/window.json", HttpService:JSONEncode(configData))
        end)
        if not success then
            Debug("Failed to initialize config: " .. err, "error")
        end
    end

    AdjustScale()
    GuiService.ScreenResolutionChanged:Connect(AdjustScale)

    EndProfiling("CreateWindow")
    return window
end

local function LoadModule(moduleName, modulePath)
    StartProfiling("LoadModule")
    if SnowtUI.Modules[moduleName] then
        Debug("Module already loaded: " .. moduleName)
        return SnowtUI.Modules[moduleName]
    end

    local success, module = pcall(function()
        return require(modulePath)
    end)

    if success then
        if module.Dependencies then
            for _, dep in ipairs(module.Dependencies) do
                if not SnowtUI.Modules[dep] then
                    Debug("Missing dependency for " .. moduleName .. ": " .. dep, "error")
                    return nil
                end
            end
        end
        SnowtUI.Modules[moduleName] = module
        Debug("Loaded module: " .. moduleName)
        FireEvent("ModuleLoaded", moduleName)
        LogToConsole("Loaded module: " .. moduleName)
        EndProfiling("LoadModule")
        return module
    else
        Debug("Failed to load module " .. moduleName .. ": " .. module, "error")
        LogToConsole("Failed to load module: " .. moduleName)
        EndProfiling("LoadModule")
        return nil
    end
end

local function RegisterEvent(eventName, callback, priority)
    BindEvent(eventName, callback, priority)
end

local function RegisterOnce(eventName, callback, priority)
    BindOnce(eventName, callback, priority)
end

local function UnregisterEvent(eventName, callback)
    UnbindEvent(eventName, callback)
end

local function RegisterHotkey(key, modifiers, callback)
    return RegisterHotkey(key, modifiers, callback)
end

local function UnregisterHotkey(hotkeyId)
    UnregisterHotkey(hotkeyId)
end

local function ToggleDebugConsole()
    DebugConsole.Visible = not DebugConsole.Visible
    Debug("Debug console toggled: " .. tostring(DebugConsole.Visible))
end

local function SetLanguage(lang)
    if not table.find(SnowtUI.Config.SupportedLanguages, lang) then
        Debug("Unsupported language: " .. lang, "error")
        return
    end
    SnowtUI.Config.Language = lang
    Debug("Language set to: " .. lang)
    FireEvent("LanguageChanged", lang)
end

local function ShowModal(title, message, buttons)
    StartProfiling("ShowModal")
    CreateModalWindow(title, message, buttons)
    EndProfiling("ShowModal")
end

local function AddFocusableElement(window, element)
    table.insert(window.FocusableElements, element)
end

local function FocusNextElement(window)
    if #window.FocusableElements == 0 then return end
    local currentFocus = window.CurrentFocus or 0
    window.CurrentFocus = (currentFocus % #window.FocusableElements) + 1
    Debug("Focusing element: " .. window.CurrentFocus)
    FireEvent("ElementFocused", window.FocusableElements[window.CurrentFocus])
end

local function ApplyProperties(element, props)
    for prop, value in pairs(props) do
        element[prop] = value
    end
end

local function CloneTemplate(template)
    local clone = template:Clone()
    clone.Parent = nil
    return clone
end

local function CheckInjector()
    local injector = identifyexecutor and identifyexecutor() or "Unknown"
    Debug("Injector detected: " .. injector)
    return injector
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not SnowtUI.Config.HotkeysEnabled then return end
    for id, hotkey in pairs(SnowtUI.Hotkeys) do
        if input.KeyCode == hotkey.Key then
            local modifiersMatch = true
            for _, mod in ipairs(hotkey.Modifiers) do
                if not UserInputService:IsKeyDown(mod) then
                    modifiersMatch = false
                    break
                end
            end
            if modifiersMatch then
                local success, err = pcall(hotkey.Callback)
                if not success then
                    Debug("Hotkey callback error: " .. err, "error")
                end
            end
        end
    end
    if SnowtUI.Config.FocusEnabled and input.KeyCode == Enum.KeyCode.Tab and Windows[FocusIndex] then
        FocusNextElement(Windows[FocusIndex])
    end
end)

UserInputService.InputChanged:Connect(function(input, gpe)
    if gpe or not SnowtUI.Config.GamepadEnabled then return end
    if input.UserInputType == Enum.UserInputType.Gamepad then
        Debug("Gamepad input detected: " .. input.KeyCode.Name)
        FireEvent("GamepadInput", input.KeyCode)
    end
end)

Debug("SnowtUI Core initialized")
FireEvent("CoreInitialized")
LogToConsole("SnowtUI Core initialized")
CheckInjector()

return SnowtUI