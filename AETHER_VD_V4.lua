--[[
 AETHER / VD V4 • One-file Roblox Luau, GitHub raw / loadstring ready.
 Restricted to the Violence District place (ID below).
 No .bat, Python, localhost or companion process required.
 Publish THIS file to GitHub and launch with:
 loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/AETHER_VD_V4.lua"))()
 Replace USER/REPO and the branch with your own GitHub path.
 Limitations: a single Roblox Lua file cannot read native Windows Spotify,
 YouTube or other desktop media sessions. The music hotbar detects Roblox
 Sound instances only. Roblox also cannot render raw SVG directly; the menu
 uses vector GUI elements. Screenshot character art needs a Roblox image asset.
 Skill-check detection is experimental, not verified in live gameplay.
 No remote-event spoofing or instant generator repairs.
]]

local TARGET_PLACE_ID = 93978595733734
if game.PlaceId ~= TARGET_PLACE_ID then
    warn("[AETHER] Only Violence District (" .. TARGET_PLACE_ID .. ") is supported. Current place: " .. tostring(game.PlaceId))
    return
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local env = (type(getgenv) == "function" and getgenv()) or _G
if env.__AETHER_VD and type(env.__AETHER_VD.Unload) == "function" then
    pcall(env.__AETHER_VD.Unload)
end

local ACTIVE = true
local connections = {}
local espRecords = {}
local configPath = "AETHER_VD_SETTINGS.json"
local defaults = {
    menuKey = "RightControl", spinKey = "X", moonKey = "V", aimKey = "Q",
    musicHotbar = true, musicEqualizer = true,
    espKiller = true, espPallet = true, espGenerator = false,
    espNames = true, espRange = 450, espPulse = true,
    fov = 80, fovCircle = false, fovCircleColor = "White",
    aimEnabled = false, aimSmooth = 0.18,
    moonwalk = false, spinDuration = 0.52,
    autoSkill = false, checkTolerance = 10,
    previewAsset = "", previewW = 206, previewH = 365,
    windowW = 960, windowH = 615,
}
local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end
if type(readfile) == "function" and type(isfile) == "function" then
    pcall(function()
        if isfile(configPath) then
            local parsed = HttpService:JSONDecode(readfile(configPath))
            if type(parsed) == "table" then
                for k, v in pairs(defaults) do
                    if type(parsed[k]) == type(v) then cfg[k] = parsed[k] end
                end
            end
        end
    end)
end

local function save()
    if type(writefile) ~= "function" then return false end
    local ok = pcall(function() writefile(configPath, HttpService:JSONEncode(cfg)) end)
    return ok
