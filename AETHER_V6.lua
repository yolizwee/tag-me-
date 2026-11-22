-- AETHER V6 | Client UI, camera and bounded visual renderer.
-- Verified public root place: 93978595733734 (2026-11-22).
-- No private game schema is assumed. See README.md for the explicit adapter API.
-- Run as a LocalScript; this file does not install or supply a script executor.

local S = {}
for _, name in ipairs({"Players", "RunService", "UserInputService", "TweenService", "HttpService",
    "Lighting", "Workspace", "GuiService", "SoundService", "ContentProvider", "ReplicatedStorage"}) do S[name] = game:GetService(name) end
assert(S.RunService:IsClient() and S.Players.LocalPlayer, "AETHER V6 must run on the Roblox client")
local player = S.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 15)
assert(playerGui, "AETHER V6: PlayerGui was not available")
local session = shared.AETHER_V6_SESSION or {profiles = {}}
if not shared.AETHER_V6_SESSION and shared.AETHER_V5_SESSION then
    for name,settings in pairs(shared.AETHER_V5_SESSION.profiles or {}) do session.profiles[name]=table.clone(settings) end
end
if shared.AETHER_V5 and type(shared.AETHER_V5.Destroy)=="function" then pcall(function() shared.AETHER_V5:Destroy() end) end
shared.AETHER_V6_SESSION = session
if shared.AETHER_V6 and type(shared.AETHER_V6.Destroy) == "function" then
    pcall(function() shared.AETHER_V6:Destroy() end)
end
for _,guiName in ipairs({"AETHER_V6","AETHER_V5"}) do
local stale = playerGui:FindFirstChild(guiName)
if stale then
    local shutdown = stale:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableFunction") then pcall(function() shutdown:Invoke() end) end
    if stale.Parent then stale:Destroy() end
end
end

local App = {alive = true, supported = game.PlaceId == 93978595733734, studio = S.RunService:IsStudio(),
    scopes = {}, refreshers = {}, schema = {}, config = {}, themes = {}, tweens = {},
    roles = {}, pallets = {}, allowedPlaces = {[93978595733734] = true},
    state = {open = true, tab = "Aim", moon = false, look = false, aimHeld = false,
        dodge = nil, nextDodge = 0, fps = 0, time = 0, dirty = true, lastError = nil}}
shared.AETHER_V6 = App

local function clean(scope)
    for i = #scope, 1, -1 do
        local object = scope[i]
        if typeof(object) == "RBXScriptConnection" then object:Disconnect()
        elseif typeof(object) == "Instance" then object:Destroy()
        elseif type(object) == "function" then pcall(object) end
        scope[i] = nil
    end
end
local function scope(name)
    App.scopes[name] = App.scopes[name] or {}
    return App.scopes[name]
end
local function own(object, name)
    table.insert(scope(name or "main"), object)
    return object
end
local function connect(signal, callback, name) return own(signal:Connect(callback), name) end
local function clear(name) if App.scopes[name] then clean(App.scopes[name]) end end
local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(parent, radius) return create("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent) end
local function stroke(parent, color, thickness)
    return create("UIStroke", {Color = color or Color3.fromRGB(36,36,36), Thickness = thickness or 1}, parent)
end
local function finite(value) return type(value) == "number" and value == value and math.abs(value) < math.huge end
local function consistent(settings)
    if settings.dangerCritical and settings.dangerWarning and settings.dangerCritical>=settings.dangerWarning then
        return false,"Critical distance must be smaller than Warning distance"
    end
    return true
end
local function hexColor(value)
    if type(value) ~= "string" then return nil end
    local hex = value:match("^#?(%x%x%x%x%x%x)$")
    if not hex then return nil end
    return Color3.fromRGB(tonumber(hex:sub(1,2),16), tonumber(hex:sub(3,4),16), tonumber(hex:sub(5,6),16))
end
local function color(key) return hexColor(App.config[key]) or Color3.new(1,1,1) end
local function define(key, default, lo, hi, choices)
    App.schema[key] = {default = default, lo = lo, hi = hi, choices = choices}
    App.config[key] = default
end
local function valid(key, value)
    local spec = App.schema[key]
    if not spec or type(value) ~= type(spec.default) then return false end
    if type(value) == "number" then return finite(value) and value >= spec.lo and value <= spec.hi end
    if spec.choices then return table.find(spec.choices, value) ~= nil end
    if key:find("Color$") then return hexColor(value) ~= nil end
    if key:find("Key$") then
        local ok, item = pcall(function() return Enum.KeyCode[value] end)
        return ok and item ~= nil and item ~= Enum.KeyCode.Unknown
    end
    return type(value) ~= "string" or #value <= 80
end
local function refresh(key)
    for _, callback in ipairs(App.refreshers[key] or {}) do callback() end
end
local function set(key, value)
    if not valid(key, value) then return false end
    local proposal=table.clone(App.config);proposal[key]=value
    if not consistent(proposal) then refresh(key);return false end
    App.config[key] = value
    App.state.dirty = true
    refresh(key)
    return true
end
local function observe(key, callback)
    App.refreshers[key] = App.refreshers[key] or {}
    table.insert(App.refreshers[key], callback)
    callback()
end
local function tween(object, duration, properties)
    local previous = App.tweens[object]
    if previous then previous:Cancel(); App.tweens[object] = nil end
    if App.config.animations == false then
        for key, value in pairs(properties) do object[key] = value end
        return nil
    end
    local item = S.TweenService:Create(object, TweenInfo.new(duration / (App.config.animationSpeed or 1),
        Enum.EasingStyle.Quint, Enum.EasingDirection.Out), properties)
    App.tweens[object] = item
    local connection
    connection = item.Completed:Connect(function()
        connection:Disconnect()
        if App.tweens[object] == item then App.tweens[object] = nil end
    end)
    item:Play()
    return item
end

-- Configuration is flat, validated and serialized as JSON data only.
for key, default in pairs({esp=false, rainbow=false, boxes=true, corners=false, skeleton=false, names=true,
    distances=true, tracers=false, chams=true, outline=true, health=false, killerPulse=true, killerLabel=true,
    killerBox=true, killerGlow=true, killerDistance=true, killerRainbow=false, palletESP=false,
    palletRainbow=false, palletWhite=false, palletPulse=true, palletLabels=true, palletDistance=true,
    whiteTiles=false, rainbowTiles=false, neonEdges=false, crystalWalls=false, glossyFloors=false,
    surfacePulse=false, squareWaves=false, reflections=false, ambientGlow=false, correction=false,
    worldLowFPS=false, customFOV=false, smoothFOV=true, fovAnimation=false, fovCircle=true,
    edgeGlow=true, cameraOffset=false, shakeReduction=false, cameraTilt=false, cameraZoom=false,
    cameraSmoothing=false, crosshair=false, moonEnabled=true, dodgeEnabled=true, quickTurn=true,
    lookBack=true, smoothStrafe=false, cameraLean=false, autoReset=true, followOffset=false,
    practice=false, aimEnabled=false, aimVisible=true, aimTracking=false, targetPreview=true,
    hud=true, animations=true, performance=false}) do define(key,default) end
local numeric = {
    rgbSpeed={0.16,0.02,1}, glow={0.5,0,1}, transparency={0.72,0,1}, espDistance={800,25,2000},
    palletRange={500,25,2000}, worldSpeed={0.7,0.05,3}, tileSize={4,1,12}, worldIntensity={0.35,0,1},
    worldRange={65,15,140}, fov={90,30,120}, fovEase={9,1,25}, fovAmplitude={3,0,15},
    circleRadius={100,10,400}, circleThickness={1,1,4}, edgeOpacity={0.45,0,0.9}, edgeIntensity={0.7,0,1},
    offsetX={0,-6,6}, offsetY={0,-4,4}, offsetZ={0,-10,10}, tilt={0,-20,20}, zoom={0,-12,12},
    cameraSmoothness={12,2,30}, shakeStrength={0.7,0,1}, crosshairSize={5,2,16},
    moonSensitivity={8,1,20}, rotationSpeed={540,90,1440}, dodgeSmoothness={0.6,0,1},
    cameraFollow={1,0,1}, recovery={10,2,25}, cooldown={1.5,0.25,8}, lean={5,0,15},
    aimSmoothness={0.5,0.05,1}, uiScale={1,0.65,1.3}, blur={12,0,30}, animationSpeed={1,0.3,2},
    hudX={0.5,0.1,0.9}, hudY={0.94,0.1,0.98}, displayWidth={4,1,64}, displayHeight={3,1,64}}
for key, spec in pairs(numeric) do define(key,spec[1],spec[2],spec[3]) end
for key, value in pairs({accentColor="#FFFFFF", fovColor="#FFFFFF", edgeColor="#65FF91",
    killerColor="#FF495C", survivorColor="#70E9CA", unknownColor="#B6BDC8", palletColor="#E4DB9B",
    usedPalletColor="#8C8798", crosshairColor="#FFFFFF", customBackgroundColor="#090909"}) do define(key,value) end
define("menuKey","LeftControl"); define("moonKey","X"); define("dodgeKey","Z")
define("quickKey","C"); define("lookKey","V"); define("aimKey","Q")
define("moonMode","Automatic",nil,nil,{"Automatic","Hold","Toggle"})
define("dodgeMode","Automatic",nil,nil,{"Automatic","Hold","Toggle"})
define("direction","Right",nil,nil,{"Left","Right","Random"})
define("theme","Midnight",nil,nil,{"Midnight","Pure Black","Frost White","Graphite","Crimson","Emerald","Custom RGB"})
define("displayPreset","16:9",nil,nil,{"16:9","16:10","4:3","5:4","1:1","16:4","Custom"})
for key,default in pairs({dangerEnabled=true,dangerEdges=true,dangerText=true,dangerSound=true,dangerMuteMenu=true}) do define(key,default) end
for key,spec in pairs({dangerWarning={35,5,200},dangerCritical={15,1,100},dangerIntensity={65,0,100},
    dangerPulseSpeed={1.2,0.5,3},dangerX={0.5,0.15,0.85},dangerY={0.4,0.15,0.8},
    dangerVolume={0.35,0,1},dangerSoundCooldown={5,1,30}}) do define(key,spec[1],spec[2],spec[3]) end
define("dangerColor","#FF3848");define("dangerStyle","CLASSIC",nil,nil,{"CLASSIC","MINIMAL"})
define("dangerSoundStyle","Soft",nil,nil,{"Soft","Digital","Alarm"})
for key,default in pairs({moonRecovery=true,dodgeRecovery=true,dodgeUseDuration=true,speedEnabled=true,
    keybindHUD=true,keybindOnlyActive=false,keybindLocked=false,spectatorHUD=true,spectatorCompact=true,
    actionNotifications=true,rainbowHUD=false,movementPreview=false,protectionRequested=false,protectionVisual=true}) do define(key,default) end
for key,spec in pairs({moonSpeed={12,1,30},moonDuration={1.5,0.4,6},moonRotation={180,0,180},moonSmoothness={0.7,0,1},
    spinDuration={0.65,0.2,1.5},spinAngle={360,30,1440},speedTarget={23,1,40},keybindScale={1,0.6,1.6},
    keybindTransparency={0.24,0,0.9},keybindX={0.13,0.08,0.9},keybindY={0.28,0.1,0.85},
    spectatorX={0.87,0.1,0.9},spectatorY={0.18,0.1,0.85}}) do define(key,spec[1],spec[2],spec[3]) end
define("speedKey","B");define("moonDirection","Backward",nil,nil,{"Backward","Left","Right"})
define("spinPreset","360 Dodge",nil,nil,{"180 Quick Turn","360 Dodge","720 Spin","Custom Angle"})
define("keybindAccentColor","#7EE4B0")
local C = App.config

local UI = {themeBindings = {}, cards = {}, pages = {}, nav = {}, activeSliders = {}, keyButtons = {}}
App.ui = UI
local palettes = {
    Midnight={"#090909","#111111","#242424","#F2F2F2","#929292"},
    ["Pure Black"]={"#000000","#090909","#202020","#FFFFFF","#9B9B9B"},
    ["Frost White"]={"#ECEEF0","#FAFBFC","#CDD0D4","#15171B","#555D67"},
    Graphite={"#17191D","#202329","#343840","#F0F1F3","#A2A7AF"},
    Crimson={"#10090B","#181013","#38242A","#FAF0F2","#B9A0A8"},
    Emerald={"#08100D","#101A16","#253B31","#EEFAF3","#95B3A4"}}
local function palette(index)
    local values = palettes[C.theme] or palettes.Midnight
    if C.theme == "Custom RGB" and index == 1 then return color("customBackgroundColor") end
    return hexColor(values[index])
end
local function themed(object, property, index)
    table.insert(UI.themeBindings, {object,property,index})
    object[property] = palette(index)
end
local function frame(parent, properties, surface)
    properties = properties or {}; properties.BorderSizePixel = 0
    local object = create("Frame",properties,parent)
    if surface then themed(object,"BackgroundColor3",surface) end
    return object
end
local function label(parent, text, properties, dim)
    local props = {Text=text,BackgroundTransparency=1,TextSize=11,Font=Enum.Font.Gotham,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,BorderSizePixel=0}
    for key,value in pairs(properties or {}) do props[key] = value end
    local object = create("TextLabel",props,parent)
    themed(object,"TextColor3",dim and 5 or 4)
    return object
end
local function button(parent, text, properties)
    local props = {Text=text,AutoButtonColor=false,TextSize=11,Font=Enum.Font.Gotham,
        BorderSizePixel=0,BackgroundTransparency=0,Size=UDim2.fromOffset(110,28)}
    for key,value in pairs(properties or {}) do props[key] = value end
    local object = create("TextButton",props,parent)
    themed(object,"BackgroundColor3",2); themed(object,"TextColor3",4)
    round(object,6); local border = stroke(object); themed(border,"Color",3)
    connect(object.MouseEnter,function() tween(border,0.15,{Color=color("accentColor")}) end)
    connect(object.MouseLeave,function() tween(border,0.2,{Color=palette(3)}) end)
    return object
end
local function textbox(parent, text, properties)
    local props = {Text=text,ClearTextOnFocus=false,TextSize=10,Font=Enum.Font.Gotham,
        BorderSizePixel=0,Size=UDim2.fromOffset(88,27)}
    for key,value in pairs(properties or {}) do props[key] = value end
    local object = create("TextBox",props,parent)
    themed(object,"BackgroundColor3",2); themed(object,"TextColor3",4)
    round(object,5); local border=stroke(object); themed(border,"Color",3)
    return object
end
UI.screen = own(create("ScreenGui",{Name="AETHER_V6",ResetOnSpawn=false,IgnoreGuiInset=true,
    DisplayOrder=70,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},playerGui))
UI.effects = frame(UI.screen,{Name="ScreenEffects",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
UI.esp = frame(UI.screen,{Name="ESP",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})
UI.main = create("CanvasGroup",{Name="Window",Size=UDim2.fromOffset(960,620),
    Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),BorderSizePixel=0,
    GroupTransparency=1,BackgroundColor3=palette(1)},UI.screen)
themed(UI.main,"BackgroundColor3",1); round(UI.main,9); themed(stroke(UI.main),"Color",3)
UI.scale = create("UIScale",{Scale=1},UI.main)
UI.sidebar = frame(UI.main,{Size=UDim2.new(0,74,1,0)},1)
frame(UI.sidebar,{Position=UDim2.new(1,0,0,0),Size=UDim2.new(0,1,1,0)},3)
UI.top = frame(UI.main,{Position=UDim2.fromOffset(75,0),Size=UDim2.new(1,-75,0,59)},1)
frame(UI.top,{Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,1)},3)
label(UI.top,"AETHER",{Position=UDim2.fromOffset(24,0),Size=UDim2.fromOffset(65,58),TextSize=14,Font=Enum.Font.GothamBold})
label(UI.top,"V6",{Position=UDim2.fromOffset(97,0),Size=UDim2.fromOffset(24,58),TextSize=10},true)
UI.title=label(UI.top,"/   AIM",{Position=UDim2.fromOffset(136,0),Size=UDim2.fromOffset(180,58),TextSize=11},true)
UI.close=button(UI.top,"×",{Position=UDim2.new(1,-43,0,16),Size=UDim2.fromOffset(26,26),TextSize=23,BackgroundTransparency=1})
UI.footer=label(UI.main,"",{Position=UDim2.fromOffset(94,594),Size=UDim2.fromOffset(838,16),TextSize=9},true)

-- Icons are built from vector-like GUI strokes; no remote assets or emoji.
local function line(parent, a, b, thickness, tint)
    local d=b-a
    return frame(parent,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2),
        Size=UDim2.fromOffset(d.Magnitude,thickness or 1),Rotation=math.deg(math.atan2(d.Y,d.X)),
        BackgroundColor3=tint or Color3.fromRGB(205,205,205)})
end
local function icon(parent, kind)
    local canvas=frame(parent,{Size=UDim2.fromOffset(22,22),Position=UDim2.fromScale(0.5,0.5),
        AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=1})
    local function l(x,y,u,v) line(canvas,Vector2.new(x,y),Vector2.new(u,v),1.6) end
    local function circle(x,y,size)
        local f=frame(canvas,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(size,size),BackgroundTransparency=1})
        round(f,100); stroke(f,Color3.fromRGB(205,205,205),1.5)
    end
    if kind=="Visuals" then
        l(1,11,6,6);l(6,6,16,6);l(16,6,21,11);l(21,11,16,16);l(16,16,6,16);l(6,16,1,11);circle(8,8,6)
    elseif kind=="Aim" then circle(4,4,14);circle(9,9,4);l(11,1,11,6);l(11,16,11,21);l(1,11,6,11);l(16,11,21,11)
    elseif kind=="Camera" then l(2,6,14,6);l(2,6,2,17);l(2,17,14,17);l(14,6,14,17);l(14,9,21,5);l(21,5,21,18);l(21,18,14,14)
    elseif kind=="Movement" then l(2,11,20,11);l(14,5,20,11);l(14,17,20,11);l(2,5,8,5);l(2,17,8,17)
    elseif kind=="Display" then l(2,3,20,3);l(20,3,20,16);l(20,16,2,16);l(2,16,2,3);l(11,16,11,20);l(6,20,16,20)
    elseif kind=="Settings" then circle(5,5,12);circle(9,9,4);l(11,1,11,5);l(11,17,11,21);l(1,11,5,11);l(17,11,21,11)
    elseif kind=="Protection" then l(11,2,20,6);l(20,6,18,15);l(18,15,11,21);l(11,21,4,15);l(4,15,2,6);l(2,6,11,2);l(7,11,10,14);l(10,14,15,8)
    elseif kind=="Spectators" then circle(7,2,8);l(3,20,4,15);l(4,15,8,12);l(8,12,14,12);l(14,12,18,15);l(18,15,19,20);l(3,20,19,20)
    else l(4,2,15,2);l(15,2,19,6);l(19,6,19,21);l(19,21,4,21);l(4,21,4,2);l(8,10,15,10);l(8,14,15,14) end
