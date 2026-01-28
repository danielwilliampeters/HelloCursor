-- HelloCursor: cursor ring addon (Retail)

local ADDON_NAME = ...
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

HelloCursorDB = HelloCursorDB or {}

-- ---------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------

local DEFAULTS = {
  enabled = true,

  -- Colour
  colorHex = "FF4FD8",      -- RRGGBB or AARRGGBB
  useClassColor = false,    -- when true, ignores colorHex for RGB

  -- Ring size (logical size; snapped to authored assets)
  size = 96,

  -- Visibility rules
  showWorld = true,
  showPvE = true,           -- dungeons / delves / raids
  showPvP = true,           -- battlegrounds / arena
  showInCombat = true,      -- override: show anywhere while in combat

  -- Menus
  hideInMenus = true,      -- when true, hide the ring while game menus are open

  -- Behaviour
  reactiveCursor = true,    -- crossfade to small ring while mouselooking

  -- GCD pop (end-of-global-cooldown pulse)
  showGCDSpinner = false,   -- when true, play a pop animation at the end of the GCD
}

-- Authored ring sizes (constant stroke thickness per asset)
local RING_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\ring_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\ring_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\ring_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\ring_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\ring_128.tga",
}

local RING_SMALL_TEX_BY_SIZE = {
  [64]  = "Interface\\AddOns\\HelloCursor\\ring_small_64.tga",
  [80]  = "Interface\\AddOns\\HelloCursor\\ring_small_80.tga",
  [96]  = "Interface\\AddOns\\HelloCursor\\ring_small_96.tga",
  [112] = "Interface\\AddOns\\HelloCursor\\ring_small_112.tga",
  [128] = "Interface\\AddOns\\HelloCursor\\ring_small_128.tga",
}

-- ---------------------------------------------------------------------
-- Tunables
-- ---------------------------------------------------------------------

local TWEEN_DURATION = 0.08
local GCD_SPELL_ID = 61304 -- "Global Cooldown"
local GCD_POP_CHECK_INTERVAL = 0.02 -- legacy; no longer used for throttling, kept for backwards compat

-- Pop at end of GCD (a quick scale pulse on the ring frame)
local GCD_POP_ENABLED   = true
local GCD_POP_SCALE     = 1.16
local GCD_POP_UP_TIME   = 0.045
local GCD_POP_DOWN_TIME = 0.075

-- Fixed canvas so ring thickness never scales (textures are authored for this)
local RING_CANVAS_SIZE = 128

-- ---------------------------------------------------------------------
-- Small utils
-- ---------------------------------------------------------------------

local function CopyDefaults(dst, src)
  if type(dst) ~= "table" then dst = {} end
  for k, v in pairs(src) do
    if dst[k] == nil then dst[k] = v end
  end
  return dst
end

local function Clamp(n, lo, hi)
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

local function Lerp(a, b, t) return a + (b - a) * t end
local function EaseInOut(t)
  if t < 0 then t = 0 elseif t > 1 then t = 1 end
  return t * t * (3 - 2 * t)
end