end
local function bind(signal, fn)
    local c = signal:Connect(fn)
    connections[#connections + 1] = c
    return c
end
local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function round(x, rad)
    mk("UICorner", {CornerRadius=UDim.new(0, rad or 8)}, x)
    return x
end
local function border(x, color, transparency, weight)
    return mk("UIStroke", {Color=color or Color3.fromRGB(42,43,47), Transparency=transparency or 0, Thickness=weight or 1}, x)
end
local C = {
    bg=Color3.fromRGB(10,10,11), card=Color3.fromRGB(17,17,19),
    card2=Color3.fromRGB(23,23,25), line=Color3.fromRGB(43,43,47),
    text=Color3.fromRGB(238,238,240), sub=Color3.fromRGB(159,159,166),
    mute=Color3.fromRGB(94,94,101), white=Color3.fromRGB(248,249,250),
    red=Color3.fromRGB(252,78,94), green=Color3.fromRGB(75,238,162),
    amber=Color3.fromRGB(247,184,93),
}
local function label(parent, txt, size, color, bold, pos, sz, align)
    return mk("TextLabel", {
        BackgroundTransparency=1, Text=tostring(txt), TextColor3=color or C.text,
        Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize=size or 12, TextXAlignment=align or Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Center, Position=pos or UDim2.new(),
        Size=sz or UDim2.fromScale(1,1), TextTruncate=Enum.TextTruncate.AtEnd,
    }, parent)
end
local function button(parent, text, pos, size, fn)
    local b = round(mk("TextButton", {
        Text=text, Font=Enum.Font.Gotham, TextSize=11, TextColor3=C.text,
        BackgroundColor3=C.card2, BorderSizePixel=0, AutoButtonColor=false,
        Position=pos, Size=size,
    }, parent), 6)
    border(b)
    if fn then bind(b.MouseButton1Click, fn) end
    bind(b.MouseEnter, function() TweenService:Create(b, TweenInfo.new(.13), {BackgroundColor3=Color3.fromRGB(38,38,41)}):Play() end)
    bind(b.MouseLeave, function() TweenService:Create(b, TweenInfo.new(.13), {BackgroundColor3=C.card2}):Play() end)
    return b
end
local function flat(parent, pos, size, color, radius)
    local x = mk("Frame", {BackgroundColor3=color, BorderSizePixel=0, Position=pos, Size=size}, parent)
    if radius then round(x, radius) end
    return x
end

local guiParent = LocalPlayer:WaitForChild("PlayerGui") -- supported in Studio and client Lua
local gui = mk("ScreenGui", {
    Name="AETHER_VD_V4", ResetOnSpawn=false, DisplayOrder=1000,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true,
}, guiParent)
local root = round(mk("Frame", {
    Name="Window", BackgroundColor3=C.bg, BorderSizePixel=0,
    Size=UDim2.fromOffset(math.clamp(cfg.windowW,850,1280), math.clamp(cfg.windowH,560,840)),
    Position=UDim2.new(.5, -math.clamp(cfg.windowW,850,1280)/2, .5, -math.clamp(cfg.windowH,560,840)/2),
    ClipsDescendants=true,
}, gui), 10)
border(root, C.line)

local side = flat(root, UDim2.fromOffset(0,0), UDim2.new(0,75,1,0), Color3.fromRGB(11,11,13))
flat(side, UDim2.new(1,-1,0,0), UDim2.new(0,1,1,0), C.line)
local header = flat(root, UDim2.fromOffset(76,0), UDim2.new(1,-76,0,60), C.bg)
flat(root, UDim2.fromOffset(75,59), UDim2.new(1,-75,0,1), C.line)
local title = label(header,"Аим",15,C.text,true,UDim2.fromOffset(23,0),UDim2.fromOffset(140,60))
local subtitle = label(header,"AETHER  /  Violence District",10,C.sub,false,UDim2.fromOffset(84,1),UDim2.fromOffset(200,58))
local close = mk("TextButton", {
    BackgroundTransparency=1, Text="×", Font=Enum.Font.GothamLight,
    TextSize=27, TextColor3=C.sub, Position=UDim2.new(1,-46,0,13),
    Size=UDim2.fromOffset(34,34),
},header)
local content = mk("Frame", {
    BackgroundTransparency=1, Position=UDim2.fromOffset(75,60), Size=UDim2.new(1,-75,1,-60),
    ClipsDescendants=true,
}, root)

local tabFrames = {}
local navButtons = {}
local selectedTab="Аим"
local currentTab
local function selectTab(name)
    selectedTab=name
    title.Text=name
    for tab, pane in pairs(tabFrames) do pane.Visible=(tab==name) end
    for tab, details in pairs(navButtons) do
        details.background.BackgroundColor3=(tab==name) and C.card2 or C.bg
        details.background.BackgroundTransparency=(tab==name) and 0 or 1
        details.stroke.Transparency=(tab==name) and 0 or 1
        for _, strokeObj in ipairs(details.parts) do
            if strokeObj:IsA("Frame") then
                strokeObj.BackgroundColor3=(tab==name) and C.white or C.mute
            elseif strokeObj:IsA("UIStroke") then
                strokeObj.Color=(tab==name) and C.white or C.mute
            end
        end
    end
end
-- Icon elements are vector-style GUI shapes. Roblox ImageLabels do not decode SVG text.
local function iconPaint(parent, kind, highlighted)
    local parts = {}
    local col=highlighted and C.white or C.mute
    local function strokeFrame(p,s,rot,r)
        local f = flat(parent,p,s,col,r)
        if rot then f.Rotation=rot end
        table.insert(parts,f)
        return f
    end
    local function circle(p,s, thickness)
        local f = mk("Frame",{BackgroundTransparency=1,Position=p,Size=s},parent)
        round(f,50)
        local st=border(f,col,0,thickness or 2)
        table.insert(parts,st)
        return f
    end
    if kind=="aim" then
        circle(UDim2.fromOffset(5,5),UDim2.fromOffset(15,15),2)
        circle(UDim2.fromOffset(11,11),UDim2.fromOffset(3,3),2)
        strokeFrame(UDim2.fromOffset(12,0),UDim2.fromOffset(2,8))
        strokeFrame(UDim2.fromOffset(12,18),UDim2.fromOffset(2,8))
        strokeFrame(UDim2.fromOffset(0,12),UDim2.fromOffset(8,2))
        strokeFrame(UDim2.fromOffset(18,12),UDim2.fromOffset(8,2))
    elseif kind=="eye" then
        strokeFrame(UDim2.fromOffset(2,8),UDim2.fromOffset(13,2),-28,1)
        strokeFrame(UDim2.fromOffset(12,8),UDim2.fromOffset(13,2),28,1)
        strokeFrame(UDim2.fromOffset(2,16),UDim2.fromOffset(13,2),28,1)
        strokeFrame(UDim2.fromOffset(12,16),UDim2.fromOffset(13,2),-28,1)
        circle(UDim2.fromOffset(10,9),UDim2.fromOffset(7,7),2)
    elseif kind=="keyboard" then
        local outline=mk("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(26,18),Position=UDim2.fromOffset(0,4)},parent)
        round(outline,3); table.insert(parts,border(outline,col,0,1.5))
        for r=0,1 do for i=0,4 do strokeFrame(UDim2.fromOffset(4+i*4,8+r*5),UDim2.fromOffset(2,2),nil,1) end end
        strokeFrame(UDim2.fromOffset(6,19),UDim2.fromOffset(14,2),nil,1)
    elseif kind=="gear" then
        circle(UDim2.fromOffset(6,6),UDim2.fromOffset(14,14),3)
        circle(UDim2.fromOffset(11,11),UDim2.fromOffset(4,4),2)
        for a=0,315,45 do
            local f=strokeFrame(UDim2.fromOffset(12,0),UDim2.fromOffset(3,8),nil,1)
            f.AnchorPoint=Vector2.new(.5,.5); f.Position=UDim2.fromOffset(13,13); f.Rotation=a
        end
    elseif kind=="user" then
        circle(UDim2.fromOffset(9,3),UDim2.fromOffset(9,9),2)
        local oval=flat(parent,UDim2.fromOffset(3,16),UDim2.fromOffset(21,10),col,10)
        table.insert(parts,oval)
    elseif kind=="arrow" then
        strokeFrame(UDim2.fromOffset(2,13),UDim2.fromOffset(20,2),-25,1)
        strokeFrame(UDim2.fromOffset(15,5),UDim2.fromOffset(2,17),35,1)
        strokeFrame(UDim2.fromOffset(9,17),UDim2.fromOffset(7,2),35,1)
    end
    return parts
end
local navInfo={
    {"Визуалы","eye",25},
    {"Аим","aim",72},
    {"Движение","keyboard",118},
    {"Настройки","gear",185},
    {"Профиль","user",232},
    {"Инфо","arrow",279},
}
flat(side,UDim2.fromOffset(23,171),UDim2.fromOffset(31,1),C.line)
for _, info in ipairs(navInfo) do
    local name, kind, y=info[1],info[2],info[3]
    local b=round(mk("TextButton",{
        Text="",BackgroundColor3=C.bg,BackgroundTransparency=1,
        Position=UDim2.fromOffset(18,y),Size=UDim2.fromOffset(40,40),AutoButtonColor=false,
    },side),9)
    local st=border(b,C.line,1)
    local icon=mk("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(26,26)},b)
    local parts=iconPaint(icon,kind,name=="Аим")
    navButtons[name]={background=b,stroke=st,parts=parts}
    bind(b.MouseButton1Click,function() selectTab(name) end)
end

local function pane(name)
    local p=mk("ScrollingFrame",{
        Name=name, BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,
        ScrollBarImageColor3=C.mute,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        Size=UDim2.fromScale(1,1),Visible=false,ScrollingDirection=Enum.ScrollingDirection.Y,
    },content)
    tabFrames[name]=p
    return p
end
local function card(parent,x,y,w,h)
    local c=round(mk("Frame",{
        BackgroundColor3=C.card,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
    },parent),10)
    border(c)
    return c
end
local function line(parent,y, x, width)
    return flat(parent,UDim2.fromOffset(x or 16,y),UDim2.fromOffset(width or 244,1),C.line)
end
local function heading(parent,text,y,w)
    label(parent,text,12,C.text,true,UDim2.fromOffset(17,y),UDim2.fromOffset(w or 240,25))
end
local toggles={}
-- iOS-style switches are used across every tab (animated white thumb / green state).
local IOS_GREEN = Color3.fromRGB(52,199,89)
local IOS_OFF = Color3.fromRGB(55,56,61)
local function makeToggle(parent,text,key,y,x,width)
    x=x or 17; width=width or 248
    local textLabel=label(parent,text,11,C.sub,false,UDim2.fromOffset(x,y),UDim2.fromOffset(width-56,30))
    local sw=round(mk("TextButton",{
        Name="iOS_Switch_"..key,Text="",BackgroundColor3=cfg[key] and IOS_GREEN or IOS_OFF,
        BorderSizePixel=0,Position=UDim2.fromOffset(x+width-46,y+3),
        Size=UDim2.fromOffset(46,26),AutoButtonColor=false,
    },parent),99)
    local thumb=round(mk("Frame",{
        Name="Thumb",BackgroundColor3=Color3.fromRGB(255,255,255),BorderSizePixel=0,
        Position=UDim2.fromOffset(cfg[key] and 22 or 2,2),Size=UDim2.fromOffset(22,22),
    },sw),99)
    mk("UIStroke",{Color=Color3.fromRGB(0,0,0),Thickness=.5,Transparency=.9},thumb)
    local function sync()
        local info=TweenInfo.new(.2,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
        TweenService:Create(sw,info,{BackgroundColor3=cfg[key] and IOS_GREEN or IOS_OFF}):Play()
        TweenService:Create(thumb,info,{Position=UDim2.fromOffset(cfg[key] and 22 or 2,2)}):Play()
    end
    toggles[key]=sync
    bind(sw.MouseButton1Click,function()
        cfg[key]=not cfg[key]
        sync()
        save()
    end)
    return sw,textLabel
end
local function makeCheck(parent,text,key,y)
    local btn=round(mk("TextButton",{Text=cfg[key] and "✓" or "",BackgroundColor3=cfg[key] and C.white or C.card2,
        TextColor3=C.bg,Font=Enum.Font.GothamBold,TextSize=12,
        Position=UDim2.fromOffset(17,y),Size=UDim2.fromOffset(18,18),AutoButtonColor=false,
    },parent),4)
    border(btn)
    label(parent,text,11,C.sub,false,UDim2.fromOffset(44,y-4),UDim2.fromOffset(200,26))
    local function sync()
        btn.Text=cfg[key] and "✓" or "";btn.BackgroundColor3=cfg[key] and C.white or C.card2
    end
    toggles[key]=sync
    bind(btn.MouseButton1Click,function() cfg[key]=not cfg[key];sync();save() end)
end
local function makeSlider(parent,txt,key,y,min,max,displayFn,onChange)
    label(parent,txt,11,C.sub,false,UDim2.fromOffset(17,y),UDim2.fromOffset(180,18))
    local val=label(parent,"",10,C.sub,false,UDim2.fromOffset(212,y),UDim2.fromOffset(47,18),Enum.TextXAlignment.Right)
    local track=round(flat(parent,UDim2.fromOffset(17,y+28),UDim2.fromOffset(239,4),C.line),3)
    local fill=round(flat(track,UDim2.fromOffset(0,0),UDim2.fromOffset(12,4),C.white),3)
    local knob=round(flat(parent,UDim2.fromOffset(17,y+25),UDim2.fromOffset(10,10),C.white),20)
    local dragging=false
    local function sync()
        local a=math.clamp((cfg[key]-min)/(max-min),0,1)
        fill.Size=UDim2.fromOffset(math.max(2,239*a),4)
        knob.Position=UDim2.fromOffset(17+math.floor(229*a),y+25)
        val.Text=displayFn and displayFn(cfg[key]) or tostring(math.floor(cfg[key]*100+.5)/100)
        if onChange then onChange(cfg[key]) end
    end
    local function setMouse(px)
        cfg[key]=math.floor((min+math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)*(max-min))*100+.5)/100
        sync()
    end
    bind(track.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;setMouse(i.Position.X) end end)
    bind(knob.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
    bind(UIS.InputChanged,function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then setMouse(i.Position.X) end end)
    bind(UIS.InputEnded,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and dragging then dragging=false;save() end end)
    sync()
end
local pendingBind=nil
local bindButtons={}
local function makeBind(parent,key,text,y)
    label(parent,text,11,C.sub,false,UDim2.fromOffset(17,y),UDim2.fromOffset(165,32))
    local b=button(parent,cfg[key],UDim2.fromOffset(202,y+2),UDim2.fromOffset(55,28))
    bindButtons[key]=b
    bind(b.MouseButton1Click,function()
        pendingBind=key
        b.Text="..."
    end)
end
local statusText=nil
local function status(t)
    if statusText then statusText.Text=t end
end

-- Aim page: matches the card layout from the provided screenshot.
local aimPage=pane("Аим")
local aimCard=card(aimPage,17,13,276,411)
heading(aimCard,"Аимбот",10)
makeToggle(aimCard,"", "aimEnabled",9,182,76)
line(aimCard,45)
makeBind(aimCard,"aimKey","Клавиша",55)
makeCheck(aimCard,"Показывать круг FOV","fovCircle",108)
makeSlider(aimCard,"FOV","fov",160,30,250,function(v) return math.floor(v).." px" end)
makeSlider(aimCard,"Плавность","aimSmooth",231,.02,.85,function(v) return string.format("%.2f",v) end)
label(aimCard,"Удерживай назначенную клавишу.",10,C.mute,false,UDim2.fromOffset(17,316),UDim2.fromOffset(240,40))
local skillCard=card(aimPage,308,13,277,257)
heading(skillCard,"Проверки генератора",10)
makeToggle(skillCard,"","autoSkill",9,182,76)
line(skillCard,45)
makeSlider(skillCard,"Допуск угла","checkTolerance",58,4,25,function(v) return math.floor(v).."°" end)
label(skillCard,"Реагирует на видимый виджет,\nа не мгновенно чинит генератор.",10,C.sub,false,UDim2.fromOffset(17,109),UDim2.fromOffset(244,45))
statusText=label(skillCard,"Проверка: ожидание",10,C.mute,false,UDim2.fromOffset(17,158),UDim2.fromOffset(246,34))
label(skillCard,"Без подмены серверных событий",9,C.mute,false,UDim2.fromOffset(17,209),UDim2.fromOffset(240,26))

-- Right visual pane with a real player's current 3D avatar, or an uploaded image ID.
local preview=round(mk("Frame",{
    Name="CharacterPreview",BackgroundColor3=Color3.fromRGB(7,7,8),
    Position=UDim2.new(1,-228,0,13),Size=UDim2.fromOffset(cfg.previewW,cfg.previewH),
    ClipsDescendants=true,
},aimPage),6)
border(preview,Color3.fromRGB(24,24,26))
local previewImage=mk("ImageLabel",{
    Name="CustomImage",BackgroundTransparency=1,Position=UDim2.new(),
    Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Stretch,Visible=false,
},preview)
local viewport=mk("ViewportFrame",{
    BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=true,
    Ambient=Color3.fromRGB(180,180,192),LightColor=Color3.fromRGB(252,252,255),
    LightDirection=Vector3.new(-1,-1,-1),
},preview)
local world=mk("WorldModel",{},viewport)
local viewportCamera=mk("Camera",{FieldOfView=40},viewport)
viewport.CurrentCamera=viewportCamera
local previewTag=label(preview,"PLAYER",10,C.white,true,UDim2.fromOffset(12,10),UDim2.fromOffset(130,18))
local previewDescription=label(preview,"3D CHARACTER",9,C.sub,false,UDim2.new(0,12,1,-26),UDim2.new(1,-24,0,17))
local previewHandle=round(mk("TextButton",{
    Text="◢",TextSize=17,Font=Enum.Font.Gotham,TextColor3=C.white,
    BackgroundColor3=C.card2,Position=UDim2.new(1,-24,1,-24),
    Size=UDim2.fromOffset(23,23),AutoButtonColor=false,
},preview),4)
local function updatePreviewPosition()
    preview.Size=UDim2.fromOffset(cfg.previewW,cfg.previewH)
    preview.Position=UDim2.new(1,-(cfg.previewW+22),0,13)
end
local function renderAvatar()
    if not ACTIVE then return end
    for _, child in ipairs(world:GetChildren()) do child:Destroy() end
    local char=LocalPlayer.Character
    if not char then return end
    local originalArchivable=char.Archivable
    char.Archivable=true
    local ok, clone=pcall(function() return char:Clone() end)
    char.Archivable=originalArchivable
    if not ok or not clone then return end
    for _, obj in ipairs(clone:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            obj:Destroy()
        elseif obj:IsA("BasePart") then
            obj.Anchored=true
            obj.CanCollide=false
        end
    end
    clone.Parent=world
    pcall(function() clone:PivotTo(CFrame.new(0,0,0)) end)
    local bbox,sz=clone:GetBoundingBox()
    local height=math.max(4,sz.Y)
    local center=bbox.Position
    local distance=math.max(7,height*1.6)
    viewportCamera.CFrame=CFrame.lookAt(Vector3.new(distance*.34,center.Y+height*.08,distance),center)
end
local function updatePreviewAsset()
    local id=tostring(cfg.previewAsset):match("%d+")
    previewImage.Visible=id~=nil
    viewport.Visible=id==nil
    if id then previewImage.Image="rbxassetid://"..id end
    previewDescription.Text=id and "CUSTOM IMAGE  /  STRETCH" or "3D CHARACTER"
end
updatePreviewAsset()
renderAvatar()
bind(LocalPlayer.CharacterAdded,function() task.delay(1,function() if ACTIVE then renderAvatar() end end) end)

-- Visuals page.
local visualsPage=pane("Визуалы")
local worldCard=card(visualsPage,17,13,276,360)
heading(worldCard,"ESP / Объекты",10)
line(worldCard,44)
makeToggle(worldCard,"Убийца / красный", "espKiller",60)
makeToggle(worldCard,"Паллеты / белые", "espPallet",105)
makeToggle(worldCard,"Генераторы / янтарь", "espGenerator",150)
makeToggle(worldCard,"Подписи и расстояние", "espNames",195)
makeToggle(worldCard,"Плавное свечение", "espPulse",240)
local rangeCard=card(visualsPage,308,13,276,180)
heading(rangeCard,"Дальность",10)
line(rangeCard,44)
makeSlider(rangeCard,"Дистанция ESP","espRange",64,80,1300,function(v) return math.floor(v).." studs" end)
label(rangeCard,"Подсветка видна через препятствия.",10,C.mute,false,UDim2.fromOffset(17,120),UDim2.fromOffset(244,32))

-- Movement page.
local movementPage=pane("Движение")
local moveCard=card(movementPage,17,13,276,333)
heading(moveCard,"Движения / DBD-style",10)
line(moveCard,44)
makeBind(moveCard,"spinKey","360° / оборот",57)
makeBind(moveCard,"moonKey","Moonwalk / вкл-выкл",106)
makeToggle(moveCard,"Moonwalk постоянно", "moonwalk",157)
makeSlider(moveCard,"Длительность 360°","spinDuration",215,.3,1.4,function(v) return string.format("%.2f c",v) end)
local notesCard=card(movementPage,308,13,276,176)
heading(notesCard,"Управление",10)
label(notesCard,"360° — один полный оборот на бинд.\nMoonwalk — персонаж смотрит назад\nот направления движения.\n\nСервер может корректировать поворот.",10,C.sub,false,UDim2.fromOffset(17,45),UDim2.fromOffset(244,120))

-- Settings page.
local settingsPage=pane("Настройки")
local keyCard=card(settingsPage,17,13,276,235)
heading(keyCard,"Горячие клавиши",10)
line(keyCard,44)
makeBind(keyCard,"menuKey","Меню (Ctrl)",60)
makeBind(keyCard,"spinKey","360°",103)
makeBind(keyCard,"moonKey","Moonwalk",146)
local uiCard=card(settingsPage,308,13,276,260)
heading(uiCard,"Предпросмотр персонажа",10)
line(uiCard,44)
label(uiCard,"Roblox Image / Decal ID",10,C.sub,false,UDim2.fromOffset(17,55),UDim2.fromOffset(242,21))
local assetBox=round(mk("TextBox",{
    Text=cfg.previewAsset,PlaceholderText="ID картинки (не ссылка)",ClearTextOnFocus=false,
    TextSize=11,Font=Enum.Font.Gotham,TextColor3=C.text,PlaceholderColor3=C.mute,
    BackgroundColor3=C.card2,TextXAlignment=Enum.TextXAlignment.Left,
    Position=UDim2.fromOffset(17,84),Size=UDim2.fromOffset(240,29),
},uiCard),6)
border(assetBox)
bind(assetBox.FocusLost,function()
    cfg.previewAsset=assetBox.Text:match("%d+") or ""
    assetBox.Text=cfg.previewAsset
    updatePreviewAsset();save()
end)
button(uiCard,"Вернуть 3D-аватар",UDim2.fromOffset(17,127),UDim2.fromOffset(239,29),function()
    cfg.previewAsset="";assetBox.Text="";updatePreviewAsset();renderAvatar();save()
end)
label(uiCard,"Размер изображения меняется за угол ◢\nна вкладке Аим.",10,C.mute,false,UDim2.fromOffset(17,177),UDim2.fromOffset(237,45))
button(keyCard,"Сохранить настройки",UDim2.fromOffset(17,193),UDim2.fromOffset(238,27),function()
    status(save() and "Настройки сохранены" or "Сохранение недоступно")
end)
local musicCard=card(settingsPage,17,271,276,310)
heading(musicCard,"Музыка / Liquid Glass",10)
line(musicCard,44)
makeToggle(musicCard,"Музыкальный хотбар","musicHotbar",57)
makeToggle(musicCard,"Живой эквалайзер","musicEqualizer",105)
label(musicCard,"Автопоказ при музыке из Roblox",10,C.sub,false,
    UDim2.fromOffset(18,161),UDim2.fromOffset(242,26))
label(musicCard,"Spotify / YouTube с ПК недоступны\nиз одного Lua-файла без внешнего источника.",9,C.mute,false,
    UDim2.fromOffset(18,267),UDim2.fromOffset(245,38))
local iosHint=label(settingsPage,
    "Переключатели iOS: плавная анимация, зелёный\nфон и белый ползунок.",
    11,C.mute,false,UDim2.fromOffset(313,288),UDim2.fromOffset(260,50))
label(settingsPage,
    "GitHub-версия: один Lua-файл, без BAT,\nPython и локального сервера.\nМузыкальная панель читает Sound в игре.",
    11,C.sub,false,UDim2.fromOffset(313,363),UDim2.fromOffset(266,100))
local settingsHint=label(settingsPage,
    "Потяни нижний правый угол меню, чтобы изменить размер.",
    11,C.mute,false,UDim2.fromOffset(22,602),UDim2.fromOffset(560,34))

-- Liquid Glass now-playing. Only Roblox Sound objects are inspected.
-- This GitHub-ready file makes NO network requests for music metadata.
local musicPreviewUntil=0
local soundCandidates={}
local activeSong=nil
local pausedSong=nil
local displayedSong=nil
local visibleMusic=false

local musicGlass=round(mk("CanvasGroup",{
    Name="LiquidGlassMusicHotbar",AnchorPoint=Vector2.new(.5,1),
    BackgroundColor3=Color3.fromRGB(39,45,56),BackgroundTransparency=.15,
    BorderSizePixel=0,Position=UDim2.new(.5,0,1,110),
    Size=UDim2.fromOffset(427,83),Visible=false,GroupTransparency=1,
    ClipsDescendants=true,
},gui),26)
-- Keep gradient on the glass background, not CanvasGroup itself; otherwise it
-- tints all descendants (including music labels and control icons).
local glassSurface=round(flat(musicGlass,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Color3.fromRGB(44,51,65)),26)
glassSurface.BackgroundTransparency=.09
border(glassSurface,Color3.fromRGB(242,247,255),.57,1.1)
mk("UIGradient",{
    Rotation=23,
    Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(123,143,174)),
        ColorSequenceKeypoint.new(.27,Color3.fromRGB(43,52,69)),
        ColorSequenceKeypoint.new(.66,Color3.fromRGB(23,29,40)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(91,104,133)),
    }),
},glassSurface)
-- Highlighted top edge, diffused glints and restrained blue-violet accents.
local glassHighlight=flat(musicGlass,UDim2.fromOffset(27,2),UDim2.new(1,-54,0,1),Color3.fromRGB(243,250,255),1)
glassHighlight.BackgroundTransparency=.53
local glassGlint=round(flat(musicGlass,UDim2.fromOffset(-12,-17),UDim2.fromOffset(170,60),Color3.fromRGB(195,213,252)),60)
glassGlint.BackgroundTransparency=.9
glassGlint.Rotation=-23
local glassGlint2=round(flat(musicGlass,UDim2.fromOffset(284,49),UDim2.fromOffset(160,51),Color3.fromRGB(127,165,251)),50)
glassGlint2.BackgroundTransparency=.92
glassGlint2.Rotation=-19
local album=round(flat(musicGlass,UDim2.fromOffset(13,13),UDim2.fromOffset(55,55),Color3.fromRGB(91,86,135)),13)
mk("UIGradient",{
    Rotation=125,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(142,140,190)),
        ColorSequenceKeypoint.new(.55,Color3.fromRGB(64,78,123)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(38,61,90)),
    }),
},album)
border(album,Color3.fromRGB(244,244,255),.81,1)
-- Hand-made, SVG-like vector music note (no emoji or font icon dependency).
local noteColor=Color3.fromRGB(239,243,255)
local noteStem=flat(album,UDim2.fromOffset(30,15),UDim2.fromOffset(3,24),noteColor,2)
noteStem.Rotation=0
local noteTop=flat(album,UDim2.fromOffset(30,14),UDim2.fromOffset(10,3),noteColor,2)
noteTop.Rotation=-12
round(flat(album,UDim2.fromOffset(21,36),UDim2.fromOffset(13,9),noteColor),8)

