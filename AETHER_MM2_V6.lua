-- AETHER MM2 V6 | Ctrl menu / Z instant snap / R assisted aim & shot attempt
-- Studio: place in StarterPlayer > StarterPlayerScripts as a LocalScript.
-- External games may restrict movement, roles, camera, and appearance.
-- R briefly faces the confirmed target before attempting to fire, then restores view.
-- This is NOT server-side Silent Aim, and it cannot guarantee hits in MM2.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")

local me = Players.LocalPlayer
if not me then warn("AETHER: this script requires a client LocalScript") return end

-- Stop a running previous release so its old hotkeys and GUI cannot stay active.
-- This does NOT import any of its keybinds, saved settings, or movement controls.
if type(_G.AETHER_MM2_V2) == "table" and type(_G.AETHER_MM2_V2.Destroy) == "function" then
    pcall(_G.AETHER_MM2_V2.Destroy)
end

if type(_G.AETHER_MM2_V3) == "table" and type(_G.AETHER_MM2_V3.Destroy) == "function" then
    pcall(_G.AETHER_MM2_V3.Destroy)
end
if type(_G.AETHER_MM2_V4) == "table" and type(_G.AETHER_MM2_V4.Destroy) == "function" then
    pcall(_G.AETHER_MM2_V4.Destroy)
end
if type(_G.AETHER_MM2_V5) == "table" and type(_G.AETHER_MM2_V5.Destroy) == "function" then
    pcall(_G.AETHER_MM2_V5.Destroy)
end
if type(_G.AETHER_MM2_V6) == "table" and type(_G.AETHER_MM2_V6.Destroy) == "function" then
    pcall(_G.AETHER_MM2_V6.Destroy)
end

local App = { alive = true, connections = {}, entries = {}, owned = {}, originalWalk = nil, originalFov = nil }
_G.AETHER_MM2_V6 = App

local function conn(signal, fn)
    local c = signal:Connect(fn)
    table.insert(App.connections, c)
    return c
end
local function hex(r,g,b) return Color3.fromRGB(r,g,b) end
local BLACK=hex(9,9,11)
local PANEL=hex(17,17,20)
local PANEL2=hex(24,24,27)
local LINE=hex(45,45,49)
local MUTED=hex(147,147,155)
local WHITE=hex(242,242,244)
local GREEN=hex(100,215,158)
local RED=hex(240,82,92)
local BLUE=hex(88,174,248)
local function make(cls, parent, props)
    local o=Instance.new(cls)
    if props then for k,v in pairs(props) do o[k]=v end end
    o.Parent=parent
    return o