end
function UI.card(tab, title, column)
    local parent=UI.pages[tab].columns[column or 1]
    local card=frame(parent,{Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},2)
    round(card,10); themed(stroke(card),"Color",3)
    local header=label(card,title,{Size=UDim2.new(1,-30,0,44),Position=UDim2.fromOffset(16,0),Font=Enum.Font.GothamMedium,TextSize=11})
    frame(card,{Position=UDim2.fromOffset(0,44),Size=UDim2.new(1,0,0,1)},3)
    local body=frame(card,{Position=UDim2.fromOffset(16,51),Size=UDim2.new(1,-32,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,5)},body)
    create("UIPadding",{PaddingBottom=UDim.new(0,15)},body)
    create("UISizeConstraint",{MinSize=Vector2.new(0,67)},card)
    table.insert(UI.cards,{card=card,body=body,header=header})
    return body
end
local function row(body,height)
    return frame(body,{Name="Control",Size=UDim2.new(1,0,0,height or 28),BackgroundTransparency=1})
end
function UI.note(body,text,height)
    local r=row(body,height or 44)
    label(r,text,{Size=UDim2.fromScale(1,1),TextWrapped=true,TextSize=10,TextYAlignment=Enum.TextYAlignment.Top},true)
    return r
end
function UI.toggle(body,title,key)
    local r=row(body,27);label(r,title,{Size=UDim2.new(1,-47,1,0),TextSize=10})
    local hit=create("TextButton",{Text="",AutoButtonColor=false,BackgroundTransparency=1,
        Size=UDim2.fromScale(1,1)},r)
    local track=frame(r,{Size=UDim2.fromOffset(36,20),Position=UDim2.new(1,-36,0.5,-10)})
    round(track,99); themed(stroke(track),"Color",3)
    local dot=frame(track,{Size=UDim2.fromOffset(14,14),Position=UDim2.fromOffset(3,3),BackgroundColor3=Color3.fromRGB(125,125,125)})
    round(dot,99)
    observe(key,function()
        tween(track,0.16,{BackgroundColor3=C[key] and color("accentColor") or palette(3)})
        tween(dot,0.16,{Position=UDim2.fromOffset(C[key] and 19 or 3,3),
            BackgroundColor3=C[key] and palette(1) or palette(5)})
    end)
    connect(hit.Activated,function() set(key,not C[key]) end)
    return r
end
function UI.slider(body,title,key,step,suffix)
    local spec=App.schema[key];local r=row(body,46)
    label(r,title,{Size=UDim2.new(1,-57,0,21),TextSize=10},true)
    local input=textbox(r,"",{Position=UDim2.new(1,-52,0,0),Size=UDim2.fromOffset(52,21),TextSize=9})
    local track=frame(r,{Position=UDim2.fromOffset(0,31),Size=UDim2.new(1,0,0,3)},3);round(track,10)
    local fill=frame(track,{Size=UDim2.fromScale(0.5,1),BackgroundColor3=color("accentColor")});round(fill,10)
    local dot=frame(track,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(11,11),BackgroundColor3=color("accentColor")});round(dot,99)
    local hit=create("TextButton",{Text="",AutoButtonColor=false,BackgroundTransparency=1,
        Position=UDim2.fromOffset(0,22),Size=UDim2.new(1,0,0,22)},r)
    local function apply(x)
        if track.AbsoluteSize.X<=0 then return end
        local alpha=math.clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local value=spec.lo+(spec.hi-spec.lo)*alpha
        value=math.clamp(math.floor(value/step+0.5)*step,spec.lo,spec.hi)
        set(key,value)
    end
    observe(key,function()
        local alpha=(C[key]-spec.lo)/(spec.hi-spec.lo)
        tween(fill,0.08,{Size=UDim2.fromScale(alpha,1),BackgroundColor3=color("accentColor")})
        tween(dot,0.08,{Position=UDim2.fromScale(alpha,0.5),BackgroundColor3=color("accentColor")})
        input.Text=(step>=1 and string.format("%d",C[key]) or string.format("%.2f",C[key]))..(suffix or "")
    end)
    connect(hit.InputBegan,function(event)
        if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
            App.state.slider={apply=apply,touch=event.UserInputType==Enum.UserInputType.Touch and event or nil}
            apply(event.Position.X)
        end
    end)
    connect(input.FocusLost,function()
        local value=tonumber(input.Text:match("[%+%-]?[%d%.]+"))
        if finite(value) then set(key,math.clamp(value,spec.lo,spec.hi)) end
        refresh(key)
    end)
end
function UI.choice(body,title,key)
    local r=row(body,30);label(r,title,{Size=UDim2.new(0.46,0,1,0),TextSize=10},true)
    local b=button(r,"",{Position=UDim2.fromScale(0.46,0),Size=UDim2.new(0.54,0,0,27),TextSize=10})
    observe(key,function() b.Text=C[key].."  ›" end)
    connect(b.Activated,function()
        local options=App.schema[key].choices;local at=table.find(options,C[key]) or 1
        set(key,options[at%#options+1])
    end)
end
function UI.color(body,title,key)
    local r=row(body,30);label(r,title,{Size=UDim2.new(1,-100,1,0),TextSize=10},true)
    local input=textbox(r,C[key],{Position=UDim2.new(1,-88,0,0),Size=UDim2.fromOffset(88,27)})
    local swatch=frame(r,{Size=UDim2.fromOffset(8,8),Position=UDim2.new(1,-99,0,9)});round(swatch,99)
    observe(key,function() input.Text=C[key];swatch.BackgroundColor3=color(key) end)
    connect(input.FocusLost,function() set(key,input.Text:upper());refresh(key) end)
end
function UI.key(body,title,key)
    local r=row(body,30);label(r,title,{Size=UDim2.new(1,-116,1,0),TextSize=10},true)
    local b=button(r,"",{Position=UDim2.new(1,-110,0,0),Size=UDim2.fromOffset(110,27),TextSize=9})
    observe(key,function() b.Text=C[key] end);UI.keyButtons[key]=b
    connect(b.Activated,function()
        if App.state.capture then refresh(App.state.capture) end
        App.state.capture=key;b.Text="Press key / Esc"
    end)
end
function UI.action(body,title,callback)
    local r=row(body,29);local b=button(r,title,{Size=UDim2.new(1,0,0,28)})
    connect(b.Activated,callback);return b
end
local function notify(text)
    App.state.notice=text;App.state.noticeUntil=os.clock()+7
    UI.footer.Text=text
    if App.runtime and App.runtime.v6.ShowToast then App.runtime.v6:ShowToast(text) end
end
function UI.select(tab)
    App.state.tab=tab;UI.title.Text="/   "..tab:upper()
    for name,page in pairs(UI.pages) do
        page.group.Visible=name==tab
        if name==tab then page.group.GroupTransparency=1;tween(page.group,0.18,{GroupTransparency=0}) end
        tween(UI.nav[name],0.15,{BackgroundTransparency=name==tab and 0 or 1})
    end
end
for i,name in ipairs({"Visuals","Aim","Camera","Movement","Display","Settings","Profiles","Protection","Spectators"}) do
    local nav=button(UI.sidebar,"",{Name=name,Size=UDim2.fromOffset(40,40),Position=UDim2.fromOffset(17,22+(i-1)*56),BackgroundTransparency=1})
    icon(nav,name);UI.nav[name]=nav
    connect(nav.Activated,function() UI.select(name) end)
    local group=create("CanvasGroup",{Name=name,Position=UDim2.fromOffset(92,73),Size=UDim2.fromOffset(566,510),
        BackgroundTransparency=1,Visible=false,BorderSizePixel=0},UI.main)
    local scroll=create("ScrollingFrame",{Name="Cards",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=Color3.fromRGB(65,65,65),
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y},group)
    local cols={}
    for column=1,2 do
        cols[column]=frame(scroll,{Position=UDim2.new((column-1)*0.51,0,0,0),Size=UDim2.new(0.487,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
        create("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,14)},cols[column])
        create("UIPadding",{PaddingBottom=UDim.new(0,4),PaddingTop=UDim.new(0,1),PaddingLeft=UDim.new(0,1),PaddingRight=UDim.new(0,1)},cols[column])
    end
    UI.pages[name]={group=group,scroll=scroll,columns=cols}
end

-- Right-hand live avatar preview, never a fabricated in-world target.
UI.preview=frame(UI.main,{Position=UDim2.fromOffset(680,73),Size=UDim2.fromOffset(258,510),BackgroundTransparency=1})
UI.previewTitle=label(UI.preview,"LIVE PREVIEW",{Size=UDim2.new(1,0,0,22),TextSize=9},true)
UI.viewport=create("ViewportFrame",{Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,1,-95),
    BackgroundTransparency=1,Ambient=Color3.fromRGB(175,175,175),LightColor=Color3.new(1,1,1),
    LightDirection=Vector3.new(-1,-1,-2)},UI.preview)
UI.previewWorld=create("WorldModel",{Name="AvatarWorld"},UI.viewport)
UI.previewCamera=create("Camera",{FieldOfView=32},UI.viewport);UI.viewport.CurrentCamera=UI.previewCamera
UI.previewOverlay=frame(UI.preview,{Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,1,-95),BackgroundTransparency=1})
UI.previewEmpty=label(UI.previewOverlay,"Waiting for character",{Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center},true)
UI.previewName=label(UI.previewOverlay,"",{Size=UDim2.fromOffset(258,20),TextXAlignment=Enum.TextXAlignment.Center,TextSize=10})
UI.previewDistance=label(UI.previewOverlay,"",{Size=UDim2.fromOffset(258,18),TextXAlignment=Enum.TextXAlignment.Center,TextSize=9},true)
UI.previewBox=frame(UI.previewOverlay,{BackgroundTransparency=1,Visible=false});UI.previewStroke=stroke(UI.previewBox,Color3.new(1,1,1))
UI.previewBar=frame(UI.previewOverlay,{BackgroundColor3=Color3.fromRGB(95,230,170),Visible=false})
UI.previewCorners={};UI.previewBones={}
for i=1,8 do
    UI.previewCorners[i]=frame(UI.previewOverlay,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),Visible=false})
end
UI.previewTracer=frame(UI.previewOverlay,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundColor3=Color3.new(1,1,1),Visible=false})
UI.previewInfo=label(UI.preview,"",{Position=UDim2.new(0,0,1,-53),Size=UDim2.new(1,0,0,48),TextSize=9,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top},true)
UI.rotate=button(UI.preview,"Rotate",{Position=UDim2.new(1,-63,0,-4),Size=UDim2.fromOffset(63,24),TextSize=9})
connect(UI.rotate.Activated,function() App.state.previewRotate=not App.state.previewRotate end)
local shutdown=create("BindableFunction",{Name="Shutdown"},UI.screen)

-- Local effects live only in this folder / ScreenGui and are destroyed on unload.
App.folder=own(create("Folder",{Name="AETHER_V6_Client"},S.Workspace))
App.blur=own(create("BlurEffect",{Name="AETHER_V6_MenuBlur",Size=0,Enabled=false},S.Lighting))
App.bloom=own(create("BloomEffect",{Name="AETHER_V6_Ambient",Intensity=0,Size=24,Threshold=1.3,Enabled=false},S.Lighting))
App.grade=own(create("ColorCorrectionEffect",{Name="AETHER_V6_Color",Enabled=false},S.Lighting))

local Runtime = {players={}, tiles={}, edges={}, playerCount=0, palletCount=0, highlights=0, camera=nil,
    lastBase=nil,lastApplied=nil,fovOriginal=nil,fovOwned=false, smooth=nil, yaw=0, lean=0,frame=0,
    previewYaw=0,previewGeneration=0, adapter=nil, heavyTime=0, hudTime=0, worldTime=0}
App.runtime=Runtime
Runtime.v6={moon=nil,poses={},boost=false,speedIntent=nil,speedDenied=false,people={},spectatorTime=0,round=0}

local function permitted() return App.supported or (App.studio and C.practice) end
local function rootOf(character)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")
end
local function origin()
    local root=rootOf(player.Character)
    local camera=S.Workspace.CurrentCamera
    return root and root.Position or (camera and camera.CFrame.Position) or Vector3.zero
end
local function roleOf(who)
    local role=App.roles[who.UserId]
    if Runtime.adapter and type(Runtime.adapter.GetRole)=="function" then
        local ok,value=pcall(Runtime.adapter.GetRole,who)
        if ok then role=value end
    end
    return (role=="KILLER" or role=="SURVIVOR") and role or "UNKNOWN"
end
local function roleColor(role,t)
    if (role=="KILLER" and C.killerRainbow) or (role~="KILLER" and C.rainbow) then
        return Color3.fromHSV((t*C.rgbSpeed)%1,0.75,1)
    end
    return color(role=="KILLER" and "killerColor" or role=="SURVIVOR" and "survivorColor" or "unknownColor")
end
local function projectBounds(camera,cf,size)
    local minimum=Vector2.new(math.huge,math.huge);local maximum=Vector2.new(-math.huge,-math.huge)
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p=camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(size.X*x,size.Y*y,size.Z*z)*0.5))
        if p.Z<=0.1 then return nil end
        minimum=Vector2.new(math.min(minimum.X,p.X),math.min(minimum.Y,p.Y))
        maximum=Vector2.new(math.max(maximum.X,p.X),math.max(maximum.Y,p.Y))
    end end end
    local view=camera.ViewportSize
    if maximum.X<0 or maximum.Y<0 or minimum.X>view.X or minimum.Y>view.Y then return nil end
    return minimum,maximum
end
local function screenLine(object,a,b,width,tint)
    local d=b-a
    object.Visible=true;object.Position=UDim2.fromOffset((a.X+b.X)/2,(a.Y+b.Y)/2)
    object.Size=UDim2.fromOffset(d.Magnitude,width);object.Rotation=math.deg(math.atan2(d.Y,d.X))
    object.BackgroundColor3=tint
end
local function newLine(parent)
    return frame(parent,{AnchorPoint=Vector2.new(0.5,0.5),BackgroundTransparency=0.08,Visible=false})
end
local function newOverlay(name)
    local overlay={root=frame(UI.esp,{Name=name,BackgroundTransparency=1,Size=UDim2.fromScale(1,1)})}
    overlay.box=frame(overlay.root,{BackgroundTransparency=1,Visible=false})
    overlay.stroke=stroke(overlay.box,Color3.new(1,1,1))
    overlay.corners={};for i=1,8 do overlay.corners[i]=newLine(overlay.root) end
    overlay.name=create("TextLabel",{Text="",BackgroundTransparency=1,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(0.5,1),Size=UDim2.fromOffset(240,18),TextXAlignment=Enum.TextXAlignment.Center,TextSize=10,TextStrokeTransparency=0.5,Visible=false},overlay.root)
    overlay.distance=create("TextLabel",{Text="",BackgroundTransparency=1,Font=Enum.Font.Gotham,TextColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(0.5,0),Size=UDim2.fromOffset(180,16),TextXAlignment=Enum.TextXAlignment.Center,TextSize=9,TextStrokeTransparency=0.5,Visible=false},overlay.root)
    overlay.tracer=newLine(overlay.root)
    overlay.healthBack=frame(overlay.root,{BackgroundColor3=Color3.fromRGB(20,20,20),Visible=false})
    overlay.healthFill=frame(overlay.healthBack,{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(90,230,150)})
    overlay.bones={}
    return overlay
end
local function releaseHighlight(record)
    if record.highlight then record.highlight:Destroy();record.highlight=nil;Runtime.highlights=math.max(0,Runtime.highlights-1) end
end
local function destroyRecord(record)
    releaseHighlight(record)
    if record.overlay then record.overlay.root:Destroy() end
    if record.connections then clean(record.connections) end
    if record.characterConnections then clean(record.characterConnections) end
end
local function updateHighlight(record,adornee,tint,fill,outlineTransparency,fillTint)
    local limit=C.performance and 16 or 48
    if not record.highlight then
        if Runtime.highlights>=limit then return end
        record.highlight=create("Highlight",{Name="AETHER_Highlight",Adornee=adornee,
            DepthMode=Enum.HighlightDepthMode.AlwaysOnTop},App.folder)
        Runtime.highlights=Runtime.highlights+1
    end
    local h=record.highlight
    h.FillColor=fillTint or tint;h.OutlineColor=record.role=="SURVIVOR" and Color3.new(1,1,1) or tint
    h.FillTransparency=fill;h.OutlineTransparency=outlineTransparency
end
local function setCharacter(record,character)
    if record.characterConnections then clean(record.characterConnections) end
    record.characterConnections={};record.jointsDirty=false
    releaseHighlight(record);record.character=character;record.joints={}
    if record.overlay then
        for _,bone in ipairs(record.overlay.bones) do bone:Destroy() end
        record.overlay.bones={}
    end
    if not character then return end
    for _,descendant in ipairs(character:GetDescendants()) do
        if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 and #record.joints<20 then
            table.insert(record.joints,descendant)
            table.insert(record.overlay.bones,newLine(record.overlay.root))
        end
    end
    table.insert(record.characterConnections,character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Motor6D") or descendant:IsA("BasePart") then record.jointsDirty=true end
    end))