local function NormalizeHex(hex)
  if not hex then return nil end
  hex = tostring(hex):gsub("%s+", ""):gsub("#", ""):upper()
  if (#hex == 6 or #hex == 8) and hex:match("^[0-9A-F]+$") then
    return hex
  end
  return nil
end

local function HexToRGBA(hex)
  hex = NormalizeHex(hex) or DEFAULTS.colorHex

  if #hex == 6 then
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 79
    local b = tonumber(hex:sub(5, 6), 16) or 216
    return r / 255, g / 255, b / 255, 1
  else
    local a = tonumber(hex:sub(1, 2), 16) or 255
    local r = tonumber(hex:sub(3, 4), 16) or 255
    local g = tonumber(hex:sub(5, 6), 16) or 79
    local b = tonumber(hex:sub(7, 8), 16) or 216
    return r / 255, g / 255, b / 255, a / 255
  end
end

local function RGBAtoHex(r, g, b)
  r = Clamp(math.floor((r or 1) * 255 + 0.5), 0, 255)
  g = Clamp(math.floor((g or 0) * 255 + 0.5), 0, 255)
  b = Clamp(math.floor((b or 1) * 255 + 0.5), 0, 255)
  return string.format("%02X%02X%02X", r, g, b)
end

local function SafeSetTexture(tex, path, fallback)
  local ok = tex:SetTexture(path)
  if not ok and fallback then
    tex:SetTexture(fallback)
  end
end

local function NearestKey(map, target)
  local bestKey, bestDist
  for k in pairs(map) do
    local d = math.abs(k - target)
    if not bestDist or d < bestDist then
      bestDist, bestKey = d, k
    end
  end
  return bestKey
end

local function GetSpellCooldownCompat(spellID)
  if C_Spell and C_Spell.GetSpellCooldown then
    local info = C_Spell.GetSpellCooldown(spellID)
    if info then
      local startTime = info.startTime or 0
      local duration  = info.duration or 0
      local enabled   = info.isEnabled
      if enabled == nil then enabled = true end
      return startTime, duration, enabled and 1 or 0
    end
  end

  if GetSpellCooldown then
    local startTime, duration, enabled = GetSpellCooldown(spellID)
    return startTime or 0, duration or 0, enabled or 0
  end

  return 0, 0, 0
end

-- ---------------------------------------------------------------------
-- Visibility rules
-- ---------------------------------------------------------------------

local function IsAnyMenuOpen()
  -- Main ESC menu
  if GameMenuFrame and GameMenuFrame:IsShown() then return true end

  -- Dragonflight settings panel
  if SettingsPanel and SettingsPanel:IsShown() then return true end

  -- Older options frames (still present on some clients)
  if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then return true end
  if VideoOptionsFrame and VideoOptionsFrame:IsShown() then return true end
  if AudioOptionsFrame and AudioOptionsFrame:IsShown() then return true end

  return false
end

local function IsAllowedInZone()
  if HelloCursorDB.showInCombat and UnitAffectingCombat("player") then
    return true
  end

  local inInstance, instanceType = IsInInstance()
  if not inInstance then
    return HelloCursorDB.showWorld
  end

  if instanceType == "pvp" or instanceType == "arena" then
    return HelloCursorDB.showPvP
  end

  return HelloCursorDB.showPvE
end

local function ShouldShowRing()
  if not HelloCursorDB.enabled then
    return false
  end

  if HelloCursorDB.hideInMenus and IsAnyMenuOpen() then
    return false
  end

  return IsAllowedInZone()
end

-- ---------------------------------------------------------------------
-- Frame + textures
-- ---------------------------------------------------------------------

local ringFrame = CreateFrame("Frame", "HelloCursorFrame", UIParent)
ringFrame:SetFrameStrata("TOOLTIP")
ringFrame:SetSize(RING_CANVAS_SIZE, RING_CANVAS_SIZE)
ringFrame:Hide()

local ringTexNormal = ringFrame:CreateTexture(nil, "OVERLAY")
ringTexNormal:SetAllPoints(true)

local ringTexSmall = ringFrame:CreateTexture(nil, "OVERLAY")
ringTexSmall:SetAllPoints(true)

-- Initial textures (overridden by RefreshSize)
SafeSetTexture(ringTexNormal, RING_TEX_BY_SIZE[96], nil)
SafeSetTexture(ringTexSmall,  RING_SMALL_TEX_BY_SIZE[96], RING_TEX_BY_SIZE[96])

-- GCD spinners (normal + small), crossfaded like the ring
local gcdSpinnerNormal = CreateFrame("Cooldown", nil, ringFrame, "CooldownFrameTemplate")
gcdSpinnerNormal:SetAllPoints(true)
gcdSpinnerNormal:SetFrameLevel(ringFrame:GetFrameLevel() + 5)
gcdSpinnerNormal:Hide()

local gcdSpinnerSmall = CreateFrame("Cooldown", nil, ringFrame, "CooldownFrameTemplate")
gcdSpinnerSmall:SetAllPoints(true)
gcdSpinnerSmall:SetFrameLevel(ringFrame:GetFrameLevel() + 5)
gcdSpinnerSmall:Hide()

local function SetupSpinner(f)
  if f.SetHideCountdownNumbers then f:SetHideCountdownNumbers(true) end
  if f.SetDrawBling then f:SetDrawBling(false) end
  if f.SetDrawEdge then f:SetDrawEdge(false) end
end

SetupSpinner(gcdSpinnerNormal)
SetupSpinner(gcdSpinnerSmall)
if gcdSpinnerNormal.SetSwipeTexture then
  gcdSpinnerNormal:SetSwipeTexture(RING_TEX_BY_SIZE[96])
end
if gcdSpinnerSmall.SetSwipeTexture then
  gcdSpinnerSmall:SetSwipeTexture(RING_SMALL_TEX_BY_SIZE[96])
end

-- ---------------------------------------------------------------------
-- Colour (class colour or hex)
-- ---------------------------------------------------------------------

local function GetPlayerClassRGB()
  local _, classFile = UnitClass("player")
  classFile = classFile or "PRIEST"

  if C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFile)
    if c and c.GetRGB then
      return c:GetRGB()
    elseif c and c.r then
      return c.r, c.g, c.b
    end
  end

  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
    local c = RAID_CLASS_COLORS[classFile]
    return c.r, c.g, c.b
  end

  if GetClassColor then
    local r, g, b = GetClassColor(classFile)
    return r, g, b
  end

  return 1, 1, 1
