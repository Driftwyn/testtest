--[[
    Driftwyn UI v5.9
    Black / crimson Roblox UI library inspired by the supplied Driftwyn Hub mockup.

    Remote usage:
    local DriftwynUI = loadstring(game:HttpGet("YOUR_RAW_URL"))()
    local Window = DriftwynUI:CreateWindow({...})

    Notes:
    - No external icon pack is required. Named icons fall back to clean glyphs.
    - For pixel-perfect icons, pass rbxassetid://... values to Icon.
    - Designed for executor/client-side environments.
]]

local DriftwynUI = {}
DriftwynUI.__index = DriftwynUI

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--========================================================
-- UTIL
--========================================================

local function New(className, props, children)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            obj[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
    end
    if props and props.Parent then
        obj.Parent = props.Parent
    end
    return obj
end

local function Corner(parent, radius)
    return New("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent
    })
end

local function Padding(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent
    })
end

local ActiveTweens = setmetatable({}, {__mode = "k"})

local function Tween(obj, duration, props, style, direction)
    if not obj or not obj.Parent then
        return nil
    end

    local objectTweens = ActiveTweens[obj]
    if not objectTweens then
        objectTweens = {}
        ActiveTweens[obj] = objectTweens
    end

    -- Cancel only older tweens that animate one of the same properties.
    local cancelled = {}
    for propertyName in pairs(props) do
        local previous = objectTweens[propertyName]
        if previous and not cancelled[previous] then
            cancelled[previous] = true
            pcall(function()
                previous:Cancel()
            end)
        end
    end

    local tween = TweenService:Create(
        obj,
        TweenInfo.new(
            duration or 0.26,
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        props
    )

    for propertyName in pairs(props) do
        objectTweens[propertyName] = tween
    end

    tween.Completed:Connect(function()
        local current = ActiveTweens[obj]
        if not current then
            return
        end

        for propertyName in pairs(props) do
            if current[propertyName] == tween then
                current[propertyName] = nil
            end
        end
    end)

    tween:Play()
    return tween
end

local function Clamp01(v)
    return math.clamp(v, 0, 1)
end

local function Darken(c, amount)
    amount = Clamp01(amount or 0.1)
    return Color3.new(c.R * (1 - amount), c.G * (1 - amount), c.B * (1 - amount))
end

local function Lighten(c, amount)
    amount = Clamp01(amount or 0.1)
    return Color3.new(
        c.R + (1 - c.R) * amount,
        c.G + (1 - c.G) * amount,
        c.B + (1 - c.B) * amount
    )
end

local function ColorToRGB(c)
    return math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
end

local function IsAssetIcon(icon)
    if type(icon) == "number" then
        return true
    end
    if type(icon) ~= "string" then
        return false
    end
    return icon:match("^rbxassetid://") ~= nil or icon:match("^https?://") ~= nil
end

local Glyphs = {
    home = "⌂",
    main = "⌂",
    eye = "◉",
    visuals = "◉",
    player = "●",
    target = "⊙",
    farm = "⊙",
    speed = "➜",
    walk = "➜",
    crown = "♛",
    mode = "♛",
    edit = "✎",
    textbox = "✎",
    bolt = "ϟ",
    run = "ϟ",
    palette = "◈",
    color = "◈",
    key = "◇",
    settings = "⚙",
    search = "⌕",
    diamond = "◆",
    fire = "♨",
}

local function GetGlyph(name, fallback)
    if type(name) ~= "string" or name == "" then
        return fallback or "◆"
    end
    return Glyphs[string.lower(name)] or fallback or "◆"
end

local function ResolveIconContent(icon)
    -- Decal/Creator Store IDs often do not render directly in ImageLabel on executors.
    -- rbxthumb resolves the supplied asset ID to a usable thumbnail image.
    if type(icon) == "number" then
        return "rbxthumb://type=Asset&id=" .. tostring(icon) .. "&w=150&h=150"
    end

    if type(icon) == "string" then
        local id = icon:match("^rbxassetid://(%d+)$")
        if id then
            return "rbxthumb://type=Asset&id=" .. id .. "&w=150&h=150"
        end
        return icon
    end

    return ""
end

local function MakeIcon(parent, icon, size, color, glyphFallback)
    size = size or 18
    color = color or Color3.new(1, 1, 1)

    if IsAssetIcon(icon) then
        local image = New("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size, size),
            Image = ResolveIconContent(icon),
            ImageColor3 = color,
            ImageTransparency = 0,
            ScaleType = Enum.ScaleType.Fit,
            Parent = parent
        })
        return image, "image"
    else
        local glyph = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(size + 4, size + 4),
            Font = Enum.Font.GothamBold,
            Text = GetGlyph(icon, glyphFallback),
            TextColor3 = color,
            TextSize = math.floor(size * 0.9),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = parent
        })
        return glyph, "text"
    end
end

local function GetGuiParent()
    local ok, hui = pcall(function()
        if gethui then
            return gethui()
        end
    end)
    if ok and hui then
        return hui
    end

    local ok2, cg = pcall(function()
        return CoreGui
    end)
    if ok2 and cg then
        return cg
    end

    return LocalPlayer:WaitForChild("PlayerGui")
end

local function ConnectDrag(handle, target, connectGlobal)
    local dragging = false
    local dragStart
    local startPos
    local dragInput

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    connectGlobal(UserInputService.InputChanged, function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local function AddNoiseDecor(parent, theme)
    -- Lightweight red "scratch" accents to mimic the reference without an image asset.
    local decor = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = parent
    })

    local lines = {
        {0.13, 0.07, 48, -20},
        {0.31, 0.12, 24, -15},
        {0.53, 0.08, 26, -16},
        {0.74, 0.11, 40, -17},
        {0.86, 0.06, 18, -16},
        {0.83, 0.31, 22, -16},
        {0.89, 0.27, 34, -16},
        {0.22, 0.69, 31, -16},
        {0.67, 0.88, 28, -16},
        {0.10, 0.87, 34, -16},
    }

    for i, info in ipairs(lines) do
        New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = theme.Accent,
            BackgroundTransparency = 0.55 + ((i % 3) * 0.12),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(info[1], info[2]),
            Size = UDim2.fromOffset(info[3], 1),
            Rotation = info[4],
            ZIndex = 3,
            Parent = decor
        })
    end

    return decor
end

--========================================================
-- THEMES
--========================================================

local Themes = {
    Driftwyn = {
        Background = Color3.fromRGB(7, 8, 11),
        Background2 = Color3.fromRGB(10, 11, 15),
        Surface = Color3.fromRGB(14, 15, 20),
        Surface2 = Color3.fromRGB(18, 19, 24),
        Surface3 = Color3.fromRGB(21, 22, 28),
        Border = Color3.fromRGB(77, 24, 30),
        BorderSoft = Color3.fromRGB(43, 33, 38),
        Accent = Color3.fromRGB(236, 46, 61),
        Accent2 = Color3.fromRGB(177, 22, 39),
        Text = Color3.fromRGB(243, 243, 246),
        TextDim = Color3.fromRGB(150, 150, 159),
        TextFaint = Color3.fromRGB(104, 104, 114),
        Shadow = Color3.fromRGB(0, 0, 0),
    },
    Crimson = {
        Background = Color3.fromRGB(9, 7, 8),
        Background2 = Color3.fromRGB(13, 9, 11),
        Surface = Color3.fromRGB(20, 13, 15),
        Surface2 = Color3.fromRGB(24, 15, 18),
        Surface3 = Color3.fromRGB(31, 18, 21),
        Border = Color3.fromRGB(92, 25, 34),
        BorderSoft = Color3.fromRGB(53, 31, 36),
        Accent = Color3.fromRGB(255, 52, 68),
        Accent2 = Color3.fromRGB(194, 24, 42),
        Text = Color3.fromRGB(248, 245, 246),
        TextDim = Color3.fromRGB(168, 154, 157),
        TextFaint = Color3.fromRGB(112, 99, 103),
        Shadow = Color3.fromRGB(0, 0, 0),
    },
    Midnight = {
        Background = Color3.fromRGB(7, 8, 13),
        Background2 = Color3.fromRGB(10, 11, 18),
        Surface = Color3.fromRGB(13, 15, 23),
        Surface2 = Color3.fromRGB(17, 20, 30),
        Surface3 = Color3.fromRGB(22, 25, 37),
        Border = Color3.fromRGB(38, 45, 68),
        BorderSoft = Color3.fromRGB(30, 34, 48),
        Accent = Color3.fromRGB(122, 137, 255),
        Accent2 = Color3.fromRGB(79, 89, 198),
        Text = Color3.fromRGB(244, 245, 249),
        TextDim = Color3.fromRGB(151, 156, 172),
        TextFaint = Color3.fromRGB(101, 106, 124),
        Shadow = Color3.fromRGB(0, 0, 0),
    },
}

--========================================================
-- WINDOW
--========================================================