end
local function addPlayer(who)
    if who==player or Runtime.players[who] then return end
    local record={who=who,overlay=newOverlay("Player_"..who.UserId),connections={}}
    Runtime.players[who]=record
    table.insert(record.connections,who.CharacterAdded:Connect(function(character) setCharacter(record,character) end))
    table.insert(record.connections,who.CharacterRemoving:Connect(function() setCharacter(record,nil) end))
    setCharacter(record,who.Character)
end
local function stopPlayers()
    clear("players")
    for who,record in pairs(Runtime.players) do destroyRecord(record);Runtime.players[who]=nil end
    Runtime.playerCount=0
end
local function startPlayers()
    stopPlayers()
    if not permitted() or not C.esp then return end
    for _,who in ipairs(S.Players:GetPlayers()) do addPlayer(who) end
    connect(S.Players.PlayerAdded,addPlayer,"players")
    connect(S.Players.PlayerRemoving,function(who)
        if Runtime.players[who] then destroyRecord(Runtime.players[who]);Runtime.players[who]=nil end
        App.roles[who.UserId]=nil
    end,"players")
end
local function drawOverlay(record,camera,cf,size,tint,distance,isPallet)
    local o=record.overlay;local a,b=projectBounds(camera,cf,size)
    o.root.Visible=a~=nil
    if not a then return end
    local width,height=b.X-a.X,b.Y-a.Y;local middle=(a.X+b.X)/2
    local boxOn=isPallet or (C.boxes and (record.role~="KILLER" or C.killerBox))
    o.box.Visible=boxOn and not C.corners
    o.box.Position=UDim2.fromOffset(a.X,a.Y);o.box.Size=UDim2.fromOffset(width,height);o.stroke.Color=tint
    local cornerOn=boxOn and C.corners;local len=math.min(width*0.25,height*0.14,18)
    local points={
        {a,Vector2.new(a.X+len,a.Y)},{a,Vector2.new(a.X,a.Y+len)},
        {Vector2.new(b.X,a.Y),Vector2.new(b.X-len,a.Y)},{Vector2.new(b.X,a.Y),Vector2.new(b.X,a.Y+len)},
        {Vector2.new(a.X,b.Y),Vector2.new(a.X+len,b.Y)},{Vector2.new(a.X,b.Y),Vector2.new(a.X,b.Y-len)},
        {b,Vector2.new(b.X-len,b.Y)},{b,Vector2.new(b.X,b.Y-len)}}
    for i,segment in ipairs(o.corners) do
        segment.Visible=cornerOn
        if cornerOn then screenLine(segment,points[i][1],points[i][2],1,tint) end
    end
    o.name.Visible=isPallet and C.palletLabels or (not isPallet and (C.names or (record.role=="KILLER" and C.killerLabel)))
    if isPallet then o.name.Text="PALLET · "..record.status
    else
        local roleText=(record.role=="KILLER" and not C.killerLabel) and "" or record.role
        o.name.Text=(C.names and record.who.DisplayName.."  " or "")..roleText
    end
    o.name.TextColor3=tint;o.name.Position=UDim2.fromOffset(middle,a.Y-3)
    o.distance.Visible=isPallet and C.palletDistance or (not isPallet and C.distances and (record.role~="KILLER" or C.killerDistance))
    -- Roblox positions are studs; no unverified conversion to meters.
    o.distance.Text=string.format("%.0f studs",distance);o.distance.Position=UDim2.fromOffset(middle,b.Y+3)
    o.tracer.Visible=not isPallet and C.tracers
    if o.tracer.Visible then screenLine(o.tracer,Vector2.new(camera.ViewportSize.X/2,camera.ViewportSize.Y-10),Vector2.new(middle,b.Y),1,tint) end
    local humanoid=not isPallet and record.character and record.character:FindFirstChildWhichIsA("Humanoid")
    o.healthBack.Visible=C.health and humanoid~=nil and humanoid.MaxHealth>0
    if o.healthBack.Visible then
        o.healthBack.Position=UDim2.fromOffset(a.X-6,a.Y);o.healthBack.Size=UDim2.fromOffset(3,height)
        o.healthFill.Size=UDim2.fromScale(1,math.clamp(humanoid.Health/humanoid.MaxHealth,0,1))
    end
    for i,bone in ipairs(o.bones) do
        bone.Visible=false
        local joint=record.joints[i]
        if C.skeleton and joint and joint.Parent and joint.Part0 and joint.Part1 then
            local p,on1=camera:WorldToViewportPoint(joint.Part0.Position)
            local q,on2=camera:WorldToViewportPoint(joint.Part1.Position)
            if on1 and on2 and p.Z>0 and q.Z>0 then screenLine(bone,Vector2.new(p.X,p.Y),Vector2.new(q.X,q.Y),1,tint) end
        end
    end
