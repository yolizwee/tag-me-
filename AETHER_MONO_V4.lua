--[[
    AETHER / MONO V4
    Roblox client-side Lua. No external HTTP dependency.
    Features: CTRL menu, dark UI, ESP boxes & role colors, shimmer highlights,
    white square-grid world visuals, persistent WalkSpeed across respawn,
    JumpPower, FOV & green edge glow, simulated aspect-ratio framing.
    FOV-ring is a visual HUD indicator; no automatic targeting or firing.
    Real monitor resolution / GPU stretching cannot be changed from Roblox Lua.
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
assert(player, "AETHER MONO requires a Roblox client")
local scope = (type(getgenv) == "function" and getgenv()) or _G
if type(scope.AetherMonoV4) == "table" and type(scope.AetherMonoV4.Destroy) == "function" then
    pcall(scope.AetherMonoV4.Destroy)
end

local CONFIG_PATH = "AETHER_MONO_V4_settings.json"
local defaults = {
    speed = 20, lockSpeed = true, jump = 50, lockJump = true,
    fov = 70, lockFov = true, fovRing = true, ringRadius = 100,
    greenEdges = true, aspect = "FULL", esp = false, espName = true,
    espDistance = true, espHighlight = false, espShimmer = true,
    espRange = 450, tiles = false, tileRadius = 75,
    tileIntensity = 65, bloom = false, fullbright = false,
}
local settings = {}
for k, v in pairs(defaults) do settings[k] = v end
local previouslySaved = scope.AetherMonoV4Config
if type(previouslySaved) ~= "table" and type(readfile) == "function" and type(isfile) == "function" then
    pcall(function()
        if isfile(CONFIG_PATH) then
            previouslySaved = HttpService:JSONDecode(readfile(CONFIG_PATH))
        end
    end)
end
if type(previouslySaved) == "table" then
    for key, default in pairs(defaults) do
        if type(previouslySaved[key]) == type(default) then
            settings[key] = previouslySaved[key]
        end
    end
elseif type(scope.AetherNightfallSavedSpeed) == "number" then
    settings.speed = scope.AetherNightfallSavedSpeed
end
local alive = true
local connections = {}
local function listen(signal, fn)
    local connection = signal:Connect(fn)
    connections[#connections+1] = connection
    return connection
end
local saveRevision = 0
local function saveNow()
    if not alive then return end
    scope.AetherMonoV4Config = table.clone(settings)
    scope.AetherNightfallSavedSpeed = settings.speed
    if type(writefile) == "function" then
        pcall(function() writefile(CONFIG_PATH, HttpService:JSONEncode(settings)) end)
    end
end
local function setOption(k, v)
    settings[k] = v
    saveRevision = saveRevision + 1
    local revision = saveRevision
    task.delay(0.6, function()
        if alive and revision == saveRevision then saveNow() end
    end)
end

local C = {
    bg = Color3.fromRGB(8, 8, 9), side = Color3.fromRGB(11, 11, 12),
    card = Color3.fromRGB(16, 16, 17), border = Color3.fromRGB(37, 37, 39),
    line = Color3.fromRGB(50, 50, 53), text = Color3.fromRGB(239, 239, 241),
    muted = Color3.fromRGB(138, 138, 141), white = Color3.new(1, 1, 1),
    green = Color3.fromRGB(62, 255, 128), red = Color3.fromRGB(255, 76, 89),
    gray = Color3.fromRGB(188, 188, 195),
}
local function new(class, parent, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function round(obj, radius)
    return new("UICorner", obj, {CornerRadius = UDim.new(0, radius or 6)})
end
local function stroke(obj, color, alpha, thickness)
    return new("UIStroke", obj, {Color = color or C.border,
        Transparency = alpha or 0, Thickness = thickness or 1})
end
local function text(parent, value, x, y, w, h, size, color, bold)
    return new("TextLabel", parent, {BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        Text = value, TextColor3 = color or C.text, TextSize = size or 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center})
end
local function tween(obj, props, duration)
    if alive and obj and obj.Parent then
        TS:Create(obj, TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart,
            Enum.EasingDirection.Out), props):Play()
    end
end
local function simpleButton(parent, title, x, y, w, h, callback)
    local b = new("TextButton", parent, {Position = UDim2.fromOffset(x,y),
        Size = UDim2.fromOffset(w,h), Text = title, Font = Enum.Font.GothamMedium,
        TextSize = 12, TextColor3 = C.text, BackgroundColor3 = C.card,
        BorderSizePixel = 0, AutoButtonColor = false})
    round(b, 6); stroke(b)
    listen(b.MouseEnter, function() tween(b, {BackgroundColor3 = Color3.fromRGB(34,34,36)},0.12) end)
    listen(b.MouseLeave, function() tween(b, {BackgroundColor3 = C.card},0.12) end)
    listen(b.MouseButton1Click, callback)
    return b
end

local parent = player:WaitForChild("PlayerGui")
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then parent = result end
end
local gui = new("ScreenGui", parent, {Name = "AETHER_MONO_V4_GUI",
    IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 9110,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local hud = new("ScreenGui", parent, {Name = "AETHER_MONO_V4_HUD",
    IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 9090,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling})

-- Aspect bars simulate framing only; they do not set the real screen resolution.
local bars = {}
for i=1,4 do
    bars[i] = new("Frame", hud, {BackgroundColor3 = Color3.new(0,0,0),
        BorderSizePixel = 0, Visible = false, ZIndex = 11})
end
local function applyAspect()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    if viewport.X < 1 or viewport.Y < 1 then return end
    for _, bar in ipairs(bars) do bar.Visible = false end
    local ratio = ({["1:1"] = 1, ["16:4"] = 4, ["4:3"] = 4/3,
        ["16:9"] = 16/9, ["16:10"] = 1.6, ["5:4"] = 1.25})[settings.aspect]
    if not ratio then return end
    local current = viewport.X/viewport.Y
    if ratio < current then
        local width = math.floor((viewport.X-viewport.Y*ratio)*0.5)
        bars[1].Size=UDim2.new(0,width,1,0); bars[1].Position=UDim2.fromOffset(0,0)
        bars[2].Size=UDim2.new(0,width,1,0); bars[2].Position=UDim2.new(1,-width,0,0)
        bars[1].Visible=true; bars[2].Visible=true
    elseif ratio > current then
        local height = math.floor((viewport.Y-viewport.X/ratio)*0.5)
        bars[3].Size=UDim2.new(1,0,0,height); bars[3].Position=UDim2.fromOffset(0,0)
        bars[4].Size=UDim2.new(1,0,0,height); bars[4].Position=UDim2.new(0,0,1,-height)
        bars[3].Visible=true; bars[4].Visible=true
    end
end
local function edgeGlow(right)
    local e = new("Frame", hud, {Name = right and "RightGreenEdge" or "LeftGreenEdge",
        AnchorPoint = Vector2.new(right and 1 or 0, 0),
        Position = right and UDim2.new(1,0,0,0) or UDim2.new(0,0,0,0),
        Size = UDim2.new(0,106,1,0), BorderSizePixel = 0,
        BackgroundColor3 = C.green, BackgroundTransparency = 1, ZIndex = 9})
    new("UIGradient", e, {Rotation = right and 180 or 0,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,0.1),
            NumberSequenceKeypoint.new(0.25,0.45),
            NumberSequenceKeypoint.new(1,1),
        })})
    return e
end
local glowLeft, glowRight = edgeGlow(false), edgeGlow(true)
local circle = new("Frame", hud, {Name = "VisualFOVCircle",
    AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5),
    Size = UDim2.fromOffset(200,200), BackgroundTransparency = 1,
    BorderSizePixel = 0, ZIndex = 8})
round(circle, 10000)
local circleStroke = stroke(circle, C.white, 0.65, 1)
local function updateHud()
    local c = workspace.CurrentCamera
    if c and settings.lockFov and math.abs(c.FieldOfView-settings.fov)>0.1 then
        c.FieldOfView = settings.fov
    end
    local strength = settings.greenEdges and math.clamp((settings.fov-102)/18,0,1) or 0
    local alpha = 1-strength*0.6
    glowLeft.BackgroundTransparency = alpha
    glowRight.BackgroundTransparency = alpha
    circle.Visible = settings.fovRing
    circle.Size = UDim2.fromOffset(settings.ringRadius*2, settings.ringRadius*2)
end

local originalFov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70
local originalLighting = {Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
    Brightness=Lighting.Brightness, ExposureCompensation=Lighting.ExposureCompensation}
local bloom = new("BloomEffect", Lighting, {Name="AETHER_MONO_BLOOM", Enabled=false,
    Intensity=0.35, Threshold=1.25, Size=25})
local color = new("ColorCorrectionEffect", Lighting, {Name="AETHER_MONO_COLOR",
    Enabled=false, Contrast=0.12, Saturation=-0.08})
local function updateLighting()
    bloom.Enabled=settings.bloom
    color.Enabled=settings.bloom
    if settings.fullbright then
        Lighting.Ambient=Color3.fromRGB(215,215,220)
        Lighting.OutdoorAmbient=Color3.fromRGB(200,200,200)
        Lighting.Brightness=3
        Lighting.ExposureCompensation=0.14
    else
        for k,v in pairs(originalLighting) do Lighting[k]=v end
    end
end

-- WalkSpeed and JumpPower survive character resets while this script runs.
local humanoidConnection
local currentHumanoid
local originalSpeed, originalJump
local updatingMovement = false
local function keepMovement()
    local h=currentHumanoid
    if not h or not h.Parent or h.Health<=0 then return end
    if updatingMovement then return end
    updatingMovement=true
    pcall(function()
        if settings.lockSpeed and math.abs(h.WalkSpeed-settings.speed)>0.01 then
            h.WalkSpeed=settings.speed
        end
        if settings.lockJump then
            h.UseJumpPower=true
            if math.abs(h.JumpPower-settings.jump)>0.01 then
                h.JumpPower=settings.jump
            end
        end
    end)
    updatingMovement=false
end
local function bindCharacter(character)
    task.spawn(function()
        local h = character:WaitForChild("Humanoid", 12)
        if not alive or not h or player.Character~=character then return end
        if humanoidConnection then humanoidConnection:Disconnect() end
        currentHumanoid=h
        originalSpeed=originalSpeed or h.WalkSpeed
        originalJump=originalJump or h.JumpPower
        keepMovement()
        humanoidConnection=listen(h:GetPropertyChangedSignal("WalkSpeed"), function()
            if alive and settings.lockSpeed then task.defer(keepMovement) end
        end)
        task.delay(0.25, function() if alive and currentHumanoid==h then keepMovement() end end)
        task.delay(1.0, function() if alive and currentHumanoid==h then keepMovement() end end)
    end)
end
if player.Character then bindCharacter(player.Character) end
listen(player.CharacterAdded, bindCharacter)

-- ESP role information is read only from replicated attributes/values.
local roles = {murderer=C.red, killer=C.red, innocent=C.green,
    sheriff=Color3.fromRGB(100,166,255), hero=Color3.fromRGB(100,166,255)}
local roleFields={"Role","CurrentRole","RoundRole","PlayerRole","MM2Role"}
local function roleColor(plr)
    local sources={plr,plr.Character}
    for _, source in ipairs(sources) do
        if source then
            for _, key in ipairs(roleFields) do
                local value=source:GetAttribute(key)
                local o=source:FindFirstChild(key)
                if value==nil and o and o:IsA("ValueBase") then value=o.Value end
                if value~=nil then
                    local v=string.lower(tostring(value))
                    for role, clr in pairs(roles) do
                        if string.find(v,role,1,true) then return clr end
                    end
                end
            end
        end
    end
    return C.gray
end
local espEntries={}
local function destroyEspEntry(plr)
    local e=espEntries[plr]
    if not e then return end
    if e.box then e.box:Destroy() end
    if e.highlight then e.highlight:Destroy() end
    espEntries[plr]=nil
end
local function getEspEntry(plr)
    local e=espEntries[plr]
    if e then return e end
    local box=new("Frame",hud,{Name="Box_"..tostring(plr.UserId),
        BackgroundTransparency=1, BorderSizePixel=0, Visible=false, ZIndex=7})
    local outline=stroke(box,C.gray,0.05,1.3)
    local shine=new("UIGradient",outline,{Rotation=0,Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,Color3.fromRGB(155,155,155)),
        ColorSequenceKeypoint.new(0.5,C.white),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(155,155,155)),
    })})
    local name=text(box,"",-55,-22,210,17,11,C.white,true)
    name.TextXAlignment=Enum.TextXAlignment.Center
    local dist=text(box,"",-55,0,210,16,10,C.muted)
    dist.TextXAlignment=Enum.TextXAlignment.Center
    e={box=box,outline=outline,shine=shine,name=name,dist=dist,highlight=nil}
    espEntries[plr]=e
    return e