end
local function radius(o, p) make("UICorner",o,{CornerRadius=UDim.new(0,p or 9)}) return o end
local function stroke(o, color, width)
    make("UIStroke",o,{Color=color or LINE,Thickness=width or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
    return o
end
local function tween(o,t,props)
    if not App.alive or not o or not o.Parent then return end
    local v=TweenService:Create(o,TweenInfo.new(t or 0.20,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props)
    v:Play()
    return v
end
local function label(parent,text,size,color,bold)
    return make("TextLabel",parent,{BackgroundTransparency=1,Text=text or "",Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,TextSize=size or 12,TextColor3=color or WHITE,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
end
local function button(parent, text, color)
    local b=radius(make("TextButton",parent,{BackgroundColor3=color or PANEL2,Text=text,Font=Enum.Font.GothamMedium,TextSize=12,TextColor3=WHITE,AutoButtonColor=false}),7)
    stroke(b,LINE)
    conn(b.MouseEnter,function() tween(b,.15,{BackgroundColor3=hex(36,36,39)}) end)
    conn(b.MouseLeave,function() tween(b,.15,{BackgroundColor3=color or PANEL2}) end)
    return b
end

local defaults={
    menu=true, previewIndex=1, previewSpin=true,
    esp=false, espUnknown=false, espNames=true, espDistance=true, espMax=160,
    proximity=true, proximityCritical=15, proximityWarning=35,
    infiniteJump=true, jumpCooldownMs=240, speed=false, speedValue=16,
    fov=false, fovValue=80, edgeGlow=true, bloom=false, colorGrade=false,
    keyHud=true, keyHudX=18, keyHudY=115, uiScale=1, uiScalePct=100,
    alertSoundId="", alertSoundVolume=40,
    -- V6 config is isolated from previous versions; default bindings: Ctrl/Z/R.
    aimbot=true, aimbotFov=165, aimbotLOS=true,
    aimbotShowCircle=true,
    silentAim=true, silentAimFov=115, silentAimLOS=true, silentAimMarker=true,
    shotCameraRestore=true,
    binds={menu="LeftControl",speed="",aim="Z",silent="R"}
}
local S={}
for k,v in pairs(defaults) do
    if type(v)=="table" then S[k]={} for a,b in pairs(v) do S[k][a]=b end else S[k]=v end
end
local function readSettings()
    -- V6 settings are isolated: no imports from earlier releases.
    local raw=nil
    pcall(function() if type(readfile)=="function" then raw=readfile("AETHER_MM2_V6.json") end end)
    local saved=raw and (function() local ok,t=pcall(HttpService.JSONDecode,HttpService,raw) if ok then return t end end)() or _G.AETHER_MM2_V6_SETTINGS
    if type(saved)~="table" then return end
    for k,v in pairs(defaults) do
        if type(v)=="boolean" and type(saved[k])=="boolean" then S[k]=saved[k] end
        if type(v)=="number" and type(saved[k])=="number" then S[k]=saved[k] end
        if type(v)=="string" and type(saved[k])=="string" then S[k]=saved[k] end
    end
    if type(saved.binds)=="table" then
        for k in pairs(S.binds) do
            local key=saved.binds[k]
            if type(key)=="string" then
                if key=="" and k~="menu" then
                    S.binds[k]=""
                elseif key~="" then
                    local ok, mapped=pcall(function() return Enum.KeyCode[key] end)
                    if ok and mapped then S.binds[k]=key end
                end
            end
        end
    end
    S.previewIndex=math.clamp(math.floor(S.previewIndex),1,3)
    S.fovValue=math.clamp(S.fovValue,50,110)
    S.speedValue=math.clamp(S.speedValue,16,35)
    S.uiScale=math.clamp(S.uiScale,.65,1.2)
    S.uiScalePct=math.floor(S.uiScale*100+.5)
    S.espMax=math.clamp(S.espMax,40,350)
    S.jumpCooldownMs=math.clamp(S.jumpCooldownMs,150,600)
    S.aimbotFov=math.clamp(S.aimbotFov,45,350)
    S.silentAimFov=math.clamp(S.silentAimFov,35,300)
end
readSettings()
local function persist()
    _G.AETHER_MM2_V6_SETTINGS=S
    pcall(function() if type(writefile)=="function" then writefile("AETHER_MM2_V6.json",HttpService:JSONEncode(S)) end end)
end

App.tabConnections={}
local function tabConn(signal,fn)
    local c=signal:Connect(fn)
    table.insert(App.tabConnections,c)
    return c
end
local gui=make("ScreenGui",me:WaitForChild("PlayerGui"),{
    Name="AETHER_MM2_V6_GUI",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=50
})
local root=radius(make("Frame",gui,{
    Name="Main",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(950,544),
    BackgroundColor3=BLACK,ClipsDescendants=true,ZIndex=10
}),12)
stroke(root,hex(35,35,39))
local uiScale=make("UIScale",root,{Scale=S.uiScale})

local function fitScale()
    local camera=Workspace.CurrentCamera
    local view=camera and camera.ViewportSize or Vector2.new(1280,720)
    uiScale.Scale=math.min(S.uiScale,math.min(view.X/995,view.Y/580))
end
fitScale()
root.Visible=S.menu

local nav=make("Frame",root,{Size=UDim2.new(0,70,1,0),BackgroundColor3=hex(13,13,15),ZIndex=11})
make("Frame",root,{Position=UDim2.fromOffset(70,0),Size=UDim2.new(0,1,1,0),BorderSizePixel=0,BackgroundColor3=LINE,ZIndex=12})
local brand=label(nav,"A",25,WHITE,true)
brand.Position=UDim2.fromOffset(25,18) brand.Size=UDim2.fromOffset(44,36)
local header=make("Frame",root,{Position=UDim2.fromOffset(72,0),Size=UDim2.new(1,-72,0,55),BackgroundTransparency=1,Active=true,ZIndex=11})
local title=label(header,"AETHER   /   MM2",16,WHITE,true)
title.Position=UDim2.fromOffset(18,8) title.Size=UDim2.fromOffset(365,24)
local sub=label(header,"V6.0   •   CTRL / Z SNAP / R ASSIST",10,MUTED)
sub.Position=UDim2.fromOffset(18,30) sub.Size=UDim2.fromOffset(420,19)
local close=button(header,"×") close.Position=UDim2.new(1,-48,0,10) close.Size=UDim2.fromOffset(33,31)
local min=button(header,"—") min.Position=UDim2.new(1,-86,0,10) min.Size=UDim2.fromOffset(33,31)

local content=make("ScrollingFrame",root,{
    Position=UDim2.fromOffset(86,72),Size=UDim2.new(1,-400,1,-88),BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=3,ScrollBarImageColor3=MUTED,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.fromOffset(0,0),ZIndex=12
})
local right=radius(make("Frame",root,{Position=UDim2.new(1,-297,0,72),Size=UDim2.new(0,281,1,-89),BackgroundColor3=PANEL,ZIndex=12}),10)
stroke(right,LINE)
local ptitle=label(right,"CHARACTER PREVIEW",11,WHITE,true)
ptitle.Position=UDim2.fromOffset(15,12) ptitle.Size=UDim2.fromOffset(230,21)
local preview=radius(make("ViewportFrame",right,{
    Position=UDim2.fromOffset(12,43),Size=UDim2.new(1,-24,1,-148),BackgroundColor3=hex(13,13,16),
    Ambient=hex(135,135,145),LightColor=hex(255,255,255),LightDirection=Vector3.new(-1,-2,-1),ZIndex=13
}),7)
local world=make("WorldModel",preview)
local pcamera=make("Camera",preview,{FieldOfView=32})
pcamera.CFrame=CFrame.new(Vector3.new(0,1.1,9.6),Vector3.new(0,.45,0))
preview.CurrentCamera=pcamera
local charTitle=label(right,"Silver Shadow",13,WHITE,true)
charTitle.Position=UDim2.new(0,15,1,-94) charTitle.Size=UDim2.new(1,-30,0,23)
local charDesc=label(right,"PROCEDURAL 3D • LOCAL PREVIEW",9,MUTED)
charDesc.Position=UDim2.new(0,15,1,-74) charDesc.Size=UDim2.new(1,-30,0,16)
local prev=button(right,"‹") prev.Position=UDim2.new(0,14,1,-42) prev.Size=UDim2.fromOffset(49,30)
local nextBtn=button(right,"›") nextBtn.Position=UDim2.new(1,-63,1,-42) nextBtn.Size=UDim2.fromOffset(49,30)
local indexLabel=label(right,"1 / 3",11,MUTED,true)
indexLabel.Position=UDim2.new(.45,0,1,-40) indexLabel.Size=UDim2.fromOffset(48,25)

local avatar=nil
local angle=0
local skins={
    {name="Silver Shadow",hair=hex(220,219,226),outfit=hex(22,23,27),lower=hex(25,24,28),eyes=hex(240,214,80),desc="Long silver hair / dark jacket"},
    {name="Grey Ghost",hair=hex(225,223,222),outfit=hex(151,154,160),lower=hex(168,170,177),eyes=hex(72,72,78),desc="Grey hoodie / pleated skirt"},
    {name="Pink Angel",hair=hex(255,151,184),outfit=hex(248,245,249),lower=hex(249,247,250),eyes=hex(231,91,169),desc="Pink hair / white dress"}
}
local function piece(parent,n,sz,cf,col,shape)
    local part=make("Part",parent,{Name=n,Size=sz,CFrame=cf,Color=col,Anchored=true,CanCollide=false,Material=Enum.Material.SmoothPlastic,CastShadow=false})
    if shape then part.Shape=shape end
    return part
end
local function makeAvatar(which)
    if avatar then avatar:Destroy() end
    local skin=skins[which]
    avatar=make("Model",world,{Name=skin.name})
    local skinTone=hex(245,213,199)
    piece(avatar,"Torso",Vector3.new(1.00,1.22,.45),CFrame.new(0,.75,0),skin.outfit)
    piece(avatar,"Neck",Vector3.new(.21,.24,.21),CFrame.new(0,1.5,0),skinTone)
    piece(avatar,"Head",Vector3.new(.86,1.01,.78),CFrame.new(0,2.06,0),skinTone,Enum.PartType.Ball)
    piece(avatar,"LeftEye",Vector3.new(.13,.11,.08),CFrame.new(-.18,2.11,.38),skin.eyes,Enum.PartType.Ball)
    piece(avatar,"RightEye",Vector3.new(.13,.11,.08),CFrame.new(.18,2.11,.38),skin.eyes,Enum.PartType.Ball)
    piece(avatar,"HairCap",Vector3.new(.96,.65,.88),CFrame.new(0,2.47,-.01),skin.hair,Enum.PartType.Ball)
    for i=-2,2 do
        local x=i*.15
        local len=which==3 and .8 or 1.65
        piece(avatar,"HairBack",Vector3.new(.16,len,.18),CFrame.new(x,2.24-len*.42,-.39),skin.hair)
    end
    piece(avatar,"BangsLeft",Vector3.new(.24,.56,.22),CFrame.new(-.30,2.34,.34)*CFrame.Angles(0,0,-.15),skin.hair)
    piece(avatar,"BangsRight",Vector3.new(.24,.56,.22),CFrame.new(.30,2.34,.34)*CFrame.Angles(0,0,.15),skin.hair)
    for _,side in ipairs({-1,1}) do
        local sleeve=which==3 and skinTone or skin.outfit
        piece(avatar,"UpperArm",Vector3.new(.26,.95,.29),CFrame.new(side*.67,1.00,0)*CFrame.Angles(0,0,side*.23),sleeve)
        piece(avatar,"Forearm",Vector3.new(.22,.56,.24),CFrame.new(side*.8,.30,.01),which==3 and skinTone or sleeve)
        piece(avatar,"Hand",Vector3.new(.22,.25,.22),CFrame.new(side*.81,-.09,.01),skinTone,Enum.PartType.Ball)
        piece(avatar,"Leg",Vector3.new(.33,1.40,.35),CFrame.new(side*.26,-1.10,0),skinTone)
        piece(avatar,"Shoe",Vector3.new(.40,.27,.67),CFrame.new(side*.26,-1.91,.13),hex(35,35,42))
    end
    if which==1 then
        piece(avatar,"JacketOpen",Vector3.new(.4,.85,.08),CFrame.new(-.34,1.0,.27),hex(6,6,9))
        piece(avatar,"JacketOpen",Vector3.new(.4,.85,.08),CFrame.new(.34,1.0,.27),hex(6,6,9))
        piece(avatar,"Shorts",Vector3.new(.86,.47,.48),CFrame.new(0,-.08,0),skin.lower)
        piece(avatar,"Sock",Vector3.new(.35,.8,.36),CFrame.new(.26,-1.34,.01),hex(28,27,33))
    elseif which==2 then
        piece(avatar,"Hood",Vector3.new(.87,.40,.45),CFrame.new(0,1.47,-.31),hex(138,140,148))
        piece(avatar,"Skirt",Vector3.new(1.25,.65,.82),CFrame.new(0,-.15,0),skin.lower)
        piece(avatar,"Pocket",Vector3.new(.38,.23,.07),CFrame.new(0,.75,.26),hex(128,130,135))
    else
        piece(avatar,"Dress",Vector3.new(1.12,1.10,.76),CFrame.new(0,.04,0),skin.outfit)
        piece(avatar,"BowMiddle",Vector3.new(.21,.21,.13),CFrame.new(0,.48,.48),hex(24,20,25))
        for _,side in ipairs({-1,1}) do
            piece(avatar,"BowWing",Vector3.new(.40,.24,.12),CFrame.new(side*.30,.47,.48)*CFrame.Angles(0,0,side*.28),hex(24,20,25))
        end
    end
    charTitle.Text=skin.name
    charDesc.Text=skin.desc
    indexLabel.Text=tostring(which).." / 3"
    angle=0
end
makeAvatar(S.previewIndex)
conn(prev.MouseButton1Click,function() S.previewIndex=(S.previewIndex+1)%3+1 makeAvatar(S.previewIndex) end)
conn(nextBtn.MouseButton1Click,function() S.previewIndex=S.previewIndex%3+1 makeAvatar(S.previewIndex) end)

local hud=radius(make("Frame",gui,{Position=UDim2.fromOffset(S.keyHudX,S.keyHudY),Size=UDim2.fromOffset(240,164),BackgroundColor3=BLACK,BackgroundTransparency=.13,ZIndex=20}),9)
stroke(hud,LINE)
local hTitle=label(hud,"AETHER  /  KEYBINDS",11,WHITE,true)
hTitle.Active=true
hTitle.Position=UDim2.fromOffset(12,8) hTitle.Size=UDim2.fromOffset(216,20)
local hlines={}
for i=1,5 do
    hlines[i]=label(hud,"",11,MUTED,i==1)
    hlines[i].Position=UDim2.fromOffset(12,27+(i-1)*23)
    hlines[i].Size=UDim2.fromOffset(216,22)
end
local function updateHud()
    if not App.alive then return end
    hud.Visible=S.keyHud
    hlines[1].Text="[CTRL]  Menu"
    hlines[2].Text="[SPACE x2+]  Infinite Jump: "..(S.infiniteJump and "ON" or "OFF")
    hlines[3].Text=S.binds.speed~="" and ("["..S.binds.speed.."]  Speed: "..(S.speed and tostring(S.speedValue) or "OFF")) or "[-]  Speed: menu only"
    hlines[4].Text="["..S.binds.aim.."]  Aim snap: "..(S.aimbot and "ON" or "OFF")
    hlines[5].Text=(S.binds.silent~="" and ("["..S.binds.silent.."]") or "[-]").."  Aim + shot: "..(S.silentAim and "ON" or "OFF")
    hlines[2].TextColor3=S.infiniteJump and GREEN or MUTED
    hlines[3].TextColor3=S.speed and GREEN or MUTED
    hlines[4].TextColor3=S.aimbot and BLUE or MUTED
    hlines[5].TextColor3=S.silentAim and RED or MUTED
end
updateHud()

-- Dragging GUI uses shared input listeners; no per-frame RenderStepped allocations.
local dragTarget,dragStart,posStart
local function draggable(frame, handle, onDone)
    conn(handle.InputBegan,function(input)
        if input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        dragTarget=frame dragStart=UIS:GetMouseLocation() posStart=frame.Position
    end)
    if onDone then App.dragDone=App.dragDone or {} App.dragDone[frame]=onDone end
end
draggable(root,header)
draggable(hud,hTitle,function()
    S.keyHudX=hud.Position.X.Offset S.keyHudY=hud.Position.Y.Offset
end)

local dangerLeft=make("Frame",gui,{Position=UDim2.fromScale(0,0),Size=UDim2.new(0,90,1,0),BackgroundColor3=RED,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5})
local dangerRight=make("Frame",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.new(0,90,1,0),BackgroundColor3=RED,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=5})
make("UIGradient",dangerLeft,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.06),NumberSequenceKeypoint.new(1,1)})})
make("UIGradient",dangerRight,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.06)})})
local dangerText=label(gui,"БЛИЗКО!",30,WHITE,true)
dangerText.AnchorPoint=Vector2.new(.5,.5)
dangerText.Position=UDim2.fromScale(.5,.28)
dangerText.Size=UDim2.fromOffset(290,50)
dangerText.TextXAlignment=Enum.TextXAlignment.Center
dangerText.TextStrokeColor3=RED
dangerText.TextStrokeTransparency=.4
dangerText.TextTransparency=1
dangerText.ZIndex=6
local fovLeft=make("Frame",gui,{Position=UDim2.fromScale(0,0),Size=UDim2.new(0,110,1,0),BackgroundColor3=hex(33,208,112),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4})
local fovRight=make("Frame",gui,{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.new(0,110,1,0),BackgroundColor3=hex(33,208,112),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=4})
make("UIGradient",fovLeft,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.06),NumberSequenceKeypoint.new(1,1)})})
make("UIGradient",fovRight,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,.06)})})
local currentGlow=-1
local function refreshFovGlow()
    local target=1
    if S.fov and S.edgeGlow then
        target=1-math.clamp((S.fovValue-94)/16,0,1)*.65
    end
    if math.abs(target-currentGlow)>.03 then
        currentGlow=target
        tween(fovLeft,.2,{BackgroundTransparency=target})
        tween(fovRight,.2,{BackgroundTransparency=target})
    end