local songName=label(musicGlass,"Сейчас играет",13,C.white,true,UDim2.fromOffset(81,13),UDim2.fromOffset(257,21))
local songMeta=label(musicGlass,"VIOLENCE DISTRICT  ·  MUSIC",9,Color3.fromRGB(182,195,216),false,UDim2.fromOffset(81,34),UDim2.fromOffset(268,16))
local elapsed=label(musicGlass,"0:00",9,Color3.fromRGB(192,201,214),false,UDim2.fromOffset(81,52),UDim2.fromOffset(40,14))
local remaining=label(musicGlass,"0:00",9,Color3.fromRGB(192,201,214),false,UDim2.fromOffset(293,52),UDim2.fromOffset(41,14),Enum.TextXAlignment.Right)
local progressBack=round(flat(musicGlass,UDim2.fromOffset(81,70),UDim2.fromOffset(253,3),Color3.fromRGB(160,180,204)),3)
progressBack.BackgroundTransparency=.69
local progressFill=round(flat(progressBack,UDim2.fromOffset(0,0),UDim2.fromOffset(0,3),Color3.fromRGB(241,247,255)),3)

local playPause=round(mk("TextButton",{
    Name="MusicPlayPause",Text="",BackgroundColor3=Color3.fromRGB(255,255,255),
    BackgroundTransparency=.9,Size=UDim2.fromOffset(49,49),
    Position=UDim2.fromOffset(362,17),AutoButtonColor=false,
},musicGlass),17)
border(playPause,Color3.fromRGB(238,244,255),.77,.7)
local pauseBar1=round(flat(playPause,UDim2.fromOffset(17,15),UDim2.fromOffset(4,20),C.white),2)
local pauseBar2=round(flat(playPause,UDim2.fromOffset(27,15),UDim2.fromOffset(4,20),C.white),2)
local playLine1=round(flat(playPause,UDim2.fromOffset(18,16),UDim2.fromOffset(3,16),C.white),2)
playLine1.Rotation=-44
local playLine2=round(flat(playPause,UDim2.fromOffset(18,23),UDim2.fromOffset(3,16),C.white),2)
playLine2.Rotation=44
local bars={}
for i=1,4 do
    local b=round(flat(album,UDim2.fromOffset(7+(i-1)*5,43),UDim2.fromOffset(3,6),Color3.fromRGB(234,239,255)),2)
    b.BackgroundTransparency=.2
    bars[#bars+1]=b
end
local function syncPlayerGlyph(playing)
    pauseBar1.Visible=playing;pauseBar2.Visible=playing
    playLine1.Visible=not playing;playLine2.Visible=not playing
end
syncPlayerGlyph(true)

local function setGlassVisible(want)
    if visibleMusic==want then return end
    visibleMusic=want
    local t=TweenInfo.new(.31,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
    if want then
        musicGlass.Visible=true
        TweenService:Create(musicGlass,t,{
            GroupTransparency=0,Position=UDim2.new(.5,0,1,-19),
        }):Play()
    else
        TweenService:Create(musicGlass,t,{
            GroupTransparency=1,Position=UDim2.new(.5,0,1,110),
        }):Play()
        task.delay(.33,function()
            if ACTIVE and not visibleMusic then musicGlass.Visible=false end
        end)
    end
end

local function trackContainer(container)
    for _,obj in ipairs(container:GetDescendants()) do
        if obj:IsA("Sound") then soundCandidates[obj]=true end
    end
    bind(container.DescendantAdded,function(obj)
        if obj:IsA("Sound") then soundCandidates[obj]=true end
    end)
    bind(container.DescendantRemoving,function(obj)
        if obj:IsA("Sound") then
            soundCandidates[obj]=nil
            if pausedSong==obj then pausedSong=nil end
        end
    end)
end
trackContainer(SoundService)
trackContainer(workspace)
trackContainer(guiParent)

local function musicScore(s)
    if not s.Parent then return nil end
    local ok,playing,duration,volume=pcall(function()
        return s.IsPlaying,s.TimeLength,s.Volume
    end)
    if not ok or not playing or volume<=0 then return nil end
    local n=string.lower(s.Name)
    local title=s:GetAttribute("SongTitle") or s:GetAttribute("TrackTitle")
        or s:GetAttribute("MusicTitle")
    local isNamed=type(title)=="string" and title~=""
    local musicName=false
    for _,token in ipairs({"music","song","track","radio","theme","bgm","ost","soundtrack","музык","песн"}) do
        if string.find(n,token,1,true) then musicName=true;break end
    end
    local isAmbient=false
    for _,token in ipairs({"ambient","rain","wind","step","foot","sfx","effect","noise","heartbeat"}) do
        if string.find(n,token,1,true) then isAmbient=true;break end
    end
    if not isNamed and not musicName and (duration<24 or isAmbient) then return nil end
    local score=(isNamed and 100 or 0)+(musicName and 70 or 0)+math.min(duration,250)/20
    if s==activeSong then score=score+40 end
    return score
end
local function findSong()
    local best,bestScore=nil,-1
    for s in pairs(soundCandidates) do
        if not s.Parent then
            soundCandidates[s]=nil
        else
            local score=musicScore(s)
            if score and score>bestScore then best,bestScore=s,score end
        end
    end
    if not best and pausedSong and pausedSong.Parent then
        return pausedSong
    end
    return best
end
local function currentTitle(s)
    local title=s:GetAttribute("SongTitle") or s:GetAttribute("TrackTitle") or s:GetAttribute("MusicTitle") or s.Name
    if type(title)~="string" or title=="" or title=="Sound" or title=="Music" then
        title="Музыка в игре"
    end
    return title
end
local function formatMusicTime(seconds)
    local s=math.max(0,math.floor(tonumber(seconds) or 0))
    return string.format("%d:%02d",math.floor(s/60),s%60)
end
bind(playPause.MouseButton1Click,function()
    local s=displayedSong
    if not s or not s.Parent then return end
    pcall(function()
        if s.IsPlaying then
            s:Pause()
            pausedSong=s
        else
            s:Resume()
            pausedSong=nil
        end
    end)
end)
local function updateMusicUi()
    if not cfg.musicHotbar then
        setGlassVisible(false)
        return
    end
    local s=findSong()
    local demo=(not s and os.clock()<musicPreviewUntil)
    if not s and not demo then
        activeSong=nil;displayedSong=nil
        setGlassVisible(false)
        return
    end
    setGlassVisible(true)
    displayedSong=s
    local isPlaying=false
    if s then
        activeSong=s
        local ok,playing,position,duration=pcall(function()
            return s.IsPlaying,s.TimePosition,s.TimeLength
        end)
        if ok then
            songName.Text=currentTitle(s)
            songMeta.Text=playing and "СЕЙЧАС ИГРАЕТ  ·  ROBLOX" or "ПАУЗА  ·  ROBLOX"
            elapsed.Text=formatMusicTime(position)
            remaining.Text=duration>0 and formatMusicTime(duration) or "--:--"
            progressFill.Size=UDim2.fromOffset(math.floor(253*math.clamp(duration>0 and position/duration or 0,0,1)),3)
            isPlaying=playing
        end
    else
        songName.Text="Пример Liquid Glass"
        songMeta.Text="ПРЕДПРОСМОТР  ·  БЕЗ ЗВУКА"
        elapsed.Text="0:00";remaining.Text="0:06"
        progressFill.Size=UDim2.fromOffset(253*math.clamp(1-(musicPreviewUntil-os.clock())/6,0,1),3)
    end
    playPause.Visible=s~=nil
    syncPlayerGlyph(isPlaying)
    for i,b in ipairs(bars) do
        if cfg.musicEqualizer and isPlaying then
            local h=4+math.floor(10*math.abs(math.sin(os.clock()*(3.1+i*.43)+i*1.6)))
            b.Size=UDim2.fromOffset(3,h)
            b.Position=UDim2.fromOffset(7+(i-1)*5,49-h)
        else
            b.Size=UDim2.fromOffset(3,4)
            b.Position=UDim2.fromOffset(7+(i-1)*5,45)
        end
    end
end
button(musicCard,"Посмотреть хотбар",UDim2.fromOffset(17,218),UDim2.fromOffset(239,29),function()
    if not cfg.musicHotbar then
        cfg.musicHotbar=true
        if toggles.musicHotbar then toggles.musicHotbar() end
        save()
    end
    musicPreviewUntil=os.clock()+6
    updateMusicUi()
end)
task.spawn(function()
    while ACTIVE do
        pcall(updateMusicUi)
        task.wait(.16)
    end
end)

local profilePage=pane("Профиль")
local profileCard=card(profilePage,17,13,565,245)
heading(profileCard,"AETHER / VD",10,510)
line(profileCard,44,16,530)
label(profileCard,"Персональный локальный интерфейс для Violence District.\n\nВизуалы, iOS-переключатели, Liquid Glass-хотбар и 3D-предпросмотр.\nВерсия для GitHub: один Lua-файл без дополнительных программ.",12,C.sub,false,UDim2.fromOffset(18,65),UDim2.fromOffset(520,135))
local infoPage=pane("Инфо")
local infoCard=card(infoPage,17,13,565,275)
heading(infoCard,"Ограничения",10,510)
line(infoCard,44,16,530)
label(infoCard,"Поддерживается только Place ID 93978595733734.\nКод не внедряется в процесс Roblox: он выполняется как обычный Luau-код\nв уже предоставленной игровой среде.\n\nАвто-Space требует доступного синтеза клавиатуры и распознаваемого\nвиджета skill-check. Не ускоряет ремонт генератора до 1 секунды.\n\nSpotify на Windows нельзя определить одним Lua-скриптом из Roblox.\nХотбар показывает только музыку, найденную внутри Roblox.\nНеподдерживаемые игровые структуры могут потребовать адаптации.",11,C.sub,false,UDim2.fromOffset(18,60),UDim2.fromOffset(520,195))

-- Dragging and resizing: movable window, adjustable preview and image stretching.
local dragKind=nil
local dragStart, initialPos, initialW, initialH
local function startDrag(kind, input)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    dragKind=kind;dragStart=input.Position
    initialPos=root.Position
    initialW=(kind=="preview") and cfg.previewW or root.AbsoluteSize.X
    initialH=(kind=="preview") and cfg.previewH or root.AbsoluteSize.Y
end
bind(header.InputBegan,function(i) startDrag("move",i) end)
bind(previewHandle.InputBegan,function(i) startDrag("preview",i) end)
local resizeHandle=round(mk("TextButton",{
    Text="◢",BackgroundColor3=C.card2,TextColor3=C.mute,Font=Enum.Font.Gotham,
    TextSize=14,Size=UDim2.fromOffset(18,18),Position=UDim2.new(1,-19,1,-19),
    AutoButtonColor=false,
},root),3)
bind(resizeHandle.InputBegan,function(i) startDrag("window",i) end)
bind(UIS.InputChanged,function(i)
    if not dragKind or i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local change=i.Position-dragStart
    if dragKind=="move" then
        root.Position=UDim2.new(initialPos.X.Scale,initialPos.X.Offset+change.X,initialPos.Y.Scale,initialPos.Y.Offset+change.Y)
    elseif dragKind=="window" then
        cfg.windowW=math.clamp(initialW+change.X,850,1280)
        cfg.windowH=math.clamp(initialH+change.Y,560,840)
        root.Size=UDim2.fromOffset(cfg.windowW,cfg.windowH)
    elseif dragKind=="preview" then
        cfg.previewW=math.clamp(initialW+change.X,130,330)
        cfg.previewH=math.clamp(initialH+change.Y,170,460)
        updatePreviewPosition()
    end
end)
bind(UIS.InputEnded,function(i)
    if dragKind and i.UserInputType==Enum.UserInputType.MouseButton1 then dragKind=nil;save() end
end)
bind(close.MouseButton1Click,function() root.Visible=false end)

-- Global circular FOV marker, drawn with native vector GUI, independent of Drawing API.
local fovRing=mk("Frame",{
    Name="FOV",BackgroundTransparency=1,Visible=false,
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(cfg.fov*2,cfg.fov*2),
},gui)
round(fovRing,999)
border(fovRing,C.white,.25,1)

local lastAimHeld=false
local spinTime=0
local spinStartCF=nil
local oldRotate=true
local oldHum=nil
local function characterParts()
    local char=LocalPlayer.Character
    if not char then return nil,nil end
    return char:FindFirstChild("HumanoidRootPart"),char:FindFirstChildOfClass("Humanoid")
end
local function isKiller(player)
    if not player or not player.Character then return false end
    if player.Team and string.lower(player.Team.Name)=="killer" then return true end
    local role=player.Character:GetAttribute("Role") or player:GetAttribute("Role")
    if type(role)=="string" and string.lower(role)=="killer" then return true end
    if player.Character:GetAttribute("IsKiller")==true or player:GetAttribute("IsKiller")==true then return true end
    return false
end
local function spin()
    if spinTime>0 then return end
    local rootPart,h=characterParts()
    if not rootPart or not h then return end
    spinStartCF=rootPart.CFrame
    spinTime=.00001
    if not cfg.moonwalk then oldRotate=h.AutoRotate;h.AutoRotate=false end
end
local function restoreRotate()
    local _,h=characterParts()
    if h and not cfg.moonwalk and spinTime==0 then h.AutoRotate=oldRotate end
end
local function changeMoon()
    cfg.moonwalk=not cfg.moonwalk
    local _,h=characterParts()
    if h then
        if cfg.moonwalk then oldHum=h;oldRotate=h.AutoRotate;h.AutoRotate=false
        elseif spinTime==0 then h.AutoRotate=oldRotate end
    end
    if toggles.moonwalk then toggles.moonwalk() end
    save()
end

local function cameraAim(dt)
    if not cfg.aimEnabled or not lastAimHeld then return end
    local camera=workspace.CurrentCamera
    if not camera then return end
    local selfKiller=isKiller(LocalPlayer)
    local candidate=nil
    local closest=cfg.fov
    local mid=camera.ViewportSize/2
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer and plr.Character and (isKiller(plr)~=selfKiller) then
            local head=plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
            local hum=plr.Character:FindFirstChildOfClass("Humanoid")
            if head and (not hum or hum.Health>0) then
                local screen,visible=camera:WorldToViewportPoint(head.Position)
                if visible then
                    local d=(Vector2.new(screen.X,screen.Y)-mid).Magnitude
                    if d<closest then closest=d;candidate=head end
                end
            end
        end
    end
    if candidate then
        local wanted=CFrame.lookAt(camera.CFrame.Position,candidate.Position)
        camera.CFrame=camera.CFrame:Lerp(wanted,math.clamp(cfg.aimSmooth*dt*60,.01,.9))
    end
end
bind(RunService.RenderStepped,function(dt)
    if not ACTIVE then return end
    local camera=workspace.CurrentCamera
    if camera then
        fovRing.Visible=cfg.fovCircle
        fovRing.Size=UDim2.fromOffset(cfg.fov*2,cfg.fov*2)
        fovRing.Position=UDim2.fromOffset(camera.ViewportSize.X*.5,camera.ViewportSize.Y*.5)
    end
    local part,hum=characterParts()
    if part and hum then
        if spinTime>0 and spinStartCF then
            spinTime=spinTime+dt
            local progress=math.clamp(spinTime/cfg.spinDuration,0,1)
            local p=part.Position
            part.CFrame=CFrame.new(p)*spinStartCF.Rotation*CFrame.Angles(0,2*math.pi*progress,0)
            if progress>=1 then
                spinTime=0
                if not cfg.moonwalk then restoreRotate() end
            end
        elseif cfg.moonwalk then
            if oldHum~=hum then oldHum=hum;oldRotate=hum.AutoRotate end
            hum.AutoRotate=false
            local dir=hum.MoveDirection
            if dir.Magnitude>.12 then
                local look=Vector3.new(-dir.X,0,-dir.Z).Unit
                part.CFrame=CFrame.lookAt(part.Position,part.Position+look)
            end
        end
    end
    cameraAim(dt)
end)

local function codeMatches(input, key)
    if input.KeyCode==Enum.KeyCode.Unknown then return false end
    return input.KeyCode.Name==key
end
bind(UIS.InputBegan,function(input,processed)
    if not ACTIVE or input.UserInputType~=Enum.UserInputType.Keyboard then return end
    if pendingBind then
        if input.KeyCode==Enum.KeyCode.Escape then
            bindButtons[pendingBind].Text=cfg[pendingBind]
            pendingBind=nil
            return
        end
        if input.KeyCode~=Enum.KeyCode.Unknown then
            cfg[pendingBind]=input.KeyCode.Name
            bindButtons[pendingBind].Text=cfg[pendingBind]
            pendingBind=nil;save()
        end
        return
    end
    if UIS:GetFocusedTextBox() then return end
    local menuKey=cfg.menuKey
    if codeMatches(input,menuKey) or ((menuKey=="RightControl" or menuKey=="LeftControl") and (input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl)) then
        root.Visible=not root.Visible
        return
    end
    if processed then return end
    if codeMatches(input,cfg.spinKey) then spin() end
    if codeMatches(input,cfg.moonKey) then changeMoon() end
    if codeMatches(input,cfg.aimKey) then lastAimHeld=true end
end)
bind(UIS.InputEnded,function(input)
    if codeMatches(input,cfg.aimKey) then lastAimHeld=false end
end)

-- ESP data scanning. We only inspect locally replicated game instances.
local function isInRange(pos)
    local me=characterParts()
    return not me or (me.Position-pos).Magnitude<=cfg.espRange
end
local function getPart(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart",true) end
    return nil
end
local function hasToken(s,token)
    return string.find(string.lower(s),token,1,true)~=nil
end
local function drawESP(key,obj,name,color)
    local part=getPart(obj)
    if not part or not part:IsDescendantOf(workspace) or not isInRange(part.Position) then return end
    local existing=espRecords[key]
    if existing and existing.obj~=obj then
        if existing.hi then existing.hi:Destroy() end
        if existing.tag then existing.tag:Destroy() end
        espRecords[key]=nil;existing=nil
    end
    if not existing then
        local hi=mk("Highlight",{
            Name="AETHER_Highlight",Adornee=obj,FillColor=color,OutlineColor=color,
            FillTransparency=.78,OutlineTransparency=.04,
            DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
        },workspace.CurrentCamera or guiParent)
        local tag=mk("BillboardGui",{
            Name="AETHER_Label",Adornee=part,AlwaysOnTop=true,
            Size=UDim2.fromOffset(175,28),StudsOffsetWorldSpace=Vector3.new(0,2.5,0),
            Enabled=cfg.espNames,
        },guiParent)
        local lab=label(tag,"",11,color,true,UDim2.fromScale(0,0),UDim2.fromScale(1,1),Enum.TextXAlignment.Center)
        existing={obj=obj,hi=hi,tag=tag,lab=lab,color=color,part=part}
        espRecords[key]=existing
    end
    existing.hi.Enabled=true
    existing.tag.Enabled=cfg.espNames
    existing.hi.Adornee=obj
    existing.tag.Adornee=part
    existing.lab.Text=name
    existing.lab.TextColor3=color
    existing.part=part
end
local function updateESP()
    local keep={}
    if cfg.espKiller then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character and isKiller(p) then
                local key="K:"..p.UserId
                keep[key]=true
                drawESP(key,p.Character,"KILLER · "..p.DisplayName,C.red)
            end
        end
    end
    if cfg.espPallet or cfg.espGenerator then
        local count=0
        local map=workspace:FindFirstChild("Map") or workspace
        for _,obj in ipairs(map:GetDescendants()) do
            if count>=170 then break end
            if (obj:IsA("Model") or obj:IsA("BasePart")) then
                local isP=cfg.espPallet and hasToken(obj.Name,"pallet")
                local isG=cfg.espGenerator and hasToken(obj.Name,"generator")
                if isP or isG then
                    -- Prevent marking each child of the same named group.
                    local parent=obj.Parent
                    if not parent or not hasToken(parent.Name,isP and "pallet" or "generator") then
                        local key=obj -- Instance identity avoids restricted GetDebugId()
                        keep[key]=true
                        drawESP(key,obj,isP and "PALLET" or "GENERATOR",isP and C.white or C.amber)
                        count=count+1
                    end
                end
            end
        end
    end
    for key,rec in pairs(espRecords) do
        if not keep[key] or not rec.obj.Parent or not rec.part or not isInRange(rec.part.Position) then
            if rec.hi then rec.hi:Destroy() end
            if rec.tag then rec.tag:Destroy() end
            espRecords[key]=nil
        end
    end
end

task.spawn(function()
    while ACTIVE do
        pcall(updateESP)
        for _,rec in pairs(espRecords) do
            if rec.hi then
                if cfg.espPulse then
                    rec.hi.FillTransparency=.72+math.sin(os.clock()*2.6)*.12
                else
                    rec.hi.FillTransparency=.79
                end
            end
        end
        task.wait(1.4)
    end
end)

-- Experimental visual skill-check detection.
-- Only fires Space if the widget exposes a needle and a target with usable
-- rotation/position. It intentionally never calls or forges a server remote.
local skillWidget=nil
local needleObj=nil
local zoneObj=nil
local lastCheck=0
local lastScan=0
local skillReported=""
local lastNeedleAngle=nil
local lastNeedleWidget=nil
local function visiblePath(obj,untilAncestor)
    local n=obj
    while n and n~=untilAncestor do
        if n:IsA("GuiObject") and not n.Visible then return false end
        n=n.Parent
    end
    return true
end
local function findVisualTargets()
    local playerGui=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local possible={}
    for _,g in ipairs(playerGui:GetDescendants()) do
        if g:IsA("GuiObject") and visiblePath(g,playerGui) and (hasToken(g.Name,"skillcheck") or hasToken(g.Name,"skill_check")) then
            possible[#possible+1]=g
        end
    end
    for _,widget in ipairs(possible) do
        local nd=nil
        local zn=nil
        for _,v in ipairs(widget:GetDescendants()) do
            if v:IsA("GuiObject") and visiblePath(v,widget) then
                local nm=string.lower(v.Name)
                if not nd and (string.find(nm,"needle",1,true) or string.find(nm,"pointer",1,true) or string.find(nm,"arrow",1,true)) then nd=v end
                if not zn and (string.find(nm,"success",1,true) or string.find(nm,"target",1,true) or string.find(nm,"perfect",1,true) or string.find(nm,"zone",1,true)) then zn=v end
            end
        end
        if nd and zn then return widget,nd,zn end
    end
    return nil
end
local function angleDifference(a,b)
    return math.abs((a-b+180)%360-180)
end
local function relativeAngle(center,item)
    local p=item.AbsolutePosition+item.AbsoluteSize/2-center
    return math.deg(math.atan2(p.Y,p.X))
end
local function sendSpace()
    if type(keypress)=="function" and type(keyrelease)=="function" then
        local ok=pcall(function() keypress(0x20);task.wait(.045);keyrelease(0x20) end)
        if ok then return true end
    end
    local ok=false
    pcall(function()
        local vim=game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true,Enum.KeyCode.Space,false,game)
        vim:SendKeyEvent(false,Enum.KeyCode.Space,false,game)
        ok=true
    end)
    return ok
end
local function skillCheckLoop()
    while ACTIVE do
        if cfg.autoSkill then
            if os.clock()-lastScan>.35 then
                skillWidget,needleObj,zoneObj=findVisualTargets()
                lastScan=os.clock()
            end
            if skillWidget and needleObj and zoneObj and visiblePath(skillWidget,LocalPlayer.PlayerGui) then
                local a=needleObj.Rotation
                local b=zoneObj.Rotation
                -- If UI objects carry no rotation, derive radial angles from center.
                if a==0 and b==0 then
                    local center=skillWidget.AbsolutePosition+skillWidget.AbsoluteSize/2
                    a=relativeAngle(center,needleObj)
                    b=relativeAngle(center,zoneObj)
                end
                status("Проверка: отслеживание угла")
                skillReported="tracking"
                local moving=(lastNeedleWidget==needleObj and lastNeedleAngle~=nil and angleDifference(a,lastNeedleAngle)>.12)
                lastNeedleAngle=a
                lastNeedleWidget=needleObj
                if moving and angleDifference(a,b)<=cfg.checkTolerance and os.clock()-lastCheck>1.1 then
                    lastCheck=os.clock()
                    status(sendSpace() and "Проверка: Space отправлен" or "Проверка: синтез ввода недоступен")
                end
            else
                lastNeedleAngle=nil;lastNeedleWidget=nil
                if skillReported~="missing" then status("Проверка: виджет не найден");skillReported="missing" end
            end
        else
            if skillReported~="off" then status("Проверка: выключено");skillReported="off" end
        end
        task.wait(.065)
    end
end
task.spawn(skillCheckLoop)

local function unload()
    if not ACTIVE then return end
    ACTIVE=false
    for _, rec in pairs(espRecords) do
        pcall(function() if rec.hi then rec.hi:Destroy() end if rec.tag then rec.tag:Destroy() end end)
    end
    for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    local _,liveHum=characterParts()
    if liveHum then pcall(function() liveHum.AutoRotate=oldRotate end) end
    pcall(function() gui:Destroy() end)
    env.__AETHER_VD=nil
end
env.__AETHER_VD={Unload=unload,Config=cfg}
local unloadButton=button(infoCard,"Выгрузить AETHER",UDim2.fromOffset(18,230),UDim2.fromOffset(231,28),unload)
selectTab("Аим")
warn("[AETHER VD V4] Loaded for place "..tostring(game.PlaceId)..". Ctrl: menu. Settings: custom binds.")