end
local function updateESP(t)
    local camera=S.Workspace.CurrentCamera
    if not camera or not permitted() then return end
    local center=origin();local entries={}
    for _,record in pairs(Runtime.players) do
        if record.jointsDirty then setCharacter(record,record.character) end
        local root=rootOf(record.character)
        local distance=root and (root.Position-center).Magnitude or math.huge
        record.overlay.root.Visible=false
        if root and distance<=C.espDistance then table.insert(entries,{r=record,d=distance}) else releaseHighlight(record) end
    end
    table.sort(entries,function(a,b) return a.d<b.d end)
    local budget=C.performance and 16 or 40;Runtime.playerCount=math.min(#entries,budget)
    for i,item in ipairs(entries) do
        local r=item.r
        if i>budget then releaseHighlight(r) else
            r.role=roleOf(r.who);local tint=roleColor(r.role,t)
            local ok,cf,size=pcall(r.character.GetBoundingBox,r.character)
            if ok then drawOverlay(r,camera,cf,size,tint,item.d,false) end
            if (C.chams or C.outline) and (r.role~="KILLER" or C.killerGlow) then
                local pulse=(r.role=="KILLER" and C.killerPulse) and (0.5+0.5*math.sin(t*3)) or 0
                updateHighlight(r,r.character,tint,C.chams and math.clamp(C.transparency+(1-C.glow)*0.2,0,1) or 1,
                    C.outline and (0.15+pulse*0.45) or 1)
            else releaseHighlight(r) end
        end
    end
    local palletEntries={}
    for instance,record in pairs(App.pallets) do
        if record.overlay then record.overlay.root.Visible=false end
        if not instance:IsDescendantOf(S.Workspace) then
            destroyRecord(record);App.pallets[instance]=nil
        elseif C.palletESP then
            local cf,size
            if instance:IsA("Model") then cf,size=instance:GetBoundingBox() else cf,size=instance.CFrame,instance.Size end
            local distance=(cf.Position-center).Magnitude
            if distance<=C.palletRange then table.insert(palletEntries,{r=record,d=distance,cf=cf,size=size}) else releaseHighlight(record) end
        else releaseHighlight(record) end
    end
    table.sort(palletEntries,function(a,b) return a.d<b.d end)
    local cap=C.performance and 12 or 32;Runtime.palletCount=math.min(#palletEntries,cap)
    for i,item in ipairs(palletEntries) do
        local r=item.r
        if i>cap then releaseHighlight(r) else
            if not r.overlay then r.overlay=newOverlay("Pallet") end
            local status="UNKNOWN"
            if r.provider then local ok,value=pcall(r.provider,r.instance);if ok and (value=="AVAILABLE" or value=="USED") then status=value end end
            r.status=status
            local tint=C.palletWhite and Color3.new(1,1,1) or color(status=="USED" and "usedPalletColor" or "palletColor")
            if C.palletRainbow then tint=Color3.fromHSV((t*C.rgbSpeed)%1,0.65,1) end
            drawOverlay(r,camera,item.cf,item.size,tint,item.d,true)
            local pulse=C.palletPulse and (0.5+0.5*math.sin(t*2.4)) or 0
            updateHighlight(r,r.instance,tint,0.82+pulse*0.12,0.05+pulse*0.35,C.palletWhite and Color3.new(1,1,1) or nil)
        end
    end
end

-- Explicit integration contract: callers supply verified real objects and role data.
-- No name matching, guessed attributes, remote calls or recursive map scans.
function App:SetRole(who,role)
    assert(typeof(who)=="Instance" and who:IsA("Player"),"SetRole expects a Player")
    assert(role=="KILLER" or role=="SURVIVOR" or role=="UNKNOWN","Invalid role")
    if not permitted() then return false,"Unsupported place" end
    self.roles[who.UserId]=role;return true
end
function App:RegisterPallet(instance,stateProvider)
    if not permitted() then return false,"Unsupported place" end
    if typeof(instance)~="Instance" or not (instance:IsA("Model") or instance:IsA("BasePart")) or not instance:IsDescendantOf(S.Workspace) then return false,"Expected an existing Workspace Model/BasePart" end
    if stateProvider~=nil and type(stateProvider)~="function" then return false,"State provider must be a function" end
    if self.pallets[instance] then self.pallets[instance].provider=stateProvider;return true end
    self.pallets[instance]={instance=instance,provider=stateProvider,status="UNKNOWN"}
    return true
end
function App:UnregisterPallet(instance)
    local record=self.pallets[instance]
    if record then destroyRecord(record);self.pallets[instance]=nil end
end
function App:RoundReset()
    table.clear(self.roles)
    for instance in pairs(self.pallets) do self:UnregisterPallet(instance) end
    if Runtime.danger then Runtime.danger:Reset(true) end
    if Runtime.v6 and Runtime.v6.RoundReset then Runtime.v6:RoundReset() end
end
function App:DetachAdapter()
    clear("adapter");Runtime.adapter=nil;self.supported=game.PlaceId==93978595733734;self:RoundReset();self.state.dirty=true
end

function App:AttachAdapter(adapter)
    if type(adapter)~="table" or type(adapter.PlaceIds)~="table" then return false,"Adapter requires explicit PlaceIds" end
    if not table.find(adapter.PlaceIds,game.PlaceId) then return false,"Adapter does not support this PlaceId" end
    if type(adapter.GetRole)~="function" or type(adapter.GetPallets)~="function" then return false,"Adapter requires GetRole and GetPallets" end
    self:DetachAdapter();Runtime.adapter=adapter;self.supported=true
    local function register(instance)
        self:RegisterPallet(instance,type(adapter.GetPalletState)=="function" and adapter.GetPalletState or nil)
    end
    local function scan()
        local ok,objects=pcall(adapter.GetPallets)
        if ok and type(objects)=="table" then for _,instance in ipairs(objects) do register(instance) end
        else notify("Adapter GetPallets failed; no pallets inferred") end
    end
    for name,callback in pairs({PalletAdded=register,PalletRemoved=function(instance) self:UnregisterPallet(instance) end,
        RoundChanged=function() self:RoundReset();scan() end}) do
        local signal=adapter[name]
        if typeof(signal)=="RBXScriptSignal" then connect(signal,callback,"adapter") end
    end
    scan();startPlayers();notify("Verified-data adapter attached")
    return true
end

local function rebuildPreview(who)
    Runtime.previewGeneration=Runtime.previewGeneration+1
    local generation=Runtime.previewGeneration
    UI.previewWorld:ClearAllChildren();Runtime.previewModel=nil;UI.previewEmpty.Visible=true
    UI.previewBox.Visible=false;UI.previewName.Text="";UI.previewDistance.Text=""
    UI.previewBar.Visible=false;UI.previewTracer.Visible=false
    for _,corner in ipairs(UI.previewCorners) do corner.Visible=false end
    for _,bone in ipairs(UI.previewBones) do bone:Destroy() end
    UI.previewBones={};Runtime.previewJoints={}
    Runtime.previewPlayer=who or player
    clear("previewCharacter")
    local function cloneCharacter(character)
        if not character or not App.alive or generation~=Runtime.previewGeneration then return end
        UI.previewWorld:ClearAllChildren();Runtime.previewModel=nil
        for _,bone in ipairs(UI.previewBones) do bone:Destroy() end
        UI.previewBones={};Runtime.previewJoints={}
        local previous=character.Archivable;character.Archivable=true
        local ok,model=pcall(character.Clone,character);character.Archivable=previous
        if not ok or not model then UI.previewEmpty.Text="Avatar cannot be cloned";UI.previewEmpty.Visible=true;return end
        for _,object in ipairs(model:GetDescendants()) do
            if object:IsA("LuaSourceContainer") or object:IsA("Tool") or object:IsA("Sound") or object:IsA("ParticleEmitter") or object:IsA("Trail") then
                object:Destroy()
            elseif object:IsA("BasePart") then
                object.Anchored=true;object.CanCollide=false;object.CanTouch=false;object.CanQuery=false;object.CastShadow=false
            end
        end
        model.Parent=UI.previewWorld
        local cf,size=model:GetBoundingBox()
        if size.Magnitude<0.01 then model:Destroy();return end
        model:PivotTo(CFrame.new(-cf.Position)*model:GetPivot())
        Runtime.previewModel=model;Runtime.previewSize=size;Runtime.previewFocus=Vector3.zero
        Runtime.previewPoseParts={}
        for _,part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") and (part.Name=="LeftFoot" or part.Name=="RightFoot" or part.Name=="Left Leg" or part.Name=="Right Leg" or part.Name=="Torso" or part.Name=="LowerTorso") then
                table.insert(Runtime.previewPoseParts,{part=part,base=part.CFrame})
            end
        end
        Runtime.previewBounds=model:GetBoundingBox()
        for _,joint in ipairs(model:GetDescendants()) do
            if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 and #Runtime.previewJoints<20 then
                table.insert(Runtime.previewJoints,joint);table.insert(UI.previewBones,newLine(UI.previewOverlay))
            end
        end
        Runtime.previewCameraCF=nil;UI.previewEmpty.Visible=false
    end
    connect(Runtime.previewPlayer.CharacterAdded,cloneCharacter,"previewCharacter")
    connect(Runtime.previewPlayer.CharacterAppearanceLoaded,function(character) cloneCharacter(character) end,"previewCharacter")
    connect(Runtime.previewPlayer.CharacterRemoving,function()
        UI.previewWorld:ClearAllChildren();Runtime.previewModel=nil;UI.previewEmpty.Visible=true
        UI.previewBox.Visible=false;UI.previewBar.Visible=false;UI.previewTracer.Visible=false
        UI.previewName.Text="";UI.previewDistance.Text=""
        for _,corner in ipairs(UI.previewCorners) do corner.Visible=false end
        for _,bone in ipairs(UI.previewBones) do bone:Destroy() end
        UI.previewBones={}
    end,"previewCharacter")
    cloneCharacter(Runtime.previewPlayer.Character)
end
local function targetVisible(who)
    local camera=S.Workspace.CurrentCamera;local root=rootOf(who and who.Character)
    if not camera or not root then return false end
    local direction=root.Position-camera.CFrame.Position
    if direction.Magnitude<0.01 then return true end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    local ignored={App.folder}
    if who~=player and player.Character then table.insert(ignored,player.Character) end
    params.FilterDescendantsInstances=ignored;params.IgnoreWater=true
    local hit=S.Workspace:Raycast(camera.CFrame.Position,direction,params)
    return not hit or hit.Instance:IsDescendantOf(who.Character)
end
local function updatePreview(dt,t)
    UI.viewport.Visible=C.targetPreview;UI.previewOverlay.Visible=C.targetPreview
    local model=Runtime.previewModel
    if not App.state.open or not model or not C.targetPreview then return end
    for i,entry in ipairs(Runtime.previewPoseParts or {}) do
        if entry.part.Parent then
            entry.part.CFrame=C.movementPreview and entry.base*CFrame.new(0,0.035*math.sin(t*5+i),0)*CFrame.Angles(math.rad(4)*math.sin(t*5+i),0,0) or entry.base
        end
    end
    local size=Runtime.previewSize
    if App.state.previewRotate then Runtime.previewYaw=Runtime.previewYaw+dt*0.45 end
    local focus=Vector3.zero
    local visible=Runtime.previewVisible~=false
    local tracking=C.aimEnabled and C.aimTracking and App.state.aimHeld and (not C.aimVisible or visible)
    if tracking then
        local head=model:FindFirstChild("Head")
        if head and head:IsA("BasePart") then focus=head.Position end
    end
    local alpha=1-math.exp(-dt*(3+30*(1-C.aimSmoothness)))
    Runtime.previewFocus=Runtime.previewFocus:Lerp(focus,alpha)
    local view=UI.viewport.AbsoluteSize;local aspect=math.max(0.2,view.X/math.max(1,view.Y))
    local depth=math.max(size.Y,size.X/aspect)/(2*math.tan(math.rad(32/2)))*1.28+size.Z/2
    local yaw=Runtime.previewYaw
    local cameraCF=CFrame.lookAt(Vector3.new(math.sin(yaw)*depth,0,-math.cos(yaw)*depth),Runtime.previewFocus)
    Runtime.previewCameraCF=Runtime.previewCameraCF and Runtime.previewCameraCF:Lerp(cameraCF,alpha) or cameraCF
    UI.previewCamera.CFrame=Runtime.previewCameraCF
    local tint=roleColor(roleOf(Runtime.previewPlayer),t)
    local sx=UI.scale.Scale;local localW=view.X/sx;local localH=view.Y/sx
    -- Viewport cameras have no usable fullscreen ViewportSize: project explicitly.
    local function project(point)
        local q=UI.previewCamera.CFrame:PointToObjectSpace(point)
        local focal=localH/(2*math.tan(math.rad(UI.previewCamera.FieldOfView/2)))
        return Vector2.new(localW/2+q.X/math.max(0.05,-q.Z)*focal,localH/2-q.Y/math.max(0.05,-q.Z)*focal)
    end
    local a=Vector2.new(math.huge,math.huge);local b=Vector2.new(-math.huge,-math.huge)
    for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
        local p=project(Runtime.previewBounds:PointToWorldSpace(Vector3.new(size.X*x,size.Y*y,size.Z*z)*0.5))
        a=Vector2.new(math.min(a.X,p.X),math.min(a.Y,p.Y));b=Vector2.new(math.max(b.X,p.X),math.max(b.Y,p.Y))
    end end end
    local width,height=b.X-a.X,b.Y-a.Y
    UI.previewBox.Position=UDim2.fromOffset(a.X,a.Y)
    UI.previewBox.Size=UDim2.fromOffset(width,height);UI.previewStroke.Color=tint
    UI.previewStroke.Transparency=C.outline and 0 or 0.45
    UI.previewBox.Visible=C.boxes and not C.corners
    local len=math.min(width/4,height/7,18)
    local segments={{a,Vector2.new(a.X+len,a.Y)},{a,Vector2.new(a.X,a.Y+len)},
        {Vector2.new(b.X,a.Y),Vector2.new(b.X-len,a.Y)},{Vector2.new(b.X,a.Y),Vector2.new(b.X,a.Y+len)},
        {Vector2.new(a.X,b.Y),Vector2.new(a.X+len,b.Y)},{Vector2.new(a.X,b.Y),Vector2.new(a.X,b.Y-len)},
        {b,Vector2.new(b.X-len,b.Y)},{b,Vector2.new(b.X,b.Y-len)}}
    for i,segment in ipairs(UI.previewCorners) do
        segment.Visible=C.boxes and C.corners
        if segment.Visible then screenLine(segment,segments[i][1],segments[i][2],1,tint) end
    end
    for i,bone in ipairs(UI.previewBones) do
        local joint=Runtime.previewJoints[i];bone.Visible=C.skeleton
        if bone.Visible then screenLine(bone,project(joint.Part0.Position),project(joint.Part1.Position),1,tint) end
    end
    UI.previewTracer.Visible=C.tracers
    if C.tracers then screenLine(UI.previewTracer,Vector2.new(localW/2,localH),Vector2.new((a.X+b.X)/2,b.Y),1,tint) end
    UI.previewName.Text=(C.names and Runtime.previewPlayer.DisplayName.." · " or "")..roleOf(Runtime.previewPlayer)
    UI.previewName.Visible=C.names;UI.previewName.Position=UDim2.fromOffset(0,a.Y-22)
    local root=rootOf(Runtime.previewPlayer.Character)
    UI.previewDistance.Text=root and string.format("%.0f studs · LIVE",(root.Position-origin()).Magnitude) or ""
    UI.previewDistance.Visible=C.distances;UI.previewDistance.Position=UDim2.fromOffset(0,b.Y+4)
    UI.previewBar.Visible=false
    local humanoid=Runtime.previewPlayer.Character and Runtime.previewPlayer.Character:FindFirstChildWhichIsA("Humanoid")
    if C.health and humanoid and humanoid.MaxHealth>0 then
        UI.previewBar.Visible=true;UI.previewBar.Position=UDim2.fromOffset(a.X-6,b.Y)
        UI.previewBar.AnchorPoint=Vector2.new(0,1);UI.previewBar.Size=UDim2.fromOffset(2,height*math.clamp(humanoid.Health/humanoid.MaxHealth,0,1))
    end
    UI.viewport.ImageColor3=C.chams and Color3.new(1,1,1):Lerp(tint,0.17*C.glow) or Color3.new(1,1,1)
    UI.previewInfo.Text=(tracking and "TRACKING PREVIEW" or "AVATAR PREVIEW").."  ·  "..(visible and "VISIBLE" or "OCCLUDED")..
        "\nESP "..(C.esp and "ON" or "OFF").."  /  Pallets "..Runtime.palletCount.."\n"..
        (Runtime.adapter and "Game adapter attached" or "Roles & pallets: data adapter required")
end

-- Bounded nearby surface patches; never changes materials of replicated map parts.
local function worldActive()
    return permitted() and (C.whiteTiles or C.rainbowTiles or C.neonEdges or C.crystalWalls or
        C.glossyFloors or C.surfacePulse or C.squareWaves or C.reflections)
end
local function clearWorld()
    for _,tile in ipairs(Runtime.tiles) do tile.part:Destroy() end
    table.clear(Runtime.tiles)
    for _,edge in ipairs(Runtime.edges) do edge:Destroy() end
    table.clear(Runtime.edges)
end
local function sampleWorld()
    if not worldActive() then if #Runtime.tiles>0 then clearWorld() end;return end
    local camera=S.Workspace.CurrentCamera;if not camera then return end
    local budget=(C.performance or C.worldLowFPS) and 8 or 24
    while #Runtime.tiles>budget do table.remove(Runtime.tiles).part:Destroy() end
    while #Runtime.edges>0 do table.remove(Runtime.edges):Destroy() end
    local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
    local excluded={App.folder};if player.Character then table.insert(excluded,player.Character) end
    params.FilterDescendantsInstances=excluded;params.IgnoreWater=true
    local edgeSeen={};local now=os.clock()
    for i=1,budget do
        local tile=Runtime.tiles[i]
        if not tile then
            local part=create("Part",{Name="SurfacePatch",Anchored=true,CanCollide=false,CanTouch=false,
                CanQuery=false,CastShadow=false,Transparency=1,Size=Vector3.new(C.tileSize,0.01,C.tileSize)},App.folder)
            tile={part=part,phase=i*0.71};Runtime.tiles[i]=tile
        end
        local ring=(i-1)%8;local layer=math.floor((i-1)/8)
        local angle=ring/8*math.pi*2
        local direction=Vector3.new(math.cos(angle),layer==0 and -1.3 or layer==1 and -0.35 or 0.25,math.sin(angle)).Unit
        direction=camera.CFrame:VectorToWorldSpace(direction)
        local hit=S.Workspace:Raycast(camera.CFrame.Position,direction*C.worldRange,params)
        tile.active=false
        if hit and hit.Instance:IsA("BasePart") then
            local target=hit.Instance
            -- Sample a small inset patch, rather than cloning the entire wall or floor.
            tile.active=true;tile.floor=hit.Normal.Y>0.65
            tile.part.CFrame=CFrame.lookAt(hit.Position+hit.Normal*0.025,hit.Position+hit.Normal)*CFrame.Angles(math.pi/2,0,0)
            tile.part.Size=Vector3.new(C.tileSize,0.012,C.tileSize)
            tile.part.Material=(C.crystalWalls and not tile.floor) and Enum.Material.Glass or Enum.Material.SmoothPlastic
            tile.part.Reflectance=((C.reflections or (C.glossyFloors and tile.floor)) and 0.25 or 0)
            tile.phase=i*0.71+now*0.01
            if C.neonEdges and not edgeSeen[target] then
                edgeSeen[target]=true
                table.insert(Runtime.edges,create("SelectionBox",{Name="SurfaceEdge",Adornee=target,
                    LineThickness=0.015,SurfaceTransparency=1,Color3=Color3.new(1,1,1)},App.folder))
            end
        else tile.part.Transparency=1 end
    end
end
local function animateWorld(t)
    for _,tile in ipairs(Runtime.tiles) do
        if tile.active then
            local wave=0.5+0.5*math.sin(t*C.worldSpeed*2+tile.phase)
            local tint=C.rainbowTiles and Color3.fromHSV((t*C.rgbSpeed+tile.phase*0.08)%1,0.65,1) or Color3.new(1,1,1)
            if C.surfacePulse then tint=tint:Lerp(Color3.fromHSV((t*C.rgbSpeed)%1,0.5,1),wave*0.6) end
            local squares=C.whiteTiles or C.rainbowTiles or C.squareWaves or C.surfacePulse
            local materialLayer=(C.crystalWalls and not tile.floor) or ((C.glossyFloors or C.reflections) and tile.floor)
            tile.part.Color=tint
            local strength=squares and C.worldIntensity*(0.1+wave*(C.squareWaves and 0.6 or 0.3)) or (materialLayer and C.worldIntensity*0.18 or 0)
            tile.part.Transparency=1-math.clamp(strength,0,0.7)
        end
    end
    for _,edge in ipairs(Runtime.edges) do
        edge.Color3=C.rainbowTiles and Color3.fromHSV((t*C.rgbSpeed)%1,0.65,1) or Color3.new(1,1,1)
        edge.Transparency=0.35+(1-C.worldIntensity)*0.5
    end
end

local function releaseHumanoid()
    local owned=Runtime.humanoidOwned
    if owned and owned.humanoid.Parent and owned.humanoid.AutoRotate==false then owned.humanoid.AutoRotate=owned.autoRotate end
    Runtime.humanoidOwned=nil
end
local function stopMovement()
    App.state.moon=false;App.state.look=false;App.state.aimHeld=false;App.state.dodge=nil;App.state.dodgeHeld=false
    App.state.quickUntil=nil;Runtime.yaw=0;Runtime.dodgeRecovery=0;Runtime.moveVector=nil;releaseHumanoid()
    Runtime.latchedYaw=0
    if Runtime.v6.StopMoon then Runtime.v6:StopMoon() end
end
local function sameCF(a,b)
    return a and b and (a.Position-b.Position).Magnitude<0.001 and a.LookVector:Dot(b.LookVector)>0.999999 and a.UpVector:Dot(b.UpVector)>0.999999
end
local function restoreCamera()
    local camera=Runtime.camera
    if camera and camera.Parent then
        if sameCF(camera.CFrame,Runtime.lastApplied) and Runtime.lastBase then camera.CFrame=Runtime.lastBase end
        if Runtime.fovOwned and Runtime.lastFOV and math.abs(camera.FieldOfView-Runtime.lastFOV)<0.01 then camera.FieldOfView=Runtime.fovOriginal end
    end
    Runtime.lastApplied=nil;Runtime.lastBase=nil;Runtime.fovOwned=false;Runtime.smooth=nil
end
local function startDodge()
    if not C.dodgeEnabled or not permitted() or App.state.open or App.state.dodge or os.clock()<App.state.nextDodge then return end
    local character=player.Character;local humanoid=character and character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid or humanoid.Health<=0 or not rootOf(character) then return end
    if Runtime.v6.StopMoon then Runtime.v6:StopMoon() end
    local sign=C.direction=="Left" and -1 or C.direction=="Random" and (math.random()<0.5 and -1 or 1) or 1
    local angle=C.spinPreset=="180 Quick Turn" and 180 or C.spinPreset=="720 Spin" and 720 or C.spinPreset=="Custom Angle" and C.spinAngle or 360
    local duration=C.dodgeUseDuration and C.spinDuration or angle/C.rotationSpeed
    App.state.dodge={start=os.clock(),duration=duration,sign=sign,angle=math.rad(angle)}
    App.state.nextDodge=os.clock()+duration+C.cooldown
    if C.actionNotifications then notify("Dodge · "..angle.."°") end
end
local function updateCamera(dt)
    local camera=S.Workspace.CurrentCamera
    if Runtime.camera~=camera then restoreCamera();Runtime.camera=camera;Runtime.fovOriginal=camera and camera.FieldOfView or 70 end
    if not camera then return end
    if not permitted() then restoreCamera();stopMovement();return end
    local t=os.clock();local base=camera.CFrame
    if C.customFOV then
        if not Runtime.fovOwned then Runtime.fovOriginal=camera.FieldOfView;Runtime.fovOwned=true end
        local target=C.fov+(C.fovAnimation and math.sin(t*1.3)*C.fovAmplitude or 0)
        target=math.clamp(target,30,120)
        local nextFOV=C.smoothFOV and camera.FieldOfView+(target-camera.FieldOfView)*(1-math.exp(-dt*C.fovEase)) or target
        camera.FieldOfView=nextFOV;Runtime.lastFOV=nextFOV
    elseif Runtime.fovOwned then
        if Runtime.lastFOV and math.abs(camera.FieldOfView-Runtime.lastFOV)<0.01 then camera.FieldOfView=Runtime.fovOriginal end
        Runtime.fovOwned=false;Runtime.lastFOV=nil
    end
    local humanoid=player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
    local alive=humanoid and humanoid.Health>0
    if not alive then stopMovement() end
    Runtime.v6:Step(dt,humanoid)
    if C.moonEnabled and App.state.moon and alive then
        if not Runtime.humanoidOwned then Runtime.humanoidOwned={humanoid=humanoid,autoRotate=humanoid.AutoRotate};humanoid.AutoRotate=false end
    else releaseHumanoid() end
    if C.smoothStrafe and alive and not App.state.open and not App.state.moon then
        Runtime.moveVector=(Runtime.moveVector or humanoid.MoveDirection):Lerp(humanoid.MoveDirection,1-math.exp(-dt*12))
        humanoid:Move(Runtime.moveVector,false)
    else Runtime.moveVector=nil end
    if App.state.dodgeHeld and not App.state.dodge and t>=App.state.nextDodge then startDodge() end
    Runtime.dodgeRecovery=(Runtime.dodgeRecovery or 0)*math.exp(-dt*C.recovery)
    local dodgeYaw=Runtime.dodgeRecovery
    if App.state.dodge then
        local d=App.state.dodge;local alpha=math.clamp((t-d.start)/d.duration,0,1)
        local eased=alpha+(alpha*alpha*(3-2*alpha)-alpha)*C.dodgeSmoothness
        dodgeYaw=d.sign*d.angle*eased;Runtime.lastDodgeYaw=dodgeYaw
        if alpha>=1 then
            App.state.dodge=nil;Runtime.lastDodgeYaw=0
            local remainder=math.atan2(math.sin(dodgeYaw),math.cos(dodgeYaw))
            if C.dodgeRecovery then Runtime.dodgeRecovery=remainder else Runtime.latchedYaw=(Runtime.latchedYaw or 0)+remainder end
        end
    end
    local targetYaw=(C.moonEnabled and App.state.moon and math.rad(C.moonRotation) or 0)+(C.lookBack and App.state.look and math.pi or 0)
    if App.state.quickUntil and t<App.state.quickUntil then targetYaw=targetYaw+math.pi else App.state.quickUntil=nil end
    Runtime.yaw=Runtime.yaw+(targetYaw-Runtime.yaw)*(1-math.exp(-dt*(App.state.moon and C.moonSensitivity or C.recovery)))
    local yaw=Runtime.yaw+dodgeYaw+(Runtime.latchedYaw or 0)
    if not (C.cameraSmoothing or C.shakeReduction or C.cameraOffset or C.followOffset or C.cameraZoom or
        C.cameraTilt or C.cameraLean or math.abs(yaw)>0.0001) then
        Runtime.lastBase=nil;Runtime.lastApplied=nil;return
    end
    local smoothing=C.cameraSmoothing or C.shakeReduction
    if smoothing then
        local rate=C.cameraSmoothing and C.cameraSmoothness or (35-28*C.shakeStrength)
        Runtime.smooth=Runtime.smooth and Runtime.smooth:Lerp(base,1-math.exp(-dt*rate)) or base
    else Runtime.smooth=nil end
    local output=Runtime.smooth or base
    if math.abs(yaw)>0.0001 then
        local root=rootOf(player.Character);local pivot=root and root.Position+Vector3.new(0,1.5,0) or camera.Focus.Position
        local rotated=CFrame.new(pivot)*CFrame.Angles(0,yaw,0)*CFrame.new(-pivot)*output
        local fraction=App.state.dodge and C.cameraFollow or 1
        local position=output.Position:Lerp(rotated.Position,fraction)
        if fraction>0 and (position-pivot).Magnitude>0.1 then
            local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude
            local exclude={App.folder};if player.Character then table.insert(exclude,player.Character) end
            params.FilterDescendantsInstances=exclude;params.IgnoreWater=true
            local hit=S.Workspace:Raycast(pivot,position-pivot,params)
            if hit then position=hit.Position+(pivot-position).Unit*0.3 end
        end
        output=CFrame.new(position)*rotated.Rotation
    end
    local offset=(C.cameraOffset or C.followOffset) and Vector3.new(C.offsetX,C.offsetY,C.offsetZ) or Vector3.zero
    if C.cameraZoom then offset=offset+Vector3.new(0,0,C.zoom) end
    output=output*CFrame.new(offset)
    local leanTarget=0
    if C.cameraLean and alive then leanTarget=-output.RightVector:Dot(humanoid.MoveDirection)*C.lean end
    Runtime.lean=Runtime.lean+(leanTarget-Runtime.lean)*(1-math.exp(-dt*9))
    output=output*CFrame.Angles(0,0,math.rad((C.cameraTilt and C.tilt or 0)+Runtime.lean))
    Runtime.lastBase=base;Runtime.lastApplied=output;camera.CFrame=output
end

-- Full-screen primitives: center stays clear while green edge glow rises near max FOV.
UI.circle=frame(UI.effects,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
    Size=UDim2.fromOffset(C.circleRadius*2,C.circleRadius*2),BackgroundTransparency=1,Visible=false})
round(UI.circle,10000);UI.circleStroke=stroke(UI.circle,color("fovColor"),1)
UI.cross={};for i=1,4 do UI.cross[i]=newLine(UI.effects) end
UI.edge={}
for side=1,2 do
    local edge=frame(UI.effects,{AnchorPoint=Vector2.new(side==1 and 0 or 1,0),Position=UDim2.fromScale(side==1 and 0 or 1,0),
        Size=UDim2.fromScale(0.13,1),BackgroundColor3=color("edgeColor"),BackgroundTransparency=1})
    create("UIGradient",{Rotation=side==1 and 0 or 180,Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.35,0.6),NumberSequenceKeypoint.new(1,1)})},edge)
    UI.edge[side]=edge
end
UI.hud=frame(UI.screen,{Name="GlassHUD",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(C.hudX,C.hudY),
    Size=UDim2.fromOffset(530,39),BackgroundColor3=Color3.fromRGB(12,15,16),BackgroundTransparency=0.27})