end
local sound=make("Sound",SoundService,{Name="AETHER_ProximitySound",Volume=.4})
local dangerState=-1
local lastSound=0
local function setDanger(level)
    if dangerState==level then return end
    dangerState=level
    if level==2 and os.clock()-lastSound>3 and S.alertSoundId~="" then
        lastSound=os.clock()
        local id=tostring(S.alertSoundId):match("%d+")
        if id then
            sound.SoundId="rbxassetid://"..id
            sound.Volume=math.clamp(S.alertSoundVolume/100,0,1)
            pcall(function() sound:Play() end)
        end
    end
    local a=level==2 and .26 or level==1 and .66 or 1
    tween(dangerLeft,.24,{BackgroundTransparency=a})
    tween(dangerRight,.24,{BackgroundTransparency=a})
    tween(dangerText,.2,{TextTransparency=level==2 and 0 or 1})
end

local effects={}
local origAmbient=Lighting.Ambient
local function updateEffects()
    if S.bloom and not effects.bloom then
        effects.bloom=make("BloomEffect",Lighting,{Name="AETHER_Bloom",Intensity=.22,Size=22,Threshold=1.8})
    elseif not S.bloom and effects.bloom then effects.bloom:Destroy() effects.bloom=nil end
    if S.colorGrade and not effects.grade then
        effects.grade=make("ColorCorrectionEffect",Lighting,{Name="AETHER_Grade",Brightness=.025,Contrast=.10,Saturation=.10})
    elseif not S.colorGrade and effects.grade then effects.grade:Destroy() effects.grade=nil end