end
local function updateESP(now)
    local camera=workspace.CurrentCamera
    if not camera then return end
    local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local targets={}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr~=player then
            targets[plr]=true
            local e=getEspEntry(plr)
            local char=plr.Character
            local h=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local eligible=settings.esp and h and h.Health>0 and root
            if eligible then
                local distance=me and (root.Position-me.Position).Magnitude or 0
                eligible=(distance<=settings.espRange)
                if eligible then
                    local top,onScreen=camera:WorldToViewportPoint(root.Position+Vector3.new(0,3.0,0))
                    local bottom=camera:WorldToViewportPoint(root.Position-Vector3.new(0,3.25,0))
                    eligible=onScreen and top.Z>0 and bottom.Z>0
                    if eligible then
                        local height=math.clamp(math.abs(bottom.Y-top.Y),15,900)
                        local width=height*0.45
                        e.box.Size=UDim2.fromOffset(width,height)
                        e.box.Position=UDim2.fromOffset(top.X-width*0.5,top.Y)
                        e.name.Size=UDim2.new(1,100,0,18)
                        e.name.Position=UDim2.fromOffset(-50,-23)
                        e.dist.Size=UDim2.new(1,100,0,17)
                        e.dist.Position=UDim2.new(0,-50,1,3)
                        local tint=roleColor(plr)
                        e.outline.Color=tint
                        e.name.Text=plr.DisplayName
                        e.dist.Text=string.format("%.0f studs",distance)
                        e.name.Visible=settings.espName
                        e.dist.Visible=settings.espDistance
                        e.shine.Enabled=settings.espShimmer
                        e.shine.Rotation=(now*85)%360
                        e.outline.Transparency=settings.espShimmer and 0.05+math.sin(now*2.5+plr.UserId)*0.08 or 0.05
                        e.box.Visible=true
                    end
                end
            end
            if not eligible then e.box.Visible=false end
            if settings.esp and settings.espHighlight and char and h and h.Health>0 then
                if not e.highlight or e.highlight.Parent~=char then
                    if e.highlight then e.highlight:Destroy() end
                    e.highlight=new("Highlight",char,{Name="AETHER_MONO_CHAMS",
                        Adornee=char,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,
                        FillTransparency=0.9,OutlineTransparency=0.18})
                end
                local tint=roleColor(plr)
                e.highlight.OutlineColor=tint
                e.highlight.FillColor=tint
                e.highlight.FillTransparency=0.86+0.08*(0.5+0.5*math.sin(now*3+plr.UserId))
            elseif e.highlight then
                e.highlight:Destroy(); e.highlight=nil
            end
        end
    end
    for plr in pairs(espEntries) do
        if not targets[plr] then destroyEspEntry(plr) end
    end
