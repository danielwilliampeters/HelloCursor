-- HelloCursor
-- Smooth asset-based cursor ring (color tintable).
-- Ring follows cursor normally and FREEZES at last cursor position when mouselook starts (RMB).
-- Optional reactive cursor: shrink while mouselooking (RMB) using texture swap so stroke stays consistent.
-- Added: 0.08s size tween for shrink/return.
-- Added: Color picker + hex input for ring colour (Retail-safe).
-- Added: Defaults button to reset settings.
--
-- REQUIRED FILES:
--   Interface/AddOns/HelloCursor/ring.tga
--   Interface/AddOns/HelloCursor/ring_small.tga

HelloCursorDB = HelloCursorDB or {}

local VERSION = "1.0.0"
local ADDON_NAME = ...
local DEFAULTS = {
  enabled = true,
  colorHex = "FF4FD8", -- default PINK (RRGGBB or AARRGGBB)
  size = 72,

  showWorld = true,
  showPvE = true,       -- dungeons / delves / raids
  showPvP = true,       -- battlegrounds / arena
  showInCombat = false, -- override: show anywhere while in combat

  reactiveCursor = true, -- shrink on RMB (mouselook) with texture swap
}

local REACTIVE_SHRINK_SCALE = 0.5
local TWEEN_DURATION = 0.08

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

-- Main ring frame
local ringFrame = CreateFrame("Frame", "HelloCursorFrame", UIParent)
ringFrame:SetFrameStrata("TOOLTIP")
ringFrame:SetSize(DEFAULTS.size, DEFAULTS.size)
ringFrame:Hide()

local ringTex = ringFrame:CreateTexture(nil, "OVERLAY")
ringTex:SetAllPoints(true)

local TEX_NORMAL = "Interface\\AddOns\\HelloCursor\\ring.tga"
local TEX_SMALL  = "Interface\\AddOns\\HelloCursor\\ring_small.tga"

local function SafeSetTexture(path)
  if not ringTex:SetTexture(path) then
    ringTex:SetTexture(TEX_NORMAL)
  end
end

-- Cursor tracking
local lastCursorX, lastCursorY = nil, nil
local wasMouselooking = false
local CURSOR_OFFSET_X = 0
local CURSOR_OFFSET_Y = 0

-- State tracking
local currentTextureKey = nil
local currentSize = DEFAULTS.size

-- Tween state
local tweenActive = false
local tweenStart = 0
local tweenFrom = DEFAULTS.size
local tweenTo = DEFAULTS.size

local function StopTween() tweenActive = false end
local function StartTween(fromSize, toSize)
  tweenActive = true
  tweenStart = GetTime()
  tweenFrom = fromSize
  tweenTo = toSize
end

local function GetDesiredSizeAndTextureKey()
  local baseSize = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 16, 256)
  HelloCursorDB.size = baseSize

  local mouselooking = (IsMouselooking and IsMouselooking()) and true or false
  if HelloCursorDB.reactiveCursor and mouselooking then
    local scaled = Clamp(math.floor(baseSize * REACTIVE_SHRINK_SCALE + 0.5), 16, 256)
    return scaled, "small"
  end

  return baseSize, "normal"
end

local function ApplyTextureKey(texKey)
  if currentTextureKey == texKey then return end
  currentTextureKey = texKey
  if texKey == "small" then
    SafeSetTexture(TEX_SMALL)
  else
    SafeSetTexture(TEX_NORMAL)
  end
end

local function ApplyTint()
  local r, g, b, a = HexToRGBA(HelloCursorDB.colorHex)
  ringTex:SetVertexColor(r, g, b, a)
end

local function ApplySizeImmediate(size)
  currentSize = size
  ringFrame:SetSize(size, size)
end

local function RefreshVisualsImmediate()
  StopTween()
  local desiredSize, desiredKey = GetDesiredSizeAndTextureKey()
  ApplyTextureKey(desiredKey)
  ApplySizeImmediate(desiredSize)
  ApplyTint()
end

local function UpdateVisibility()
  if HelloCursorDB.enabled and IsAllowedInZone() then
    ringFrame:Show()
  else
    ringFrame:Hide()
  end
end

local function SetRingToCursor()
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale

  local mouselooking = (IsMouselooking and IsMouselooking()) and true or false

  if not mouselooking then
    lastCursorX, lastCursorY = cx, cy
  end

  if mouselooking and not wasMouselooking then
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

ringFrame:SetScript("OnUpdate", function()
  if not ringFrame:IsShown() then return end

  local desiredSize, desiredKey = GetDesiredSizeAndTextureKey()
  ApplyTextureKey(desiredKey)
  ApplyTint()

  if tweenActive then
    local t = (GetTime() - tweenStart) / TWEEN_DURATION
    if t >= 1 then
      StopTween()
      ApplySizeImmediate(tweenTo)
    else
      ApplySizeImmediate(Lerp(tweenFrom, tweenTo, EaseInOut(t)))
    end
  else
    if math.abs(currentSize - desiredSize) >= 0.01 then
      StartTween(currentSize, desiredSize)
    end
  end

  SetRingToCursor()
end)

-- --------------------------
-- Color picker compatibility
-- --------------------------

local hexEditBox -- assigned in settings UI

-- UI refs so we can refresh without closing the panel
local cbWorldRef, cbPvERef, cbPvPRef, cbCombatRef, cbReactiveRef