end
updateEffects()

local character, humanoid, rootPart
local heldSpace=false
local lastAir=0
local function attachCharacter(c)
    heldSpace=false
    lastAir=0
    character=c
    humanoid=c:WaitForChild("Humanoid",6)
    rootPart=c:WaitForChild("HumanoidRootPart",6)
    if humanoid then
        App.originalWalk=humanoid.WalkSpeed
        if S.speed then humanoid.WalkSpeed=S.speedValue end
    end
end
if me.Character then task.defer(attachCharacter,me.Character) end
conn(me.CharacterAdded,attachCharacter)

local function setSpeed(enabled)
    S.speed=enabled
    if humanoid and humanoid.Parent then
        if enabled then
            if not App.originalWalk then App.originalWalk=humanoid.WalkSpeed end
            humanoid.WalkSpeed=S.speedValue
        else humanoid.WalkSpeed=App.originalWalk or 16 end
    end
    updateHud()
end
local function roleOf(player)
    -- Expose explicit role from own development environments; otherwise only visible, equipped tools.
    local a=player:GetAttribute("Role")
    if type(a)=="string" then
        local text=a:lower()
        if text=="murderer" or text=="murder" then return "MURDERER" end
        if text=="sheriff" or text=="hero" then return "SHERIFF" end
        if text=="innocent" then return "INNOCENT" end
    end
    local model=player.Character
    if model then
        for _,obj in ipairs(model:GetChildren()) do
            if obj:IsA("Tool") then
                local name=obj.Name:lower()
                if name=="knife" then return "MURDERER" end
                if name=="gun" or name=="revolver" then return "SHERIFF" end
            end
        end
    end
    return "UNKNOWN"
end
-- Targeting is based ONLY on confirmed, client-visible role information.
-- Z snaps the camera. R briefly aligns the camera, activates the gun, and restores the view.
-- This is NOT genuine Silent Aim and can never guarantee a server-validated hit.
local function validMurdererTarget(limitPixels, needLineOfSight)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local center=cam.ViewportSize/2
    local best, bestScreenDist=nil, limitPixels
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=me and roleOf(pl)=="MURDERER" then
            local model=pl.Character
            local head=model and model:FindFirstChild("Head")
            local h=model and model:FindFirstChildOfClass("Humanoid")
            if head and h and h.Health>0 and head:IsA("BasePart") then
                local screen,onScreen=cam:WorldToViewportPoint(head.Position)
                if onScreen and screen.Z>0 then
                    local pixels=(Vector2.new(screen.X,screen.Y)-center).Magnitude
                    if pixels<=bestScreenDist then
                        local visible=true
                        if needLineOfSight then
                            local params=RaycastParams.new()
                            params.FilterType=Enum.RaycastFilterType.Exclude
                            params.FilterDescendantsInstances=character and {character} or {}
                            local diff=head.Position-cam.CFrame.Position
                            local hit=Workspace:Raycast(cam.CFrame.Position,diff,params)
                            visible=hit==nil or hit.Instance:IsDescendantOf(model)
                        end
                        if visible then
                            best,bestScreenDist={player=pl,head=head,screen=screen,pixels=pixels},pixels
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Targets may be outside the current view for the Z snap and R action.
-- This never guesses hidden MM2 roles or accesses another player's camera.
local function nearestConfirmedMurderer(requireLOS, maxStuds)
    local cam=Workspace.CurrentCamera
    if not cam then return nil end
    local origin=(rootPart and rootPart.Position) or cam.CFrame.Position
    local best, bestDistance=nil, maxStuds or 300
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=me and roleOf(pl)=="MURDERER" then
            local model=pl.Character
            local head=model and model:FindFirstChild("Head")
            local h=model and model:FindFirstChildOfClass("Humanoid")
            if head and head:IsA("BasePart") and h and h.Health>0 then
                local distance=(head.Position-origin).Magnitude
                if distance<bestDistance then
                    local visible=true
                    if requireLOS then
                        local params=RaycastParams.new()
                        params.FilterType=Enum.RaycastFilterType.Exclude
                        params.FilterDescendantsInstances=character and {character} or {}
                        local delta=head.Position-cam.CFrame.Position
                        local hit=Workspace:Raycast(cam.CFrame.Position,delta,params)
                        visible=hit==nil or hit.Instance:IsDescendantOf(model)
                    end
                    if visible then
                        best,bestDistance={player=pl,head=head,distance=distance},distance
                    end
                end
            end
        end
    end
    return best