end

-- Square-line shimmer on nearby anchored map geometry. Limits prevent huge UI counts.
local grids={}
local function clearGrids()
    for part, entries in pairs(grids) do
        for _, guiItem in ipairs(entries) do pcall(function() guiItem:Destroy() end) end
        grids[part]=nil
    end
end
local function faceSize(part,face)
    local s=part.Size
    if face==Enum.NormalId.Top then return s.X,s.Z end
    if face==Enum.NormalId.Right then return s.Z,s.Y end
    return s.X,s.Y
end
local function makeGrid(part,face)
    local sw,sh=faceSize(part,face)
    local surf=new("SurfaceGui",part,{Name="AETHER_MONO_GRID",Adornee=part,
        Face=face,AlwaysOnTop=false,LightInfluence=0.1,
        SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud,PixelsPerStud=12,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    local group=new("CanvasGroup",surf,{Size=UDim2.fromScale(1,1),
        BorderSizePixel=0,BackgroundTransparency=1,GroupTransparency=0.42})
    local nx=math.clamp(math.floor(sw/2.8),2,13)
    local ny=math.clamp(math.floor(sh/2.8),2,13)
    for i=0,nx do
        new("Frame",group,{Position=UDim2.fromScale(i/nx,0),
            Size=UDim2.new(0,1,1,0),BorderSizePixel=0,
            BackgroundColor3=C.white,BackgroundTransparency=0.15})
    end
    for i=0,ny do
        new("Frame",group,{Position=UDim2.fromScale(0,i/ny),
            Size=UDim2.new(1,0,0,1),BorderSizePixel=0,
            BackgroundColor3=C.white,BackgroundTransparency=0.15})
    end
    return surf,group
end
local gridGroups={}
local function scanGrids()
    if not settings.tiles then clearGrids(); table.clear(gridGroups); return end
    local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local wanted={}
    local count=0
    -- GetPartBoundsInRadius uses the spatial index; avoids scanning the full Workspace.
    local overlap=OverlapParams.new()
    overlap.FilterType=Enum.RaycastFilterType.Exclude
    if player.Character then overlap.FilterDescendantsInstances={player.Character} end
    overlap.MaxParts=160
    for _,part in ipairs(workspace:GetPartBoundsInRadius(root.Position,settings.tileRadius,overlap)) do
        if count>=32 then break end
        if part:IsA("BasePart") and part.Anchored and part.Transparency<0.55
            and math.max(part.Size.X,part.Size.Y,part.Size.Z)>=7
            and part.Shape==Enum.PartType.Block then
            local model=part:FindFirstAncestorOfClass("Model")
            if not (model and model:FindFirstChildOfClass("Humanoid")) then
                wanted[part]=true; count=count+1
                if not grids[part] then
                    local faces
                    if part.Size.Y<=2.5 then faces={Enum.NormalId.Top}
                    else faces={Enum.NormalId.Front,Enum.NormalId.Right} end
                    local entries={}
                    for _,face in ipairs(faces) do
                        local surf,group=makeGrid(part,face)
                        entries[#entries+1]=surf
                        gridGroups[#gridGroups+1]={part=part,group=group,
                            phase=math.random()*math.pi*2}
                    end
                    grids[part]=entries
                end
            end
        end
    end
    for part,entries in pairs(grids) do
        if not wanted[part] or not part.Parent then
            for _,item in ipairs(entries) do item:Destroy() end
            grids[part]=nil
        end
    end
    local kept={}
    for _, item in ipairs(gridGroups) do
        if grids[item.part] and item.group.Parent then kept[#kept+1]=item end
    end
    gridGroups=kept
end
local function animateGrids(now)
    local intensity=settings.tileIntensity/100
    for _,item in ipairs(gridGroups) do
        if item.group.Parent then
            item.group.GroupTransparency=math.clamp(0.88-intensity*0.55
                + 0.14*math.sin(now*2.5+item.phase),0.12,0.98)
        end
    end
end

-- Main panel copies the screenshot's hierarchy, dark flat palette, and compact cards.
local panel=new("Frame",gui,{Name="AETHER_MONO_PANEL",AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(960,615),
    BackgroundColor3=C.bg,BorderSizePixel=0,ClipsDescendants=true})
stroke(panel,Color3.fromRGB(46,46,48),0.02)
round(panel,7)
local uiscale=new("UIScale",panel,{Scale=1})
local sidebar=new("Frame",panel,{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(76,615),
    BackgroundColor3=C.side,BorderSizePixel=0})
new("Frame",sidebar,{Position=UDim2.new(1,-1,0,0),Size=UDim2.new(0,1,1,0),
    BackgroundColor3=C.border,BorderSizePixel=0})
local header=new("Frame",panel,{Position=UDim2.fromOffset(77,0),Size=UDim2.fromOffset(883,60),
    BackgroundTransparency=1})
text(header,"Аим",23,17,78,27,14,C.text,true)
text(header,"@moonstonedlc Free  /  AETHER MONO V4",73,21,380,17,10,C.muted)
new("Frame",panel,{Position=UDim2.fromOffset(77,59),Size=UDim2.fromOffset(883,1),
    BackgroundColor3=C.border,BorderSizePixel=0})
local close=simpleButton(header,"×",836,14,33,32,function() end)
close.TextSize=20; close.BackgroundTransparency=1; close.UIStroke.Transparency=1
local menuOpen=true
local function menuToggle()
    menuOpen=not menuOpen
    if menuOpen then
        panel.Visible=true
        panel.BackgroundTransparency=1
        tween(panel,{BackgroundTransparency=0},0.24)
    else
        panel.Visible=false
    end
end
listen(close.MouseButton1Click,menuToggle)

local pageHost=new("Frame",panel,{Position=UDim2.fromOffset(76,61),
    Size=UDim2.fromOffset(884,554),BackgroundTransparency=1,ClipsDescendants=true})
local pages={}
local navBtns={}
local function page(name)
    local p=new("ScrollingFrame",pageHost,{Name=name,Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,BorderSizePixel=0,Visible=false,
        CanvasSize=UDim2.fromOffset(0,670),ScrollBarThickness=3,
        ScrollBarImageColor3=C.line,ScrollingDirection=Enum.ScrollingDirection.Y})
    pages[name]=p
    return p
end
local pAim=page("Aim")
local pEsp=page("ESP")
local pVisuals=page("Visuals")
local pMove=page("Movement")
local pScreen=page("Screen")
local pSettings=page("Settings")
local function showPage(name)
    for key, item in pairs(pages) do
        item.Visible=key==name
        if key==name then
            item.CanvasPosition=Vector2.zero
        end
    end
    for key, btn in pairs(navBtns) do
        tween(btn,{BackgroundColor3=key==name and Color3.fromRGB(34,34,36) or C.side},0.15)
        btn.TextColor3=key==name and C.white or C.muted
    end
    local caption=header:FindFirstChild("PageCaption")
    if caption then caption.Text=({Aim="Аим",ESP="ESP",Visuals="Визуалы",
        Movement="Движение",Screen="Экран",Settings="Настройки"})[name] end
end
local cap=header:FindFirstChildWhichIsA("TextLabel")
cap.Name="PageCaption"
local navSpecs={
    {"Aim","◎"},{"ESP","▣"},{"Visuals","◈"},
    {"Movement","⌁"},{"Screen","▤"},{"Settings","⚙"},
}
for i, spec in ipairs(navSpecs) do
    local key=spec[1]
    local nav=new("TextButton",sidebar,{Name=key,Position=UDim2.fromOffset(18,17+(i-1)*67),
        Size=UDim2.fromOffset(40,40),Text=spec[2],TextColor3=C.muted,
        TextSize=21,Font=Enum.Font.GothamBold,BackgroundColor3=C.side,
        BorderSizePixel=0,AutoButtonColor=false})
    round(nav,10)
    navBtns[key]=nav
    listen(nav.MouseButton1Click,function() showPage(key) end)
end
local function card(p,x,y,w,h,title)
    local f=new("Frame",p,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
        BackgroundColor3=C.card,BorderSizePixel=0})
    round(f,10); stroke(f,C.border,0.15)
    text(f,title,16,12,w-32,23,13,C.text,true)
    new("Frame",f,{Position=UDim2.fromOffset(1,45),Size=UDim2.new(1,-2,0,1),
        BackgroundColor3=C.border,BorderSizePixel=0})
    return f
end
local function switch(parent,title,key,y,w,action)
    local width=w or parent.AbsoluteSize.X
    if width<10 then width=270 end
    text(parent,title,16,y,width-91,22,11,C.muted)
    local track=new("TextButton",parent,{Position=UDim2.new(1,-56,0,y),
        Size=UDim2.fromOffset(38,21),Text="",BackgroundColor3=C.line,
        BorderSizePixel=0,AutoButtonColor=false})
    round(track,11)
    local dot=new("Frame",track,{Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(15,15),
        BackgroundColor3=C.muted,BorderSizePixel=0})
    round(dot,9)
    local function refresh()
        tween(track,{BackgroundColor3=settings[key] and C.white or C.line},0.12)
        tween(dot,{Position=UDim2.fromOffset(settings[key] and 20 or 3,3),
            BackgroundColor3=settings[key] and C.bg or C.muted},0.12)
    end
    listen(track.MouseButton1Click,function()
        setOption(key,not settings[key])
        refresh()
        if action then action(settings[key]) end
    end)
    refresh()
    return refresh
end
local function slider(parent,title,key,low,high,y,w,action,units)
    local width=w or 255
    local valueLabel=text(parent,"",width-49,y,48,17,10,C.muted)
    valueLabel.TextXAlignment=Enum.TextXAlignment.Right
    text(parent,title,16,y,width-74,17,11,C.muted)
    local track=new("Frame",parent,{Position=UDim2.fromOffset(16,y+31),
        Size=UDim2.fromOffset(width-16,4),BackgroundColor3=C.line,BorderSizePixel=0})
    round(track,3)
    local fill=new("Frame",track,{Size=UDim2.fromScale(0,1),BackgroundColor3=C.white,BorderSizePixel=0})
    round(fill,3)
    local knob=new("Frame",track,{AnchorPoint=Vector2.new(.5,.5),
        Position=UDim2.fromScale(0,.5),Size=UDim2.fromOffset(12,12),
        BackgroundColor3=C.white,BorderSizePixel=0})
    round(knob,7)
    local function update(value)
        value=math.floor(math.clamp(value,low,high)+0.5)
        setOption(key,value)
        local fraction=(value-low)/(high-low)
        fill.Size=UDim2.fromScale(fraction,1)
        knob.Position=UDim2.fromScale(fraction,.5)
        valueLabel.Text=tostring(value)..(units or "")
        if action then action(value) end
    end
    local function setX(x)
        local aw=track.AbsoluteSize.X
        if aw<=0 then return end
        update(low+math.clamp((x-track.AbsolutePosition.X)/aw,0,1)*(high-low))
    end
    local drag=false
    listen(track.InputBegan,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
            inp.UserInputType==Enum.UserInputType.Touch then drag=true;setX(inp.Position.X) end
    end)
    listen(UIS.InputChanged,function(inp)
        if drag and (inp.UserInputType==Enum.UserInputType.MouseMovement or
            inp.UserInputType==Enum.UserInputType.Touch) then setX(inp.Position.X) end
    end)
    listen(UIS.InputEnded,function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or
            inp.UserInputType==Enum.UserInputType.Touch then drag=false end
    end)
    update(settings[key])
end
local function paragraph(p,message,x,y,w)
    return text(p,message,x,y,w,24,11,C.muted)
end

-- AIM / Visual FOV (no auto-aim)
local aimLeft=card(pAim,16,14,277,427,"FOV / КАМЕРА")
switch(aimLeft,"Круг FOV","fovRing",61,277,updateHud)
slider(aimLeft,"Радиус круга","ringRadius",30,350,108,257,updateHud," px")
slider(aimLeft,"FOV камеры","fov",40,120,197,257,function(v)
    local cam=workspace.CurrentCamera
    if cam then cam.FieldOfView=v end
    updateHud()
end,"°")
switch(aimLeft,"Зелёные края при max FOV","greenEdges",296,277,updateHud)
paragraph(aimLeft,"Зелёное свечение усиливается от 102° до 120°.",16,347,246)
local aimRight=card(pAim,306,14,277,246,"ПАРАМЕТРЫ")
switch(aimRight,"Сохранять FOV","lockFov",62,277,updateHud)
paragraph(aimRight,"Прицел и круг FOV — элементы интерфейса.",16,109,248)
paragraph(aimRight,"Они не управляют наведением или выстрелами.",16,138,248)
local infoCard=card(pAim,598,14,267,427,"ПРОСМОТР")
local preview=new("ViewportFrame",infoCard,{Position=UDim2.fromOffset(8,51),
    Size=UDim2.fromOffset(251,296),BackgroundColor3=Color3.fromRGB(11,11,12),
    BorderSizePixel=0,Ambient=Color3.fromRGB(190,190,190),LightColor=C.white,
    LightDirection=Vector3.new(-0.5,-1,-0.4)})
round(preview,6)
local pvCamera=new("Camera",preview,{FieldOfView=35})
preview.CurrentCamera=pvCamera
local world=new("WorldModel",preview,{})
local previewBox=new("Frame",preview,{Position=UDim2.new(.22,0,.12,0),
    Size=UDim2.new(.56,0,.79,0),BackgroundTransparency=1})
stroke(previewBox,C.white,0.12,1)
text(infoCard,player.DisplayName,15,356,237,19,12,C.text,true)
text(infoCard,"LIVE CHARACTER / ESP",15,379,237,15,10,C.muted)
local function renderPreview()
    for _, child in ipairs(world:GetChildren()) do child:Destroy() end
    local char=player.Character
    if not char then return end
    local before=char.Archivable
    char.Archivable=true
    local ok, clone=pcall(function() return char:Clone() end)
    char.Archivable=before
    if not ok or not clone then return end
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("BaseScript") then d:Destroy()
        elseif d:IsA("BasePart") then d.Anchored=true;d.CanCollide=false end
    end
    clone.Parent=world
    clone:PivotTo(CFrame.new(0,0,0))
    local _,size=clone:GetBoundingBox()
    local height=math.max(size.Y,4)
    pvCamera.CFrame=CFrame.lookAt(Vector3.new(0,height*.5,height*1.7),
        Vector3.new(0,height*.50,0))
end
task.defer(function() if alive then pcall(renderPreview) end end)
listen(player.CharacterAdded,function()
    task.delay(1.3,function() if alive then pcall(renderPreview) end end)
end)
pAim.CanvasSize=UDim2.fromOffset(0,482)

-- ESP PAGE
local espCard=card(pEsp,16,14,277,454,"ESP / ИГРОКИ")
switch(espCard,"ESP-боксы","esp",63,277)
switch(espCard,"Никнеймы","espName",112,277)
switch(espCard,"Дистанция","espDistance",161,277)
switch(espCard,"Подсветка сквозь стены","espHighlight",210,277)
switch(espCard,"Белые переливания","espShimmer",259,277)
slider(espCard,"Дальность ESP","espRange",50,2000,323,257,nil," st")
local espInfo=card(pEsp,306,14,559,244,"ЦВЕТА РОЛЕЙ")
local legend={{"Убийца / killer",C.red},{"Невиновный / innocent",C.green},
    {"Шериф / sheriff",Color3.fromRGB(100,166,255)},{"Неизвестно",C.gray}}
for i,item in ipairs(legend) do
    new("Frame",espInfo,{Position=UDim2.fromOffset(18,57+(i-1)*40),
        Size=UDim2.fromOffset(9,9),BackgroundColor3=item[2],BorderSizePixel=0})
    text(espInfo,item[1],38,50+(i-1)*40,430,22,12,C.muted)
end
paragraph(pEsp,"Роль отображается только если игра передаёт её клиенту. Иначе — серый.",320,288,530)
pEsp.CanvasSize=UDim2.fromOffset(0,520)

-- VISUALS PAGE
local v1=card(pVisuals,16,14,277,396,"КВАДРАТНЫЕ ПЕРЕЛИВАНИЯ")
switch(v1,"Белая сетка стен и пола","tiles",63,277,function(enabled)
    if not enabled then clearGrids();table.clear(gridGroups) else scanGrids() end
end)
slider(v1,"Радиус поверхностей","tileRadius",20,140,120,257,function() scanGrids() end," st")
slider(v1,"Яркость сетки","tileIntensity",10,100,218,257,nil,"%")
paragraph(v1,"Квадраты накладываются на ближайшие",16,310,243)
paragraph(v1,"стены и пол без изменения материалов.",16,333,243)
local v2=card(pVisuals,306,14,277,228,"СВЕТ И ЭФФЕКТЫ")
switch(v2,"Bloom / мягкое свечение","bloom",64,277,updateLighting)
switch(v2,"Осветлить карту","fullbright",118,277,updateLighting)
paragraph(v2,"Эффекты работают только на этом клиенте.",16,174,247)
local v3=card(pVisuals,598,14,267,228,"ИНФОРМАЦИЯ")
paragraph(v3,"Сетка ограничена 32 деталями поблизости",16,62,239)
paragraph(v3,"для снижения нагрузки на слабых ПК.",16,91,239)
paragraph(v3,"Белые линии плавно мерцают.",16,120,239)
pVisuals.CanvasSize=UDim2.fromOffset(0,475)

-- MOVEMENT PAGE
local m1=card(pMove,16,14,277,382,"ХОДЬБА")
switch(m1,"Сохранять WalkSpeed","lockSpeed",63,277,keepMovement)
slider(m1,"WalkSpeed","speed",8,200,121,257,function(v)
    scope.AetherNightfallSavedSpeed=v; keepMovement()
end)
paragraph(m1,"Скорость применяется повторно после Reset",16,227,246)
paragraph(m1,"и при попытке игры её изменить.",16,251,246)
local m2=card(pMove,306,14,277,280,"ПРЫЖОК")
switch(m2,"Сохранять JumpPower","lockJump",63,277,keepMovement)
slider(m2,"JumpPower","jump",20,150,121,257,keepMovement)
pMove.CanvasSize=UDim2.fromOffset(0,450)

-- SCREEN PAGE
local s1=card(pScreen,16,14,565,323,"ФОРМАТ КАДРА")
paragraph(s1,"Это визуальные маски кадра, не смена разрешения монитора.",16,58,530)
local options={"FULL","1:1","4:3","5:4","16:10","16:9","16:4"}
local ratioButtons={}
local function refreshRatios()
    for value, btn in pairs(ratioButtons) do
        local active=value==settings.aspect
        btn.BackgroundColor3=active and C.white or C.card
        btn.TextColor3=active and C.bg or C.text
    end
end
for i,option in ipairs(options) do
    local col=(i-1)%3
    local row=math.floor((i-1)/3)
    ratioButtons[option]=simpleButton(s1,option,16+col*179,100+row*60,166,43,function()
        setOption("aspect",option);applyAspect();refreshRatios()
    end)
end
refreshRatios()
local s2=card(pScreen,596,14,269,280,"ПОЯСНЕНИЕ")
paragraph(s2,"1:1 — квадратный кадр",16,60,240)
paragraph(s2,"4:3 — классическое соотношение",16,99,240)
paragraph(s2,"16:4 — широкий киноформат",16,138,240)
paragraph(s2,"Реальный stretch задаётся в настройках",16,190,240)
paragraph(s2,"экрана и видеодрайвера, не Lua.",16,211,240)
pScreen.CanvasSize=UDim2.fromOffset(0,388)

-- SETTINGS PAGE
local setCard=card(pSettings,16,14,565,268,"ПРОГРАММА")
paragraph(setCard,"Горячая клавиша: LEFT CTRL / RIGHT CTRL",16,67,525)
paragraph(setCard,"Настройки сохраняются автоматически, если доступна запись файлов.",16,109,525)
paragraph(setCard,"Повторный запуск корректно удаляет прошлые подключения и объекты.",16,151,525)
simpleButton(setCard,"Восстановить настройки",16,202,258,39,function()
    for k,v in pairs(defaults) do setOption(k,v) end
    keepMovement();updateHud();updateLighting();applyAspect()
    clearGrids();table.clear(gridGroups)
    refreshRatios()
end)
simpleButton(setCard,"Сохранить сейчас",291,202,258,39,saveNow)
local diag=card(pSettings,596,14,269,268,"СТАТУС")
paragraph(diag,"AETHER MONO V4",16,61,236)
paragraph(diag,"Без внешних библиотек",16,100,236)
paragraph(diag,"CLIENT / LUA",16,139,236)
paragraph(diag,"Клавиша открытия: CTRL",16,178,236)
pSettings.CanvasSize=UDim2.fromOffset(0,360)

-- Drag by header, responsive scaling and input controls.
local dragging, dragStart, panelStart = false, nil, nil
listen(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
        input.UserInputType==Enum.UserInputType.Touch then
        dragging=true;dragStart=input.Position;panelStart=panel.Position
    end
end)
listen(UIS.InputChanged,function(input)
    if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or
        input.UserInputType==Enum.UserInputType.Touch) then
        local diff=(input.Position-dragStart)/uiscale.Scale
        panel.Position=UDim2.new(panelStart.X.Scale,panelStart.X.Offset+diff.X,
            panelStart.Y.Scale,panelStart.Y.Offset+diff.Y)
    end
end)
listen(UIS.InputEnded,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
        input.UserInputType==Enum.UserInputType.Touch then dragging=false end
end)
listen(UIS.InputBegan,function(input,processed)
    if not alive or UIS:GetFocusedTextBox()~=nil then return end
    if input.KeyCode==Enum.KeyCode.LeftControl or input.KeyCode==Enum.KeyCode.RightControl then
        menuToggle()
    end
end)
local timer,gridTimer,layoutTimer=0,0,0
listen(RS.Heartbeat,function(dt)
    timer=timer+dt;gridTimer=gridTimer+dt;layoutTimer=layoutTimer+dt
    if timer>=0.08 then
        timer=0
        keepMovement();updateHud();updateESP(os.clock());animateGrids(os.clock())
    end
    if gridTimer>=2.2 then gridTimer=0;scanGrids() end
    if layoutTimer>=0.65 then
        layoutTimer=0
        local cam=workspace.CurrentCamera
        if cam then
            local vp=cam.ViewportSize
            uiscale.Scale=math.min(1,(vp.X-26)/960,(vp.Y-26)/615)
            applyAspect()
        end
    end
end)
local function destroy()
    if not alive then return end
    saveNow()
    alive=false
    for _,conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    if humanoidConnection then pcall(function() humanoidConnection:Disconnect() end) end
    for plr in pairs(espEntries) do destroyEspEntry(plr) end
    clearGrids()
    for k,v in pairs(originalLighting) do pcall(function() Lighting[k]=v end) end
    if bloom then bloom:Destroy() end
    if color then color:Destroy() end
    local camera=workspace.CurrentCamera
    if camera then camera.FieldOfView=originalFov end
    if currentHumanoid and currentHumanoid.Parent and currentHumanoid.Health>0 then
        pcall(function()
            if originalSpeed then currentHumanoid.WalkSpeed=originalSpeed end
            if originalJump then currentHumanoid.JumpPower=originalJump end
        end)
    end
    gui:Destroy(); hud:Destroy()
    if scope.AetherMonoV4 and scope.AetherMonoV4.Destroy==destroy then
        scope.AetherMonoV4=nil
    end
end
scope.AetherMonoV4={Destroy=destroy,Version="4.0",Config=settings,
    Show=function() if alive and not menuOpen then menuToggle() end end,
    Hide=function() if alive and menuOpen then menuToggle() end end}
showPage("Aim")
applyAspect();updateHud();updateLighting();keepMovement();saveNow()
print("[AETHER MONO V4] CTRL: menu / WalkSpeed / ESP / white-square grid / FOV glow ready")
