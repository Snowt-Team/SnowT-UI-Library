-- Tabs.lua: Tabbed navigation module for SnowtUI with scrolling support
-- Provides a tabbed interface with animations, theming, accessibility, and scrollable tab bar
-- Dependencies: Core.lua, Theme.lua, Elements.lua
local Tabs = {}
Tabs.Version = "1.0.0"
Tabs.Dependencies = { "Core", "Theme", "Elements" }

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Internal state
Tabs.TabCache = {} -- Stores tab containers by ID
Tabs.ActiveTabs = {} -- Tracks active tab per container
Tabs.TabOrder = {} -- Stores tab order for drag-and-drop
Tabs.EventCallbacks = {} -- Stores event callbacks
Tabs.AnimationCache = {} -- Caches tweens for reuse
Tabs.FocusableTabs = {} -- Tracks focusable tab buttons per group
Tabs.ScrollPositions = {} -- Tracks scroll position per container

-- Default configurations for tab components
Tabs.Defaults = {
    TabContainer = {
        Size = UDim2.new(1, -10, 1, -40),
        Position = UDim2.new(0, 5, 0, 35),
        BackgroundTransparency = 0,
        TabBarHeight = 30,
        ScrollButtonSize = UDim2.new(0, 30, 1, 0),
        ScrollSpeed = 50,
        Animation = { Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Tooltip = "Tab navigation container"
    },
    TabButton = {
        Size = UDim2.new(0, 100, 1, 0),
        TextSize = 14,
        Font = Enum.Font.SourceSans,
        Animation = { HoverScale = 1.05, Duration = 0.2, EasingStyle = Enum.EasingStyle.Sine },
        Padding = UDim.new(0, 5),
        Tooltip = "Switch to this tab",
        Enabled = true
    },
    TabContent = {
        Size = UDim2.new(1, 0, 1, -40),
        BackgroundTransparency = 0,
        Animation = { FadeDuration = 200, EasingStyle = Enum.EasingStyle.Quad },
        Tooltip = ""
    }
}

-- Utility function to create tweens
local function CreateTween(obj, props, duration, easingStyle, easingDirection)
    local tweenInfo = TweenInfo.new(
        duration or Tabs.Defaults.TabContainer.Animation.Duration,
        easingStyle or Tabs.Defaults.TabContainer.Animation.EasingStyle,
        easingDirection or Enum.EasingDirection.InOut
    )
    local tween = Tabs.AnimationCache[obj] or TweenService:Create(obj, tweenInfo, props)
    Tabs.AnimationCache[obj] = tween
    tween:Play()
    return tween
end

-- Utility function to apply theme styles
local function ApplyThemeStyle(element, theme, elementType)
    if not SnowtUI or not SnowtUI.Modules.Theme then
        SnowtUI.Debug("Theme module not loaded for tab styling", "error")
        return
    end
    local style = theme[elementType] or theme.Button
    for prop, value in pairs(style) do
        if prop == "HoverColor" or prop == "Gradient" then
            -- Handled in interaction events
        elseif prop == "Transparency" then
            element.BackgroundTransparency = value
        else
            element[prop] = value
        end
    end
    SnowtUI.Modules.Theme:ApplyAdaptiveStyle(element, style)
end

-- Utility function to create a UIStroke
local function CreateStroke(parent, theme)
    local stroke = SnowtUI:GetPooledObject("UIStroke")
    stroke.Thickness = theme.Stroke.Thickness
    stroke.Color = theme.Stroke.Color
    stroke.Transparency = theme.Stroke.Transparency
    stroke.Parent = parent
    return stroke
end

-- Utility function to create a UICorner
local function CreateCorner(parent, theme)
    local corner = SnowtUI:GetPooledObject("UICorner")
    corner.CornerRadius = theme.Corner.Radius
    corner.Parent = parent
    return corner
end

-- Utility function to create a ripple effect
local function CreateRipple(parent, position)
    local ripple = SnowtUI:GetPooledObject("Frame")
    ripple.Size = UDim2.new(0, 0, 0, 0)
    ripple.Position = position
    ripple.BackgroundTransparency = 0.5
    ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ripple.ZIndex = parent.ZIndex + 1
    ripple.Parent = parent
    CreateCorner(ripple, { Corner = { Radius = UDim.new(1, 0) } })
    
    local tween = CreateTween(ripple, {
        Size = UDim2.new(0, 100, 0, 100),
        BackgroundTransparency = 1
    }, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    tween.Completed:Connect(function()
        ripple:Destroy()
    end)
end

-- Utility function to add tooltip support
local function AddTooltip(element, tooltipText)
    if tooltipText and tooltipText ~= "" then
        element.MouseEnter:Connect(function()
            SnowtUI:ShowTooltip(tooltipText, UDim2.new(0, element.AbsolutePosition.X, 0, element.AbsolutePosition.Y + element.AbsoluteSize.Y))
        end)
        element.MouseLeave:Connect(function()
            SnowtUI:HideTooltip()
        end)
    end
end

-- Utility function to add context menu support
local function AddContextMenu(element, items)
    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            SnowtUI:ShowContextMenu(items, UDim2.new(0, input.Position.X, 0, input.Position.Y))
        end)
    end
end

-- Utility function to update scroll button visibility
local function UpdateScrollButtons(containerId)
    local container = Tabs.TabCache[containerId]
    if not container then return end
    local scrollFrame = container.TabBar.ScrollFrame
    local leftArrow = container.TabBar.LeftArrow
    local rightArrow = container.TabBar.RightArrow
    
    local canvasWidth = scrollFrame.CanvasSize.X.Offset
    local frameWidth = scrollFrame.AbsoluteSize.X
    local scrollPos = scrollFrame.CanvasPosition.X
    
    leftArrow.Visible = scrollPos > 0
    rightArrow.Visible = scrollPos < canvasWidth - frameWidth
end

-- Tab container creation with scrolling support
function Tabs:CreateTabContainer(parent, settings)
    settings = settings or {}
    local containerId = settings.Id or "TabContainer_" .. HttpService:GenerateGUID(false)
    local frame = SnowtUI:GetPooledObject("Frame")
    frame.Size = settings.Size or Tabs.Defaults.TabContainer.Size
    frame.Position = settings.Position or Tabs.Defaults.TabContainer.Position
    frame.BackgroundTransparency = Tabs.Defaults.TabContainer.BackgroundTransparency
    frame.Parent = parent
    frame.Name = containerId
    frame.ClipsDescendants = true

    local tabBar = SnowtUI:GetPooledObject("Frame")
    tabBar.Size = UDim2.new(1, -60, 0, settings.TabBarHeight or Tabs.Defaults.TabContainer.TabBarHeight)
    tabBar.Position = UDim2.new(0, 30, 0, 0)
    tabBar.BackgroundTransparency = 0
    tabBar.Parent = frame

    local scrollFrame = SnowtUI:GetPooledObject("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.ScrollBarThickness = 0
    scrollFrame.CanvasSize = UDim2.new(0, 0, 1, 0)
    scrollFrame.Parent = tabBar
    scrollFrame.Name = "ScrollFrame"

    local tabList = SnowtUI:GetPooledObject("UIListLayout")
    tabList.FillDirection = Enum.FillDirection.Horizontal
    tabList.Padding = UDim.new(0, 2)
    tabList.Parent = scrollFrame

    local leftArrow = SnowtUI:GetPooledObject("TextButton")
    leftArrow.Size = Tabs.Defaults.TabContainer.ScrollButtonSize
    leftArrow.Position = UDim2.new(0, 0, 0, 0)
    leftArrow.Text = "◄"
    leftArrow.TextSize = 14
    leftArrow.BackgroundTransparency = 0
    leftArrow.AutoButtonColor = false
    leftArrow.Visible = false
    leftArrow.Parent = frame
    leftArrow.Name = "LeftArrow"

    local rightArrow = SnowtUI:GetPooledObject("TextButton")
    rightArrow.Size = Tabs.Defaults.TabContainer.ScrollButtonSize
    rightArrow.Position = UDim2.new(1, -30, 0, 0)
    rightArrow.Text = "►"
    rightArrow.TextSize = 14
    rightArrow.BackgroundTransparency = 0
    rightArrow.AutoButtonColor = false
    rightArrow.Visible = false
    rightArrow.Parent = frame
    rightArrow.Name = "RightArrow"

    local contentArea = SnowtUI:GetPooledObject("Frame")
    contentArea.Size = UDim2.new(1, 0, 1, -Tabs.Defaults.TabContainer.TabBarHeight)
    contentArea.Position = UDim2.new(0, 0, 0, Tabs.Defaults.TabContainer.TabBarHeight)
    contentArea.BackgroundTransparency = 1
    contentArea.Parent = frame
    contentArea.ClipsDescendants = true

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(frame, theme, "Button")
    ApplyThemeStyle(tabBar, theme, "Button")
    ApplyThemeStyle(scrollFrame, theme, "Button")
    ApplyThemeStyle(leftArrow, theme, "Button")
    ApplyThemeStyle(rightArrow, theme, "Button")
    ApplyThemeStyle(contentArea, theme, "Button")
    CreateStroke(frame, theme)
    CreateCorner(frame, theme)
    CreateCorner(tabBar, theme)
    CreateCorner(leftArrow, theme)
    CreateCorner(rightArrow, theme)

    -- Scroll button interactions
    leftArrow.MouseButton1Click:Connect(function()
        local scrollFrame = tabBar.ScrollFrame
        local newPos = math.max(0, scrollFrame.CanvasPosition.X - Tabs.Defaults.TabContainer.ScrollSpeed)
        CreateTween(scrollFrame, { CanvasPosition = Vector2.new(newPos, 0) }, 0.3, Enum.EasingStyle.Sine):Play()
        UpdateScrollButtons(containerId)
    end)

    rightArrow.MouseButton1Click:Connect(function()
        local scrollFrame = tabBar.ScrollFrame
        local canvasWidth = scrollFrame.CanvasSize.X.Offset
        local frameWidth = scrollFrame.AbsoluteSize.X
        local newPos = math.min(canvasWidth - frameWidth, scrollFrame.CanvasPosition.X + Tabs.Defaults.TabContainer.ScrollSpeed)
        CreateTween(scrollFrame, { CanvasPosition = Vector2.new(newPos, 0) }, 0.3, Enum.EasingStyle.Sine):Play()
        UpdateScrollButtons(containerId)
    end)

    leftArrow.MouseEnter:Connect(function()
        CreateTween(leftArrow, { BackgroundColor3 = theme.Button.HoverColor }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        AddTooltip(leftArrow, "Scroll left")
    end)

    leftArrow.MouseLeave:Connect(function()
        CreateTween(leftArrow, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    rightArrow.MouseEnter:Connect(function()
        CreateTween(rightArrow, { BackgroundColor3 = theme.Button.HoverColor }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        AddTooltip(rightArrow, "Scroll right")
    end)

    rightArrow.MouseLeave:Connect(function()
        CreateTween(rightArrow, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    -- Mouse wheel scrolling
    scrollFrame.MouseWheelForward:Connect(function()
        local newPos = math.max(0, scrollFrame.CanvasPosition.X - Tabs.Defaults.TabContainer.ScrollSpeed)
        CreateTween(scrollFrame, { CanvasPosition = Vector2.new(newPos, 0) }, 0.3, Enum.EasingStyle.Sine):Play()
        UpdateScrollButtons(containerId)
    end)

    scrollFrame.MouseWheelBackward:Connect(function()
        local canvasWidth = scrollFrame.CanvasSize.X.Offset
        local frameWidth = scrollFrame.AbsoluteSize.X
        local newPos = math.min(canvasWidth - frameWidth, scrollFrame.CanvasPosition.X + Tabs.Defaults.TabContainer.ScrollSpeed)
        CreateTween(scrollFrame, { CanvasPosition = Vector2.new(newPos, 0) }, 0.3, Enum.EasingStyle.Sine):Play()
        UpdateScrollButtons(containerId)
    end)

    Tabs.TabCache[containerId] = { Frame = frame, Tabs = {}, Content = contentArea, TabBar = tabBar, ScrollFrame = scrollFrame, LeftArrow = leftArrow, RightArrow = rightArrow }
    Tabs.ActiveTabs[containerId] = nil
    Tabs.TabOrder[containerId] = {}
    Tabs.FocusableTabs[containerId] = {}
    Tabs.ScrollPositions[containerId] = 0

    frame.MouseEnter:Connect(function()
        AddTooltip(frame, settings.Tooltip or Tabs.Defaults.TabContainer.Tooltip)
    end)

    frame.MouseLeave:Connect(function()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(frame, {
        { Name = "Add New Tab", Callback = function()
            Tabs:AddTab(containerId, { Text = "New Tab" })
        end },
        { Name = "Close All Tabs", Callback = function()
            for _, tab in ipairs(Tabs.TabCache[containerId].Tabs) do
                tab.Frame:Destroy()
            end
            Tabs.TabCache[containerId].Tabs = {}
            Tabs.ActiveTabs[containerId] = nil
            Tabs.TabOrder[containerId] = {}
            Tabs.FocusableTabs[containerId] = {}
            Tabs.ScrollPositions[containerId] = 0
            scrollFrame.CanvasPosition = Vector2.new(0, 0)
            UpdateScrollButtons(containerId)
            SnowtUI.FireEvent("TabsCleared", containerId)
        end }
    })

    return containerId
end

-- Add a new tab to a container
function Tabs:AddTab(containerId, settings)
    settings = settings or {}
    local container = Tabs.TabCache[containerId]
    if not container then
        SnowtUI.Debug("Tab container not found: " .. containerId, "error")
        return
    end

    local tabId = settings.Id or "Tab_" .. HttpService:GenerateGUID(false)
    local tabButton = SnowtUI:GetPooledObject("TextButton")
    tabButton.Size = settings.Size or Tabs.Defaults.TabButton.Size
    tabButton.Text = settings.Text or "Tab"
    tabButton.TextSize = settings.TextSize or Tabs.Defaults.TabButton.TextSize
    tabButton.Font = settings.Font or Tabs.Defaults.TabButton.Font
    tabButton.BackgroundTransparency = 0
    tabButton.AutoButtonColor = false
    tabButton.Parent = container.ScrollFrame
    tabButton.Name = tabId
    tabButton.Active = settings.Enabled ~= false

    local tabContent = SnowtUI:GetPooledObject("Frame")
    tabContent.Size = Tabs.Defaults.TabContent.Size
    tabContent.BackgroundTransparency = Tabs.Defaults.TabContent.BackgroundTransparency
    tabContent.Visible = false
    tabContent.Parent = container.Content
    tabContent.Name = tabId .. "_Content"

    local contentList = SnowtUI:GetPooledObject("UIListLayout")
    contentList.FillDirection = Enum.FillDirection.Vertical
    contentList.Padding = UDim.new(0, 5)
    contentList.Parent = tabContent

    local theme = SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()]
    ApplyThemeStyle(tabButton, theme, "Button")
    ApplyThemeStyle(tabContent, theme, "Button")
    CreateStroke(tabButton, theme)
    CreateCorner(tabButton, theme)
    CreateCorner(tabContent, theme)

    local tabData = {
        Id = tabId,
        Button = tabButton,
        Content = tabContent,
        Order = #Tabs.TabOrder[containerId] + 1
    }
    table.insert(container.Tabs, tabData)
    table.insert(Tabs.TabOrder[containerId], tabId)
    table.insert(Tabs.FocusableTabs[containerId], tabButton)

    -- Update canvas size
    local tabWidth = (settings.Size or Tabs.Defaults.TabButton.Size).X.Offset
    container.ScrollFrame.CanvasSize = UDim2.new(0, #container.Tabs * (tabWidth + 2), 1, 0)
    UpdateScrollButtons(containerId)

    local function activateTab()
        if not tabButton.Active then return
        if Tabs.ActiveTabs[containerId] then
            local prevTab = Tabs.ActiveTabs[containerId]
            prevTab.Content.Visible = false
            CreateTween(prevTab.Button, { BackgroundColor3 = theme.Button.BackgroundColor3 }, Tabs.Defaults.TabButton.Animation.Duration):Play()
            CreateTween(prevTab.Content, { BackgroundTransparency = 1 }, Tabs.Defaults.TabContent.Animation.FadeDuration / 1000):Play()
        end
        Tabs.ActiveTabs[containerId] = tabData
        tabContent.Visible = true
        CreateTween(tabButton, { BackgroundColor3 = theme.Button.HoverColor }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        CreateTween(tabContent, { BackgroundTransparency = Tabs.Defaults.TabContent.BackgroundTransparency }, Tabs.Defaults.TabContent.Animation.FadeDuration / 1000):Play()
        -- Scroll to make tab visible
        local tabIndex = table.find(Tabs.TabOrder[containerId], tabId)
        local tabPos = (tabIndex - 1) * (tabWidth + 2)
        local scrollFrame = container.ScrollFrame
        local frameWidth = scrollFrame.AbsoluteSize.X
        local scrollPos = scrollFrame.CanvasPosition.X
        if tabPos < scrollPos then
            CreateTween(scrollFrame, { CanvasPosition = Vector2.new(tabPos, 0) }, 0.3, Enum.EasingStyle.Sine):Play()
        elseif tabPos + tabWidth > scrollPos + frameWidth then
            CreateTween(scrollFrame, { CanvasPosition = Vector2.new(tabPos + tabWidth - frameWidth, 0) }, 0.3, Enum.EasingStyle.Sine):Play()
        end
        Tabs.ScrollPositions[containerId] = scrollFrame.CanvasPosition.X
        UpdateScrollButtons(containerId)
        SnowtUI.FireEvent("TabActivated", containerId, tabId)
    end

    tabButton.MouseButton1Click:Connect(function()
        activateTab()
        if settings.Animation and settings.Animation.Ripple then
            local mousePos = UserInputService:GetMouseLocation()
            local relPos = UDim2.new(0, mousePos.X - tabButton.AbsolutePosition.X, 0, mousePos.Y - tabButton.AbsolutePosition.Y)
            CreateRipple(tabButton, relPos)
        end
    end)

    tabButton.MouseEnter:Connect(function()
        if not tabButton.Active then return
        CreateTween(tabButton, {
            Size = UDim2.new(
                tabButton.Size.X.Scale * Tabs.Defaults.TabButton.Animation.HoverScale,
                tabButton.Size.X.Offset * Tabs.Defaults.TabButton.Animation.HoverScale,
                tabButton.Size.Y.Scale,
                tabButton.Size.Y.Offset
            ),
            BackgroundColor3 = Tabs.ActiveTabs[containerId] == tabData and theme.Button.HoverColor or theme.Button.BackgroundColor3:Lerp(theme.Button.HoverColor, 0.5)
        }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        AddTooltip(tabButton, settings.Tooltip or Tabs.Defaults.TabButton.Tooltip)
    end)

    tabButton.MouseLeave:Connect(function()
        if not tabButton.Active then return
        CreateTween(tabButton, {
            Size = settings.Size or Tabs.Defaults.TabButton.Size,
            BackgroundColor3 = Tabs.ActiveTabs[containerId] == tabData and theme.Button.HoverColor or theme.Button.BackgroundColor3
        }, Tabs.Defaults.TabButton.Animation.Duration):Play()
        SnowtUI:HideTooltip()
    end)

    AddContextMenu(tabButton, {
        { Name = "Rename Tab", Callback = function()
            SnowtUI:Prompt("Enter new tab name", function(newName)
                if newName then
                    tabButton.Text = newName
                    SnowtUI.FireEvent("TabRenamed", containerId, tabId, newName)
                end
            end)
        end },
        { Name = "Close Tab", Callback = function()
            Tabs:RemoveTab(containerId, tabId)
        end },
        { Name = "Disable Tab", Callback = function()
            tabButton.Active = false
            if Tabs.ActiveTabs[containerId] == tabData then
                Tabs.ActiveTabs[containerId] = nil
                tabContent.Visible = false
            end
        end },
        { Name = "Enable Tab", Callback = function()
            tabButton.Active = true
        end }
    })

    -- Drag-and-drop support
    local dragging = false
    local dragStartPos = nil
    local originalIndex = nil

    tabButton.InputBegan:Connect(function(input)
        if not tabButton.Active then return
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = input.Position
            originalIndex = table.find(Tabs.TabOrder[containerId], tabId)
        end
    end)

    tabButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            dragStartPos = nil
            originalIndex = nil
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not tabButton.Active then return
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position.X - dragStartPos.X
            local tabWidth = tabButton.AbsoluteSize.X
            if math.abs(delta) > tabWidth / 2 then
                local newIndex = math.clamp(originalIndex + (delta > 0 and 1 or -1), 1, #Tabs.TabOrder[containerId])
                if newIndex ~= originalIndex then
                    table.remove(Tabs.TabOrder[containerId], originalIndex)
                    table.insert(Tabs.TabOrder[containerId], newIndex, tabId)
                    originalIndex = newIndex
                    dragStartPos = input.Position
                    -- Reorder UI
                    local buttons = {}
                    for _, tab in ipairs(container.Tabs) do
                        buttons[table.find(Tabs.TabOrder[containerId], tab.Id)] = tab.Button
                    end
                    for i, button in ipairs(buttons) do
                        button.Position = UDim2.new(0, (i - 1) * (tabWidth + 2), 0, 0)
                    end
                    SnowtUI.FireEvent("TabReordered", containerId, tabId, newIndex)
                    UpdateScrollButtons(containerId)
                end
            end
        end
    end)

    if #container.Tabs == 1 or settings.Selected then
        activateTab()
    end

    return tabId, tabContent
end

-- Remove a tab from a container
function Tabs:RemoveTab(containerId, tabId)
    local container = Tabs.TabCache[containerId]
    if not container then
        SnowtUI.Debug("Tab container not found: " .. containerId, "error")
        return
    end

    for i, tab in ipairs(container.Tabs) do
        if tab.Id == tabId then
            tab.Button:Destroy()
            tab.Content:Destroy()
            table.remove(container.Tabs, i)
            table.remove(Tabs.TabOrder[containerId], table.find(Tabs.TabOrder[containerId], tabId))
            table.remove(Tabs.FocusableTabs[containerId], table.find(Tabs.FocusableTabs[containerId], tab.Button))
            -- Update canvas size
            local tabWidth = Tabs.Defaults.TabButton.Size.X.Offset
            container.ScrollFrame.CanvasSize = UDim2.new(0, #container.Tabs * (tabWidth + 2), 1, 0)
            if Tabs.ActiveTabs[containerId] == tab then
                Tabs.ActiveTabs[containerId] = nil
                if #container.Tabs > 0 then
                    container.Tabs[1].Button:MouseButton1Click()
                end
            end
            UpdateScrollButtons(containerId)
            SnowtUI.FireEvent("TabRemoved", containerId, tabId)
            break
        end
    end
end

-- Get tab content frame
function Tabs:GetTabContent(containerId, tabId)
    local container = Tabs.TabCache[containerId]
    if not container then
        SnowtUI.Debug("Tab container not found: " .. containerId, "error")
        return
    end
    for _, tab in ipairs(container.Tabs) do
        if tab.Id == tabId then
            return tab.Content
        end
    end
    SnowtUI.Debug("Tab not found: " .. tabId, "error")
    return
end

-- Set active tab
function Tabs:SetActiveTab(containerId, tabId)
    local container = Tabs.TabCache[containerId]
    if not container then
        SnowtUI.Debug("Tab container not found: " .. containerId, "error")
        return
    end
    for _, tab in ipairs(container.Tabs) do
        if tab.Id == tabId and tab.Button.Active then
            tab.Button:MouseButton1Click()
            return
        end
    end
    SnowtUI.Debug("Tab not found or disabled: " .. tabId, "error")
end

-- Initialize the Tabs module
function Tabs:Init(core)
    SnowtUI = core
    SnowtUI.Debug("Tabs module initialized")

    -- Handle theme changes
    SnowtUI:RegisterEvent("ThemeChanged", function(themeName)
        local theme = SnowtUI.Modules.Theme.Themes[themeName]
        for containerId, container in pairs(Tabs.TabCache) do
            ApplyThemeStyle(container.Frame, theme, "Button")
            ApplyThemeStyle(container.TabBar, theme, "Button")
            ApplyThemeStyle(container.ScrollFrame, theme, "Button")
            ApplyThemeStyle(container.LeftArrow, theme, "Button")
            ApplyThemeStyle(container.RightArrow, theme, "Button")
            ApplyThemeStyle(container.Content, theme, "Button")
            for _, child in ipairs(container.Frame:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                    ApplyThemeStyle(child, theme, child.ClassName == "TextLabel" and "Text" or "Button")
                elseif child:IsA("UIStroke") then
                    ApplyThemeStyle(child, theme, "Stroke")
                elseif child:IsA("UICorner") then
                    ApplyThemeStyle(child, theme, "Corner")
                end
            end
            for _, tab in ipairs(container.Tabs) do
                ApplyThemeStyle(tab.Button, theme, "Button")
                ApplyThemeStyle(tab.Content, theme, "Button")
                if Tabs.ActiveTabs[containerId] == tab then
                    tab.Button.BackgroundColor3 = theme.Button.HoverColor
                else
                    tab.Button.BackgroundColor3 = theme.Button.BackgroundColor3
                end
            end
        end
    end)

    -- Handle scale changes
    SnowtUI:RegisterEvent("ScaleAdjusted", function()
        for containerId, container in pairs(Tabs.TabCache) do
            SnowtUI.Modules.Theme:ApplyAdaptiveStyle(container.Frame, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
            for _, child in ipairs(container.Frame:GetDescendants()) do
                if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") then
                    SnowtUI.Modules.Theme:ApplyAdaptiveStyle(child, SnowtUI.Modules.Theme.Themes[SnowtUI.Modules.Theme:LoadTheme()].Button)
                end
            end
            -- Update scroll positions after scaling
            local scrollFrame = container.ScrollFrame
            local tabWidth = Tabs.Defaults.TabButton.Size.X.Offset
            scrollFrame.CanvasSize = UDim2.new(0, #container.Tabs * (tabWidth + 2), 1, 0)
            UpdateScrollButtons(containerId)
        end
    end)

    -- Gamepad support
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent or not SnowtUI.Config.GamepadEnabled then return
        if input.UserInputType == Enum.UserInputType.Gamepad1 then
            for containerId, _ in pairs(Tabs.TabCache) do
                local focusable = Tabs.FocusableTabs[containerId]
                if #focusable > 0 then
                    local currentIndex = 1
                    for i, button in ipairs(focusable) do
                        if Tabs.ActiveTabs[containerId] and Tabs.ActiveTabs[containerId].Button == button then
                            currentIndex = i
                            break
                        end
                    end
                    local direction = input.KeyCode == Enum.KeyCode.DPadRight and 1 or (input.KeyCode == Enum.KeyCode.DPadLeft and -1 or 0)
                    if direction ~= 0 then
                        local newIndex = (currentIndex - 1 + direction) % #focusable + 1
                        focusable[newIndex]:MouseButton1Click()
                    end
                    break
                end
            end
        end
    end)
end

return Tabs