end
local snapTarget=nil
local snapUntil=0
local function snapToMurderer()
    if not S.aimbot then return false end
    local target=nearestConfirmedMurderer(S.aimbotLOS,300)
    if not target then return false end
    snapTarget=target.head
    snapUntil=os.clock()+0.12
    local cam=Workspace.CurrentCamera
    if cam and snapTarget.Parent then cam.CFrame=CFrame.lookAt(cam.CFrame.Position,snapTarget.Position) end
    return true
end
local renderSnapName="AETHER_MM2_V6_SNAP"
RunService:BindToRenderStep(renderSnapName,Enum.RenderPriority.Camera.Value+2,function()
    if not App.alive then return end
    if snapTarget and os.clock()<snapUntil and snapTarget.Parent then
        local cam=Workspace.CurrentCamera
        if cam then cam.CFrame=CFrame.lookAt(cam.CFrame.Position,snapTarget.Position) end
    else snapTarget=nil end
end)

local aimCircle=make("Frame",gui,{
    Name="AimFOV",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(S.aimbotFov*2,S.aimbotFov*2),BackgroundTransparency=1,
    BorderSizePixel=0,ZIndex=7,Visible=false
})
radius(aimCircle,1000)
local aimStroke=make("UIStroke",aimCircle,{Color=WHITE,Transparency=.35,Thickness=1})
local aimTargetText=label(gui,"",12,RED,true)
aimTargetText.Name="SilentAimTarget"
aimTargetText.AnchorPoint=Vector2.new(.5,1)
aimTargetText.Size=UDim2.fromOffset(240,24)
aimTargetText.TextXAlignment=Enum.TextXAlignment.Center
aimTargetText.ZIndex=9
aimTargetText.Visible=false
local actionStatus=label(gui,"",13,WHITE,true)
actionStatus.AnchorPoint=Vector2.new(.5,0)
actionStatus.Position=UDim2.fromScale(.5,.2)
actionStatus.Size=UDim2.fromOffset(460,27)
actionStatus.TextXAlignment=Enum.TextXAlignment.Center
actionStatus.ZIndex=29
actionStatus.Visible=false
local function flashAction(message, color)
    actionStatus.Text=message
    actionStatus.TextColor3=color or WHITE
    actionStatus.Visible=true
    local thisMessage=message
    task.delay(1.3,function()
        if App.alive and actionStatus.Text==thisMessage then actionStatus.Visible=false end
    end)
end
local silentMark=make("Frame",gui,{
    Name="SilentMarker",AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(26,26),
    BackgroundTransparency=1,BorderSizePixel=0,ZIndex=9,Visible=false
})
radius(silentMark,1000)
make("UIStroke",silentMark,{Color=RED,Thickness=2,Transparency=.12})
local silentDot=make("Frame",silentMark,{
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),
    Size=UDim2.fromOffset(4,4),BackgroundColor3=RED,BorderSizePixel=0,ZIndex=10
})
radius(silentDot,100)
local function updateTargetPreviews(dt)
    local cam=Workspace.CurrentCamera
    if not cam then return end
    aimCircle.Visible=S.aimbot and S.aimbotShowCircle
    aimCircle.Size=UDim2.fromOffset(S.aimbotFov*2,S.aimbotFov*2)
    local candidate=nil
    if S.aimbot and not S.menu then
        candidate=validMurdererTarget(S.aimbotFov,S.aimbotLOS)
    end
    aimStroke.Color=candidate and GREEN or WHITE
    aimTargetText.Visible=false
    silentMark.Visible=false
    if S.silentAim and S.silentAimMarker then
        local target=validMurdererTarget(S.silentAimFov,S.silentAimLOS)
        if target then
            local screen=target.screen
            silentMark.Position=UDim2.fromOffset(screen.X,screen.Y)
            silentMark.Visible=true
            aimTargetText.Position=UDim2.fromOffset(screen.X,screen.Y-21)
            aimTargetText.Text="TARGET  •  "..target.player.DisplayName.."  [PREVIEW]"
            aimTargetText.Visible=true
        end
    end
end

local roleColors={MURDERER=RED,SHERIFF=BLUE,INNOCENT=GREEN,UNKNOWN=hex(185,185,188)}
local function removeEsp(player)
    local ent=App.entries[player]
    if ent then
        if ent.hl then ent.hl:Destroy() end
        if ent.bb then ent.bb:Destroy() end
    end
    App.entries[player]=nil
end
local function updateEsp()
    local closestDanger=math.huge
    for _,pl in ipairs(Players:GetPlayers()) do
        if pl~=me then
            local model=pl.Character
            local targetRoot=model and model:FindFirstChild("HumanoidRootPart")
            local head=model and model:FindFirstChild("Head")
            local h=model and model:FindFirstChildOfClass("Humanoid")
            local role=roleOf(pl)
            local distance=(rootPart and targetRoot) and (rootPart.Position-targetRoot.Position).Magnitude or math.huge
            if role=="MURDERER" and h and h.Health>0 and distance<closestDanger then closestDanger=distance end
            local visible=S.esp and model and targetRoot and head and h and h.Health>0 and distance<=S.espMax and (role~="UNKNOWN" or S.espUnknown)
            if not visible then removeEsp(pl) else
                local ent=App.entries[pl]
                if not ent or ent.model~=model then
                    removeEsp(pl)
                    local hl=make("Highlight",model,{Name="AETHER_LocalHighlight",Adornee=model,DepthMode=Enum.HighlightDepthMode.AlwaysOnTop,FillTransparency=.86,OutlineTransparency=.1})
                    local bb=make("BillboardGui",head,{Name="AETHER_RoleTag",Adornee=head,Size=UDim2.fromOffset(180,25),StudsOffsetWorldSpace=Vector3.new(0,2,0),AlwaysOnTop=true})
                    local t=label(bb,"",11,WHITE,true) t.Size=UDim2.fromScale(1,1) t.TextXAlignment=Enum.TextXAlignment.Center
                    ent={model=model,hl=hl,bb=bb,text=t}
                    App.entries[pl]=ent
                end
                local col=roleColors[role]
                ent.hl.FillColor=col ent.hl.OutlineColor=col
                ent.text.TextColor3=col
                local name=S.espNames and pl.DisplayName or role
                local suffix=S.espDistance and ("  ["..math.floor(distance).." studs]") or ""
                ent.text.Text=name.." / "..role..suffix
            end
        end
    end
    if S.proximity and closestDanger<S.proximityCritical then setDanger(2)
    elseif S.proximity and closestDanger<S.proximityWarning then setDanger(1)
    else setDanger(0) end
end
conn(Players.PlayerRemoving,removeEsp)