end

local lastTintKey = nil

local function ComputeTint()
  if HelloCursorDB.useClassColor then
    local r, g, b = GetPlayerClassRGB()
    return r, g, b, 1, ("class:%0.4f:%0.4f:%0.4f"):format(r, g, b)
  end

  local r, g, b, a = HexToRGBA(HelloCursorDB.colorHex)
  return r, g, b, a, ("hex:%s"):format(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
end

local function ApplyTintIfNeeded(force)
  local r, g, b, a, key = ComputeTint()
  if force or key ~= lastTintKey then
    ringTexNormal:SetVertexColor(r, g, b, a)
    ringTexSmall:SetVertexColor(r, g, b, a)
    if gcdSpinnerNormal and gcdSpinnerNormal.SetSwipeColor then
      gcdSpinnerNormal:SetSwipeColor(r, g, b, a or 1)
    end
    if gcdSpinnerSmall and gcdSpinnerSmall.SetSwipeColor then
      gcdSpinnerSmall:SetSwipeColor(r, g, b, a or 1)
    end
    lastTintKey = key
  end
end

-- ---------------------------------------------------------------------
-- Crossfade state
-- ---------------------------------------------------------------------

local currentMix = 0
local WantsSmallRing -- forward decl
local SetMix         -- forward decl

local lastTexKey = 96
local lastGCDRemaining = 0
local lastGCDBusy = false
local gcdVisualActive = false -- when true, spinner replaces the ring visuals

-- ---------------------------------------------------------------------
-- GCD end pop
-- ---------------------------------------------------------------------

local gcdPopAnim = ringFrame:CreateAnimationGroup()

local popUp = gcdPopAnim:CreateAnimation("Scale")
popUp:SetOrder(1)
if popUp.SetScaleFrom then popUp:SetScaleFrom(1, 1) end
popUp:SetScale(GCD_POP_SCALE, GCD_POP_SCALE)
popUp:SetDuration(GCD_POP_UP_TIME)
popUp:SetSmoothing("OUT")

local popDown = gcdPopAnim:CreateAnimation("Scale")
popDown:SetOrder(2)
if popDown.SetScaleFrom then popDown:SetScaleFrom(GCD_POP_SCALE, GCD_POP_SCALE) end
popDown:SetScale(1, 1)
popDown:SetDuration(GCD_POP_DOWN_TIME)
popDown:SetSmoothing("IN")

local function TriggerGCDPop()
  if not GCD_POP_ENABLED then return end
  if not ringFrame:IsShown() then return end
  if not HelloCursorDB.showGCDSpinner then return end

  if gcdPopAnim:IsPlaying() then
    gcdPopAnim:Stop()
  end
  gcdPopAnim:Play()
end

local function CheckGCDPop()
  if not HelloCursorDB.showGCDSpinner then
    return
  end

  local now = GetTime()
  local startTime, duration, enabled = GetSpellCooldownCompat(GCD_SPELL_ID)
  local gcdActive = false
  local remaining = 0

  if enabled ~= 0 and duration and duration > 0 and startTime and startTime > 0 then
    remaining = (startTime + duration) - now
    gcdActive = remaining > 0
  end

  -- Case 1: GCD was busy and now became idle -> pop.
  if lastGCDBusy and (not gcdActive) then
    TriggerGCDPop()
  end

  -- Case 2: GCD stayed busy but remaining jumped up (new GCD started
  -- while the previous one finished in between samples, e.g. via spell queue).
  if lastGCDBusy and gcdActive and (remaining > lastGCDRemaining + 0.02) then
    TriggerGCDPop()
  end

  -- Spinner / ring base visibility
  local wantSpinner = HelloCursorDB.showGCDSpinner and gcdActive

  if wantSpinner then
    if gcdSpinnerNormal and gcdSpinnerNormal.SetCooldown then
      gcdSpinnerNormal:SetCooldown(startTime, duration)
      gcdSpinnerNormal:Show()
    end
    if gcdSpinnerSmall and gcdSpinnerSmall.SetCooldown then
      gcdSpinnerSmall:SetCooldown(startTime, duration)
      gcdSpinnerSmall:Show()
    end
  else
    if gcdSpinnerNormal then gcdSpinnerNormal:Hide() end
    if gcdSpinnerSmall then gcdSpinnerSmall:Hide() end
  end

  gcdVisualActive = wantSpinner

  if not gcdVisualActive then
    -- restore ring visuals according to the current mix
    SetMix(currentMix)
  else
    -- ensure the base ring is hidden so the spinner fully replaces it
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(0)
  end

  lastGCDBusy = gcdActive
  lastGCDRemaining = remaining
end

-- ---------------------------------------------------------------------
-- Crossfade tween (normal <-> small)
-- mix: 0 = normal, 1 = small
-- ---------------------------------------------------------------------

local tweenActive = false
local tweenStart = 0
local tweenFrom = 0
local tweenTo = 0

local function StopTween() tweenActive = false end
local function StartTween(fromMix, toMix)
  tweenActive = true
  tweenStart = GetTime()
  tweenFrom = fromMix
  tweenTo = toMix
end

SetMix = function(mix)
  mix = Clamp(mix, 0, 1)
  currentMix = mix

  -- Never hard-hide textures. Alpha-only = no flicker.
  ringTexNormal:Show()
  ringTexSmall:Show()

  if gcdVisualActive then
    -- While the GCD spinner is visually active, keep the base ring
    -- fully hidden so the spinner "replaces" it, and crossfade
    -- between the normal/small spinner visuals using the same mix.
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(0)

    if gcdSpinnerNormal then
      if mix <= 0.0001 then
        gcdSpinnerNormal:SetAlpha(1)
      elseif mix >= 0.9999 then
        gcdSpinnerNormal:SetAlpha(0)
      else
        gcdSpinnerNormal:SetAlpha(1 - mix)
      end
    end

    if gcdSpinnerSmall then
      if mix <= 0.0001 then
        gcdSpinnerSmall:SetAlpha(0)
      elseif mix >= 0.9999 then
        gcdSpinnerSmall:SetAlpha(1)
      else
        gcdSpinnerSmall:SetAlpha(mix)
      end
    end

    return
  end

  if mix <= 0.0001 then
    ringTexNormal:SetAlpha(1)
    ringTexSmall:SetAlpha(0)
  elseif mix >= 0.9999 then
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(1)
  else
    ringTexNormal:SetAlpha(1 - mix)
    ringTexSmall:SetAlpha(mix)
  end

  if SetSpinnerMix then
    -- legacy no-op; spinner visuals removed
  end
end

WantsSmallRing = function()
  if not HelloCursorDB.reactiveCursor then return false end
  return (IsMouselooking and IsMouselooking()) and true or false
end

local function SnapToTargetMix()
  SetMix(WantsSmallRing() and 1 or 0)
end

-- ---------------------------------------------------------------------
-- Cursor anchoring (freeze on mouselook start)
-- ---------------------------------------------------------------------

local lastCursorX, lastCursorY = nil, nil
local wasMouselooking = false
local CURSOR_OFFSET_X = 0
local CURSOR_OFFSET_Y = 0

local function CaptureCursorNow()
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  lastCursorX, lastCursorY = (cx / scale), (cy / scale)
end

local function UpdateRingPosition()
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale

  local mouselooking = (IsMouselooking and IsMouselooking()) and true or false

  if not mouselooking then
    lastCursorX, lastCursorY = cx, cy
  elseif not wasMouselooking then
    if not lastCursorX or not lastCursorY then
      lastCursorX, lastCursorY = cx, cy
    end
  end

  wasMouselooking = mouselooking

  local x = (lastCursorX or cx) + CURSOR_OFFSET_X
  local y = (lastCursorY or cy) + CURSOR_OFFSET_Y

  ringFrame:ClearAllPoints()
  ringFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
end

-- Capture cursor before mouselook clamps it
if WorldFrame and WorldFrame.HookScript then
  WorldFrame:HookScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      CaptureCursorNow()
    end
  end)
