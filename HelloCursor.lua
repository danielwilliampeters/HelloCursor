-- HelloCursor
-- Asset-based cursor ring (tintable), with optional reactive crossfade to a smaller ring on RMB (mouselook).
-- Ring follows cursor normally and FREEZES at last cursor position when mouselook starts (RMB).
--
-- REQUIRED FILES:
--   Interface/AddOns/HelloCursor/ring.tga
--   Interface/AddOns/HelloCursor/ring_small.tga

local ADDON_NAME = ...
local VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

HelloCursorDB = HelloCursorDB or {}

local DEFAULTS = {
  enabled = true,

  -- Colour
  colorHex = "FF4FD8",      -- RRGGBB or AARRGGBB
  useClassColor = false,    -- when true, ignores colorHex for RGB

  -- Ring size (frame size; textures are scaled to fit)
  size = 90,

  -- Visibility rules
  showWorld = true,
  showPvE = true,           -- dungeons / delves / raids
  showPvP = true,           -- battlegrounds / arena
  showInCombat = true,     -- override: show anywhere while in combat

  -- Behaviour
  reactiveCursor = true,    -- crossfade to small ring while mouselooking
}

local TEX_NORMAL = "Interface\\AddOns\\HelloCursor\\ring.tga"
local TEX_SMALL  = "Interface\\AddOns\\HelloCursor\\ring_small.tga"

local TWEEN_DURATION = 0.08

-- ---------------------------------------------------------------------
-- Utils
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

-- ---------------------------------------------------------------------
-- Visibility rules
-- ---------------------------------------------------------------------

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
  return HelloCursorDB.enabled and IsAllowedInZone()
end

-- ---------------------------------------------------------------------
-- Frame + textures
-- ---------------------------------------------------------------------

local ringFrame = CreateFrame("Frame", "HelloCursorFrame", UIParent)
ringFrame:SetFrameStrata("TOOLTIP")
ringFrame:SetSize(DEFAULTS.size, DEFAULTS.size)
ringFrame:Hide()

-- Two textures stacked; we crossfade between them, but hard-hide one at rest.
local ringTexNormal = ringFrame:CreateTexture(nil, "OVERLAY")
ringTexNormal:SetAllPoints(true)

local ringTexSmall = ringFrame:CreateTexture(nil, "OVERLAY")
ringTexSmall:SetAllPoints(true)

SafeSetTexture(ringTexNormal, TEX_NORMAL, nil)
SafeSetTexture(ringTexSmall, TEX_SMALL, TEX_NORMAL)

-- ---------------------------------------------------------------------
-- Colour (class colour or hex)
-- ---------------------------------------------------------------------

local function GetPlayerClassRGB()
  local _, classFile = UnitClass("player")
  classFile = classFile or "PRIEST"

  if C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(classFile)
    if c and c.GetRGB then
      local r, g, b = c:GetRGB()
      return r, g, b
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

-- Cache last applied tint to avoid reapplying every frame
local lastTintKey = nil

local function ComputeTint()
  if HelloCursorDB.useClassColor then
    local r, g, b = GetPlayerClassRGB()
    -- alpha: keep at 1 for class colour mode
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
    lastTintKey = key
  end
end

-- ---------------------------------------------------------------------
-- Crossfade tween (normal <-> small)
-- mix: 0 = normal, 1 = small
-- ---------------------------------------------------------------------

local currentMix = 0
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

local function SetMix(mix)
  if mix < 0 then mix = 0 elseif mix > 1 then mix = 1 end
  currentMix = mix

  -- Hard-hide one texture at rest so you never “see both”
  if mix <= 0.0001 then
    ringTexNormal:Show()
    ringTexSmall:Hide()
    ringTexNormal:SetAlpha(1)
    ringTexSmall:SetAlpha(0)
    return
  end

  if mix >= 0.9999 then
    ringTexNormal:Hide()
    ringTexSmall:Show()
    ringTexNormal:SetAlpha(0)
    ringTexSmall:SetAlpha(1)
    return
  end

  ringTexNormal:Show()
  ringTexSmall:Show()
  ringTexNormal:SetAlpha(1 - mix)
  ringTexSmall:SetAlpha(mix)
end

local function WantsSmallRing()
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

local function UpdateRingPosition()
  local scale = UIParent:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  cx, cy = cx / scale, cy / scale

  local mouselooking = (IsMouselooking and IsMouselooking()) and true or false

  if not mouselooking then
    lastCursorX, lastCursorY = cx, cy
  elseif not wasMouselooking then
    -- just entered mouselook, freeze at last known cursor
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