round(UI.hud,13);stroke(UI.hud,Color3.fromRGB(97,103,104)).Transparency=0.55
UI.hudScale=create("UIScale",{Scale=1},UI.hud)
UI.hudText=label(UI.hud,"AETHER V6",{Size=UDim2.new(1,-24,1,0),Position=UDim2.fromOffset(12,0),TextSize=10,TextColor3=Color3.fromRGB(237,241,241),TextXAlignment=Enum.TextXAlignment.Center})
local function updateScreenEffects()
    local active=permitted();local camera=S.Workspace.CurrentCamera
    UI.circle.Visible=active and C.fovCircle
    UI.circle.Size=UDim2.fromOffset(C.circleRadius*2,C.circleRadius*2)
    UI.circleStroke.Color=color("fovColor");UI.circleStroke.Thickness=C.circleThickness
    local view=camera and camera.ViewportSize or Vector2.new(960,620);local center=view/2
    local s=C.crosshairSize;local tint=color("crosshairColor")
    local arms={{Vector2.new(-s-4,0),Vector2.new(-4,0)},{Vector2.new(4,0),Vector2.new(s+4,0)},
        {Vector2.new(0,-s-4),Vector2.new(0,-4)},{Vector2.new(0,4),Vector2.new(0,s+4)}}
    for i,arm in ipairs(UI.cross) do
        arm.Visible=active and C.crosshair
        if arm.Visible then screenLine(arm,center+arms[i][1],center+arms[i][2],1,tint) end
    end
    local strength=(active and camera and C.edgeGlow and C.customFOV) and math.clamp((camera.FieldOfView-100)/20,0,1)*C.edgeIntensity*C.edgeOpacity or 0
    for _,edge in ipairs(UI.edge) do edge.BackgroundTransparency=1-strength;edge.BackgroundColor3=color("edgeColor") end
    UI.hud.Visible=C.hud
end

-- Proximity alerts use the role provider directly, independent of ESP visibility.
-- One reusable GUI and Sound; distance samples at 10 Hz (5 Hz in Performance Mode).
local Danger={level="SAFE",distance=nil,killer=nil,latched=false,lastSound=-math.huge,
    sampleTime=0,flashAt=nil,testAt=nil,serial=0,soundStatus="LOADING",textEvents=0,soundEvents=0}
Runtime.danger=Danger
Danger.root=frame(UI.effects,{Name="DangerAlert",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=4})
Danger.gain=create("NumberValue",{Value=0},Danger.root)
Danger.severity=create("NumberValue",{Value=0},Danger.root)
Danger.bands={}
for side=1,2 do for layer=1,2 do
    local band=frame(Danger.root,{Name="DangerEdge",AnchorPoint=Vector2.new(side==1 and 0 or 1,0),
        Position=UDim2.fromScale(side==1 and 0 or 1,0),Size=UDim2.fromScale(layer==1 and 0.17 or 0.075,1),
        BackgroundColor3=color("dangerColor"),BackgroundTransparency=1,ZIndex=4})
    create("UIGradient",{Rotation=side==1 and 0 or 180,Transparency=NumberSequence.new({
        NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.3,0.48),
        NumberSequenceKeypoint.new(0.7,0.9),NumberSequenceKeypoint.new(1,1)})},band)
    table.insert(Danger.bands,{object=band,strength=layer==1 and 0.4 or 0.9})
end end
Danger.caption=create("CanvasGroup",{Name="CloseWarning",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(C.dangerX,C.dangerY),
    Size=UDim2.fromOffset(330,90),BackgroundTransparency=1,BorderSizePixel=0,GroupTransparency=1,Visible=false,ZIndex=5},Danger.root)
Danger.textScale=create("UIScale",{Scale=1},Danger.caption)
Danger.halo={}
for i=1,3 do
    Danger.halo[i]=create("TextLabel",{Text="БЛИЗКО!",Size=UDim2.new(1,0,0,57),Position=UDim2.fromOffset(0,3-i),
        BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=36+i*2,TextColor3=color("dangerColor"),
        TextTransparency=0.78+i*0.045,TextStrokeColor3=color("dangerColor"),TextStrokeTransparency=0.85,ZIndex=5},Danger.caption)
end
Danger.text=create("TextLabel",{Text="БЛИЗКО!",BackgroundTransparency=1,Size=UDim2.new(1,0,0,57),Font=Enum.Font.GothamBold,
    TextSize=36,TextColor3=Color3.new(1,1,1),TextStrokeColor3=color("dangerColor"),TextStrokeTransparency=0.45,ZIndex=6},Danger.caption)
Danger.distanceText=create("TextLabel",{Text="",BackgroundTransparency=1,Position=UDim2.fromOffset(0,56),Size=UDim2.new(1,0,0,19),
    Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(240,225,225),ZIndex=6},Danger.caption)
Danger.previewTag=create("TextLabel",{Text="ПРЕДПРОСМОТР",BackgroundTransparency=1,Position=UDim2.fromOffset(0,77),Size=UDim2.new(1,0,0,12),
    Font=Enum.Font.Gotham,TextSize=9,TextColor3=Color3.fromRGB(180,180,180),Visible=false,ZIndex=6},Danger.caption)
-- Existing Roblox-owned Creator Store asset; see README for source and availability checks.
Danger.sound=own(create("Sound",{Name="AETHER_V6_Proximity",SoundId="rbxassetid://12221990",Volume=C.dangerVolume,
    Looped=false,PlaybackSpeed=1},S.SoundService))
connect(Danger.sound.Loaded,function() if App.alive then Danger.soundStatus="READY" end end)
task.spawn(function()
    local ok=pcall(function()
        S.ContentProvider:PreloadAsync({Danger.sound},function(_,status)
            if App.alive then Danger.soundStatus=status==Enum.AssetFetchStatus.Success and "READY" or "UNAVAILABLE" end
        end)
    end)
    if App.alive then
        if Danger.sound.IsLoaded then Danger.soundStatus="READY"
        elseif not ok or Danger.soundStatus=="LOADING" then Danger.soundStatus="UNAVAILABLE" end
    end
end)
function Danger:HideText()
    if not self.flashAt and not self.caption.Visible and self.caption.GroupTransparency==1 then return end
    self.flashAt=nil;self.fading=false
    tween(self.caption,0,{GroupTransparency=1});self.caption.Visible=false
end
function Danger:Reset(rearm)
    self.serial=self.serial+1;self.level="SAFE";self.distance=nil;self.killer=nil;self.testAt=nil
    self:HideText();self.sound:Stop();self.targetGain=0;self.targetSeverity=nil
    tween(self.gain,0,{Value=0});tween(self.severity,0,{Value=0})
    for _,band in ipairs(self.bands) do band.object.BackgroundTransparency=1 end
    if rearm then self.latched=false;self.safeSince=nil end
end
function Danger:PlaySignal()
    local now=os.clock()
    if not C.dangerSound or C.dangerVolume<=0 or (App.state.open and C.dangerMuteMenu) or
        self.soundStatus~="READY" or now-self.lastSound<C.dangerSoundCooldown then return end
    self.lastSound=now;self.soundEvents=self.soundEvents+1
    self.sound:Stop();self.sound.Volume=C.dangerVolume
    self.sound.PlaybackSpeed=C.dangerSoundStyle=="Soft" and 0.85 or C.dangerSoundStyle=="Digital" and 1.3 or 0.7
    self.sound.TimePosition=0;self.sound:Play()
    local serial=self.serial
    if C.dangerSoundStyle=="Alarm" then task.delay(0.18,function()
        if App.alive and self.serial==serial and C.dangerEnabled and C.dangerSound and self.level=="CRITICAL" and
            not (App.state.open and C.dangerMuteMenu) then self.sound.TimePosition=0;self.sound:Play() end
    end) end
    task.delay(0.55,function() if App.alive and self.serial==serial then self.sound:Stop() end end)
end
function Danger:EnterCritical()
    self.latched=true;self.safeSince=nil
    if C.dangerText then
        self.flashAt=os.clock();self.fading=false;self.textEvents=self.textEvents+1
        self.caption.Visible=true;self.caption.GroupTransparency=1
        tween(self.caption,0.18,{GroupTransparency=0})
    end
    self:PlaySignal()
end
function Danger:SetDistance(distance,killer,isTest)
    local now=os.clock();local level=distance<C.dangerCritical and "CRITICAL" or distance<=C.dangerWarning and "WARNING" or "SAFE"
    self.level=level;self.distance=distance;self.killer=killer;self.previewTag.Visible=isTest==true
    if distance>=C.dangerCritical+1.5 then
        self.safeSince=self.safeSince or now
        if now-self.safeSince>=0.65 then self.latched=false end
    else self.safeSince=nil end
    if level=="CRITICAL" and not self.latched then self:EnterCritical() end
    if level~="CRITICAL" and self.flashAt then self:HideText() end
    local gain=0
    if level=="WARNING" then gain=0.12+0.33*(1-(distance-C.dangerCritical)/(C.dangerWarning-C.dangerCritical))
    elseif level=="CRITICAL" then gain=0.5+0.45*(1-math.clamp(distance/C.dangerCritical,0,1)) end
    if not self.targetGain or math.abs(self.targetGain-gain)>0.002 then
        self.targetGain=gain;tween(self.gain,0.25,{Value=gain})
    end
    local severity=level=="CRITICAL" and 1 or level=="WARNING" and 0.2 or 0
    if severity~=self.targetSeverity then self.targetSeverity=severity;tween(self.severity,0.25,{Value=severity}) end
end
function Danger:Sample(dt)
    if not C.dangerEnabled then if self.level~="SAFE" or self.testAt or self.gain.Value>0 then self:Reset(true) end;return end
    self.sampleTime=self.sampleTime+dt
    if self.sampleTime<(C.performance and 0.2 or 0.1) then return end
    self.sampleTime=0
    local now=os.clock()
    if self.testAt then
        local age=now-self.testAt
        if age<1 then self:SetDistance(C.dangerCritical+(C.dangerWarning-C.dangerCritical)*0.4,nil,true)
        elseif age<2.6 then self:SetDistance(C.dangerCritical*0.55,nil,true)
        else self:Reset(true) end
        return
    end
    local character=player.Character;local root=rootOf(character)
    local humanoid=character and character:FindFirstChildWhichIsA("Humanoid")
    if not permitted() or not root or not humanoid or humanoid.Health<=0 or not root:IsDescendantOf(S.Workspace) then self:Reset(true);return end
    local closest,nearest=math.huge,nil
    for _,who in ipairs(S.Players:GetPlayers()) do
        if who~=player and roleOf(who)=="KILLER" then
            local target=rootOf(who.Character);local health=who.Character and who.Character:FindFirstChildWhichIsA("Humanoid")
            if target and target:IsDescendantOf(S.Workspace) and health and health.Health>0 then
                local distance=(target.Position-root.Position).Magnitude
                if finite(distance) and distance<closest then closest=distance;nearest=who end
            end
        end
    end
    if nearest then self:SetDistance(closest,nearest,false)
    else
        -- Drop all presentation immediately when no confirmed live killer is available.
        local latched=self.latched;local since=self.safeSince or now
        if self.level~="SAFE" or self.distance or self.gain.Value>0 or self.caption.Visible then self:Reset(false) end
        self.safeSince=since;self.latched=latched and now-since<0.65
    end
end
function Danger:Render()
    if not C.dangerEnabled then return end
    local now=os.clock();local phase=(now*C.dangerPulseSpeed)%1
    local pulse=0.82+0.18*math.sin(now*C.dangerPulseSpeed*math.pi*2)
    if self.level=="CRITICAL" then
        local double=math.exp(-((phase-0.13)/0.075)^2)+0.8*math.exp(-((phase-0.38)/0.09)^2)
        pulse=0.58+0.42*math.min(1,double)
    end
    local tint=Color3.fromRGB(255,110,38):Lerp(color("dangerColor"),self.severity.Value)
    local alpha=C.dangerEdges and self.gain.Value*pulse*C.dangerIntensity/100 or 0
    for _,band in ipairs(self.bands) do band.object.BackgroundColor3=tint;band.object.BackgroundTransparency=1-math.clamp(alpha*band.strength,0,0.85) end
    if not C.dangerText then self:HideText() end
    if self.flashAt then
        local age=now-self.flashAt
        if age>=1.2 then self:HideText()
        elseif age>=0.95 and not self.fading then self.fading=true;tween(self.caption,0.25,{GroupTransparency=1}) end
        self.textScale.Scale=(C.dangerStyle=="MINIMAL" and 0.55 or 1)*(1+0.025*math.sin(age*math.pi*5))
        self.caption.Position=UDim2.fromScale(C.dangerX,C.dangerY)
        self.distanceText.Text=self.distance and string.format("%.1f studs",self.distance) or ""
        self.text.TextStrokeColor3=color("dangerColor")
        for _,halo in ipairs(self.halo) do halo.TextColor3=color("dangerColor");halo.TextStrokeColor3=color("dangerColor") end
    end
    if (not C.dangerSound or (App.state.open and C.dangerMuteMenu)) and self.sound.IsPlaying then self.sound:Stop() end
end
function App:TestDangerAlert()
    if not self.alive then return false,"AETHER is unloaded" end
    if not C.dangerEnabled then return false,"Enable Killer Proximity Alert first" end
    Danger:Reset(true);Danger.testAt=os.clock();Danger.sampleTime=1
    notify("Danger alert preview · 2.6 seconds");return true
end
function App:GetDangerState()
    return {level=Danger.level,distance=Danger.distance,killer=Danger.killer,preview=Danger.testAt~=nil,sound=Danger.soundStatus}
end

-- V6 movement owns normal input and WalkSpeed temporarily; it never writes root CFrame or velocity.
local V6=Runtime.v6
function V6:ResetPose()
    for joint,pose in pairs(self.poses) do
        if joint.Parent and sameCF(joint.Transform,pose.applied) then joint.Transform=pose.base end
        self.poses[joint]=nil
    end
end
function V6:ReleaseSpeed()
    local held=self.speedOwned
    if held and held.humanoid.Parent and math.abs(held.humanoid.WalkSpeed-held.applied)<0.01 then held.humanoid.WalkSpeed=held.original end
    self.speedOwned=nil;self.speedIntent=nil
end
function V6:StopMoon(recover)
    local active=self.moon;self.moon=nil;App.state.moon=false;self:ResetPose();releaseHumanoid()
    if active and active.humanoid.Parent then active.humanoid:Move(Vector3.zero,false) end
    if active and recover==false then Runtime.latchedYaw=(Runtime.latchedYaw or 0)+Runtime.yaw;Runtime.yaw=0 end
end
function V6:StartMoon()
    if not C.moonEnabled or not permitted() or App.state.open or App.state.dodge then return false end
    if self.moon then self:StopMoon();return true end
    local root=rootOf(player.Character);local humanoid=player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
    if not root or not humanoid or humanoid.Health<=0 then return false end
    local heading=C.moonDirection=="Left" and -root.CFrame.RightVector or C.moonDirection=="Right" and root.CFrame.RightVector or -root.CFrame.LookVector
    heading=Vector3.new(heading.X,0,heading.Z)
    if heading.Magnitude<0.01 then return false end
    self.moon={start=os.clock(),direction=heading.Unit,humanoid=humanoid,joints={}}
    for _,joint in ipairs(player.Character:GetDescendants()) do
        if joint:IsA("Motor6D") and joint.Part1 and #self.moon.joints<20 then table.insert(self.moon.joints,joint) end
    end
    App.state.moon=true;self.speedIntent=nil;self.speedDenied=false
    if C.actionNotifications then notify("Moonwalk · "..C.moonMode) end
    return true
end
function V6:Step(dt,humanoid)
    local alive=humanoid and humanoid.Health>0
    local active=self.moon
    if active and (not alive or humanoid~=active.humanoid or not App.state.moon or not C.moonEnabled or App.state.open) then self:StopMoon();active=nil end
    if active and C.moonMode=="Automatic" and os.clock()-active.start>=C.moonDuration then self:StopMoon(C.moonRecovery);active=nil end
    local intent,target=nil,nil
    if alive and permitted() then
        if active then target=(self.boost and C.speedEnabled) and C.speedTarget or C.moonSpeed;intent="moon:"..tostring(target)
        elseif self.boost and C.speedEnabled then intent="boost:"..tostring(C.speedTarget);target=C.speedTarget end
    end
    if not intent then self:ReleaseSpeed();self.speedDenied=false
    elseif self.speedIntent~=intent or not self.speedOwned or self.speedOwned.humanoid~=humanoid then
        local original=self.speedOwned and self.speedOwned.humanoid==humanoid and self.speedOwned.original or humanoid.WalkSpeed
        self:ReleaseSpeed();self.speedIntent=intent;self.speedDenied=false
        if finite(original) then self.speedOwned={humanoid=humanoid,original=original,applied=target};humanoid.WalkSpeed=target end
    elseif self.speedOwned and math.abs(humanoid.WalkSpeed-self.speedOwned.applied)>0.05 then
        -- Respect a game/server correction. Do not repeatedly force the target back.
        self.speedDenied=true
    end
    if active then
        local age=os.clock()-active.start;local ramp=0.08+0.32*C.moonSmoothness
        local envelope=math.clamp(age/ramp,0,1)
        if C.moonMode=="Automatic" then envelope=math.min(envelope,math.clamp((C.moonDuration-age)/ramp,0,1)) end
        envelope=envelope*envelope*(3-2*envelope);active.envelope=envelope
        humanoid:Move(active.direction*envelope,false)
    end