end

-- ---------------------------------------------------------------------
-- Visual refresh helpers
-- ---------------------------------------------------------------------

local function RefreshSize()
  local size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)
  HelloCursorDB.size = size

  -- fixed canvas size so ring thickness never scales
  ringFrame:SetSize(RING_CANVAS_SIZE, RING_CANVAS_SIZE)

  local key = NearestKey(RING_TEX_BY_SIZE, size) or 96
  if key == lastTexKey then return end

  -- update ring textures
  SafeSetTexture(ringTexNormal, RING_TEX_BY_SIZE[key], RING_TEX_BY_SIZE[96])
  SafeSetTexture(ringTexSmall,  RING_SMALL_TEX_BY_SIZE[key], RING_SMALL_TEX_BY_SIZE[96])

  -- update spinner swipe textures to match the current ring size
  if gcdSpinnerNormal and gcdSpinnerNormal.SetSwipeTexture then
    gcdSpinnerNormal:SetSwipeTexture(RING_TEX_BY_SIZE[key])
  end
  if gcdSpinnerSmall and gcdSpinnerSmall.SetSwipeTexture then
    gcdSpinnerSmall:SetSwipeTexture(RING_SMALL_TEX_BY_SIZE[key] or RING_TEX_BY_SIZE[key])
  end

  lastTexKey = key

  ApplyTintIfNeeded(true)

  -- re-apply current mix against new textures
  if SetMix then
    SetMix(currentMix)
  end