-- ---------------------------------------------------------------------
-- Visual refresh helpers
-- ---------------------------------------------------------------------

local function RefreshSize()
  local size = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 16, 256)
  HelloCursorDB.size = size
  ringFrame:SetSize(size, size)
end

local function RefreshVisualsImmediate()
  StopTween()
  RefreshSize()
  ApplyTintIfNeeded(true)
  SnapToTargetMix()
end

local function UpdateVisibility()
  if ShouldShowRing() then
    ringFrame:Show()
  else
    ringFrame:Hide()
  end
end

-- ---------------------------------------------------------------------
-- OnUpdate loop
-- ---------------------------------------------------------------------

ringFrame:SetScript("OnUpdate", function()
  if not ringFrame:IsShown() then return end

  ApplyTintIfNeeded(false)

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
      -- Keep snapped cleanly at rest
      SetMix(targetMix)
    end
  end

  UpdateRingPosition()
end)

-- ---------------------------------------------------------------------
-- Color picker (Retail-safe)
-- ---------------------------------------------------------------------

local hexEditBox
local pickBtnRef
local cbClassRef

local cbWorldRef, cbPvERef, cbPvPRef, cbCombatRef, cbReactiveRef

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
  if cbClassRef then cbClassRef:SetChecked(HelloCursorDB.useClassColor and true or false) end

  if hexEditBox then
    hexEditBox:SetText(NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex)
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

-- ---------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------

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

-- ---------------------------------------------------------------------
-- Settings UI
-- ---------------------------------------------------------------------

local function CreateSettingsPanel()
  if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end

  local panel = CreateFrame("Frame")
  panel.name = "HelloCursor"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("HelloCursor")

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
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
    "Show in combat",
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
    function()
      -- keep current state consistent immediately
      StopTween()
      SnapToTargetMix()
    end
  )

  cbClassRef = MakeCheckbox(
    "Use class colour",
    function() return HelloCursorDB.useClassColor end,
    function(v) HelloCursorDB.useClassColor = v end,
    cbReactiveRef,
    -12,
    function()
      ApplyTintIfNeeded(true)
      RefreshColourUIEnabledState()
    end
  )

  -- Colour section
  local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", cbClassRef, "BOTTOMLEFT", 0, -18)
  colorLabel:SetText("Ring colour")

  pickBtnRef = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  pickBtnRef:SetSize(120, 22)
  pickBtnRef:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -8)
  pickBtnRef:SetText("Pick colour...")
  pickBtnRef:SetScript("OnClick", OpenColorPicker)

  local hexLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hexLabel:SetPoint("LEFT", pickBtnRef, "RIGHT", 10, 0)
  hexLabel:SetText("Hex")

  hexEditBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
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

  local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", pickBtnRef, "BOTTOMLEFT", 0, -6)
  hint:SetText("Use RRGGBB (example: FF4FD8). Class colour ignores hex.")

  local defaultsBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  defaultsBtn:SetSize(140, 22)
  defaultsBtn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)
  defaultsBtn:SetText("Reset to defaults")
  defaultsBtn:SetScript("OnClick", ResetToDefaults)

  local separator = panel:CreateTexture(nil, "ARTWORK")
  separator:SetPoint("TOPLEFT", defaultsBtn, "BOTTOMLEFT", -16, -16)
  separator:SetSize(560, 1)
  separator:SetColorTexture(0.3, 0.3, 0.3, 0.8)

  local reloadNote = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  reloadNote:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", 16, -12)
  reloadNote:SetText("Note: Some changes may require a UI reload to take full effect")
  reloadNote:SetTextColor(1, 0.5, 0.25)

  local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  btn:SetSize(140, 22)
  btn:SetPoint("TOPLEFT", reloadNote, "BOTTOMLEFT", 0, -12)
  btn:SetText("Reload UI")
  btn:SetScript("OnClick", ReloadUI)

  local category = Settings.RegisterCanvasLayoutCategory(panel, "HelloCursor")
  Settings.RegisterAddOnCategory(category)
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

    -- Ensure textures are present
    SafeSetTexture(ringTexNormal, TEX_NORMAL, nil)
    SafeSetTexture(ringTexSmall, TEX_SMALL, TEX_NORMAL)

    RefreshVisualsImmediate()
    UpdateVisibility()

    if not settingsCategory then
      settingsCategory = CreateSettingsPanel()
    end

    print("|cFF00FF00HelloCursor:|r v" .. VERSION .. " Loaded. Use |cFFFFA500/hc|r to open options.")
    return
  end

  -- Keep correct after zone/combat changes (combat override logic depends on it)
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