local function RefreshOptionsUI()
  if cbWorldRef then cbWorldRef:SetChecked(HelloCursorDB.showWorld and true or false) end
  if cbPvERef then cbPvERef:SetChecked(HelloCursorDB.showPvE and true or false) end
  if cbPvPRef then cbPvPRef:SetChecked(HelloCursorDB.showPvP and true or false) end
  if cbCombatRef then cbCombatRef:SetChecked(HelloCursorDB.showInCombat and true or false) end
  if cbReactiveRef then cbReactiveRef:SetChecked(HelloCursorDB.reactiveCursor and true or false) end

  if hexEditBox then
    hexEditBox:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
  end
end

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

local function SetColorHex(hex)
  local norm = NormalizeHex(hex)
  if not norm then return end
  HelloCursorDB.colorHex = norm
  ApplyTint()
  if hexEditBox then
    hexEditBox:SetText(norm)
  end
end

local function OpenColorPicker()
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

  -- Retail expects swatchFunc on OK; set both for compatibility
  ColorPickerFrame.swatchFunc = ApplyFromPicker
  ColorPickerFrame.func = ApplyFromPicker

  ColorPickerFrame.opacityFunc = nil
  ColorPickerFrame.cancelFunc = CancelToPrev

  picker:SetColorRGB(r, g, b)
  ColorPickerFrame:Show()
end

-- --------------------------
-- Defaults reset
-- --------------------------

local function ResetToDefaults()
  for k, v in pairs(DEFAULTS) do
    HelloCursorDB[k] = v
  end

  HelloCursorDB.colorHex = NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex
  HelloCursorDB.size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 16, 256)

  RefreshVisualsImmediate()
  UpdateVisibility()
  RefreshOptionsUI() -- ✅ instant UI update
end

-- --------------------------
-- Settings UI
-- --------------------------

local function CreateSettingsPanel()
  if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end

  local panel = CreateFrame("Frame")
  panel.name = "HelloCursor"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("HelloCursor")

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  subtitle:SetText("Cursor ring settings")

  local function MakeCheckbox(label, get, set, anchor, yOff, onChange)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)
    cb.Text:SetText(label)

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

  cbWorldRef = MakeCheckbox(
    "Show in world",
    function() return HelloCursorDB.showWorld end,
    function(v) HelloCursorDB.showWorld = v end,
    subtitle,
    -20
  )

  cbPvERef = MakeCheckbox(
    "Show in dungeons / delves / raids",
    function() return HelloCursorDB.showPvE end,
    function(v) HelloCursorDB.showPvE = v end,
    cbWorldRef,
    -12
  )

  cbPvPRef = MakeCheckbox(
    "Show in battlegrounds / arena",
    function() return HelloCursorDB.showPvP end,
    function(v) HelloCursorDB.showPvP = v end,
    cbPvERef,
    -12
  )

  cbCombatRef = MakeCheckbox(
    "Show in combat (override)",
    function() return HelloCursorDB.showInCombat end,
    function(v) HelloCursorDB.showInCombat = v end,
    cbPvPRef,
    -12
  )

  cbReactiveRef = MakeCheckbox(
    "Reactive cursor (shrink while holding RMB)",
    function() return HelloCursorDB.reactiveCursor end,
    function(v) HelloCursorDB.reactiveCursor = v end,
    cbCombatRef,
    -12,
    function() RefreshVisualsImmediate() end
  )

  -- Colour section
  local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", cbReactiveRef, "BOTTOMLEFT", 0, -18)
  colorLabel:SetText("Ring colour")

  local pickBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  pickBtn:SetSize(120, 22)
  pickBtn:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -8)
  pickBtn:SetText("Pick colour...")
  pickBtn:SetScript("OnClick", OpenColorPicker)

  local hexLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hexLabel:SetPoint("LEFT", pickBtn, "RIGHT", 10, 0)
  hexLabel:SetText("Hex")

  hexEditBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
  hexEditBox:SetSize(110, 22)
  hexEditBox:SetPoint("LEFT", hexLabel, "RIGHT", 8, 0)
  hexEditBox:SetAutoFocus(false)

  hexEditBox:SetScript("OnShow", function(self)
    self:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
  end)

  hexEditBox:SetScript("OnEnterPressed", function(self)
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

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", pickBtn, "BOTTOMLEFT", 0, -6)
  hint:SetText("Use RRGGBB (example: FF4FD8).")

  -- Defaults button
  local defaultsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defaultsBtn:SetSize(140, 22)
  defaultsBtn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  defaultsBtn:SetText("Reset to defaults")
  defaultsBtn:SetScript("OnClick", ResetToDefaults)

  local category = Settings.RegisterCanvasLayoutCategory(panel, "HelloCursor")
  Settings.RegisterAddOnCategory(category)
  return category
end

local settingsCategory = nil

-- Events
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

    SafeSetTexture(TEX_NORMAL)
    currentTextureKey = "normal"

    StopTween()
    ApplySizeImmediate(HelloCursorDB.size)
    ApplyTint()

    UpdateVisibility()

    if not settingsCategory then
      settingsCategory = CreateSettingsPanel()
    end

    print("|cFF00FF00HelloCursor:|r v" .. VERSION .. " Loaded. Use |cFFFFA500/hc|r to open options.")

    return
  end

  UpdateVisibility()
end)

-- Slash commands
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