end

local function RefreshVisualsImmediate()
  StopTween()
  RefreshSize()
  ApplyTintIfNeeded(true)
  SnapToTargetMix()
end

local function UpdateVisibility()
  if ShouldShowRing() then
    if (IsMouselooking and IsMouselooking()) and (not lastCursorX or not lastCursorY) then
      CaptureCursorNow()
    end
    ringFrame:Show()
  else
    ringFrame:Hide()
  end
end

-- Always-on driver to re-evaluate visibility each frame so that
-- menu open/close and zone changes immediately affect the ring
-- without relying solely on game events. This frame itself is
-- never hidden, unlike the ring frame.
local visibilityDriver = CreateFrame("Frame")
visibilityDriver:SetScript("OnUpdate", function()
  UpdateVisibility()
end)

-- ---------------------------------------------------------------------
-- OnUpdate loop
-- ---------------------------------------------------------------------

ringFrame:SetScript("OnUpdate", function()
  if not ringFrame:IsShown() then return end

  local targetMix = WantsSmallRing() and 1 or 0
  if tweenActive then
    local t = (GetTime() - tweenStart) / TWEEN_DURATION
    if t >= 1 then
      StopTween()
      SetMix(tweenTo)
    else
      SetMix(Lerp(tweenFrom, tweenTo, EaseInOut(t)))
    end
  else
    if math.abs(currentMix - targetMix) > 0.001 then
      StartTween(currentMix, targetMix)
    else
      SetMix(targetMix)
    end
  end

  -- Only detect end-of-GCD to fire the pop (no brighten logic here)
  CheckGCDPop()

  UpdateRingPosition()
end)

-- ---------------------------------------------------------------------
-- Settings UI (left functionally identical; only minimal tidy-ups)
-- ---------------------------------------------------------------------

local hexEditBox
local pickBtnRef
local cbClassRef

local cbWorldRef, cbPvERef, cbPvPRef, cbCombatRef, cbReactiveRef
local cbGCDRef, cbHideMenusRef

local sizeSliderRef
local sizeValueRef

local function GetPickerWidget()
  if not ColorPickerFrame then return nil end
  if ColorPickerFrame.GetColorRGB and ColorPickerFrame.SetColorRGB then
    return ColorPickerFrame
  end
  if ColorPickerFrame.Content and ColorPickerFrame.Content.ColorPicker
    and ColorPickerFrame.Content.ColorPicker.GetColorRGB
    and ColorPickerFrame.Content.ColorPicker.SetColorRGB then
    return ColorPickerFrame.Content.ColorPicker
  end
  return nil
