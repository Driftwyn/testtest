--[[
    Driftwyn UI v6.0
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

local MoonImageBase64 = table.concat({
    "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",
    "dDL5+OPH73/46K1ffPTeBw/f/+jx4/3po73TJwfTvf0pB8LJtJ3M/Uf3D//23/sd4v4//n//1e//8KfTZdMfbzWBY2HeRhNNMeFu7X3tQxO8j4l2",
    "3fT40wbf+uiD+KghCKuBIuA5jqzlpgGccywSNKP4yeRkf+/J4cHecjGv6+Xp6fFsNmExTKenk8kJWK0WRWE3N8cbGyMuHrPFfDZfLhe1byNNpGcM",
    "H2loc3tnON6g3YPD48OD43rVKl/HRIcbm3xyGOzs3nn5xfHmxpMDnojusaPjT+EqKMNWWEf0L2ZT/FwuFs1y2S4SmtWqWSzCYiF8pGtbxrxtW+qe",
    "np7ClFVlRuk/BhIRsiBNkHNk69VKeCohr0otzCI0JBEDl2lU7hufQlf0CVERjQk4hwkMiaQwxY7tEgwHvRgF2ZpclojvS0EV5Dh5WaVPZCYmnmmH",
    "oQogD82Axwg0Z6HwBCUUxKAgMd1wwNBchhgLgwQwkfQOSGR81kiDgyQIErQSYiJnfyEy8QxMYJusa8a/VcO21a/6w8FoPBhtjkYb/cFGUQ5Ebet1",
    "2YRlGw8niw8+fvyTt9//3g9+7+9893f/i7/53b/6X/6d/8d/8l/8J3/1b/61v/Wbf/s3v/9f/s3f/K/+1nff+fBxOdzavHojmupoujw8nU2m6frk",
    "oxDBvk1Ni5fQpZiSQtq2JTChBJYPoQ0sj9j4WPT6BOL21evbV6+Ot3Z6g2HRH5WD8dzHeetbdbEoT+bze48fT5fN9tUbW1d3h1sbg+F4NN68cvX6",
    "9Zs3dq9cG43Hi9l8tVhi3BjTK8uqKJxz8ASlqvb7/bIsi4KLjOXK/tOf/hSXyO7s7l69enW2XLz99lvTBw+Gw2Fbr3xofN0YjaOqX6iYxm/QMexZ",
    "k2POSHSl491XMR6dHh9NuQkd7B8+eQxjfDuoSvzzq+VqOucYWS2XIlJaR4vSRb8wPTEyPPxpYNsQ07bsEMZYZxxf5qwYx9N6ZG6Siqg1qkoFBk0l",
    "JFt8rwjBiDhjgRFWhKAgRoNElj2naFQVYwCM0ryy4SmTBKIaJMbRilWbIMZ4VdAK+xPTRwMe14BYESuqqQmrDGrhzDnUGcqoTENW1bIWNGjqE6Ef",
    "qWEiFqJqgsEfjeYMQSlOCFGiwKCqNeMQjTWFcBv2Me3acGVPrWt9XNVtiCpqfdQmhEjFKD5EH86Slxgop7nWEw1t3TA4hS19ExZszMt6tfI+GOP6",
    "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",
})

local moonAsset
local function DecodeBase64(encoded)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #alphabet do
        lookup[alphabet:sub(i, i)] = i - 1
    end
    local bytes = {}
    for i = 1, #encoded, 4 do
        local c1, c2, c3, c4 = encoded:sub(i, i), encoded:sub(i + 1, i + 1), encoded:sub(i + 2, i + 2), encoded:sub(i + 3, i + 3)
        local n = (lookup[c1] or 0) * 262144 + (lookup[c2] or 0) * 4096
            + (lookup[c3] or 0) * 64 + (lookup[c4] or 0)
        bytes[#bytes + 1] = string.char(math.floor(n / 65536) % 256)
        if c3 ~= "=" then bytes[#bytes + 1] = string.char(math.floor(n / 256) % 256) end
        if c4 ~= "=" then bytes[#bytes + 1] = string.char(n % 256) end
    end
    return table.concat(bytes)
end

local function ResolveBackgroundImage(image)
    if image == false then return "" end
    if type(image) == "number" then return "rbxassetid://" .. tostring(image) end
    if type(image) == "string" and image ~= "" then return image end
    if moonAsset then return moonAsset end

    local customAsset = getcustomasset or getsynasset
    if type(writefile) ~= "function" or type(customAsset) ~= "function" then
        return ""
    end
    local ok, asset = pcall(function()
        local filename = "DriftwynUI_moon.png"
        writefile(filename, DecodeBase64(MoonImageBase64))
        return customAsset(filename)
    end)
    if ok and type(asset) == "string" then
        moonAsset = asset
        return asset
    end
    return ""
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

    local backgroundSource = ResolveBackgroundImage(config.BackgroundImage)
    local BackgroundImage = New("ImageLabel", {
        BackgroundTransparency = 1,
        Image = backgroundSource,
        ImageTransparency = math.clamp(tonumber(config.BackgroundImageTransparency) or 0, 0, 1),
        ScaleType = Enum.ScaleType.Crop,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
        Visible = backgroundSource ~= "",
        Parent = Root
    })
    local BackgroundShade = New("Frame", {
        BackgroundColor3 = Color3.fromRGB(3, 6, 12),
        BackgroundTransparency = 0.36,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
        Visible = backgroundSource ~= "",
        Parent = Root
    })

    function Window:SetBackgroundImage(image)
        local source = ResolveBackgroundImage(image)
        BackgroundImage.Image = source
        BackgroundImage.Visible = source ~= ""
        BackgroundShade.Visible = source ~= ""
        if self._ApplyTheme then self:_ApplyTheme() end
        return source ~= ""
    end

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
        Text = config.Version or "v6.0",
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
        Header.BackgroundTransparency = BackgroundImage.Visible and 0.22 or 0.03
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
        Sidebar.BackgroundTransparency = BackgroundImage.Visible and 0.22 or 0.06
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
                SectionRoot.BackgroundTransparency = BackgroundImage.Visible and 0.14 or 0
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
                    Row.BackgroundTransparency = BackgroundImage.Visible and 0.08 or 0
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