local currentTab="Characters"
local navButtons={}
local redraw
local function section(heading,desc)
    local card=radius(make("Frame",content,{Size=UDim2.new(1,-9,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=PANEL,ZIndex=13}),9)
    stroke(card,LINE)
    make("UIPadding",card,{PaddingTop=UDim.new(0,12),PaddingBottom=UDim.new(0,12),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
    make("UIListLayout",card,{Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})
    local headingLabel=label(card,heading,12,WHITE,true)
    headingLabel.Size=UDim2.new(1,0,0,24)
    if desc then
        local d=label(card,desc,10,MUTED)
        d.Size=UDim2.new(1,0,0,17)
    end
    return card
end
local function switch(card,text,key,onChanged)
    local row=make("TextButton",card,{Size=UDim2.new(1,0,0,37),BackgroundTransparency=1,Text="",AutoButtonColor=false})
    local name=label(row,text,11,WHITE)
    name.Position=UDim2.fromOffset(0,0) name.Size=UDim2.new(1,-62,1,0)
    local shell=radius(make("Frame",row,{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,0,.5,0),Size=UDim2.fromOffset(41,23),BackgroundColor3=S[key] and WHITE or hex(62,62,67)}),12)
    local knob=radius(make("Frame",shell,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(0,S[key] and 29 or 12,.5,0),Size=UDim2.fromOffset(17,17),BackgroundColor3=S[key] and BLACK or hex(145,145,148)}),9)
    tabConn(row.MouseButton1Click,function()
        S[key]=not S[key]
        tween(shell,.15,{BackgroundColor3=S[key] and WHITE or hex(62,62,67)})
        tween(knob,.15,{Position=UDim2.new(0,S[key] and 29 or 12,.5,0),BackgroundColor3=S[key] and BLACK or hex(145,145,148)})
        if onChanged then onChanged(S[key]) end
        updateHud() persist()
    end)
    return row
end
local function slider(card,text,key,lo,hi,changed)
    local row=make("Frame",card,{Size=UDim2.new(1,0,0,53),BackgroundTransparency=1})
    local n=label(row,text,11,WHITE) n.Size=UDim2.new(1,-100,0,20)
    local val=label(row,tostring(S[key]),11,MUTED,true) val.Size=UDim2.fromOffset(70,20) val.Position=UDim2.new(1,-70,0,0) val.TextXAlignment=Enum.TextXAlignment.Right
    local bar=radius(make("Frame",row,{Position=UDim2.new(0,2,0,34),Size=UDim2.new(1,-5,0,4),BackgroundColor3=hex(66,66,71)}),3)
    local fill=radius(make("Frame",bar,{Size=UDim2.new(math.clamp((S[key]-lo)/(hi-lo),0,1),0,1,0),BackgroundColor3=WHITE}),3)
    local active=false
    local function setAt(x)
        local ratio=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1)
        S[key]=math.floor((lo+ratio*(hi-lo))+.5)
        fill.Size=UDim2.new(ratio,0,1,0)
        val.Text=tostring(S[key])
        if changed then changed(S[key]) end
    end
    tabConn(bar.InputBegan,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 then active=true setAt(UIS:GetMouseLocation().X) end end)
    tabConn(UIS.InputChanged,function(input) if active and input.UserInputType==Enum.UserInputType.MouseMovement then setAt(UIS:GetMouseLocation().X) end end)
    tabConn(UIS.InputEnded,function(input) if active and input.UserInputType==Enum.UserInputType.MouseButton1 then active=false persist() end end)
end
local function action(card,text,fn)
    local b=button(card,text)
    b.Size=UDim2.new(1,0,0,35)
    tabConn(b.MouseButton1Click,fn)
    return b
end
local function note(card,text)
    local t=label(card,text,10,MUTED)
    t.TextWrapped=true t.TextYAlignment=Enum.TextYAlignment.Top
    t.Size=UDim2.new(1,0,0,40)
end
local awaiting=nil
local function setMenuShown(show)
    S.menu=show
    root.Visible=show
    persist()
end
local lastShot=0
local shotPending=false
local function assistedShot()
    if not S.silentAim or shotPending then return false end
    if os.clock()-lastShot<0.8 then return false end
    local target=nearestConfirmedMurderer(S.silentAimLOS,300)
    if not target or not target.head or not target.head.Parent then
        flashAction("NO VERIFIED MURDERER IN RANGE",RED)
        return false
    end
    if not character or not humanoid or humanoid.Health<=0 then return false end
    local gun=nil
    for _,item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            local name=item.Name:lower()
            if name:find("gun",1,true) or name:find("revolver",1,true) or name:find("pistol",1,true) then
                gun=item
                break
            end
        end
    end
    if not gun then
        flashAction("EQUIP YOUR GUN FIRST",RED)
        return false
    end
    local camera=Workspace.CurrentCamera
    if not camera then return false end
    lastShot=os.clock()
    shotPending=true
    local before=camera.CFrame
    local originalType=camera.CameraType
    local head=target.head
    -- Attempt a client-side camera-assisted shot. We cannot redirect server hits.
    -- Do not alter remotes, suppress server logic or pretend it is a silent hit.
    task.spawn(function()
        local ok,fired=pcall(function()
            if not App.alive or gun.Parent~=character or not head.Parent then return false end
            camera.CFrame=CFrame.lookAt(camera.CFrame.Position,head.Position)
            -- Render-step camera alignment gives camera-dependent weapon scripts a chance
            -- to read a new direction; MM2 weapon behavior is NOT verified.
            RunService.RenderStepped:Wait()
            if not App.alive or gun.Parent~=character or not head.Parent then return false end
            camera.CFrame=CFrame.lookAt(camera.CFrame.Position,head.Position)
            gun:Activate()
            return true
        end)
        -- Camera intentionally turns for a moment. Optionally restore former view.
        if S.shotCameraRestore and camera==Workspace.CurrentCamera and camera.CameraType==originalType then
            task.wait(0.07)
            if App.alive and camera==Workspace.CurrentCamera then
                camera.CFrame=before
            end
        end
        shotPending=false
        if App.alive then
            if ok and fired then
                flashAction("GUN ACTIVATED · HIT UNCONFIRMED",GREEN)
            elseif not ok then
                flashAction("WEAPON ACTIVATION FAILED",RED)
                warn("AETHER V6 gun activation error:",fired)
            else
                flashAction("SHOT CANCELLED",RED)
            end
        end
    end)
    return true
end