end

local function RefreshColourUIEnabledState()
  local enabled = not HelloCursorDB.useClassColor
  if pickBtnRef then pickBtnRef:SetEnabled(enabled) end
  if hexEditBox then
    hexEditBox:SetEnabled(enabled)
    hexEditBox:SetAlpha(enabled and 1 or 0.5)
  end
end

local function RefreshOptionsUI()
  if cbWorldRef then cbWorldRef:SetChecked(HelloCursorDB.showWorld and true or false) end
  if cbPvERef then cbPvERef:SetChecked(HelloCursorDB.showPvE and true or false) end
  if cbPvPRef then cbPvPRef:SetChecked(HelloCursorDB.showPvP and true or false) end
  if cbCombatRef then cbCombatRef:SetChecked(HelloCursorDB.showInCombat and true or false) end
  if cbReactiveRef then cbReactiveRef:SetChecked(HelloCursorDB.reactiveCursor and true or false) end
  if cbGCDRef then cbGCDRef:SetChecked(HelloCursorDB.showGCDSpinner and true or false) end
  if cbHideMenusRef then cbHideMenusRef:SetChecked(HelloCursorDB.hideInMenus and true or false) end
  if cbClassRef then cbClassRef:SetChecked(HelloCursorDB.useClassColor and true or false) end

  if hexEditBox then
    hexEditBox:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
  end

  if sizeSliderRef then
    local v = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 64, 128)
    local snappedKey = NearestKey(RING_TEX_BY_SIZE, v) or 96
    sizeSliderRef:SetValue(snappedKey)
  end

  RefreshColourUIEnabledState()
end

local function SetColorHex(hex)
  local norm = NormalizeHex(hex)
  if not norm then return end
  HelloCursorDB.colorHex = norm
  ApplyTintIfNeeded(true)
  if hexEditBox then hexEditBox:SetText(norm) end
end

local function OpenColorPicker()
  if HelloCursorDB.useClassColor then return end

  local picker = GetPickerWidget()
  if not picker then
    print("HelloCursor: Color picker not available on this client.")
    return
  end

  local r, g, b = HexToRGBA(HelloCursorDB.colorHex)
  local prevHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex

  local function ApplyFromPicker()
    local nr, ng, nb = picker:GetColorRGB()
    SetColorHex(RGBAtoHex(nr, ng, nb))
  end

  local function CancelToPrev()
    SetColorHex(prevHex)
  end

  ColorPickerFrame.hasOpacity = false
  ColorPickerFrame.opacity = 0
  ColorPickerFrame.previousValues = { r = r, g = g, b = b, opacity = 0 }

  ColorPickerFrame.swatchFunc = ApplyFromPicker
  ColorPickerFrame.func = ApplyFromPicker
  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.cancelFunc = CancelToPrev

  picker:SetColorRGB(r, g, b)
  ColorPickerFrame:Show()
end

local function ResetToDefaults()
  for k, v in pairs(DEFAULTS) do
    HelloCursorDB[k] = v
  end
  HelloCursorDB.colorHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex
  HelloCursorDB.size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 16, 256)

  RefreshVisualsImmediate()
  UpdateVisibility()
  RefreshOptionsUI()
end