end
function V6:Animate(dt)
    local step=math.min(dt or 1/60,1/30)
    self.springPosition=self.springPosition or 1;self.springVelocity=self.springVelocity or 0
    self.springVelocity=self.springVelocity+(-180*(self.springPosition-1)-24*self.springVelocity)*step
    self.springPosition=self.springPosition+self.springVelocity*step
    if self.keyScale then
        local view=S.Workspace.CurrentCamera and S.Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        local fit=math.max(0.2,math.min(C.keybindScale,(view.X-16)/230,(view.Y-16)/math.max(self.keyHeight or 153,40)))
        self.keyScale.Scale=fit*(C.animations and self.springPosition or 1)
    end
    if self.toastAt then
        local age=os.clock()-self.toastAt
        if age>2 and not self.toastFading then self.toastFading=true;tween(self.toast,0.2,{GroupTransparency=1}) end
        if age>2.2 then self.toast.Visible=false;self.toastAt=nil end
    end
    self:ResetPose()
    local active=self.moon
    if not active then return end
    local phase=(os.clock()-active.start)*5.5;local strength=(active.envelope or 0)*(0.4+0.6*C.moonSmoothness)
    for _,joint in ipairs(active.joints) do
        if joint.Parent and joint.Part1 then
            local name=joint.Part1.Name;local offset=nil
            if name=="LeftFoot" or name=="Left Leg" then offset=CFrame.Angles(math.rad(9)*math.sin(phase)*strength,0,0)
            elseif name=="RightFoot" or name=="Right Leg" then offset=CFrame.Angles(-math.rad(9)*math.sin(phase)*strength,0,0)
            elseif name=="LowerTorso" or name=="Torso" then offset=CFrame.new(0,0.025*math.sin(phase*2)*strength,0)*CFrame.Angles(0,0,math.rad(2)*math.sin(phase)*strength) end
            if offset then local base=joint.Transform;joint.Transform=base*offset;self.poses[joint]={base=base,applied=joint.Transform} end
        end
    end
end
function App:ToggleSpeedBoost()
    if not permitted() or not C.speedEnabled then return false,"Speed boost unavailable" end
    V6.boost=not V6.boost;V6.speedIntent=nil;V6.speedDenied=false
    if not V6.boost then V6:ReleaseSpeed() end
    if C.actionNotifications then notify("Speed Boost "..(V6.boost and "ON · target "..C.speedTarget or "OFF")) end
    return true
end
connect(S.RunService.PreAnimation,function() if App.alive then V6:ResetPose() end end)

-- Floating keybind HUD; rows are reused and statuses always derive from actual state.
V6.keys=frame(UI.screen,{Name="KeybindsHUD",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(C.keybindX,C.keybindY),
    Size=UDim2.fromOffset(230,153),BackgroundColor3=Color3.fromRGB(8,10,10),BackgroundTransparency=C.keybindTransparency,Active=true})
round(V6.keys,10);stroke(V6.keys,Color3.fromRGB(105,110,109)).Transparency=0.6
V6.keyScale=create("UIScale",{Scale=C.keybindScale},V6.keys)
V6.keyTitle=label(V6.keys,"AETHER V6 / KEYBINDS",{Position=UDim2.fromOffset(13,0),Size=UDim2.new(1,-26,0,33),TextSize=10,Font=Enum.Font.GothamMedium})
V6.keyRows={}
for i,item in ipairs({{"moonKey","Moonwalk"},{"dodgeKey","Dodge"},{"speedKey","Speed Boost"},{"menuKey","Menu"}}) do
    local r=frame(V6.keys,{Position=UDim2.fromOffset(13,33+(i-1)*28),Size=UDim2.new(1,-26,0,25),BackgroundTransparency=1})
    local dot=frame(r,{Position=UDim2.fromOffset(0,9),Size=UDim2.fromOffset(5,5),BackgroundColor3=Color3.new(1,1,1)});round(dot,99)
    local text=label(r,"",{Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-12,1,0),TextSize=10})
    V6.keyRows[i]={root=r,dot=dot,text=text,key=item[1],name=item[2]}
end
V6.toast=create("CanvasGroup",{Name="ActionNotice",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.fromScale(0.5,0.12),
    Size=UDim2.fromOffset(340,34),BackgroundColor3=Color3.fromRGB(12,14,14),BackgroundTransparency=0.2,
    GroupTransparency=1,Visible=false,BorderSizePixel=0},UI.screen)
round(V6.toast,8);stroke(V6.toast,Color3.fromRGB(62,68,65))
V6.toastText=label(V6.toast,"",{Size=UDim2.new(1,-20,1,0),Position=UDim2.fromOffset(10,0),TextSize=10,TextTruncate=Enum.TextTruncate.AtEnd})
function V6:ShowToast(text)
    if not C.actionNotifications then return end
    self.toastAt=os.clock();self.toastFading=false;self.toastText.Text=text;self.toast.Visible=true
    self.toast.GroupTransparency=1;tween(self.toast,0.2,{GroupTransparency=0})
end
function V6:FlashKey(key)
    self.springVelocity=1.5
    for _,entry in ipairs(self.keyRows) do if C[entry.key]==key then
        entry.dot.BackgroundColor3=Color3.new(1,1,1);entry.flashUntil=os.clock()+0.18;entry.lastTint=nil
    end end
end
connect(V6.keys.InputBegan,function(event)
    if not C.keybindLocked and (event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch) then
        V6.keyDrag={pointer=Vector2.new(event.Position.X,event.Position.Y),x=C.keybindX,y=C.keybindY,
            touch=event.UserInputType==Enum.UserInputType.Touch and event or nil}
    end
end)
function V6:UpdateKeyHUD()
    self.keys.Visible=C.keybindHUD;self.keys.BackgroundTransparency=C.keybindTransparency
    self.keyScale.Scale=math.min(C.keybindScale,math.max(0.5,((S.Workspace.CurrentCamera and S.Workspace.CurrentCamera.ViewportSize.X or 1280)-16)/230))
    self.keys.Position=UDim2.fromScale(C.keybindX,C.keybindY)
    local y=33;local accent=C.rainbowHUD and Color3.fromHSV((os.clock()*C.rgbSpeed)%1,0.55,1) or color("keybindAccentColor")
    for i,r in ipairs(self.keyRows) do
        local enabled=i==1 and C.moonEnabled or i==2 and C.dodgeEnabled or i==3 and C.speedEnabled or i==4
        local active=i==1 and App.state.moon or i==2 and App.state.dodge~=nil or i==3 and self.boost or i==4 and App.state.open
        local cooling=i==2 and os.clock()<App.state.nextDodge and not App.state.dodge
        local status=not enabled and "DISABLED" or not permitted() and i<4 and "BLOCKED" or active and "ACTIVE" or cooling and string.format("%.1fs",App.state.nextDodge-os.clock()) or i==3 and "OFF" or "READY"
        if i==3 and self.boost then status=self.speedDenied and "LIMITED" or "ON" end
        r.root.Visible=not C.keybindOnlyActive or active or cooling
        if r.root.Visible then r.root.Position=UDim2.fromOffset(13,y);y=y+28 end
        local tint=not enabled and Color3.fromRGB(90,95,94) or active and accent or cooling and Color3.fromRGB(165,145,115) or Color3.fromRGB(220,225,223)
        if r.flashUntil and os.clock()<r.flashUntil then tint=Color3.new(1,1,1) end
        if r.lastTint~=status..tostring(tint) then tween(r.dot,0.2,{BackgroundColor3=tint});r.lastTint=status..tostring(tint) end
        r.text.Text="["..C[r.key].."] "..r.name.." · "..status
    end
    if self.keyHeight~=y+7 then self.keyHeight=y+7;tween(self.keys,0.2,{Size=UDim2.fromOffset(230,y+7)}) end
end

-- Spectator data is explicit; other clients' camera targets are never inferred.
V6.spectator=frame(UI.screen,{Name="SpectatorHUD",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(C.spectatorX,C.spectatorY),
    Size=UDim2.fromOffset(225,93),BackgroundColor3=Color3.fromRGB(8,10,10),BackgroundTransparency=0.25})
round(V6.spectator,10);stroke(V6.spectator,Color3.fromRGB(105,110,109)).Transparency=0.6
V6.spectatorText=label(V6.spectator,"",{Position=UDim2.fromOffset(13,9),Size=UDim2.new(1,-26,1,-18),TextSize=10,TextYAlignment=Enum.TextYAlignment.Top,TextWrapped=true})
function V6:RoundReset()
    self.round=self.round+1
    for _,record in pairs(self.people) do record.status=nil;record.changed=nil end
    self:StopMoon();Danger:Reset(true)