redraw=function()
    for _,c in ipairs(App.tabConnections) do pcall(function() c:Disconnect() end) end
    table.clear(App.tabConnections)
    for _,v in ipairs(content:GetChildren()) do v:Destroy() end
    make("UIListLayout",content,{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder})
    make("UIPadding",content,{PaddingBottom=UDim.new(0,8)})
    for name,b in pairs(navButtons) do
        tween(b,.12,{BackgroundColor3=(name==currentTab) and PANEL2 or hex(13,13,15)})
        b.TextColor3=(name==currentTab) and WHITE or MUTED
    end
    if currentTab=="Characters" then
        local c=section("3D CHARACTER GALLERY","Three stylized procedural preview models")
        for i,sk in ipairs(skins) do
            action(c,(i==S.previewIndex and "●  " or "○  ")..sk.name,function()
                S.previewIndex=i makeAvatar(i) persist() redraw()
            end)
        end
        switch(c,"Auto Rotate Preview","previewSpin")
        note(c,"Models are approximate 3D shapes, not imported mesh replicas. The preview does not replace avatars in MM2.")
    elseif currentTab=="Movement" then
        local c=section("INFINITE JUMP","Normal jump strength, only on separate Space presses")
        switch(c,"Infinite Jump","infiniteJump")
        slider(c,"Air jump cooldown (ms)","jumpCooldownMs",150,600)
        note(c,"Tap Space to jump normally. Release and press again in the air for the next normal-strength jump. Holding Space does not trigger air jumps or flight.")
        local d=section("WALK SPEED","Optional and off by default; no inherited hotkeys")
        switch(d,"Enable WalkSpeed", "speed",setSpeed)
        slider(d,"Speed Value","speedValue",16,35,function(v) if S.speed and humanoid then humanoid.WalkSpeed=v end updateHud() end)
        note(d,"Speed changes from the menu. You can set a new hotkey in Keybinds. The game server may override it.")
    elseif currentTab=="ESP" then
        local c=section("ROLE ESP","Only confirmed role data / visible equipment")
        switch(c,"Enable Highlight","esp",function(enabled) if not enabled then for pl in pairs(App.entries) do removeEsp(pl) end end end)
        switch(c,"Include UNKNOWN","espUnknown")
        switch(c,"Show Player Names","espNames")
        switch(c,"Show Distance (studs)","espDistance")
        slider(c,"Maximum Distance","espMax",40,350)
        note(c,"Red = confirmed murderer; blue = confirmed sheriff; green = confirmed innocent. Unknown roles remain UNKNOWN.")
        local d=section("PROXIMITY ALERT","Reactive red edge bars / warning")
        switch(d,"Killer Warning","proximity",function(on) if not on then setDanger(0) end end)
        slider(d,"Warning Distance","proximityWarning",25,75)
        slider(d,"Critical Distance","proximityCritical",5,24)
        slider(d,"Alert Sound Volume (%)","alertSoundVolume",0,100)
        local row=make("Frame",d,{Size=UDim2.new(1,0,0,48),BackgroundTransparency=1})
        local soundLabel=label(row,"Optional sound asset ID",10,MUTED)
        soundLabel.Size=UDim2.new(1,0,0,17)
        local soundInput=radius(make("TextBox",row,{
            Position=UDim2.fromOffset(0,20),Size=UDim2.new(1,0,0,27),BackgroundColor3=PANEL2,
            Text=S.alertSoundId,PlaceholderText="Enter an owned / permitted audio ID",PlaceholderColor3=MUTED,
            TextColor3=WHITE,TextSize=11,Font=Enum.Font.Gotham,ClearTextOnFocus=false
        }),5)
        tabConn(soundInput.FocusLost,function()
            S.alertSoundId=soundInput.Text:gsub("[^0-9]", "")
            persist()
        end)
        action(d,"Test 'БЛИЗКО!' warning",function() setDanger(2) task.delay(1.1,function() if App.alive then dangerState=-1 setDanger(0) end end) end)
    elseif currentTab=="Camera" then
        local c=section("CAMERA","Locally adjustable field of view")
        switch(c,"Custom Camera FOV","fov",function(on) if not on and Workspace.CurrentCamera and App.originalFov then Workspace.CurrentCamera.FieldOfView=App.originalFov end end)
        slider(c,"FOV","fovValue",50,110)
        switch(c,"Edge Glow at High FOV","edgeGlow")
        action(c,"Reset Camera FOV",function()
            S.fov=false if App.originalFov and Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView=App.originalFov end
            persist() redraw()
        end)
    elseif currentTab=="Visuals" then
        local c=section("CLIENT VISUALS","Reversible local post-processing")
        switch(c,"Soft Bloom","bloom",updateEffects)
        switch(c,"Color Correction","colorGrade",updateEffects)
        note(c,"These effects use Roblox Lighting and can be turned off without changing the map's server objects.")
    elseif currentTab=="Aim" then
        local c=section("INSTANT AIMBOT  /  Z","Press Z once to snap camera toward confirmed murderer")
        switch(c,"Enable Aimbot","aimbot")
        switch(c,"Line-of-Sight Check","aimbotLOS")
        switch(c,"Show Aim FOV Circle","aimbotShowCircle")
        slider(c,"Aim Circle (pixels)","aimbotFov",45,350)
        action(c,"Test Snap to Murderer",function()
            if not snapToMurderer() then flashAction("NO CONFIRMED TARGET",RED) end
        end)
        note(c,"Z snaps immediately, including toward an off-screen murderer if their role is confirmed and they are within 300 studs. No smoothing or RMB hold.")
        local d=section("R AIM + SHOT","Briefly aim toward verified murderer and attempt a shot")
        switch(d,"Enable R Aim + Shot","silentAim")
        switch(d,"Restore Camera After Shot","shotCameraRestore")
        switch(d,"Require Clear Line of Sight","silentAimLOS")
        switch(d,"Show Target Marker","silentAimMarker")
        slider(d,"Marker FOV (pixels)","silentAimFov",35,300)
        action(d,"Test R Aim + Shot",assistedShot)
        note(d,"R briefly turns the camera toward a verified murderer, triggers the equipped gun, and optionally restores your view. This is NOT Silent Aim. The MM2 server decides hits; no guaranteed kill.")
        local e=section("ROLE CONDITIONS","MM2 roles are not always available to clients")
        note(e,"Targets must have a visible knife or verified Role attribute. UNKNOWN roles are never guessed.")
    elseif currentTab=="Keybinds" then
        local c=section("V6 KEYBINDS","Ctrl opens the menu, Z snaps aim, R attempts assisted shot. Backspace clears optional binds.")
        for _,data in ipairs({{"menu","Open / Close Menu"},{"aim","Aimbot Snap"},{"silent","R Aim + Shot"},{"speed","Speed Toggle"}}) do
            local key,name=data[1],data[2]
            action(c,name.."   ["..(S.binds[key]~="" and S.binds[key] or "UNBOUND").."]",function()
                awaiting=key
                for _,x in ipairs(c:GetChildren()) do
                    if x:IsA("TextButton") and x.Text:find(name,1,true) then x.Text="Press a key..." end
                end
            end)
        end
        local d=section("ON-SCREEN HUD")
        switch(d,"Show Keybinds","keyHud")
        action(d,"Reset HUD Position",function() hud.Position=UDim2.fromOffset(18,115) S.keyHudX=18 S.keyHudY=115 persist() end)
    elseif currentTab=="Settings" then
        local c=section("APPEARANCE")
        slider(c,"UI Scale (%)","uiScalePct",65,120,function(v) -- value is percent in this tab
            S.uiScale=v/100 fitScale()
        end)
        switch(c,"Show Keybind HUD","keyHud")
        action(c,"Save Config",persist)
        action(c,"Unload / Restore",function() App.Destroy() end)
        note(c,"Settings stay in this Lua session. File persistence is optional and requires a compatible sandbox API.")
    end