local function CreateSettingsPanel()
  if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end

  local panel = CreateFrame("Frame")
  panel.name = "HelloCursor"

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

  local content = CreateFrame("Frame", nil, scrollFrame)
  scrollFrame:SetScrollChild(content)

  content:SetSize(560, 1)
  content:SetPoint("TOPLEFT", 0, 0)
  content:SetPoint("TOPRIGHT", 0, 0)

  local function UpdateContentHeight(lastWidget, bottomPadding)
    bottomPadding = bottomPadding or 24
    if not lastWidget then
      content:SetHeight(1)
      return
    end

    local top = content:GetTop()
    local bottom = lastWidget:GetBottom()
    if not top or not bottom then return end

    local h = (top - bottom) + bottomPadding
    if h < 1 then h = 1 end
    content:SetHeight(h)
  end

  local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("HelloCursor")

  local subtitle = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  subtitle:SetText("Cursor ring settings")

  local function MakeHeader(text, anchor, yOff)
    local h = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    h:SetText(text)
    return h
  end

  local function MakeCheckbox(label, get, set, anchor, yOff, onChange)
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)

    if cb.Text then
      cb.Text:SetText(label)
    else
      local t = _G[cb:GetName() .. "Text"]
      if t then t:SetText(label) end
    end

    cb:SetScript("OnShow", function()
      cb:SetChecked(get() and true or false)
    end)

    cb:SetScript("OnClick", function(self)
      set(self:GetChecked() and true or false)
      if onChange then onChange() end
      UpdateVisibility()
    end)

    return cb
  end

  local function MakeSeparator(anchor, yOff)
    local sep = content:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -16, yOff)
    sep:SetSize(560, 1)
    sep:SetColorTexture(0.25, 0.25, 0.25, 0.8)
    return sep
  end

  -- Visibility
  local visHeader = MakeHeader("Visibility", subtitle, -18)

  cbWorldRef = MakeCheckbox(
    "Show in world",
    function() return HelloCursorDB.showWorld end,
    function(v) HelloCursorDB.showWorld = v end,
    visHeader, -10
  )

  cbPvERef = MakeCheckbox(
    "Show in dungeons / delves / raids",
    function() return HelloCursorDB.showPvE end,
    function(v) HelloCursorDB.showPvE = v end,
    cbWorldRef, -10
  )

  cbPvPRef = MakeCheckbox(
    "Show in battlegrounds / arena",
    function() return HelloCursorDB.showPvP end,
    function(v) HelloCursorDB.showPvP = v end,
    cbPvERef, -10
  )

  cbCombatRef = MakeCheckbox(
    "Show in combat",
    function() return HelloCursorDB.showInCombat end,
    function(v) HelloCursorDB.showInCombat = v end,
    cbPvPRef, -10
  )

  MakeSeparator(cbCombatRef, -14)

  -- Behaviour
  local behHeader = MakeHeader("Behaviour", cbCombatRef, -26)

  cbReactiveRef = MakeCheckbox(
    "Reactive cursor (shrink while holding RMB)",
    function() return HelloCursorDB.reactiveCursor end,
    function(v) HelloCursorDB.reactiveCursor = v end,
    behHeader, -10,
    function()
      StopTween()
      SnapToTargetMix()
    end
  )

  cbGCDRef = MakeCheckbox(
    "Global cooldown (GCD) animation",
    function() return HelloCursorDB.showGCDSpinner end,
    function(v) HelloCursorDB.showGCDSpinner = v end,
    cbReactiveRef, -10,
    function()
      ApplyTintIfNeeded(true)
    end
  )

  cbHideMenusRef = MakeCheckbox(
    "Hide ring while game menus are open",
    function() return HelloCursorDB.hideInMenus end,
    function(v) HelloCursorDB.hideInMenus = v end,
    cbGCDRef, -10,
    function()
      UpdateVisibility()
    end
  )

  MakeSeparator(cbHideMenusRef, -14)

  -- Appearance
  local appearanceHeader = MakeHeader("Appearance", cbHideMenusRef, -26)

  local sizeLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  sizeLabel:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", 0, -12)
  sizeLabel:SetText("Ring size")

  sizeSliderRef = CreateFrame("Slider", "HelloCursorSizeSlider", content, "OptionsSliderTemplate")
  sizeSliderRef:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -8)
  sizeSliderRef:SetWidth(260)
  sizeSliderRef:SetMinMaxValues(64, 128)
  sizeSliderRef:SetValueStep(16)
  sizeSliderRef:SetObeyStepOnDrag(true)

  do
    local sliderName = sizeSliderRef:GetName()
    if sliderName then
      local low  = _G[sliderName .. "Low"]
      local high = _G[sliderName .. "High"]
      local text = _G[sliderName .. "Text"]
      if low  then low:SetText("64") end
      if high then high:SetText("128") end
      if text then text:SetText("") end
    end
  end

  local sliderLock = false
  sizeSliderRef:SetScript("OnValueChanged", function(self, value)
    if sliderLock then return end

    value = tonumber(value) or DEFAULTS.size
    local snappedKey = NearestKey(RING_TEX_BY_SIZE, value) or 96

    sliderLock = true
    self:SetValue(snappedKey)
    sliderLock = false

    HelloCursorDB.size = snappedKey

    RefreshSize()
    UpdateRingPosition()
  end)

  cbClassRef = MakeCheckbox(
    "Use class colour",
    function() return HelloCursorDB.useClassColor end,
    function(v) HelloCursorDB.useClassColor = v end,
    sizeSliderRef, -16,
    function()
      ApplyTintIfNeeded(true)
      RefreshColourUIEnabledState()
    end
  )

  local colorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  colorLabel:SetPoint("TOPLEFT", cbClassRef, "BOTTOMLEFT", 0, -10)
  colorLabel:SetText("Ring colour")

  pickBtnRef = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  pickBtnRef:SetSize(120, 22)
  pickBtnRef:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -6)
  pickBtnRef:SetText("Pick colour...")
  pickBtnRef:SetScript("OnClick", OpenColorPicker)

  local hexLabel = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hexLabel:SetPoint("LEFT", pickBtnRef, "RIGHT", 10, 0)
  hexLabel:SetText("Hex")

  hexEditBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
  hexEditBox:SetSize(110, 22)
  hexEditBox:SetPoint("LEFT", hexLabel, "RIGHT", 8, 0)
  hexEditBox:SetAutoFocus(false)

  hexEditBox:SetScript("OnShow", function(self)
    self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
    RefreshColourUIEnabledState()
  end)

  hexEditBox:SetScript("OnEnterPressed", function(self)
    if HelloCursorDB.useClassColor then
      self:ClearFocus()
      return
    end

    local typed = self:GetText()
    local norm = NormalizeHex(typed)
    if norm then
      SetColorHex(norm)
    else
      self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
    end
    self:ClearFocus()
  end)

  hexEditBox:SetScript("OnEscapePressed", function(self)
    self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
    self:ClearFocus()
  end)

  local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", pickBtnRef, "BOTTOMLEFT", 0, -6)
  hint:SetText("Use RRGGBB (example: FF4FD8). Class colour disables picker & hex.")
  hint:SetTextColor(0.75, 0.75, 0.75)

  MakeSeparator(hint, -14)

  -- Utilities
  local utilHeader = MakeHeader("Utilities", hint, -26)

  local defaultsBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  defaultsBtn:SetSize(140, 22)
  defaultsBtn:SetPoint("TOPLEFT", utilHeader, "BOTTOMLEFT", 0, -10)
  defaultsBtn:SetText("Reset to defaults")
  defaultsBtn:SetScript("OnClick", ResetToDefaults)

  local reloadBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  reloadBtn:SetSize(140, 22)
  reloadBtn:SetPoint("LEFT", defaultsBtn, "RIGHT", 10, 0)
  reloadBtn:SetText("Reload UI")
  reloadBtn:SetScript("OnClick", ReloadUI)

  panel:HookScript("OnShow", function()
    RefreshOptionsUI()
    C_Timer.After(0, function()
      if reloadBtn and reloadBtn.GetBottom then
        UpdateContentHeight(reloadBtn, 28)
      end
    end)
  end)

  local category = Settings.RegisterCanvasLayoutCategory(panel, "HelloCursor")
  Settings.RegisterAddOnCategory(category)

  RefreshOptionsUI()
  return category
end

local settingsCategory = nil

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    HelloCursorDB = CopyDefaults(HelloCursorDB, DEFAULTS)
    HelloCursorDB.colorHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex
    HelloCursorDB.size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 16, 256)

    CaptureCursorNow()

    RefreshVisualsImmediate()
    UpdateVisibility()

    if not settingsCategory then
      settingsCategory = CreateSettingsPanel()
    end

    print("|cFF00FF00HelloCursor:|r v" .. VERSION .. " Loaded. Use |cFFFFA500/hc|r to open options.")
    return
  end

  ApplyTintIfNeeded(false)
  UpdateVisibility()
end)

-- ---------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------

SLASH_HELLOCURSOR1 = "/hc"
SLASH_HELLOCURSOR2 = "/hellocursor"

SlashCmdList.HELLOCURSOR = function(msg)
  if msg == "toggle" then
    HelloCursorDB.enabled = not HelloCursorDB.enabled
    UpdateVisibility()
    print(("HelloCursor: %s"):format(HelloCursorDB.enabled and "enabled" or "disabled"))
    return
  end

  if settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(settingsCategory:GetID())
  end
end