function DriftwynUI:CreateWindow(config)
    config = config or {}

    local Window = {}
    Window.Tabs = {}
    Window.Flags = {}
    Window.ThemeObjects = {}
    Window.Theme = config.Theme or "Driftwyn"
    Window.Config = config

    if not Themes[Window.Theme] then
        Window.Theme = "Driftwyn"
    end

    local function T()
        return Themes[Window.Theme]
    end

    local old = GetGuiParent():FindFirstChild("DriftwynUI_" .. tostring(config.Title or "Window"))
    if old then
        old:Destroy()
    end

    local ScreenGui = New("ScreenGui", {
        Name = "DriftwynUI_" .. tostring(config.Title or "Window"),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999999,
        Parent = GetGuiParent()
    })

    Window.ScreenGui = ScreenGui

    local globalConnections = {}
    local destroyed = false
    local function ConnectGlobal(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(globalConnections, connection)
        return connection
    end

    ScreenGui.Destroying:Connect(function()
        destroyed = true
        for _, connection in ipairs(globalConnections) do
            connection:Disconnect()
        end
        table.clear(globalConnections)
        table.clear(Window.ThemeObjects)
    end)

    function Window:Destroy()
        if not destroyed then
            ScreenGui:Destroy()
        end
    end

    function Window:GetFlag(flag)
        return self.Flags[flag]
    end

    -- Only one dropdown popup may be open at a time.
    -- This prevents multiple dropdown menus from stacking over each other.
    local ActiveDropdownClose = nil

    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1366, 768)
    local wanted = config.Size or UDim2.fromOffset(860, 560)
    local width = math.min(wanted.X.Offset, math.max(700, viewport.X - 40))
    local height = math.min(wanted.Y.Offset, math.max(480, viewport.Y - 40))

    local Shadow = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = T().Shadow,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, 8),
        Size = UDim2.fromOffset(width + 18, height + 18),
        ZIndex = 1,
        Parent = ScreenGui
    })
    Corner(Shadow, 16)

    local Root = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = T().Background,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, height),
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = ScreenGui
    })
    Corner(Root, 15)
    local rootStroke = Stroke(Root, T().Border, 1, 0.05)

    AddNoiseDecor(Root, T())

    local Header = New("Frame", {
        BackgroundColor3 = T().Background,
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 75),
        ZIndex = 5,
        Parent = Root
    })

    local headerLine = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = T().Border,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        ZIndex = 6,
        Parent = Header
    })

    local LogoWrap = New("Frame", {
        BackgroundColor3 = T().Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, 10),
        Size = UDim2.fromOffset(58, 58),
        ZIndex = 7,
        Parent = Header
    })
    Corner(LogoWrap, 29)
    local logoStroke = Stroke(LogoWrap, T().Accent, 1.4, 0)

    local Logo
    if config.Icon and config.Icon ~= "" then
        Logo = New("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(3, 3),
            Size = UDim2.new(1, -6, 1, -6),
            Image = type(config.Icon) == "number" and ("rbxassetid://" .. config.Icon) or config.Icon,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 8,
            Parent = LogoWrap
        })
    else
        Logo = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBlack,
            Text = "DH",
            TextColor3 = T().Accent,
            TextSize = 22,
            ZIndex = 8,
            Parent = LogoWrap
        })
    end

    local Title = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(92, 16),
        Size = UDim2.new(0, 360, 0, 29),
        Font = Enum.Font.GothamBold,
        Text = config.Title or "Driftwyn Hub",
        TextColor3 = T().Text,
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = Header
    })

    local Subtitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(92, 45),
        Size = UDim2.new(0, 360, 0, 18),
        Font = Enum.Font.Gotham,
        Text = config.Subtitle or "Modern UI",
        TextColor3 = T().Accent,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = Header
    })

    local Minimize = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = T().Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -77, 0, 38),
        Size = UDim2.fromOffset(42, 42),
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = T().TextDim,
        TextSize = 20,
        ZIndex = 8,
        Parent = Header
    })
    Corner(Minimize, 11)
    local minStroke = Stroke(Minimize, T().BorderSoft, 1, 0)

    local Close = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = T().Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -20, 0, 38),
        Size = UDim2.fromOffset(42, 42),
        Font = Enum.Font.Gotham,
        Text = "×",
        TextColor3 = T().Text,
        TextSize = 32,
        ZIndex = 8,
        Parent = Header
    })
    Corner(Close, 11)
    local closeStroke = Stroke(Close, T().Accent, 1, 0)

    local Sidebar = New("Frame", {
        BackgroundColor3 = T().Background,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 75),
        Size = UDim2.new(0, 235, 1, -75),
        ZIndex = 4,
        Parent = Root
    })

    local sidebarLine = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundColor3 = T().BorderSoft,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        ZIndex = 5,
        Parent = Sidebar
    })

    local SearchBox = New("Frame", {
        BackgroundColor3 = T().Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(16, 16),
        Size = UDim2.new(1, -32, 0, 46),
        ZIndex = 6,
        Parent = Sidebar
    })
    Corner(SearchBox, 10)
    local searchStroke = Stroke(SearchBox, T().BorderSoft, 1, 0.2)

    local searchIcon = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(13, 0),
        Size = UDim2.fromOffset(24, 46),
        Font = Enum.Font.GothamBold,
        Text = "⌕",
        TextColor3 = T().TextFaint,
        TextSize = 23,
        ZIndex = 7,
        Parent = SearchBox
    })

    local Search = New("TextBox", {
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Position = UDim2.fromOffset(43, 0),
        Size = UDim2.new(1, -114, 1, 0),
        Font = Enum.Font.Gotham,
        PlaceholderText = "Search...",
        PlaceholderColor3 = T().TextFaint,
        Text = "",
        TextColor3 = T().Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = SearchBox
    })

    local SearchHint = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = T().Surface2,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -9, 0.5, 0),
        Size = UDim2.fromOffset(58, 25),
        Font = Enum.Font.GothamMedium,
        Text = "CTRL / K",
        TextColor3 = T().TextFaint,
        TextSize = 10,
        ZIndex = 7,
        Parent = SearchBox
    })
    Corner(SearchHint, 6)
    Stroke(SearchHint, T().BorderSoft, 1, 0.25)

    -- Faint lower-left DH watermark from the reference.
    -- Supply a dedicated decal later if you want the exact scratched DH artwork.
    local SidebarWatermark = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 30, 1, -230),
        Size = UDim2.fromOffset(170, 95),
        Font = Enum.Font.GothamBlack,
        Text = "DH",
        TextColor3 = T().Accent,
        TextTransparency = 0.68,
        TextSize = 66,
        Rotation = -9,
        ZIndex = 5,
        Parent = Sidebar
    })

    local SplitArrow = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, 2, 0, 240),
        Size = UDim2.fromOffset(22, 35),
        Font = Enum.Font.GothamBold,
        Text = ">",
        TextColor3 = T().Accent,
        TextSize = 25,
        ZIndex = 9,
        Parent = Sidebar
    })

    local TabList = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 76),
        Size = UDim2.new(1, 0, 1, -160),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        ZIndex = 6,
        Parent = Sidebar
    })
    Padding(TabList, 15, 15, 0, 0)
    New("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = TabList
    })

    local Footer = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = T().Background2,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 84),
        ZIndex = 6,
        Parent = Sidebar
    })
    local footerTop = New("Frame", {
        BackgroundColor3 = T().BorderSoft,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 1),
        Parent = Footer
    })

    local fireCircle = New("Frame", {
        BackgroundColor3 = T().Surface2,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(18, 21),
        Size = UDim2.fromOffset(30, 30),
        Parent = Footer
    })
    Corner(fireCircle, 15)
    local fireIcon = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = Enum.Font.GothamBold,
        Text = "♨",
        TextColor3 = T().Accent,
        TextSize = 18,
        Parent = fireCircle
    })

    local FooterName = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(60, 18),
        Size = UDim2.new(1, -92, 0, 20),
        Font = Enum.Font.GothamBold,
        Text = string.upper(config.Title or "Driftwyn Hub"),
        TextColor3 = T().Accent,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Footer
    })

    local FooterVersion = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(60, 39),
        Size = UDim2.new(1, -92, 0, 20),
        Font = Enum.Font.Gotham,
        Text = config.Version or "v5.7",
        TextColor3 = T().TextDim,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Footer
    })

    local StatusDot = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = T().Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -19, 0.5, 0),
        Size = UDim2.fromOffset(8, 8),
        Parent = Footer
    })
    Corner(StatusDot, 4)
    local dotStroke = Stroke(StatusDot, Lighten(T().Accent, 0.35), 1, 0.25)

    local Content = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(235, 75),
        Size = UDim2.new(1, -235, 1, -75),
        ZIndex = 4,
        Parent = Root
    })

    local PageHolder = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -12, 1, 0),
        ZIndex = 5,
        Parent = Content
    })

    local NotificationHolder = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -14, 0, 14),
        Size = UDim2.fromOffset(320, 500),
        ZIndex = 200,
        Parent = ScreenGui
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = NotificationHolder
    })

    Window._themeApply = function() end

    local themed = {}
    local function ThemeBind(fn)
        table.insert(themed, fn)
        pcall(fn, T())
    end

    ThemeBind(function(th)
        Root.BackgroundColor3 = th.Background
        rootStroke.Color = th.Border
        Shadow.BackgroundColor3 = th.Shadow
        Header.BackgroundColor3 = th.Background
        headerLine.BackgroundColor3 = th.Border
        LogoWrap.BackgroundColor3 = th.Surface
        logoStroke.Color = th.Accent
        Title.TextColor3 = th.Text
        Subtitle.TextColor3 = th.Accent
        Minimize.BackgroundColor3 = th.Surface
        Minimize.TextColor3 = th.TextDim
        minStroke.Color = th.BorderSoft
        Close.BackgroundColor3 = th.Surface
        Close.TextColor3 = th.Text
        closeStroke.Color = th.Accent
        Sidebar.BackgroundColor3 = th.Background
        sidebarLine.BackgroundColor3 = th.BorderSoft
        SearchBox.BackgroundColor3 = th.Surface
        searchStroke.Color = th.BorderSoft
        searchIcon.TextColor3 = th.TextFaint
        Search.TextColor3 = th.Text
        Search.PlaceholderColor3 = th.TextFaint
        SearchHint.BackgroundColor3 = th.Surface2
        SearchHint.TextColor3 = th.TextFaint
        Footer.BackgroundColor3 = th.Background2
        footerTop.BackgroundColor3 = th.BorderSoft
        fireCircle.BackgroundColor3 = th.Surface2
        fireIcon.TextColor3 = th.Accent
        FooterName.TextColor3 = th.Accent
        FooterVersion.TextColor3 = th.TextDim
        SidebarWatermark.TextColor3 = th.Accent
        SplitArrow.TextColor3 = th.Accent
        StatusDot.BackgroundColor3 = th.Accent
        dotStroke.Color = Lighten(th.Accent, 0.35)
    end)

    function Window:_ApplyTheme()
        for _, fn in ipairs(themed) do
            pcall(fn, T())
        end
    end

    function Window:GetThemes()
        local out = {}
        for name in pairs(Themes) do
            table.insert(out, name)
        end
        table.sort(out)
        return out
    end

    function Window:GetTheme()
        return self.Theme
    end

    function Window:SetTheme(name)
        if not Themes[name] then
            return false
        end
        self.Theme = name
        self:_ApplyTheme()
        return true
    end

    function Window:Notify(data)
        data = data or {}
        local duration = tonumber(data.Duration) or 4

        local Card = New("Frame", {
            BackgroundColor3 = T().Surface,
            BackgroundTransparency = 0.02,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(310, 0),
            ClipsDescendants = true,
            ZIndex = 210,
            Parent = NotificationHolder
        })
        Corner(Card, 10)
        local cStroke = Stroke(Card, T().Border, 1, 0.05)

        local Accent = New("Frame", {
            BackgroundColor3 = T().Accent,
            BorderSizePixel = 0,
            Size = UDim2.new(0, 3, 1, 0),
            ZIndex = 211,
            Parent = Card
        })

        local NTitle = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(16, 10),
            Size = UDim2.new(1, -28, 0, 19),
            Font = Enum.Font.GothamBold,
            Text = data.Title or "Driftwyn",
            TextColor3 = T().Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 211,
            Parent = Card
        })

        local NContent = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(16, 31),
            Size = UDim2.new(1, -28, 0, 34),
            Font = Enum.Font.Gotham,
            Text = data.Content or "",
            TextColor3 = T().TextDim,
            TextSize = 11,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 211,
            Parent = Card
        })

        local Progress = New("Frame", {
            BackgroundColor3 = T().Accent,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 3, 1, -2),
            Size = UDim2.new(1, -3, 0, 2),
            ZIndex = 212,
            Parent = Card
        })

        ThemeBind(function(th)
            Card.BackgroundColor3 = th.Surface
            cStroke.Color = th.Border
            Accent.BackgroundColor3 = th.Accent
            NTitle.TextColor3 = th.Text
            NContent.TextColor3 = th.TextDim
            Progress.BackgroundColor3 = th.Accent
        end)

        Card.Size = UDim2.fromOffset(310, 0)
        Tween(Card, 0.24, {Size = UDim2.fromOffset(310, 72)})
        Tween(Progress, duration, {Size = UDim2.new(0, 0, 0, 2)}, Enum.EasingStyle.Linear)

        task.delay(duration, function()
            if Card and Card.Parent then
                Tween(Card, 0.2, {Size = UDim2.fromOffset(310, 0)})
                task.wait(0.22)
                if Card then Card:Destroy() end
            end
        end)
    end

    local hidden = false
    local minimized = false
    local fullSize = Root.Size

    --========================================================
    -- MINI CIRCLE
    --========================================================

    local MiniCircle = New("TextButton", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        AutoButtonColor = false,
        BackgroundColor3 = T().Surface,
        BorderSizePixel = 0,
        Position = Root.Position,
        Size = UDim2.fromOffset(60, 60),
        Text = "",
        Visible = false,
        ZIndex = 300,
        Parent = ScreenGui
    })
    Corner(MiniCircle, 30)

    local miniStroke = Stroke(MiniCircle, T().Accent, 2, 0)

    local MiniInner = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = T().Background2,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(50, 50),
        ZIndex = 301,
        Parent = MiniCircle
    })
    Corner(MiniInner, 25)

    local MiniIcon
    local MiniIconKind

    if config.Icon and config.Icon ~= "" then
        MiniIcon = New("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(42, 42),
            Image = ResolveIconContent(config.Icon),
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 302,
            Parent = MiniInner
        })
        MiniIconKind = "image"
    else
        MiniIcon = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBlack,
            Text = "DH",
            TextColor3 = T().Accent,
            TextSize = 18,
            ZIndex = 302,
            Parent = MiniInner
        })
        MiniIconKind = "text"
    end

    ThemeBind(function(th)
        MiniCircle.BackgroundColor3 = th.Surface
        MiniInner.BackgroundColor3 = th.Background2
        miniStroke.Color = th.Accent

        if MiniIconKind == "text" then
            MiniIcon.TextColor3 = th.Accent
        end
    end)

    -- The minimized circle can be moved anywhere on screen.
    ConnectDrag(MiniCircle, MiniCircle, ConnectGlobal)

    local restoreDebounce = false
    local miniDragStart
    local miniMoved = false

    MiniCircle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            miniDragStart = input.Position
            miniMoved = false
        end
    end)

    ConnectGlobal(UserInputService.InputChanged, function(input)
        if miniDragStart and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            if (input.Position - miniDragStart).Magnitude > 6 then
                miniMoved = true
            end
        end
    end)

    ConnectGlobal(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            task.delay(0.05, function()
                miniDragStart = nil
            end)
        end
    end)

    local function minimizeWindow()
        if minimized or restoreDebounce then
            return
        end

        restoreDebounce = true
        minimized = true
        fullSize = Root.Size

        -- Put the circle where the full window currently is.
        MiniCircle.Position = Root.Position

        Tween(
            Root,
            0.30,
            {Size = UDim2.fromOffset(60, 60)},
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.InOut
        )

        Tween(
            Shadow,
            0.30,
            {Size = UDim2.fromOffset(72, 72)},
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.InOut
        )

        task.delay(0.28, function()
            if not ScreenGui.Parent then
                return
            end

            if minimized then
                Root.Visible = false
                Shadow.Visible = false

                if not hidden then
                    MiniCircle.Visible = true
                end
            end

            restoreDebounce = false
        end)
    end

    local function restoreWindow()
        if not minimized or restoreDebounce then
            return
        end

        restoreDebounce = true
        minimized = false

        local restorePosition = MiniCircle.Position

        MiniCircle.Visible = false

        Root.Position = restorePosition
        Root.Size = UDim2.fromOffset(60, 60)
        Root.Visible = not hidden

        Shadow.Position = restorePosition + UDim2.fromOffset(0, 8)
        Shadow.Size = UDim2.fromOffset(72, 72)
        Shadow.Visible = not hidden

        if not hidden then
            Tween(
                Root,
                0.34,
                {Size = fullSize},
                Enum.EasingStyle.Back,
                Enum.EasingDirection.Out
            )

            Tween(
                Shadow,
                0.34,
                {Size = UDim2.fromOffset(width + 18, height + 18)},
                Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out
            )
        else
            Root.Size = fullSize
            Shadow.Size = UDim2.fromOffset(width + 18, height + 18)
        end

        task.delay(0.35, function()
            restoreDebounce = false
        end)
    end

    function Window:SetVisible(state)
        state = state ~= false
        hidden = not state

        if not state and ActiveDropdownClose then
            ActiveDropdownClose()
        end

        if minimized then
            Root.Visible = false
            Shadow.Visible = false
            MiniCircle.Visible = state
        else
            MiniCircle.Visible = false
            Root.Visible = state
            Shadow.Visible = state
        end
    end

    function Window:Toggle()
        self:SetVisible(hidden)
    end

    function Window:IsMinimized()
        return minimized
    end

    function Window:Minimize()
        if ActiveDropdownClose then
            ActiveDropdownClose()
        end
        minimizeWindow()
    end

    function Window:Restore()
        restoreWindow()
    end

    Minimize.MouseButton1Click:Connect(minimizeWindow)

    MiniCircle.MouseButton1Click:Connect(function()
        -- Dragging the circle should not accidentally restore the window.
        if miniMoved then
            miniMoved = false
            return
        end

        restoreWindow()
    end)

    MiniCircle.MouseEnter:Connect(function()
        Tween(
            MiniCircle,
            0.24,
            {
                Size = UDim2.fromOffset(66, 66),
                BackgroundColor3 = T().Surface2
            },
            Enum.EasingStyle.Back,
            Enum.EasingDirection.Out
        )
    end)

    MiniCircle.MouseLeave:Connect(function()
        Tween(
            MiniCircle,
            0.24,
            {
                Size = UDim2.fromOffset(60, 60),
                BackgroundColor3 = T().Surface
            },
            Enum.EasingStyle.Quint,
            Enum.EasingDirection.Out
        )
    end)

    Close.MouseButton1Click:Connect(function()
        if ActiveDropdownClose then
            ActiveDropdownClose()
        end
        Window:Destroy()
    end)

    Close.MouseEnter:Connect(function()
        Tween(Close, 0.15, {BackgroundColor3 = Darken(T().Accent, 0.62)})
    end)
    Close.MouseLeave:Connect(function()
        Tween(Close, 0.15, {BackgroundColor3 = T().Surface})
    end)

    Minimize.MouseEnter:Connect(function()
        Tween(Minimize, 0.15, {BackgroundColor3 = T().Surface2})
    end)
    Minimize.MouseLeave:Connect(function()
        Tween(Minimize, 0.15, {BackgroundColor3 = T().Surface})
    end)

    ConnectDrag(Header, Root, ConnectGlobal)

    -- keep the shadow following the dragged root
    ConnectGlobal(RunService.RenderStepped, function()
        if not ScreenGui.Parent then return end
        Shadow.Position = Root.Position + UDim2.fromOffset(0, 8)
    end)

    ConnectGlobal(UserInputService.InputBegan, function(input, processed)
        if processed then return end

        if UserInputService:GetFocusedTextBox() then return end

        if input.KeyCode == (config.ToggleKey or Enum.KeyCode.RightControl) then
            Window:Toggle()
        end

        if input.KeyCode == Enum.KeyCode.K
        and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            if Root.Visible then
                Search:CaptureFocus()
            end
        end
    end)

    local function selectTab(tab)
        for _, t in ipairs(Window.Tabs) do
            local selectedNow = (t == tab)
            t.Selected = selectedNow

            if selectedNow then
                t.Page.Visible = true
                t.Page.Position = UDim2.fromOffset(9, 0)

                Tween(
                    t.Page,
                    0.24,
                    {Position = UDim2.fromOffset(0, 0)},
                    Enum.EasingStyle.Quint,
                    Enum.EasingDirection.Out
                )

                Tween(t.Button, 0.20, {BackgroundTransparency = 0})
                Tween(t.SideAccent, 0.20, {BackgroundTransparency = 0})
                Tween(t.NameLabel, 0.20, {TextColor3 = T().Accent})

                if t.IconObject then
                    if t.IconKind == "image" then
                        Tween(t.IconObject, 0.20, {ImageColor3 = T().Accent})
                    else
                        Tween(t.IconObject, 0.20, {TextColor3 = T().Accent})
                    end
                end
            else
                t.Page.Visible = false

                Tween(t.Button, 0.20, {BackgroundTransparency = 1})
                Tween(t.SideAccent, 0.20, {BackgroundTransparency = 1})
                Tween(t.NameLabel, 0.20, {TextColor3 = T().TextDim})

                if t.IconObject then
                    if t.IconKind == "image" then
                        Tween(t.IconObject, 0.20, {ImageColor3 = T().TextFaint})
                    else
                        Tween(t.IconObject, 0.20, {TextColor3 = T().TextFaint})
                    end
                end
            end
        end
    end

    function Window:AddTab(data)
        data = data or {}

        local Tab = {}
        Tab.Sections = {}
        Tab.Rows = {}
        Tab.Name = data.Name or "Tab"
        Tab.Description = data.Description or ""
        Tab.Icon = data.Icon or ""
        Tab.Window = Window

        local TabButton = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = T().Surface2,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 48),
            Text = "",
            ZIndex = 7,
            Parent = TabList
        })
        Corner(TabButton, 9)
        local tbStroke = Stroke(TabButton, T().Border, 1, 1)

        local SideAccent = New("Frame", {
            BackgroundColor3 = T().Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 8),
            Size = UDim2.fromOffset(3, 32),
            ZIndex = 8,
            Parent = TabButton
        })
        Corner(SideAccent, 2)

        local IconHolder = New("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(14, 12),
            Size = UDim2.fromOffset(24, 24),
            ZIndex = 8,
            Parent = TabButton
        })
        local tabFallback = (string.lower(Tab.Name) == "visuals" and "◉") or (string.lower(Tab.Name) == "main" and "⌂") or "◆"
        local iconObject, iconKind = MakeIcon(IconHolder, data.Icon, 20, T().TextFaint, tabFallback)
        iconObject.AnchorPoint = Vector2.new(0.5, 0.5)
        iconObject.Position = UDim2.fromScale(0.5, 0.5)

        local NameLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(49, 0),
            Size = UDim2.new(1, -58, 1, 0),
            Font = Enum.Font.GothamMedium,
            Text = Tab.Name,
            TextColor3 = T().TextDim,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 8,
            Parent = TabButton
        })

        local Page = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            ZIndex = 6,
            Parent = PageHolder
        })

        local PageTop = New("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 15),
            Size = UDim2.new(1, -36, 0, 70),
            ZIndex = 7,
            Parent = Page
        })

        local diamond = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(1, 1),
            Size = UDim2.fromOffset(26, 28),
            Font = Enum.Font.GothamBold,
            Text = "◇",
            TextColor3 = T().Accent,
            TextSize = 22,
            ZIndex = 8,
            Parent = PageTop
        })

        local PageTitle = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(34, 0),
            Size = UDim2.new(1, -34, 0, 31),
            Font = Enum.Font.GothamBold,
            Text = Tab.Name,
            TextColor3 = T().Text,
            TextSize = 22,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 8,
            Parent = PageTop
        })

        local PageDesc = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(34, 31),
            Size = UDim2.new(1, -34, 0, 20),
            Font = Enum.Font.Gotham,
            Text = Tab.Description,
            TextColor3 = T().TextDim,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 8,
            Parent = PageTop
        })

        local Line = New("Frame", {
            BackgroundColor3 = T().Accent,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(35, 61),
            Size = UDim2.fromOffset(94, 1),
            ZIndex = 8,
            Parent = PageTop
        })

        local Line2 = New("Frame", {
            BackgroundColor3 = T().BorderSoft,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(129, 61),
            Size = UDim2.new(1, -129, 0, 1),
            ZIndex = 8,
            Parent = PageTop
        })

        local sparkle = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(124, 48),
            Size = UDim2.fromOffset(28, 28),
            Font = Enum.Font.GothamBold,
            Text = "✦",
            TextColor3 = Lighten(T().Accent, 0.35),
            TextSize = 13,
            ZIndex = 9,
            Parent = PageTop
        })

        local Scroll = New("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(18, 86),
            Size = UDim2.new(1, -36, 1, -97),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T().Accent,
            ScrollBarImageTransparency = 0.35,
            ZIndex = 7,
            Parent = Page
        })
        Padding(Scroll, 0, 7, 0, 10)
        New("UIListLayout", {
            Padding = UDim.new(0, 11),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = Scroll
        })

        Tab.Button = TabButton
        Tab.SideAccent = SideAccent
        Tab.NameLabel = NameLabel
        Tab.IconObject = iconObject
        Tab.IconKind = iconKind
        Tab.Page = Page
        Tab.Scroll = Scroll

        ThemeBind(function(th)
            TabButton.BackgroundColor3 = th.Surface2
            tbStroke.Color = th.Border
            SideAccent.BackgroundColor3 = th.Accent
            PageTitle.TextColor3 = th.Text
            PageDesc.TextColor3 = th.TextDim
            diamond.TextColor3 = th.Accent
            Line.BackgroundColor3 = th.Accent
            Line2.BackgroundColor3 = th.BorderSoft
            sparkle.TextColor3 = Lighten(th.Accent, 0.35)
            Scroll.ScrollBarImageColor3 = th.Accent

            if Tab.Selected then
                NameLabel.TextColor3 = th.Accent
                if iconKind == "image" then iconObject.ImageColor3 = th.Accent
                else iconObject.TextColor3 = th.Accent end
            else
                NameLabel.TextColor3 = th.TextDim
                if iconKind == "image" then iconObject.ImageColor3 = th.TextFaint
                else iconObject.TextColor3 = th.TextFaint end
            end
        end)

        TabButton.MouseEnter:Connect(function()
            if not Tab.Selected then
                Tween(TabButton, 0.14, {BackgroundTransparency = 0.65})
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if not Tab.Selected then
                Tween(TabButton, 0.14, {BackgroundTransparency = 1})
            end
        end)
        TabButton.MouseButton1Click:Connect(function()
            selectTab(Tab)
        end)

        local function refreshSectionVisibility()
            local query = string.lower(Search.Text or "")
            for _, section in ipairs(Tab.Sections) do
                local visibleCount = 0
                for _, rowInfo in ipairs(section.Rows) do
                    local hit = query == ""
                        or string.find(string.lower(rowInfo.Name), query, 1, true)
                        or string.find(string.lower(rowInfo.Description or ""), query, 1, true)
                    rowInfo.Frame.Visible = hit
                    if hit then visibleCount = visibleCount + 1 end
                end
                section.Root.Visible = (query == "") or visibleCount > 0
            end
        end

        Search:GetPropertyChangedSignal("Text"):Connect(refreshSectionVisibility)

        function Tab:AddSection(sectionData)
            sectionData = sectionData or {}

            local Section = {}
            Section.Rows = {}
            Section.Tab = Tab
            Section.Name = sectionData.Name or "Section"
            Section.Description = sectionData.Description or ""

            local SectionRoot = New("Frame", {
                BackgroundColor3 = T().Background2,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 100),
                AutomaticSize = Enum.AutomaticSize.Y,
                ZIndex = 8,
                Parent = Scroll
            })
            Corner(SectionRoot, 12)
            local sectionStroke = Stroke(SectionRoot, T().Border, 1, 0.12)
            Padding(SectionRoot, 14, 14, 14, 14)

            local Layout = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = SectionRoot
            })

            local SectionHeader = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 42),
                LayoutOrder = 0,
                ZIndex = 9,
                Parent = SectionRoot
            })

            local SectionIconCircle = New("Frame", {
                BackgroundColor3 = T().Surface2,
                BorderSizePixel = 0,
                Position = UDim2.fromOffset(0, 0),
                Size = UDim2.fromOffset(35, 35),
                ZIndex = 10,
                Parent = SectionHeader
            })
            Corner(SectionIconCircle, 18)
            local sectionIconStroke = Stroke(SectionIconCircle, T().Border, 1, 0.1)

            local SectionIcon = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Font = Enum.Font.GothamBold,
                Text = "●",
                TextColor3 = T().Accent,
                TextSize = 16,
                ZIndex = 11,
                Parent = SectionIconCircle
            })

            local SectionName = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(46, 0),
                Size = UDim2.new(1, -46, 0, 20),
                Font = Enum.Font.GothamBold,
                Text = Section.Name,
                TextColor3 = T().Accent,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 10,
                Parent = SectionHeader
            })

            local SectionDesc = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(46, 20),
                Size = UDim2.new(1, -46, 0, 18),
                Font = Enum.Font.Gotham,
                Text = Section.Description,
                TextColor3 = T().TextDim,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 10,
                Parent = SectionHeader
            })

            Section.Root = SectionRoot

            ThemeBind(function(th)
                SectionRoot.BackgroundColor3 = th.Background2
                sectionStroke.Color = th.Border
                SectionIconCircle.BackgroundColor3 = th.Surface2
                sectionIconStroke.Color = th.Border
                SectionIcon.TextColor3 = th.Accent
                SectionName.TextColor3 = th.Accent
                SectionDesc.TextColor3 = th.TextDim
            end)

            local function MakeRow(rowData, kind, fallbackIcon)
                rowData = rowData or {}
                local Row = New("Frame", {
                    BackgroundColor3 = T().Surface,
                    BorderSizePixel = 0,
                    Size = UDim2.new(1, 0, 0, 58),
                    LayoutOrder = #Section.Rows * 2 + 1,
                    ZIndex = 9,
                    Parent = SectionRoot
                })
                Corner(Row, 10)
                local rowStroke = Stroke(Row, T().BorderSoft, 1, 0.3)

                local IconCircle = New("Frame", {
                    BackgroundColor3 = T().Surface2,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(10, 10),
                    Size = UDim2.fromOffset(38, 38),
                    ZIndex = 10,
                    Parent = Row
                })
                Corner(IconCircle, 19)
                local iconStroke = Stroke(IconCircle, T().Border, 1, 0.12)

                local iconObj, iconKind = MakeIcon(IconCircle, rowData.Icon, 18, T().Accent, fallbackIcon or "◆")
                iconObj.AnchorPoint = Vector2.new(0.5, 0.5)
                iconObj.Position = UDim2.fromScale(0.5, 0.5)
                iconObj.ZIndex = 11

                local RowName = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(60, 8),
                    Size = UDim2.new(1, -260, 0, 20),
                    Font = Enum.Font.GothamMedium,
                    Text = rowData.Name or kind,
                    TextColor3 = T().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 10,
                    Parent = Row
                })

                local RowDesc = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(60, 29),
                    Size = UDim2.new(1, -260, 0, 18),
                    Font = Enum.Font.Gotham,
                    Text = rowData.Description or "",
                    TextColor3 = T().TextDim,
                    TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 10,
                    Parent = Row
                })

                local info = {
                    Frame = Row,
                    Name = rowData.Name or kind,
                    Description = rowData.Description or "",
                }
                table.insert(Section.Rows, info)
                table.insert(Tab.Rows, info)

                ThemeBind(function(th)
                    Row.BackgroundColor3 = th.Surface
                    rowStroke.Color = th.BorderSoft
                    IconCircle.BackgroundColor3 = th.Surface2
                    iconStroke.Color = th.Border
                    RowName.TextColor3 = th.Text
                    RowDesc.TextColor3 = th.TextDim
                    if iconKind == "image" then
                        iconObj.ImageColor3 = th.Accent
                    else
                        iconObj.TextColor3 = th.Accent
                    end
                end)

                Row.MouseEnter:Connect(function()
                    Tween(
                        Row,
                        0.22,
                        {BackgroundColor3 = T().Surface2},
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.Out
                    )
                end)

                Row.MouseLeave:Connect(function()
                    Tween(
                        Row,
                        0.24,
                        {BackgroundColor3 = T().Surface},
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.Out
                    )
                end)

                return Row, RowName, RowDesc
            end

            function Section:AddToggle(rowData)
                rowData = rowData or {}
                local Row = MakeRow(rowData, "Toggle", "⊙")

                local Track = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    AutoButtonColor = false,
                    BackgroundColor3 = T().Surface3,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -13, 0.5, 0),
                    Size = UDim2.fromOffset(43, 24),
                    Text = "",
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(Track, 12)
                local trackStroke = Stroke(Track, T().BorderSoft, 1, 0.1)

                local Knob = New("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = T().Text,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 3, 0.5, 0),
                    Size = UDim2.fromOffset(18, 18),
                    ZIndex = 13,
                    Parent = Track
                })
                Corner(Knob, 9)

                local value = rowData.Default == true
                local flag = rowData.Flag
                if flag then Window.Flags[flag] = value end

                local function render(animated)
                    local pos = value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
                    local col = value and T().Accent or T().Surface3
                    if animated then
                        Tween(
                            Track,
                            0.24,
                            {BackgroundColor3 = col},
                            Enum.EasingStyle.Quint,
                            Enum.EasingDirection.Out
                        )

                        Tween(
                            Knob,
                            0.26,
                            {Position = pos},
                            Enum.EasingStyle.Back,
                            Enum.EasingDirection.Out
                        )
                    else
                        Track.BackgroundColor3 = col
                        Knob.Position = pos
                    end
                end

                local function set(v, call)
                    value = not not v
                    if flag then Window.Flags[flag] = value end
                    render(true)
                    if call ~= false and rowData.Callback then
                        task.spawn(rowData.Callback, value)
                    end
                end

                Track.MouseButton1Click:Connect(function()
                    set(not value, true)
                end)
                Row.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local p = UserInputService:GetMouseLocation()
                        local ap = Track.AbsolutePosition
                        local as = Track.AbsoluteSize
                        if not (p.X >= ap.X and p.X <= ap.X + as.X and p.Y >= ap.Y and p.Y <= ap.Y + as.Y) then
                            set(not value, true)
                        end
                    end
                end)

                ThemeBind(function(th)
                    trackStroke.Color = th.BorderSoft
                    Knob.BackgroundColor3 = th.Text
                    render(false)
                end)

                render(false)

                return {
                    Set = function(_, v) set(v, true) end,
                    Get = function() return value end
                }
            end

            function Section:AddSlider(rowData)
                rowData = rowData or {}
                local Row = MakeRow(rowData, "Slider", "➜")

                local min = tonumber(rowData.Min) or 0
                local max = tonumber(rowData.Max) or 100
                local step = tonumber(rowData.Step) or 1
                if max < min then min, max = max, min end
                if step <= 0 or step ~= step then step = 1 end
                local value = math.clamp(tonumber(rowData.Default) or min, min, max)
                local flag = rowData.Flag
                if flag then Window.Flags[flag] = value end

                local ValueBox = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0),
                    BackgroundColor3 = T().Background2,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -12, 0, 10),
                    Size = UDim2.fromOffset(50, 30),
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(ValueBox, 8)
                local valueStroke = Stroke(ValueBox, T().BorderSoft, 1, 0.25)

                local ValueLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Font = Enum.Font.GothamBold,
                    Text = tostring(value),
                    TextColor3 = T().Accent,
                    TextSize = 12,
                    ZIndex = 13,
                    Parent = ValueBox
                })

                local Track = New("Frame", {
                    BackgroundColor3 = T().Surface3,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(60, 48),
                    Size = UDim2.new(1, -130, 0, 4),
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(Track, 2)

                local Fill = New("Frame", {
                    BackgroundColor3 = T().Accent,
                    BorderSizePixel = 0,
                    Size = UDim2.new(0, 0, 1, 0),
                    ZIndex = 13,
                    Parent = Track
                })
                Corner(Fill, 2)

                local Knob = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = T().Accent,
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale(0, 0.5),
                    Size = UDim2.fromOffset(14, 14),
                    ZIndex = 14,
                    Parent = Track
                })
                Corner(Knob, 7)
                local knobStroke = Stroke(Knob, Lighten(T().Accent, 0.3), 2, 0.05)

                local dragging = false

                local function ratioFor(v)
                    if max == min then return 0 end
                    return (v - min) / (max - min)
                end

                local function render()
                    local r = math.clamp(ratioFor(value), 0, 1)
                    Fill.Size = UDim2.new(r, 0, 1, 0)
                    Knob.Position = UDim2.new(r, 0, 0.5, 0)
                    ValueLabel.Text = tostring(value)
                end

                local function set(v, call)
                    v = tonumber(v) or min
                    v = math.clamp(v, min, max)
                    v = math.floor(((v - min) / step) + 0.5) * step + min
                    v = math.clamp(v, min, max)
                    local decimals = step < 1 and math.min(8, math.max(0, math.ceil(-math.log10(step)))) or 0
                    value = tonumber(string.format("%." .. decimals .. "f", v))

                    if flag then Window.Flags[flag] = value end
                    render()
                    if call ~= false and rowData.Callback then
                        task.spawn(rowData.Callback, value)
                    end
                end

                local function updateFromX(x)
                    local r = math.clamp((x - Track.AbsolutePosition.X) / math.max(1, Track.AbsoluteSize.X), 0, 1)
                    set(min + (max - min) * r, true)
                end

                Track.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        updateFromX(input.Position.X)
                    end
                end)
                Knob.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                    end
                end)
                ConnectGlobal(UserInputService.InputChanged, function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                    or input.UserInputType == Enum.UserInputType.Touch) then
                        updateFromX(input.Position.X)
                    end
                end)
                ConnectGlobal(UserInputService.InputEnded, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = false
                    end
                end)

                ThemeBind(function(th)
                    ValueBox.BackgroundColor3 = th.Background2
                    valueStroke.Color = th.BorderSoft
                    ValueLabel.TextColor3 = th.Accent
                    Track.BackgroundColor3 = th.Surface3
                    Fill.BackgroundColor3 = th.Accent
                    Knob.BackgroundColor3 = th.Accent
                    knobStroke.Color = Lighten(th.Accent, 0.3)
                end)

                render()

                return {
                    Set = function(_, v) set(v, true) end,
                    Get = function() return value end
                }
            end

            function Section:AddDropdown(rowData)
                rowData = rowData or {}

                local Row = MakeRow(rowData, "Dropdown", "♛")
                local values = rowData.Values or {}
                local multi = rowData.Multi == true
                local searchable = rowData.Searchable == true
                local flag = rowData.Flag
                local placeholder = tostring(rowData.Placeholder or "Select...")

                local value
                local selected = {}

                local function copySelected()
                    local copy = {}
                    for k, v in pairs(selected) do
                        if v == true then
                            copy[k] = true
                        end
                    end
                    return copy
                end

                if multi then
                    local default = rowData.Default

                    if type(default) == "table" then
                        for k, v in pairs(default) do
                            if type(k) == "number" then
                                if table.find(values, v) then
                                    selected[v] = true
                                end
                            elseif v == true and table.find(values, k) then
                                selected[k] = true
                            end
                        end
                    elseif default ~= nil and table.find(values, default) then
                        selected[default] = true
                    end

                    value = copySelected()
                else
                    local default = rowData.Default

                    if type(default) == "number" and values[default] ~= nil then
                        default = values[default]
                    end

                    value = default or values[1] or "None"
                end

                local Button = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    AutoButtonColor = false,
                    BackgroundColor3 = T().Background2,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(185, 34),
                    Font = Enum.Font.Gotham,
                    Text = "",
                    TextColor3 = T().Text,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(Button, 8)

                local buttonStroke = Stroke(Button, T().Border, 1, 0.05)

                local ButtonScale = New("UIScale", {
                    Scale = 1,
                    Parent = Button
                })

                local Arrow = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundTransparency = 1,
                    Position = UDim2.new(1, -9, 0.5, 0),
                    Size = UDim2.fromOffset(16, 16),
                    Rotation = 0,
                    ZIndex = 13,
                    Parent = Button
                })

                local ArrowLeft = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = T().Accent,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0.5, 1, 0.5, 0),
                    Size = UDim2.fromOffset(7, 2),
                    Rotation = 42,
                    ZIndex = 14,
                    Parent = Arrow
                })
                Corner(ArrowLeft, 1)

                local ArrowRight = New("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundColor3 = T().Accent,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0.5, -1, 0.5, 0),
                    Size = UDim2.fromOffset(7, 2),
                    Rotation = -42,
                    ZIndex = 14,
                    Parent = Arrow
                })
                Corner(ArrowRight, 1)

                local popup
                local popupScale
                local opened = false

                local function selectedCount()
                    local count = 0
                    for _, v in ipairs(values) do
                        if selected[v] then
                            count = count + 1
                        end
                    end
                    return count
                end

                local function updateFlag()
                    if not flag then
                        return
                    end

                    if multi then
                        Window.Flags[flag] = copySelected()
                    else
                        Window.Flags[flag] = value
                    end
                end

                local function getCurrentValue()
                    if multi then
                        return copySelected()
                    end
                    return value
                end

                local function updateButton()
                    if not multi then
                        Button.Text = "   " .. tostring(value)
                        return
                    end

                    local chosen = {}

                    for _, v in ipairs(values) do
                        if selected[v] then
                            table.insert(chosen, tostring(v))
                        end
                    end

                    if #chosen == 0 then
                        Button.Text = "   " .. placeholder
                    elseif #chosen <= 2 then
                        Button.Text = "   " .. table.concat(chosen, ", ")
                    else
                        Button.Text = "   " .. tostring(#chosen) .. " selected"
                    end
                end

                local function fireCallback()
                    updateFlag()
                    if rowData.Callback then
                        task.spawn(rowData.Callback, getCurrentValue())
                    end
                end

                local function closePopup(instant)
                    if not opened and not popup then
                        return
                    end

                    opened = false

                    if ActiveDropdownClose == closePopup then
                        ActiveDropdownClose = nil
                    end

                    Tween(
                        Arrow,
                        instant and 0.01 or 0.24,
                        {Rotation = 0},
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out
                    )

                    Tween(
                        Button,
                        instant and 0.01 or 0.16,
                        {BackgroundColor3 = T().Background2}
                    )

                    Tween(
                        buttonStroke,
                        instant and 0.01 or 0.16,
                        {Color = T().Border}
                    )

                    local closingPopup = popup
                    local closingScale = popupScale
                    popup = nil
                    popupScale = nil

                    if not closingPopup or not closingPopup.Parent then
                        return
                    end

                    if instant then
                        closingPopup:Destroy()
                        return
                    end

                    local currentSize = closingPopup.Size

                    Tween(
                        closingPopup,
                        0.26,
                        {
                            Size = UDim2.new(currentSize.X.Scale, currentSize.X.Offset, 0, 0),
                            GroupTransparency = 1
                        },
                        Enum.EasingStyle.Quart,
                        Enum.EasingDirection.In
                    )

                    if closingScale then
                        Tween(
                            closingScale,
                            0.26,
                            {Scale = 0.94},
                            Enum.EasingStyle.Quart,
                            Enum.EasingDirection.In
                        )
                    end

                    task.delay(0.27, function()
                        if closingPopup and closingPopup.Parent then
                            closingPopup:Destroy()
                        end
                    end)
                end

                local function setSingle(v, call)
                    if v == nil then
                        return
                    end

                    value = v
                    updateButton()
                    updateFlag()

                    if call ~= false and rowData.Callback then
                        task.spawn(rowData.Callback, value)
                    end

                    closePopup(false)
                end

                local function setMulti(newValue, call)
                    if type(newValue) == "table" then
                        selected = {}

                        for k, v in pairs(newValue) do
                            if type(k) == "number" then
                                if table.find(values, v) then
                                    selected[v] = true
                                end
                            elseif v == true and table.find(values, k) then
                                selected[k] = true
                            end
                        end
                    elseif newValue ~= nil and table.find(values, newValue) then
                        selected[newValue] = not selected[newValue]

                        if not selected[newValue] then
                            selected[newValue] = nil
                        end
                    end

                    value = copySelected()
                    updateButton()
                    updateFlag()

                    if call ~= false and rowData.Callback then
                        task.spawn(rowData.Callback, copySelected())
                    end
                end

                local function set(v, call)
                    if multi then
                        setMulti(v, call)
                    else
                        setSingle(v, call)
                    end
                end

                updateButton()
                updateFlag()

                Button.MouseEnter:Connect(function()
                    if not opened then
                        Tween(Button, 0.16, {
                            BackgroundColor3 = T().Surface
                        })

                        Tween(buttonStroke, 0.16, {
                            Color = T().BorderSoft
                        })
                    end

                    Tween(ButtonScale, 0.20, {
                        Scale = 1.012
                    })
                end)

                Button.MouseLeave:Connect(function()
                    if not opened then
                        Tween(Button, 0.16, {
                            BackgroundColor3 = T().Background2
                        })

                        Tween(buttonStroke, 0.16, {
                            Color = T().Border
                        })
                    end

                    Tween(ButtonScale, 0.20, {
                        Scale = 1
                    })
                end)

                Button.MouseButton1Down:Connect(function()
                    Tween(ButtonScale, 0.11, {
                        Scale = 0.985
                    })
                end)

                Button.MouseButton1Up:Connect(function()
                    Tween(ButtonScale, 0.18, {
                        Scale = 1.012
                    })
                end)

                Button.MouseButton1Click:Connect(function()
                    if opened then
                        closePopup(false)
                        return
                    end

                    if ActiveDropdownClose and ActiveDropdownClose ~= closePopup then
                        ActiveDropdownClose(true)
                    end

                    opened = true
                    ActiveDropdownClose = closePopup

                    Tween(
                        Arrow,
                        0.30,
                        {Rotation = 180},
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out
                    )

                    Tween(Button, 0.18, {
                        BackgroundColor3 = T().Surface
                    })

                    Tween(buttonStroke, 0.18, {
                        Color = T().Accent
                    })

                    local searchHeight = searchable and 38 or 0
                    local listHeight = math.min(#values * 30 + 8, 170)
                    local popupHeight = searchHeight + listHeight

                    popup = New("CanvasGroup", {
                        BackgroundColor3 = T().Background2,
                        BorderSizePixel = 0,
                        Size = UDim2.new(1, 0, 0, 0),
                        LayoutOrder = Row.LayoutOrder + 1,
                        ClipsDescendants = true,
                        GroupTransparency = 1,
                        ZIndex = 12,
                        Parent = SectionRoot
                    })

                    Corner(popup, 9)

                    local popupStroke = Stroke(
                        popup,
                        T().Border,
                        1,
                        0.25
                    )

                    popupScale = New("UIScale", {
                        Scale = 0.94,
                        Parent = popup
                    })

                    local SearchInput

                    if searchable then
                        SearchInput = New("TextBox", {
                            BackgroundColor3 = T().Surface,
                            BackgroundTransparency = 0.08,
                            BorderSizePixel = 0,
                            ClearTextOnFocus = false,
                            Position = UDim2.fromOffset(5, 5),
                            Size = UDim2.new(1, -10, 0, 29),
                            Font = Enum.Font.Gotham,
                            PlaceholderText = "Search...",
                            PlaceholderColor3 = T().TextFaint,
                            Text = "",
                            TextColor3 = T().Text,
                            TextSize = 10,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 14,
                            Parent = popup
                        })

                        Padding(SearchInput, 9, 9, 0, 0)
                        Corner(SearchInput, 7)
                        Stroke(SearchInput, T().BorderSoft, 1, 0.45)

                        SearchInput.Focused:Connect(function()
                            Tween(SearchInput, 0.16, {
                                BackgroundTransparency = 0
                            })
                        end)

                        SearchInput.FocusLost:Connect(function()
                            Tween(SearchInput, 0.16, {
                                BackgroundTransparency = 0.08
                            })
                        end)
                    end

                    local list = New("ScrollingFrame", {
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Position = UDim2.fromOffset(0, searchHeight),
                        Size = UDim2.new(1, 0, 1, -searchHeight),
                        CanvasSize = UDim2.new(),
                        AutomaticCanvasSize = Enum.AutomaticSize.Y,
                        ScrollBarThickness = 2,
                        ScrollBarImageColor3 = T().Accent,
                        ScrollBarImageTransparency = 0.28,
                        ZIndex = 13,
                        Parent = popup
                    })

                    Padding(list, 4, 4, 4, 4)

                    New("UIListLayout", {
                        Padding = UDim.new(0, 2),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        Parent = list
                    })

                    local optionRows = {}

                    local function isSelected(v)
                        if multi then
                            return selected[v] == true
                        end
                        return v == value
                    end

                    local function renderOption(option, v, animated)
                        local active = isSelected(v)

                        local targetBackground =
                            active
                            and Darken(T().Accent, 0.78)
                            or T().Surface

                        local targetBackgroundTransparency =
                            active and 0 or 0.25

                        local targetTextColor =
                            active and T().Accent or T().TextDim

                        option.Text =
                            (active and "  ✓  " or "     ")
                            .. tostring(v)

                        if animated then
                            Tween(option, 0.16, {
                                BackgroundColor3 = targetBackground,
                                BackgroundTransparency =
                                    targetBackgroundTransparency,
                                TextColor3 = targetTextColor
                            })
                        else
                            option.BackgroundColor3 = targetBackground
                            option.BackgroundTransparency =
                                targetBackgroundTransparency
                            option.TextColor3 = targetTextColor
                        end
                    end

                    local function pulseOption(entry)
                        Tween(entry.Scale, 0.08, {
                            Scale = 0.975
                        })

                        task.delay(0.08, function()
                            if entry.Scale and entry.Scale.Parent then
                                Tween(entry.Scale, 0.14, {
                                    Scale = 1
                                })
                            end
                        end)
                    end

                    for index, v in ipairs(values) do
                        local option = New("TextButton", {
                            AutoButtonColor = false,
                            BackgroundColor3 = T().Surface,
                            BackgroundTransparency = 1,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, 28),
                            Font = Enum.Font.Gotham,
                            Text = "",
                            TextColor3 = T().TextDim,
                            TextTransparency = 1,
                            TextSize = 11,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 14,
                            LayoutOrder = index,
                            Parent = list
                        })

                        Corner(option, 6)

                        local optionScale = New("UIScale", {
                            Scale = 0.985,
                            Parent = option
                        })

                        local entry = {
                            Button = option,
                            Value = v,
                            Scale = optionScale,
                            FilterToken = 0
                        }

                        table.insert(optionRows, entry)

                        renderOption(option, v, false)
                        option.TextTransparency = 1
                        option.BackgroundTransparency = 1

                        task.delay(0.06 + ((index - 1) * 0.026), function()
                            if option and option.Parent then
                                local active = isSelected(v)

                                Tween(
                                    option,
                                    0.22,
                                    {
                                        TextTransparency = 0,
                                        BackgroundTransparency =
                                            active and 0 or 0.25
                                    },
                                    Enum.EasingStyle.Quint,
                                    Enum.EasingDirection.Out
                                )

                                Tween(
                                    optionScale,
                                    0.24,
                                    {Scale = 1},
                                    Enum.EasingStyle.Back,
                                    Enum.EasingDirection.Out
                                )
                            end
                        end)

                        option.MouseEnter:Connect(function()
                            Tween(option, 0.13, {
                                BackgroundColor3 = T().Surface2,
                                BackgroundTransparency = 0
                            })

                            Tween(optionScale, 0.13, {
                                Scale = 1.012
                            })
                        end)

                        option.MouseLeave:Connect(function()
                            renderOption(option, v, true)

                            Tween(optionScale, 0.13, {
                                Scale = 1
                            })
                        end)

                        option.MouseButton1Click:Connect(function()
                            pulseOption(entry)

                            if multi then
                                setMulti(v, true)

                                for _, other in ipairs(optionRows) do
                                    renderOption(
                                        other.Button,
                                        other.Value,
                                        true
                                    )
                                end
                            else
                                setSingle(v, true)
                            end
                        end)
                    end

                    if SearchInput then
                        SearchInput:GetPropertyChangedSignal("Text"):Connect(function()
                            local query =
                                string.lower(SearchInput.Text or "")

                            for _, entry in ipairs(optionRows) do
                                local optionText =
                                    string.lower(tostring(entry.Value))

                                local shouldShow =
                                    query == ""
                                    or string.find(
                                        optionText,
                                        query,
                                        1,
                                        true
                                    ) ~= nil

                                entry.FilterToken = entry.FilterToken + 1
                                local filterToken = entry.FilterToken

                                if shouldShow then
                                    if not entry.Button.Visible then
                                        entry.Button.Visible = true
                                        entry.Button.Size =
                                            UDim2.new(1, 0, 0, 0)
                                        entry.Button.TextTransparency = 1
                                        entry.Scale.Scale = 0.98
                                    end

                                    Tween(entry.Button, 0.16, {
                                        Size = UDim2.new(1, 0, 0, 28),
                                        TextTransparency = 0
                                    })

                                    Tween(entry.Scale, 0.16, {
                                        Scale = 1
                                    })

                                    renderOption(
                                        entry.Button,
                                        entry.Value,
                                        true
                                    )
                                else
                                    Tween(entry.Button, 0.14, {
                                        Size = UDim2.new(1, 0, 0, 0),
                                        TextTransparency = 1,
                                        BackgroundTransparency = 1
                                    })

                                    Tween(entry.Scale, 0.14, {
                                        Scale = 0.98
                                    })

                                    task.delay(0.145, function()
                                        if entry.FilterToken == filterToken
                                        and entry.Button
                                        and entry.Button.Parent then
                                            entry.Button.Visible = false
                                        end
                                    end)
                                end
                            end
                        end)
                    end

                    Tween(
                        popup,
                        0.34,
                        {
                            Size = UDim2.new(1, 0, 0, popupHeight),
                            GroupTransparency = 0
                        },
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out
                    )

                    Tween(
                        popupScale,
                        0.34,
                        {Scale = 1},
                        Enum.EasingStyle.Back,
                        Enum.EasingDirection.Out
                    )

                    Tween(
                        popupStroke,
                        0.30,
                        {Transparency = 0.05},
                        Enum.EasingStyle.Quint,
                        Enum.EasingDirection.Out
                    )

                    local openedPopup = popup
                    task.delay(0.36, function()
                        if not openedPopup or not openedPopup.Parent or not opened then
                            return
                        end
                        local visibleBottom = Scroll.AbsolutePosition.Y + Scroll.AbsoluteSize.Y - 10
                        local popupBottom = openedPopup.AbsolutePosition.Y + openedPopup.AbsoluteSize.Y
                        local extra = math.max(0, popupBottom - visibleBottom)
                        if extra > 0 then
                            Scroll.CanvasPosition = Vector2.new(
                                Scroll.CanvasPosition.X,
                                Scroll.CanvasPosition.Y + extra
                            )
                        end
                    end)
                end)

                ThemeBind(function(th)
                    Button.BackgroundColor3 = th.Background2
                    Button.TextColor3 = th.Text
                    buttonStroke.Color = opened and th.Accent or th.Border
                    ArrowLeft.BackgroundColor3 = th.Accent
                    ArrowRight.BackgroundColor3 = th.Accent
                end)

                return {
                    Set = function(_, v)
                        set(v, true)
                    end,

                    Get = function()
                        return getCurrentValue()
                    end,

                    Refresh = function(_, newValues)
                        values = newValues or {}

                        if multi then
                            local cleaned = {}

                            for _, v in ipairs(values) do
                                if selected[v] then
                                    cleaned[v] = true
                                end
                            end

                            selected = cleaned
                            value = copySelected()
                            updateButton()
                            updateFlag()
                        else
                            if not table.find(values, value) then
                                if values[1] then
                                    setSingle(values[1], true)
                                else
                                    value = "None"
                                    updateButton()
                                    updateFlag()
                                end
                            end
                        end

                        if opened then
                            closePopup(false)
                        end
                    end,

                    Clear = function()
                        if multi then
                            selected = {}
                            value = {}
                            updateButton()
                            fireCallback()
                        elseif values[1] then
                            setSingle(values[1], true)
                        end
                    end,

                    Count = function()
                        if multi then
                            return selectedCount()
                        end

                        return value ~= nil and 1 or 0
                    end,

                    Close = function()
                        closePopup(false)
                    end,

                    IsOpen = function()
                        return opened
                    end
                }
            end

            function Section:AddMultiDropdown(rowData)
                rowData = rowData or {}
                rowData.Multi = true
                return self:AddDropdown(rowData)
            end

            function Section:AddTextbox(rowData)
                rowData = rowData or {}
                local Row = MakeRow(rowData, "Textbox", "✎")
                local value = rowData.Default or ""
                local flag = rowData.Flag
                if flag then Window.Flags[flag] = value end

                local Box = New("TextBox", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = T().Background2,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(205, 34),
                    Font = Enum.Font.Gotham,
                    PlaceholderText = rowData.Placeholder or "Type here...",
                    PlaceholderColor3 = T().TextFaint,
                    Text = tostring(value),
                    TextColor3 = T().Text,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 12,
                    Parent = Row
                })
                Padding(Box, 12, 12, 0, 0)
                Corner(Box, 8)
                local boxStroke = Stroke(Box, T().BorderSoft, 1, 0.2)

                Box.FocusLost:Connect(function()
                    value = Box.Text
                    if flag then Window.Flags[flag] = value end
                    if rowData.Callback then
                        task.spawn(rowData.Callback, value)
                    end
                end)

                ThemeBind(function(th)
                    Box.BackgroundColor3 = th.Background2
                    Box.TextColor3 = th.Text
                    Box.PlaceholderColor3 = th.TextFaint
                    boxStroke.Color = th.BorderSoft
                end)

                return {
                    Set = function(_, v)
                        value = tostring(v)
                        Box.Text = value
                        if flag then Window.Flags[flag] = value end
                        if rowData.Callback then task.spawn(rowData.Callback, value) end
                    end,
                    Get = function() return value end
                }
            end

            function Section:AddButton(rowData)
                rowData = rowData or {}
                local Row = MakeRow(rowData, "Button", "ϟ")

                local Button = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    AutoButtonColor = false,
                    BackgroundColor3 = Darken(T().Accent, 0.68),
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(130, 34),
                    Font = Enum.Font.GothamMedium,
                    Text = rowData.Text or "Run",
                    TextColor3 = T().Text,
                    TextSize = 11,
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(Button, 8)
                local buttonStroke = Stroke(Button, T().Accent, 1, 0)

                Button.MouseEnter:Connect(function()
                    Tween(Button, 0.14, {BackgroundColor3 = Darken(T().Accent, 0.55)})
                end)
                Button.MouseLeave:Connect(function()
                    Tween(Button, 0.14, {BackgroundColor3 = Darken(T().Accent, 0.68)})
                end)
                Button.MouseButton1Click:Connect(function()
                    Tween(Button, 0.07, {Size = UDim2.fromOffset(126, 32)})
                    task.delay(0.08, function()
                        if Button and Button.Parent then
                            Tween(Button, 0.1, {Size = UDim2.fromOffset(130, 34)})
                        end
                    end)
                    if rowData.Callback then
                        task.spawn(rowData.Callback)
                    end
                end)

                ThemeBind(function(th)
                    Button.BackgroundColor3 = Darken(th.Accent, 0.68)
                    Button.TextColor3 = th.Text
                    buttonStroke.Color = th.Accent
                end)

                return Button
            end

            function Section:AddKeybind(rowData)
                rowData = rowData or {}
                local Row = MakeRow(rowData, "Keybind", "◇")
                local key = rowData.Default or Enum.KeyCode.K
                local waiting = false

                local Button = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    AutoButtonColor = false,
                    BackgroundColor3 = T().Background2,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(110, 34),
                    Font = Enum.Font.GothamMedium,
                    Text = key.Name,
                    TextColor3 = T().Text,
                    TextSize = 11,
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(Button, 8)
                local buttonStroke = Stroke(Button, T().Border, 1, 0.1)

                Button.MouseButton1Click:Connect(function()
                    waiting = true
                    Button.Text = "..."
                    Tween(buttonStroke, 0.15, {Color = T().Accent})
                end)

                ConnectGlobal(UserInputService.InputBegan, function(input, processed)
                    if waiting then
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            key = input.KeyCode
                            waiting = false
                            Button.Text = key.Name
                            Tween(buttonStroke, 0.15, {Color = T().Border})
                        end
                        return
                    end

                    if not processed and not UserInputService:GetFocusedTextBox() and not hidden
                    and input.KeyCode == key and rowData.Callback then
                        task.spawn(rowData.Callback)
                    end
                end)

                ThemeBind(function(th)
                    Button.BackgroundColor3 = th.Background2
                    Button.TextColor3 = th.Text
                    if not waiting then buttonStroke.Color = th.Border end
                end)

                return {
                    Set = function(_, newKey)
                        key = newKey
                        Button.Text = newKey.Name
                    end,
                    Get = function() return key end
                }
            end

            function Section:AddColorPicker(rowData)
                rowData = rowData or {}
                local Row = MakeRow(rowData, "Color Picker", "◈")
                local color = rowData.Default or T().Accent

                local Preview = New("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    AutoButtonColor = false,
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -12, 0.5, 0),
                    Size = UDim2.fromOffset(65, 34),
                    Font = Enum.Font.GothamBold,
                    Text = "",
                    ZIndex = 12,
                    Parent = Row
                })
                Corner(Preview, 8)
                local previewStroke = Stroke(Preview, Lighten(color, 0.25), 1, 0)

                local inner = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.new(1, -10, 1, -10),
                    ZIndex = 13,
                    Parent = Preview
                })
                Corner(inner, 5)

                local popup
                local popupConnections = {}
                local open = false
                local flag = rowData.Flag
                if flag then Window.Flags[flag] = color end

                local function setColor(c, call)
                    if typeof(c) ~= "Color3" then return end
                    color = c
                    if flag then Window.Flags[flag] = color end
                    Preview.BackgroundColor3 = Darken(c, 0.25)
                    inner.BackgroundColor3 = c
                    previewStroke.Color = Lighten(c, 0.25)
                    if call ~= false and rowData.Callback then
                        task.spawn(rowData.Callback, color)
                    end
                end

                local function close()
                    open = false
                    for _, connection in ipairs(popupConnections) do
                        connection:Disconnect()
                    end
                    table.clear(popupConnections)
                    if popup then popup:Destroy() popup = nil end
                end

                Preview.MouseButton1Click:Connect(function()
                    if open then close() return end
                    open = true

                    popup = New("Frame", {
                        BackgroundColor3 = T().Background2,
                        BorderSizePixel = 0,
                        Position = UDim2.fromOffset(
                            math.max(10, Preview.AbsolutePosition.X - 175),
                            Preview.AbsolutePosition.Y + Preview.AbsoluteSize.Y + 5
                        ),
                        Size = UDim2.fromOffset(240, 155),
                        ZIndex = 400,
                        Parent = ScreenGui
                    })
                    Corner(popup, 10)
                    Stroke(popup, T().Border, 1, 0)

                    local title = New("TextLabel", {
                        BackgroundTransparency = 1,
                        Position = UDim2.fromOffset(12, 8),
                        Size = UDim2.new(1, -24, 0, 20),
                        Font = Enum.Font.GothamBold,
                        Text = "Accent Color",
                        TextColor3 = T().Text,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 401,
                        Parent = popup
                    })

                    local closeBtn = New("TextButton", {
                        AnchorPoint = Vector2.new(1, 0),
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -7, 0, 5),
                        Size = UDim2.fromOffset(28, 25),
                        Font = Enum.Font.GothamBold,
                        Text = "×",
                        TextColor3 = T().TextDim,
                        TextSize = 18,
                        ZIndex = 402,
                        Parent = popup
                    })
                    closeBtn.MouseButton1Click:Connect(close)

                    local r, g, b = ColorToRGB(color)
                    local comps = {
                        {"R", r, Color3.fromRGB(255, 80, 80)},
                        {"G", g, Color3.fromRGB(80, 255, 130)},
                        {"B", b, Color3.fromRGB(80, 130, 255)},
                    }

                    for i, comp in ipairs(comps) do
                        local y = 38 + (i - 1) * 34

                        New("TextLabel", {
                            BackgroundTransparency = 1,
                            Position = UDim2.fromOffset(12, y),
                            Size = UDim2.fromOffset(18, 20),
                            Font = Enum.Font.GothamBold,
                            Text = comp[1],
                            TextColor3 = T().TextDim,
                            TextSize = 11,
                            ZIndex = 401,
                            Parent = popup
                        })

                        local val = New("TextLabel", {
                            AnchorPoint = Vector2.new(1, 0),
                            BackgroundTransparency = 1,
                            Position = UDim2.new(1, -12, 0, y),
                            Size = UDim2.fromOffset(32, 20),
                            Font = Enum.Font.Gotham,
                            Text = tostring(comp[2]),
                            TextColor3 = T().TextDim,
                            TextSize = 10,
                            ZIndex = 401,
                            Parent = popup
                        })

                        local tr = New("Frame", {
                            BackgroundColor3 = T().Surface3,
                            BorderSizePixel = 0,
                            Position = UDim2.fromOffset(37, y + 8),
                            Size = UDim2.new(1, -87, 0, 4),
                            ZIndex = 401,
                            Parent = popup
                        })
                        Corner(tr, 2)

                        local fl = New("Frame", {
                            BackgroundColor3 = comp[3],
                            BorderSizePixel = 0,
                            Size = UDim2.new(comp[2] / 255, 0, 1, 0),
                            ZIndex = 402,
                            Parent = tr
                        })
                        Corner(fl, 2)

                        local dragging = false
                        local function update(x)
                            local ratio = math.clamp((x - tr.AbsolutePosition.X) / math.max(1, tr.AbsoluteSize.X), 0, 1)
                            local n = math.floor(ratio * 255 + 0.5)
                            comp[2] = n
                            val.Text = tostring(n)
                            fl.Size = UDim2.new(ratio, 0, 1, 0)

                            comps[i][2] = n
                            setColor(Color3.fromRGB(comps[1][2], comps[2][2], comps[3][2]), true)
                        end

                        tr.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                                dragging = true
                                update(input.Position.X)
                            end
                        end)
                        table.insert(popupConnections, UserInputService.InputChanged:Connect(function(input)
                            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                            or input.UserInputType == Enum.UserInputType.Touch) then
                                update(input.Position.X)
                            end
                        end))
                        table.insert(popupConnections, UserInputService.InputEnded:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                                dragging = false
                            end
                        end))
                    end
                end)

                ScreenGui.Destroying:Connect(close)

                return {
                    Set = function(_, c) setColor(c, true) end,
                    Get = function() return color end
                }
            end

            table.insert(Tab.Sections, Section)
            Section.AddMultiSelect = Section.AddMultiDropdown
            return Section
        end

        table.insert(Window.Tabs, Tab)

        if #Window.Tabs == 1 then
            selectTab(Tab)
        end

        Tab.CreateSection = Tab.AddSection
        return Tab
    end

    Window.CreateTab = Window.AddTab
    return Window
end

return DriftwynUI