end
function V6:UpdateSpectators()
    if not self.groups then return end
    local present={};local alive,dead,watching,known,total=0,0,0,0,0
    for _,who in ipairs(S.Players:GetPlayers()) do
        present[who]=true
        local data=nil
        if permitted() and Runtime.adapter and type(Runtime.adapter.GetPlayerStatus)=="function" then
            local ok,value=pcall(Runtime.adapter.GetPlayerStatus,who);if ok and type(value)=="table" then data=value end
        end
        local h=who.Character and who.Character:FindFirstChildWhichIsA("Humanoid")
        local life=data and data.life or h and (h.Health>0 and "ALIVE" or "DEAD") or "UNKNOWN"
        if life~="ALIVE" and life~="DEAD" then life="UNKNOWN" end
        local watches=data and data.watchingKnown==true and data.watchingUserId==player.UserId and who~=player
        if who~=player then total=total+1;if data and data.watchingKnown==true then known=known+1 end end
        if life=="ALIVE" then alive=alive+1 elseif life=="DEAD" then dead=dead+1 end
        if watches then watching=watching+1 end
        local status=watches and "SPECTATING" or life
        local record=self.people[who]
        if not record then
            record={};self.people[who]=record
            record.row=frame(self.groups[status],{Size=UDim2.new(1,0,0,54),BackgroundTransparency=1})
            record.avatar=create("ImageLabel",{Position=UDim2.fromOffset(0,7),Size=UDim2.fromOffset(34,34),BackgroundTransparency=1,Image=""},record.row)
            round(record.avatar,7)
            record.text=create("TextLabel",{Position=UDim2.fromOffset(43,0),Size=UDim2.new(1,-43,1,0),BackgroundTransparency=1,
                Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,TextColor3=Color3.fromRGB(220,225,223)},record.row)
            task.spawn(function()
                local ok,thumbnail=pcall(S.Players.GetUserThumbnailAsync,S.Players,who.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
                if ok and App.alive and self.people[who]==record then record.avatar.Image=thumbnail end
            end)
        end
        if record.status~=status then record.status=status;record.changed=os.clock();record.row.Parent=self.groups[status] end
        local tint=status=="ALIVE" and Color3.fromRGB(135,220,173) or status=="DEAD" and Color3.fromRGB(215,122,130) or status=="SPECTATING" and Color3.fromRGB(172,156,239) or Color3.fromRGB(165,165,165)
        record.text.TextColor3=tint
        record.text.Text=who.DisplayName.."  @"..who.Name.."\n"..status.." · "..(data and "GAME DATA" or "CHARACTER ONLY").."\nObserved "..string.format("%.0fs ago",os.clock()-record.changed)
    end
    for who,record in pairs(self.people) do if not present[who] then record.row:Destroy();self.people[who]=nil end end
    local target=known==total and tostring(watching) or watching>0 and tostring(watching).." confirmed / ?" or "NOT AVAILABLE"
    self.spectator.Visible=C.spectatorHUD;self.spectator.Position=UDim2.fromScale(C.spectatorX,C.spectatorY)
    self.spectatorText.Text="SPECTATORS\nWatching you: "..target.."\nAlive: "..alive.."   Dead: "..dead..(C.spectatorCompact and "" or "\nLife counts: character / adapter data")
    local height=C.spectatorCompact and 82 or 104
    if self.specHeight~=height then self.specHeight=height;tween(self.spectator,0.25,{Size=UDim2.fromOffset(225,height)}) end
    self.counts={alive=alive,dead=dead,watching=watching,known=known,total=total}
end

-- Own-game protection requires an explicit server endpoint. No local health spoofing.
V6.protection={status="SERVER CONTROLLED",enabled=false,remote=nil,revision=0}
function App:AttachProtection(remote)
    if not permitted() or typeof(remote)~="Instance" or not remote:IsA("RemoteEvent") or not remote:IsDescendantOf(S.ReplicatedStorage) then return false,"Expected your own authorized server RemoteEvent" end
    clear("protection")
    local p=V6.protection;p.remote=remote;p.status="QUERYING SERVER";p.lastRequest=nil;p.authorized=false;p.enabled=false;p.queryAt=os.clock()
    connect(remote.OnClientEvent,function(reply)
        if type(reply)~="table" or type(reply.enabled)~="boolean" then return end
        if reply.revision and reply.revision<p.revision then return end
        p.status=reply.authorized and (reply.enabled and "PROTECTED · SERVER" or "READY · SERVER") or "SERVER CONTROLLED"
        p.enabled=reply.authorized==true and reply.enabled;p.authorized=reply.authorized==true
        if (not p.authorized or p.action=="set") and C.protectionRequested~=p.enabled then C.protectionRequested=p.enabled;refresh("protectionRequested") end
    end,"protection")
    p.revision=p.revision+1;p.action="query";remote:FireServer("query",false,C.protectionVisual,p.revision)
    return true
end
function V6:SyncProtection()
    local p=self.protection
    if p.remote and not p.remote.Parent then clear("protection");p.remote=nil;p.authorized=false;p.enabled=false end
    if not p.remote and App.studio and permitted() then
        local folder=S.ReplicatedStorage:FindFirstChild("AETHER_V6_StudioProtection")
        local remote=folder and folder:FindFirstChild("Control")
        if remote then App:AttachProtection(remote) end
    end
    if not p.remote or not p.remote.Parent or not permitted() then
        p.status="SERVER CONTROLLED";p.enabled=false
        if C.protectionRequested then C.protectionRequested=false;refresh("protectionRequested");notify("Godmode requires the own-game server component") end
    elseif p.authorized then
        local request=tostring(C.protectionRequested)..":"..tostring(C.protectionVisual)
        if p.lastRequest~=request then
            p.lastRequest=request;p.revision=p.revision+1;p.status="WAITING FOR SERVER";p.action="set"
            p.remote:FireServer("set",C.protectionRequested,C.protectionVisual,p.revision)
        end
    elseif p.queryAt and os.clock()-p.queryAt>3 then
        p.status="SERVER CONTROLLED"
        if C.protectionRequested then C.protectionRequested=false;refresh("protectionRequested") end
    end
    local h=player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
    if UI.protectionStatus then UI.protectionStatus.Text=p.status.."\nHealth: "..(h and string.format("%.0f / %.0f",h.Health,h.MaxHealth) or "NOT AVAILABLE") end
end

-- Profiles work without filesystem APIs; optional APIs never become a dependency.
local environment=getfenv()
local fileWrite=type(environment.writefile)=="function" and environment.writefile or nil
local fileRead=type(environment.readfile)=="function" and environment.readfile or nil
local function profileName(name)
    if type(name)~="string" or #name<1 or #name>32 or not name:match("^[%w_%-]+$") then return nil end
    return name
end
local function snapshot()
    local result={};for key,value in pairs(C) do result[key]=value end;return result
end
local function applyConfig(settings)
    if type(settings)~="table" then return false,"Expected settings table" end
    local merged={}
    for key,spec in pairs(App.schema) do merged[key]=spec.default end
    for key,value in pairs(settings) do
        if not valid(key,value) then return false,"Invalid setting: "..tostring(key) end
        merged[key]=value
    end
    local compatible,why=consistent(merged);if not compatible then return false,why end
    local keys={}
    for key,value in pairs(merged) do
        if key:find("Key$") then
            local normalized=(value=="RightControl") and "LeftControl" or value
            if keys[normalized] then return false,"Duplicate key: "..value end
            keys[normalized]=true
        end
    end
    stopMovement();restoreCamera()
    for key,value in pairs(merged) do C[key]=value;refresh(key) end
    App.state.dirty=true;return true
end
function App:SaveConfig(name)
    name=profileName(name);if not name then return false,"Name: 1–32 letters, digits, _ or -" end
    local settings=snapshot();session.profiles[name]=settings
    if fileWrite then
        local ok,reason=pcall(function()
            fileWrite("AETHER_V6_"..name..".json",S.HttpService:JSONEncode({version=6,settings=settings}))
        end)
        if ok then return true,"Saved locally: "..name end
        return true,"Saved in session; file write failed: "..tostring(reason):sub(1,60)
    end
    return true,"Saved for this client session: "..name
end
function App:LoadConfig(name)
    name=profileName(name);if not name then return false,"Invalid profile name" end
    local settings=session.profiles[name]
    if not settings and fileRead then
        local ok,payload=pcall(function()
            local found,raw=pcall(fileRead,"AETHER_V6_"..name..".json")
            if not found then raw=fileRead("AETHER_V5_"..name..".json") end
            assert(type(raw)=="string" and #raw<=65536,"Profile is too large")
            return S.HttpService:JSONDecode(raw)
        end)
        if not ok or type(payload)~="table" or (payload.version~=6 and payload.version~=5) then return false,"Cannot load V5/V6 JSON profile" end
        settings=payload.settings
    end
    if not settings then return false,"Profile not found in this session" end
    local ok,reason=applyConfig(settings)
    return ok,ok and "Loaded: "..name or reason
end
function App:SetConfig(key,value)
    if not valid(key,value) then return false,"Invalid setting" end
    local settings=snapshot();settings[key]=value
    return applyConfig(settings)
end
function App:GetConfig() return snapshot() end
function App:ResetSettings()
    local ok,reason=applyConfig({});App.state.displayApplied=nil
    App.state.dragTarget=Vector2.zero;return ok,reason
end

-- Every visible control is connected to the runtime above, not to a decorative value.
do
    local body=UI.card("Visuals","Danger Alert",2);body.Parent.LayoutOrder=-10
    UI.toggle(body,"Killer Proximity Alert","dangerEnabled")
    UI.toggle(body,"Edge glow","dangerEdges");UI.toggle(body,"Warning text","dangerText")
    UI.toggle(body,"Sound alert","dangerSound");UI.toggle(body,"Mute when menu open","dangerMuteMenu")
    UI.slider(body,"Warning distance","dangerWarning",1," st");UI.slider(body,"Critical distance","dangerCritical",1," st")
    UI.slider(body,"Glow intensity","dangerIntensity",1,"%");UI.slider(body,"Pulse speed","dangerPulseSpeed",0.1)
    UI.color(body,"Custom alert color","dangerColor");UI.choice(body,"Warning style","dangerStyle")
    UI.slider(body,"Alert position X","dangerX",0.01);UI.slider(body,"Alert position Y","dangerY",0.01)
    UI.slider(body,"Sound volume","dangerVolume",0.01);UI.slider(body,"Sound cooldown","dangerSoundCooldown",0.5," s")
    UI.choice(body,"Sound style","dangerSoundStyle")
    UI.action(body,"Test Alert",function() local ok,reason=App:TestDangerAlert();if not ok then notify(reason) end end)
    UI.dangerStatus=UI.note(body,"",48):FindFirstChildOfClass("TextLabel")
    UI.note(body,"Confirmed live killers only. Works independently of ESP. Preview is explicitly labelled; distances use studs.",57)
end
do
    local body=UI.card("Visuals","Player ESP",1)
    for _,item in ipairs({{"Enable ESP","esp"},{"Rainbow ESP","rainbow"},{"Box ESP","boxes"},
        {"Corner box","corners"},{"Skeleton","skeleton"},{"Name tags","names"},{"Distance","distances"},
        {"Tracers","tracers"},{"Chams","chams"},{"Outline","outline"},{"Health · if available","health"}}) do UI.toggle(body,item[1],item[2]) end
    UI.slider(body,"RGB speed","rgbSpeed",0.01);UI.slider(body,"Fill intensity","glow",0.01)
    UI.slider(body,"Transparency","transparency",0.01);UI.slider(body,"ESP distance","espDistance",25," st")
    UI.color(body,"Survivor color","survivorColor");UI.color(body,"Unknown color","unknownColor")
    body=UI.card("Visuals","Killer",1)
    for _,item in ipairs({{"Pulse outline","killerPulse"},{"KILLER label","killerLabel"},{"Killer box","killerBox"},
        {"Killer glow","killerGlow"},{"Killer distance","killerDistance"},{"Killer RGB","killerRainbow"}}) do UI.toggle(body,item[1],item[2]) end
    UI.color(body,"Killer color","killerColor")
    UI.note(body,"Role data: explicit adapter only. Unconfirmed players remain UNKNOWN.",44)
    body=UI.card("Visuals","Pallets",2)
    for _,item in ipairs({{"Pallet ESP","palletESP"},{"Rainbow outline","palletRainbow"},{"White fill","palletWhite"},
        {"Pulse","palletPulse"},{"Labels","palletLabels"},{"Distance","palletDistance"}}) do UI.toggle(body,item[1],item[2]) end
    UI.slider(body,"Pallet range","palletRange",25," st");UI.color(body,"Available / unknown","palletColor");UI.color(body,"Used color","usedPalletColor")
    UI.note(body,"No pallet schema was verified. Only real objects registered by an adapter are rendered.",52)
    body=UI.card("Visuals","World surfaces",2)
    for _,item in ipairs({{"White tile shimmer","whiteTiles"},{"Rainbow tile shimmer","rainbowTiles"},{"Neon edges","neonEdges"},
        {"Crystal wall patches","crystalWalls"},{"Glossy floor patches","glossyFloors"},{"RGB surface pulse","surfacePulse"},
        {"White square waves","squareWaves"},{"Sky reflections","reflections"},{"Ambient glow","ambientGlow"},
        {"Color correction","correction"},{"Low FPS mode","worldLowFPS"}}) do UI.toggle(body,item[1],item[2]) end
    UI.slider(body,"Wave speed","worldSpeed",0.05);UI.slider(body,"Square size","tileSize",0.5," st")
    UI.slider(body,"Intensity","worldIntensity",0.01);UI.slider(body,"Sample radius","worldRange",5," st")
    UI.note(body,"8 / 24 local patches near the camera. Reflections use Roblox materials and the sky, not ray tracing.",55)
end
do
    local body=UI.card("Aim","Camera preview",1)
    UI.toggle(body,"Main toggle · preview","aimEnabled");UI.key(body,"Preview hotkey","aimKey")
    UI.toggle(body,"Target visibility","aimVisible");UI.toggle(body,"Target preview","targetPreview")
    UI.toggle(body,"Camera tracking preview","aimTracking")
    UI.slider(body,"Smoothness","aimSmoothness",0.01)
    UI.action(body,"Next preview player",function()
        local people=S.Players:GetPlayers();local index=table.find(people,Runtime.previewPlayer) or 0
        if #people>0 then rebuildPreview(people[index%#people+1]) end
    end)
    UI.note(body,"Hold the preview hotkey to focus the avatar's head in the right viewport. World camera is unaffected.",60)
    body=UI.card("Aim","FOV overlay",2)
    UI.toggle(body,"Draw FOV circle","fovCircle");UI.slider(body,"Radius","circleRadius",5," px")
    UI.color(body,"FOV color","fovColor");UI.slider(body,"Thickness","circleThickness",0.25)
    UI.toggle(body,"Custom crosshair","crosshair");UI.color(body,"Crosshair color","crosshairColor")
    UI.slider(body,"Crosshair size","crosshairSize",1," px")
    UI.note(body,"The circle is a screen overlay. Aim controls operate on the avatar preview only.",46)
end
do
    local body=UI.card("Camera","Field of view",1)
    UI.toggle(body,"Custom FOV","customFOV");UI.slider(body,"Field of view","fov",1,"°")
    UI.toggle(body,"Smooth FOV","smoothFOV");UI.slider(body,"FOV response","fovEase",1)
    UI.toggle(body,"FOV animation","fovAnimation");UI.slider(body,"Animation amplitude","fovAmplitude",0.5)
    UI.toggle(body,"FOV edge glow","edgeGlow");UI.color(body,"Edge color","edgeColor")
    UI.slider(body,"Edge opacity","edgeOpacity",0.01);UI.slider(body,"Edge intensity","edgeIntensity",0.01)
    body=UI.card("Camera","Camera controller",2)
    for _,item in ipairs({{"Camera offset","cameraOffset"},{"Shake reduction","shakeReduction"},{"Camera tilt","cameraTilt"},
        {"Camera zoom","cameraZoom"},{"Camera smoothing","cameraSmoothing"}}) do UI.toggle(body,item[1],item[2]) end
    UI.slider(body,"Offset X","offsetX",0.1);UI.slider(body,"Offset Y","offsetY",0.1);UI.slider(body,"Offset Z","offsetZ",0.1)
    UI.slider(body,"Tilt","tilt",1,"°");UI.slider(body,"Zoom offset","zoom",0.5," st")
    UI.slider(body,"Camera response","cameraSmoothness",1);UI.slider(body,"Shake reduction strength","shakeStrength",0.01)
    UI.note(body,"Post-camera filter. Games that update their camera after AETHER may override it.",45)
end
do
    local body=UI.card("Movement","Moonwalk",1)
    UI.toggle(body,"Enable Moonwalk","moonEnabled");UI.key(body,"Moonwalk key","moonKey")
    UI.choice(body,"Activation","moonMode");UI.slider(body,"Turn response","moonSensitivity",1)
    UI.slider(body,"Moonwalk speed","moonSpeed",0.5);UI.slider(body,"Duration","moonDuration",0.1," s")
    UI.slider(body,"Camera rotation","moonRotation",5,"°");UI.slider(body,"Animation smoothness","moonSmoothness",0.01)
    UI.choice(body,"Move direction","moonDirection");UI.toggle(body,"Auto recovery","moonRecovery")
    UI.toggle(body,"Movement preview","movementPreview")
    UI.note(body,"Automatic runs a timed backward movement sequence with normal Humanoid input and an additive local rig pose. Press X again to cancel.",76)
    body=UI.card("Movement","Practice & follow",1)
    for _,item in ipairs({{"Quick turn 180","quickTurn"},{"Camera look back","lookBack"},{"Smooth strafe","smoothStrafe"},
        {"Camera lean","cameraLean"},{"Auto reset on focus loss","autoReset"},{"Follow offset","followOffset"},
        {"Studio practice mode","practice"}}) do UI.toggle(body,item[1],item[2]) end
    UI.key(body,"Quick turn key","quickKey");UI.key(body,"Look back key","lookKey");UI.slider(body,"Lean angle","lean",0.5,"°")
    UI.note(body,"Practice permits local effects in Studio. It never adds targets or pallets to a live game.",50)
    body=UI.card("Movement","360 Dodge",2)
    UI.toggle(body,"Enable Dodge","dodgeEnabled");UI.key(body,"Dodge key","dodgeKey")
    UI.choice(body,"Activation","dodgeMode");UI.choice(body,"Direction","direction")
    UI.slider(body,"Rotation speed","rotationSpeed",30," °/s");UI.slider(body,"Smoothness","dodgeSmoothness",0.01)
    UI.slider(body,"Camera follow","cameraFollow",0.01);UI.slider(body,"Recovery response","recovery",1)
    UI.slider(body,"Cooldown","cooldown",0.25," s")
    UI.toggle(body,"Use spin duration","dodgeUseDuration");UI.slider(body,"Spin duration","spinDuration",0.05," s")
    UI.choice(body,"Spin variant","spinPreset");UI.slider(body,"Custom angle","spinAngle",30,"°")
    UI.toggle(body,"Auto recovery","dodgeRecovery")
    UI.note(body,"Automatic: one full spin per press; repeated presses during the spin are ignored. Hold / legacy Toggle remain available. Rotation speed applies when Use spin duration is off.",91)
    body=UI.card("Movement","Speed Boost",2)
    UI.toggle(body,"Enable B action","speedEnabled");UI.key(body,"Speed key","speedKey")
    UI.slider(body,"Target WalkSpeed","speedTarget",0.5)
    UI.action(body,"Toggle Speed Boost",function() local ok,why=App:ToggleSpeedBoost();if not ok then notify(why) end end)
    UI.note(body,"Default target: 23. Previous WalkSpeed is restored on disable. A game/server correction is respected instead of being repeatedly overwritten.",76)
end
do
    local body=UI.card("Display","Aspect ratio",1)
    UI.choice(body,"Preset","displayPreset");UI.slider(body,"Custom width","displayWidth",1)
    UI.slider(body,"Custom height","displayHeight",1)
    UI.action(body,"Apply to viewport preview",function()
        local ratio=C.displayPreset=="Custom" and (C.displayWidth/C.displayHeight) or nil
        if not ratio then local a,b=C.displayPreset:match("^(%d+):(%d+)$");ratio=tonumber(a)/tonumber(b) end
        App.state.displayApplied=ratio;notify("Aspect applied to 3D preview only; system resolution unchanged")
    end)
    UI.action(body,"Reset preview aspect",function() App.state.displayApplied=nil;notify("Preview aspect reset") end)
    UI.displayInfo=UI.note(body,"",75):FindFirstChildOfClass("TextLabel")
    body=UI.card("Display","Actual display stretching",2)
    UI.note(body,"This LocalScript cannot change Windows resolution. Apply affects the avatar ViewportFrame only and does not stretch the game image.",87)
    UI.note(body,"For full-screen stretch: Windows Display resolution → a supported lower mode; Intel Display → Scaling → Stretched. Exact availability depends on the display and driver.",100)
    UI.note(body,"The README includes official Intel instructions. Extreme ratios such as 16:4 may have no supported display mode.",66)
end
do
    local body=UI.card("Settings","Appearance",1)
    UI.slider(body,"UI scale","uiScale",0.05);UI.slider(body,"Menu blur","blur",1)
    UI.color(body,"Accent color","accentColor");UI.slider(body,"Animation speed","animationSpeed",0.05)
    UI.toggle(body,"Animations","animations");UI.choice(body,"Theme","theme")
    UI.color(body,"Custom background","customBackgroundColor")
    UI.toggle(body,"Performance mode","performance")
    body=UI.card("Settings","Keybind manager",2)
    for _,item in ipairs({{"Menu key","menuKey"},{"Moonwalk","moonKey"},{"360 Dodge","dodgeKey"},
        {"Speed Boost","speedKey"},{"Quick turn","quickKey"},{"Look back","lookKey"},{"Aim preview","aimKey"}}) do UI.key(body,item[1],item[2]) end
    UI.note(body,"Default menu: either Ctrl key. Rebinding replaces both Ctrl bindings. Esc cancels capture. Duplicate keys are rejected.",64)
    UI.action(body,"Reset all binds",function()
        local values=snapshot();for key,spec in pairs(App.schema) do if key:find("Key$") then values[key]=spec.default end end
        applyConfig(values);notify("Default keybinds restored")
    end)
    body=UI.card("Settings","Liquid glass HUD",1)
    UI.toggle(body,"Show HUD","hud");UI.slider(body,"HUD horizontal","hudX",0.01)
    UI.slider(body,"HUD vertical","hudY",0.01)
    UI.note(body,"Translucent glass styling. Roblox blur is full-screen while the menu is open; isolated HUD refraction is unavailable.",65)
    UI.toggle(body,"Action notifications","actionNotifications");UI.toggle(body,"Rainbow HUD accent","rainbowHUD")
    body=UI.card("Settings","Keybinds HUD",1)
    UI.toggle(body,"Show keybinds","keybindHUD");UI.toggle(body,"Only active actions","keybindOnlyActive")
    UI.toggle(body,"Lock position","keybindLocked");UI.slider(body,"HUD scale","keybindScale",0.05)
    UI.slider(body,"Background transparency","keybindTransparency",0.01)
    UI.slider(body,"Position X","keybindX",0.01);UI.slider(body,"Position Y","keybindY",0.01)
    UI.color(body,"HUD accent","keybindAccentColor")
    body=UI.card("Settings","Session",2)
    UI.action(body,"Reset all settings",function() App:ResetSettings();notify("Default settings restored") end)
    UI.action(body,"Unload AETHER V6",function() App:Destroy() end)
end
do
    local body=UI.card("Profiles","Configuration",1)
    UI.profileName=textbox(row(body,30),"default",{Size=UDim2.new(1,0,0,28)})
    UI.action(body,"Save config",function() local _,message=App:SaveConfig(UI.profileName.Text);notify(message) end)
    UI.action(body,"Load config",function() local _,message=App:LoadConfig(UI.profileName.Text);notify(message) end)
    UI.action(body,"Next session profile",function()
        local names={};for name in pairs(session.profiles) do table.insert(names,name) end;table.sort(names)
        if #names==0 then notify("No saved session profiles");return end
        UI.profileName.Text=names[((table.find(names,UI.profileName.Text) or 0)%#names)+1]
    end)
    UI.action(body,"Reset settings",function() App:ResetSettings();notify("Default settings restored") end)
    UI.note(body,fileWrite and "Local file API detected. V6 JSON is saved to the API's permitted directory." or
        "No filesystem API. Profiles remain available in this client session, including a clean script rerun.",70)
    body=UI.card("Profiles","Integration status",2)
    UI.integrationInfo=UI.note(body,"",160):FindFirstChildOfClass("TextLabel")
    UI.note(body,"No guessed game remotes, roles or map objects. Protection uses only your own explicitly attached server component. See README for the data contract.",83)
end
do
    local body=UI.card("Protection","Own-game Godmode",1)
    UI.toggle(body,"Godmode request","protectionRequested");UI.toggle(body,"Protection visual","protectionVisual")
    UI.protectionStatus=UI.note(body,"SERVER CONTROLLED",70):FindFirstChildOfClass("TextLabel")
    UI.note(body,"Requires the included authorized server component in your own Studio game. There is no client-only invulnerability in Violence District.",83)
    body=UI.card("Protection","Damage contract",2)
    UI.note(body,"Server ForceField blocks Humanoid:TakeDamage. Use the provided server ApplyDamage gateway for your own combat system. Direct Health assignments and arbitrary kill scripts are outside this contract.",125)
    body=UI.card("Spectators","Data source",2)
    UI.note(body,"Character health gives ALIVE / DEAD only. Round participation and who watches you require GetPlayerStatus from a verified game adapter. Missing spectator data stays NOT AVAILABLE.",113)
    UI.toggle(body,"Spectator HUD","spectatorHUD");UI.toggle(body,"Compact mode","spectatorCompact")
    UI.slider(body,"HUD position X","spectatorX",0.01);UI.slider(body,"HUD position Y","spectatorY",0.01)
    V6.groups={}
    V6.groups.ALIVE=UI.card("Spectators","ALIVE",1);V6.groups.DEAD=UI.card("Spectators","DEAD",1)
    V6.groups.SPECTATING=UI.card("Spectators","SPECTATING · confirmed",2);V6.groups.UNKNOWN=UI.card("Spectators","UNKNOWN",2)
end

-- Input routing, window motion, runtime scheduling and deterministic teardown.
local function fitScale()
    local camera=S.Workspace.CurrentCamera;local view=camera and camera.ViewportSize or Vector2.new(1280,720)
    return math.max(0.2,math.min(C.uiScale,(view.X-24)/960,(view.Y-24)/620))
end
UI.motion=create("NumberValue",{Name="OpeningScale",Value=0.975},UI.main)
App.state.dragPosition=Vector2.zero;App.state.dragTarget=Vector2.zero
function App:SetOpen(open)
    if not self.alive then return end
    self.state.open=open==true;self.state.menuSerial=(self.state.menuSerial or 0)+1
    local serial=self.state.menuSerial
    if open then
        stopMovement();restoreCamera();UI.main.Visible=true
        tween(UI.main,0.25,{GroupTransparency=0});tween(UI.motion,0.25,{Value=1})
    else
        self.state.capture=nil
        local focused=S.UserInputService:GetFocusedTextBox()
        if focused and focused:IsDescendantOf(UI.screen) then focused:ReleaseFocus() end
        for key in pairs(UI.keyButtons) do refresh(key) end
        tween(UI.main,0.2,{GroupTransparency=1});tween(UI.motion,0.2,{Value=0.975})
        task.delay(C.animations and 0.2/C.animationSpeed or 0,function()
            if self.alive and self.state.menuSerial==serial and not self.state.open then UI.main.Visible=false end
        end)
    end
    self.state.dirty=true
end
local function updateTheme()
    for i=#UI.themeBindings,1,-1 do
        local binding=UI.themeBindings[i]
        if binding[1].Parent then binding[1][binding[2]]=palette(binding[3]) else table.remove(UI.themeBindings,i) end
    end
    for key in pairs(App.refreshers) do refresh(key) end
    -- Glass HUD remains readable in both dark and light themes.
    UI.hudText.TextColor3=Color3.fromRGB(237,241,241)
    V6.keyTitle.TextColor3=Color3.fromRGB(237,241,241)
    V6.spectatorText.TextColor3=Color3.fromRGB(237,241,241)
    V6.toastText.TextColor3=Color3.fromRGB(237,241,241)
    for _,entry in ipairs(V6.keyRows) do entry.text.TextColor3=Color3.fromRGB(237,241,241) end
end
local function updateSettings()
    local last=Runtime.settings or {}
    if last.esp~=C.esp or last.permitted~=permitted() then startPlayers() end
    if not C.palletESP or not permitted() then
        for _,record in pairs(App.pallets) do
            releaseHighlight(record)
            if record.overlay then record.overlay.root:Destroy();record.overlay=nil end
        end
    end
    if not permitted() then stopMovement();restoreCamera() end
    if not C.moonEnabled then App.state.moon=false;releaseHumanoid() end
    if not C.dodgeEnabled then App.state.dodge=nil;App.state.dodgeHeld=false end
    if not C.lookBack then App.state.look=false end
    if not C.aimEnabled then App.state.aimHeld=false end
    if not C.quickTurn then App.state.quickUntil=nil end
    if not C.speedEnabled then V6.boost=false;V6:ReleaseSpeed() end
    V6:SyncProtection()
    if not C.dangerEnabled then Danger:Reset(true) end
    if not C.dangerText then Danger:HideText() end
    if not C.dangerEdges then for _,band in ipairs(Danger.bands) do band.object.BackgroundTransparency=1 end end
    if not C.dangerSound then Danger.sound:Stop() end
    if last.performance~=C.performance or last.worldLowFPS~=C.worldLowFPS then
        clearWorld()
        for _,record in pairs(Runtime.players) do releaseHighlight(record) end
        for _,record in pairs(App.pallets) do releaseHighlight(record) end
    end
    App.blur.Enabled=App.state.open and C.blur>0 and not C.performance
    tween(App.blur,0.2,{Size=App.blur.Enabled and C.blur or 0})
    App.bloom.Enabled=permitted() and C.ambientGlow and not C.performance
    App.bloom.Intensity=C.worldIntensity*0.65
    App.grade.Enabled=permitted() and C.correction
    App.grade.Brightness=C.worldIntensity*0.03;App.grade.Contrast=C.worldIntensity*0.12
    App.grade.Saturation=C.worldIntensity*0.1
    App.grade.TintColor=Color3.new(1,1,1):Lerp(color("accentColor"),C.worldIntensity*0.08)
    if last.theme~=C.theme or last.accent~=C.accentColor or last.background~=C.customBackgroundColor then updateTheme() end
    UI.hud.Position=UDim2.fromScale(C.hudX,C.hudY)
    Runtime.settings={esp=C.esp,permitted=permitted(),theme=C.theme,accent=C.accentColor,
        background=C.customBackgroundColor,performance=C.performance,worldLowFPS=C.worldLowFPS}
    App.state.dirty=false
end
local function updateInfo()
    local state=App.state
    local effectCount=0
    for _,key in ipairs({"esp","palletESP","whiteTiles","rainbowTiles","neonEdges","crystalWalls","glossyFloors",
        "surfacePulse","squareWaves","reflections","ambientGlow","correction"}) do if C[key] then effectCount=effectCount+1 end end
    local camera=S.Workspace.CurrentCamera;local view=camera and camera.ViewportSize or Vector2.new(1,1)
    local preset=C.customFOV and string.format("FOV %.0f",C.fov) or "Default camera"
    local waitTime=math.max(0,state.nextDodge-os.clock())
    local dodge=state.dodge and "SPIN" or waitTime>0 and string.format("%.1fs",waitTime) or "READY"
    UI.hudText.Text=string.format("AETHER V6 · %.0f FPS | %s | MOON %s | Z %s | B %s | FX %d",
        state.fps,preset,state.moon and "ON" or "OFF",dodge,V6.boost and (V6.speedDenied and "LIMITED" or "ON") or "OFF",permitted() and effectCount or 0)
    UI.hudScale.Scale=math.min(1,(view.X-20)/530)
    UI.dangerStatus.Text=(Danger.testAt and "PREVIEW · " or "")..Danger.level..
        (Danger.distance and string.format(" · %.1f studs",tonumber(Danger.distance) or 0) or " · no confirmed live target")..
        "\nAudio: "..Danger.soundStatus
    V6:UpdateKeyHUD();V6:SyncProtection()
    local ratio=view.X/math.max(view.Y,1)
    UI.displayInfo.Text=string.format("Current screen: %.3f:1\nSelected: %s\nApplied preview: %s",ratio,C.displayPreset,
        state.displayApplied and string.format("%.3f:1",state.displayApplied) or "default")
    UI.integrationInfo.Text="PlaceId: "..tostring(game.PlaceId).."\n"..
        (App.supported and "Place allowed" or permitted() and "Studio practice allowed" or "Unsupported: game features blocked")..
        "\nAdapter: "..(Runtime.adapter and "attached" or "not attached")..
        "\nRole source: "..(Runtime.adapter and "adapter" or "explicit SetRole / UNKNOWN")..
        "\nRegistered pallets: "..tostring((function() local n=0;for _ in pairs(App.pallets) do n=n+1 end;return n end)())..
        "\nRendered players / pallets: "..Runtime.playerCount.." / "..Runtime.palletCount..
        "\nFilesystem: "..(fileWrite and "available" or "session only")
    if not state.noticeUntil or os.clock()>state.noticeUntil then
        UI.footer.Text="AETHER V6  /  "..(App.supported and "VIOLENCE DISTRICT" or permitted() and "STUDIO PRACTICE" or "UNSUPPORTED PLACE · UI PREVIEW ONLY")..
            "  /  "..(Runtime.adapter and "ADAPTER CONNECTED" or "ROLE & PALLET SCHEMA UNVERIFIED")
    end
    local applied=state.displayApplied;local w,h=258,415
    if applied then if w/h>applied then w=h*applied else h=w/applied end end
    local position=UDim2.fromOffset((258-w)/2,30+(415-h)/2)
    UI.viewport.Position=position;UI.viewport.Size=UDim2.fromOffset(w,h)
    UI.previewOverlay.Position=position;UI.previewOverlay.Size=UDim2.fromOffset(w,h)
    UI.previewName.Size=UDim2.fromOffset(w,20);UI.previewDistance.Size=UDim2.fromOffset(w,18)
end
UI.top.Active=true
connect(UI.top.InputBegan,function(event)
    if event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch then
        if event.Position.X>UI.top.AbsolutePosition.X+UI.top.AbsoluteSize.X-50*UI.scale.Scale then return end
        App.state.drag={start=Vector2.new(event.Position.X,event.Position.Y),offset=App.state.dragTarget,
            touch=event.UserInputType==Enum.UserInputType.Touch and event or nil}
    end
end)
connect(UI.close.Activated,function() App:SetOpen(false) end)
local function keyIsMenu(key)
    return key.Name==C.menuKey or ((C.menuKey=="LeftControl" or C.menuKey=="RightControl") and
        (key==Enum.KeyCode.LeftControl or key==Enum.KeyCode.RightControl))
end
connect(S.UserInputService.InputBegan,function(event,processed)
    if not App.alive or S.UserInputService:GetFocusedTextBox() then return end
    if event.UserInputType~=Enum.UserInputType.Keyboard then return end
    local key=event.KeyCode
    if App.state.capture then
        local setting=App.state.capture;App.state.capture=nil
        if key~=Enum.KeyCode.Escape and key~=Enum.KeyCode.Unknown then
            local settings=snapshot();settings[setting]=key.Name
            local ok,message=applyConfig(settings);if not ok then notify(message) end
        end
        refresh(setting);return
    end
    if keyIsMenu(key) then App:SetOpen(not App.state.open);return end
    if not processed and App.state.open and key.Name==C.aimKey and C.aimEnabled then App.state.aimHeld=true;return end
    if processed or not permitted() or App.state.open then return end
    V6:FlashKey(key.Name)
    if key.Name==C.moonKey and C.moonEnabled then
        V6:StartMoon()
    elseif key.Name==C.dodgeKey and C.dodgeEnabled then
        if C.dodgeMode=="Hold" then App.state.dodgeHeld=true;startDodge()
        elseif App.state.dodge and C.dodgeMode=="Toggle" then
            Runtime.dodgeRecovery=math.atan2(math.sin(Runtime.lastDodgeYaw or 0),math.cos(Runtime.lastDodgeYaw or 0))
            App.state.dodge=nil
        else startDodge() end
    elseif key.Name==C.speedKey and C.speedEnabled then App:ToggleSpeedBoost()
    elseif key.Name==C.quickKey and C.quickTurn then App.state.quickUntil=os.clock()+0.5
    elseif key.Name==C.lookKey and C.lookBack then App.state.look=true
    elseif key.Name==C.aimKey and C.aimEnabled then App.state.aimHeld=true end
end)
connect(S.UserInputService.InputChanged,function(event)
    local point=Vector2.new(event.Position.X,event.Position.Y)
    local keyDrag=V6.keyDrag
    if keyDrag and not C.keybindLocked and (event.UserInputType==Enum.UserInputType.MouseMovement or event==keyDrag.touch) then
        local view=S.Workspace.CurrentCamera and S.Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
        set("keybindX",math.clamp(keyDrag.x+(point.X-keyDrag.pointer.X)/view.X,0.08,0.9))
        set("keybindY",math.clamp(keyDrag.y+(point.Y-keyDrag.pointer.Y)/view.Y,0.1,0.85))
        V6.keys.Position=UDim2.fromScale(C.keybindX,C.keybindY)
    end
    if App.state.slider and (event.UserInputType==Enum.UserInputType.MouseMovement or event==App.state.slider.touch) then App.state.slider.apply(point.X) end
    local drag=App.state.drag
    if drag and (event.UserInputType==Enum.UserInputType.MouseMovement or event==drag.touch) then
        local camera=S.Workspace.CurrentCamera;local view=camera and camera.ViewportSize or Vector2.new(1280,720)
        local scale=fitScale();local limit=Vector2.new(math.max(0,(view.X-960*scale)/2-8),math.max(0,(view.Y-620*scale)/2-8))
        local target=drag.offset+point-drag.start
        App.state.dragTarget=Vector2.new(math.clamp(target.X,-limit.X,limit.X),math.clamp(target.Y,-limit.Y,limit.Y))
    end
end)
connect(S.UserInputService.InputEnded,function(event)
    if V6.keyDrag and ((event.UserInputType==Enum.UserInputType.MouseButton1 and not V6.keyDrag.touch) or event==V6.keyDrag.touch) then V6.keyDrag=nil end
    if event.UserInputType==Enum.UserInputType.MouseButton1 then
        if App.state.slider and not App.state.slider.touch then App.state.slider=nil end
        if App.state.drag and not App.state.drag.touch then App.state.drag=nil end
    elseif event.UserInputType==Enum.UserInputType.Touch then
        if App.state.slider and App.state.slider.touch==event then App.state.slider=nil end
        if App.state.drag and App.state.drag.touch==event then App.state.drag=nil end
    end
    local key=event.KeyCode.Name
    if key==C.moonKey and C.moonMode=="Hold" then V6:StopMoon(C.moonRecovery) end
    if key==C.dodgeKey then App.state.dodgeHeld=false end
    if key==C.lookKey then App.state.look=false end
    if key==C.aimKey then App.state.aimHeld=false end
end)
connect(S.UserInputService.WindowFocusReleased,function()
    App.state.slider=nil;App.state.drag=nil;V6.keyDrag=nil
    -- Hold actions are always released so focus changes cannot leave a held key stuck.
    App.state.look=false;App.state.aimHeld=false;App.state.dodgeHeld=false
    if C.moonMode=="Hold" or C.autoReset then V6:StopMoon() end
    if C.autoReset then stopMovement();restoreCamera() end
end)
connect(S.UserInputService.TextBoxFocused,function()
    stopMovement();App.state.slider=nil;App.state.drag=nil
end)
connect(player.CharacterRemoving,function() stopMovement();restoreCamera();Danger:Reset(true);V6:ReleaseSpeed() end)
connect(player.CharacterAdded,function()
    stopMovement();Runtime.smooth=nil;Danger:Reset(true)
end)
connect(S.Players.PlayerRemoving,function(who)
    App.roles[who.UserId]=nil
    if Danger.killer==who then Danger:Reset(false) end
    if Runtime.previewPlayer==who then rebuildPreview(player) end
end)

local function guarded(callback,...)
    local ok,reason=pcall(callback,...)
    if not ok and App.alive then
        local message=tostring(reason)
        if App.state.lastError~=message then
            App.state.lastError=message;warn("AETHER V6: "..message);notify("Runtime error; inspect client console: "..message:sub(1,75))
        end
    end
end
function App:Destroy()
    if not self.alive then return end
    self.alive=false;Runtime.previewGeneration=Runtime.previewGeneration+1
    S.RunService:UnbindFromRenderStep("AETHER_V6_PreCamera")
    S.RunService:UnbindFromRenderStep("AETHER_V6_PostCamera")
    Danger:Reset(true);stopMovement();V6:ReleaseSpeed();restoreCamera();stopPlayers();clearWorld()
    local protection=V6.protection
    if protection.remote and protection.remote.Parent and protection.enabled and protection.authorized then
        pcall(function() protection.remote:FireServer("set",false,false,protection.revision+1) end)
    end
    for instance in pairs(self.pallets) do self:UnregisterPallet(instance) end
    for object,item in pairs(self.tweens) do item:Cancel();self.tweens[object]=nil end
    for _,items in pairs(self.scopes) do clean(items) end
    Runtime.adapter=nil;table.clear(self.roles)
    table.clear(self.refreshers);table.clear(UI.themeBindings)
    if shared.AETHER_V6==self then shared.AETHER_V6=nil end
end
shutdown.OnInvoke=function() App:Destroy();return true end
connect(UI.screen.Destroying,function() App:Destroy() end)
S.RunService:BindToRenderStep("AETHER_V6_PreCamera",Enum.RenderPriority.Camera.Value-1,function()
    if not App.alive then return end
    local camera=Runtime.camera
    if camera and camera==S.Workspace.CurrentCamera and sameCF(camera.CFrame,Runtime.lastApplied) and Runtime.lastBase then camera.CFrame=Runtime.lastBase end
    Runtime.lastApplied=nil;Runtime.lastBase=nil
end)
S.RunService:BindToRenderStep("AETHER_V6_PostCamera",Enum.RenderPriority.Camera.Value+2,function(dt)
    if App.alive then guarded(updateCamera,math.min(dt,0.1)) end
end)
connect(S.RunService.RenderStepped,function(dt)
    if not App.alive then return end
    App.state.fps=App.state.fps+(1/math.max(dt,0.001)-App.state.fps)*(1-math.exp(-dt*2))
    dt=math.min(dt,0.2)
    local scale=fitScale();UI.scale.Scale=scale*UI.motion.Value
    local view=S.Workspace.CurrentCamera and S.Workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
    local limit=Vector2.new(math.max(0,(view.X-960*scale)/2-8),math.max(0,(view.Y-620*scale)/2-8))
    App.state.dragTarget=Vector2.new(math.clamp(App.state.dragTarget.X,-limit.X,limit.X),math.clamp(App.state.dragTarget.Y,-limit.Y,limit.Y))
    App.state.dragPosition=App.state.dragPosition:Lerp(App.state.dragTarget,C.animations and (1-math.exp(-dt*18)) or 1)
    UI.main.Position=UDim2.new(0.5,App.state.dragPosition.X,0.5,App.state.dragPosition.Y)
    guarded(updatePreview,dt,os.clock());updateScreenEffects();guarded(Danger.Render,Danger);guarded(V6.Animate,V6,dt)
end)
connect(S.RunService.Heartbeat,function(dt)
    if not App.alive then return end
    Runtime.heavyTime=Runtime.heavyTime+dt;Runtime.hudTime=Runtime.hudTime+dt;Runtime.worldTime=Runtime.worldTime+dt
    if App.state.dirty then guarded(updateSettings) end
    guarded(Danger.Sample,Danger,dt)
    V6.spectatorTime=V6.spectatorTime+dt
    if V6.spectatorTime>=(C.performance and 1 or 0.5) then V6.spectatorTime=0;guarded(V6.UpdateSpectators,V6) end
    local interval=C.performance and 1/8 or 1/24
    if Runtime.heavyTime>=interval then
        Runtime.heavyTime=0
        if permitted() and (C.esp or C.palletESP) then guarded(updateESP,os.clock()) end
        if worldActive() then guarded(animateWorld,os.clock()) elseif #Runtime.tiles>0 then clearWorld() end
    end
    if Runtime.worldTime>=((C.performance or C.worldLowFPS) and 1 or 0.5) then
        Runtime.worldTime=0;guarded(sampleWorld)
    end
    if Runtime.hudTime>=0.25 then
        Runtime.hudTime=0;guarded(updateInfo)
        Runtime.previewVisible=targetVisible(Runtime.previewPlayer)
        for instance in pairs(App.pallets) do if not instance:IsDescendantOf(S.Workspace) then App:UnregisterPallet(instance) end end
    end
end)
rebuildPreview(player);UI.select("Aim");App:SetOpen(true);updateSettings();updateInfo()
return App