end

local navData={{"Aim","◎"},{"ESP","▣"},{"Movement","↗"},{"Visuals","◈"},{"Camera","◉"},{"Characters","♙"},{"Keybinds","⌘"},{"Settings","⚙"}}
for i,item in ipairs(navData) do
    local name,glyph=item[1],item[2]
    local b=make("TextButton",nav,{Position=UDim2.fromOffset(12,73+(i-1)*53),Size=UDim2.fromOffset(46,43),BackgroundColor3=hex(13,13,15),Text=glyph,TextSize=22,Font=Enum.Font.GothamMedium,TextColor3=MUTED,AutoButtonColor=false,ZIndex=12})
    radius(b,9)
    navButtons[name]=b
    conn(b.MouseButton1Click,function() currentTab=name redraw() end)
end
redraw()
conn(close.MouseButton1Click,function() setMenuShown(false) end)
conn(min.MouseButton1Click,function() setMenuShown(false) end)

-- Fresh Space presses only: the key must go UP before another air jump.
-- Never create a held-Space flight loop or additive vertical velocity.
conn(UIS.InputBegan,function(input,gp)
    if not App.alive or UIS:GetFocusedTextBox() then return end
    local key=input.KeyCode
    if awaiting and key~=Enum.KeyCode.Unknown then
        -- Space is reserved for normal Roblox jumping and our extra air jumps.
        if key==Enum.KeyCode.Space then return end
        local newName=(key==Enum.KeyCode.Backspace and awaiting~="menu") and "" or key.Name
        if newName~="" then
            for name,other in pairs(S.binds) do
                if name~=awaiting and other==newName then S.binds[name]="" end
            end
        end
        S.binds[awaiting]=newName
        awaiting=nil persist() redraw() updateHud()
        return
    end
    if key.Name==S.binds.menu or (S.binds.menu=="LeftControl" and key==Enum.KeyCode.RightControl) then
        setMenuShown(not S.menu)
        return
    end
    if gp then return end
    if S.binds.speed~="" and key.Name==S.binds.speed then
        setSpeed(not S.speed) persist()
    elseif S.binds.aim~="" and key.Name==S.binds.aim and S.aimbot then
        if not snapToMurderer() then flashAction("NO CONFIRMED TARGET",RED) end
    elseif S.binds.silent~="" and key.Name==S.binds.silent and S.silentAim then
        assistedShot()
    elseif key==Enum.KeyCode.Space and not heldSpace then
        heldSpace=true
        -- Grounded presses remain ordinary Roblox jumps. A new press in the air
        -- requests exactly ONE extra jump using normal jump velocity (NOT added to it).
        if S.infiniteJump and humanoid and rootPart and humanoid.Health>0
            and humanoid.FloorMaterial==Enum.Material.Air
            and os.clock()-lastAir >= S.jumpCooldownMs/1000 then
            lastAir=os.clock()
            local current=rootPart.AssemblyLinearVelocity
            local gravity=math.max(Workspace.Gravity,1)
            local normalY=humanoid.UseJumpPower and humanoid.JumpPower
                or math.sqrt(2*gravity*math.max(humanoid.JumpHeight,0))
            if normalY>0 then
                -- Replace the vertical component, rather than stacking upward impulses.
                rootPart.AssemblyLinearVelocity=Vector3.new(current.X,normalY,current.Z)
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)
conn(UIS.InputEnded,function(input)
    if input.KeyCode==Enum.KeyCode.Space then heldSpace=false end
    if dragTarget and input.UserInputType==Enum.UserInputType.MouseButton1 then
        if App.dragDone and App.dragDone[dragTarget] then App.dragDone[dragTarget]() persist() end
        dragTarget=nil
    end
end)
conn(UIS.InputChanged,function(input)
    if dragTarget and input.UserInputType==Enum.UserInputType.MouseMovement then
        local delta=UIS:GetMouseLocation()-dragStart
        dragTarget.Position=UDim2.new(posStart.X.Scale,posStart.X.Offset+delta.X,posStart.Y.Scale,posStart.Y.Offset+delta.Y)
    end
end)

local elapsed=0
local previewTick=0
conn(RunService.RenderStepped,function(dt)
    if not App.alive then return end
    updateTargetPreviews(dt)
end)
conn(RunService.Heartbeat,function(dt)
    if not App.alive then return end
    local cam=Workspace.CurrentCamera
    if cam and not App.originalFov then App.originalFov=cam.FieldOfView end
    if cam and S.fov then cam.FieldOfView=cam.FieldOfView+(S.fovValue-cam.FieldOfView)*math.min(dt*10,1) end
    elapsed=elapsed+dt
    if elapsed>=.22 then elapsed=0 updateEsp() refreshFovGlow() end
    previewTick=previewTick+dt
    if avatar and S.previewSpin and previewTick>=.035 then
        angle=angle+previewTick*.35
        avatar:PivotTo(CFrame.Angles(0,angle,0))
        previewTick=0
    end
end)

function App.Destroy()
    if not App.alive then return end
    App.alive=false
    pcall(function() RunService:UnbindFromRenderStep(renderSnapName) end)
    for _,c in ipairs(App.connections) do pcall(function() c:Disconnect() end) end
    for _,c in ipairs(App.tabConnections) do pcall(function() c:Disconnect() end) end
    for pl in pairs(App.entries) do removeEsp(pl) end
    if humanoid and humanoid.Parent and App.originalWalk then pcall(function() humanoid.WalkSpeed=App.originalWalk end) end
    if Workspace.CurrentCamera and App.originalFov then pcall(function() Workspace.CurrentCamera.FieldOfView=App.originalFov end) end
    for _,eff in pairs(effects) do if eff then eff:Destroy() end end
    gui:Destroy()
    sound:Destroy()
    if _G.AETHER_MM2_V6==App then _G.AETHER_MM2_V6=nil end
end

print("AETHER MM2 V6 loaded — CTRL menu | Z snap | R assisted shot (NOT guaranteed) | No BunnyHop")
