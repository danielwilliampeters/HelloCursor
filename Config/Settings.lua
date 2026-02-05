-- Hello Cursor settings & options UI

local ADDON_NAME = ...

HelloCursor = HelloCursor or {}
local HC = HelloCursor

local DEFAULTS = HC.DEFAULTS
local NormalizeHex = HC.NormalizeHex
local Clamp = HC.Clamp
local NearestKey = HC.NearestKey

local CaptureCursorNow = HC.CaptureCursorNow
local RefreshVisualsImmediate = HC.RefreshVisualsImmediate
local UpdateVisibility = HC.UpdateVisibility
local ApplyTintIfNeeded = HC.ApplyTintIfNeeded
local SyncRingStyleFlags = HC.SyncRingStyleFlags

local HexToRGBA = HC.HexToRGBA
local RGBAtoHex = HC.RGBAtoHex

local RefreshSize = HC.RefreshSize
local UpdateRingPosition = HC.UpdateRingPosition
local StopTween = HC.StopTween
local SetMix = HC.SetMix

local ForceVisibilityRecompute = HC.ForceVisibilityRecompute
local SetForceShowWhilePickingColour = HC.SetForceShowWhilePickingColour
local StartPickerCursorDriver = HC.StartPickerCursorDriver
local StopPickerCursorDriver = HC.StopPickerCursorDriver
local ResyncGCDVisualsAfterPicker = HC.ResyncGCDVisualsAfterPicker

local function GetNormalizedColorHex()
  return NormalizeHex(HelloCursorDB.colorHex) or DEFAULTS.colorHex
end

-- ---------------------------------------------------------------------
-- Settings UI (Blizzard Settings panel)
-- ---------------------------------------------------------------------

local hexEditBox
local pickBtnRef
local cbClassRef

local cbWorldRef, cbHousingRef, cbPvERef, cbPvPRef, cbCombatRef, cbReactiveRef, cbMouselookShowRef
local cbGCDRef, cbHideMenusRef, cbClassicStyleRef

local sizeSliderRef

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
  if cbHousingRef then cbHousingRef:SetChecked(HelloCursorDB.showHousing and true or false) end
  if cbPvERef then cbPvERef:SetChecked(HelloCursorDB.showPvE and true or false) end
  if cbPvPRef then cbPvPRef:SetChecked(HelloCursorDB.showPvP and true or false) end
  if cbCombatRef then cbCombatRef:SetChecked(HelloCursorDB.showInCombat and true or false) end
  if cbReactiveRef then cbReactiveRef:SetChecked(HelloCursorDB.reactiveCursor and true or false) end
  if cbMouselookShowRef then cbMouselookShowRef:SetChecked(HelloCursorDB.showWhileMouselooking and true or false) end
  if cbGCDRef then cbGCDRef:SetChecked(HelloCursorDB.showGCDSpinner and true or false) end
  if cbHideMenusRef then cbHideMenusRef:SetChecked(HelloCursorDB.hideInMenus and true or false) end
  if cbClassRef then cbClassRef:SetChecked(HelloCursorDB.useClassColor and true or false) end
  if cbClassicStyleRef then cbClassicStyleRef:SetChecked(HelloCursorDB.classicRingStyle and true or false) end

  if hexEditBox then
    hexEditBox:SetText(GetNormalizedColorHex())
  end

  if sizeSliderRef then
    local v = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 96, 192)
    local snappedKey = NearestKey(DEFAULTS and { [96]=true,[128]=true,[192]=true } or {}, v) or 96
    sizeSliderRef:SetValue(snappedKey)
  end

  RefreshColourUIEnabledState()
end

local function SetColorHex(hex)
  local norm = NormalizeHex(hex)
  if not norm then return end

  HelloCursorDB.colorHex = norm
  HelloCursorDB["HelloCursor_colorHex"] = norm

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

  local r, g, b, _ = HexToRGBA(HelloCursorDB.colorHex)
  local prevHex = GetNormalizedColorHex()

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

  -- While picking a colour, show the ring even if menus are open
  SetForceShowWhilePickingColour(true)
  CaptureCursorNow()
  StopTween()
  SetMix(0)
  UpdateVisibility()
  StartPickerCursorDriver()

  -- Turn the override off when the picker closes (hook once)
  if not ColorPickerFrame.__HelloCursorHooked then
    ColorPickerFrame.__HelloCursorHooked = true
    ColorPickerFrame:HookScript("OnHide", function()
      SetForceShowWhilePickingColour(false)
      StopPickerCursorDriver()
      StopTween()

      ForceVisibilityRecompute()

      -- resync GCD visuals immediately after leaving picker
      ResyncGCDVisualsAfterPicker()
    end)
  end

  ColorPickerFrame:Show()
end

local function ResetToDefaults()
  for k in pairs(HelloCursorDB) do
    if type(k) == "string" and k:match("^HelloCursor_") then
      HelloCursorDB[k] = nil
    end
  end

  for k, v in pairs(DEFAULTS) do
    HelloCursorDB[k] = v
  end

  HelloCursorDB.neonPulseEnabled = nil
  HelloCursorDB["HelloCursor_neonPulseEnabled"] = nil
  HelloCursorDB.useNeonRing = nil
  
  HelloCursorDB.colorHex = DEFAULTS.colorHex
  HelloCursorDB.size = DEFAULTS.size

  -- Ensure style flags are consistent (classic vs neon + legacy useNeonRing)
  SyncRingStyleFlags()

  -- Keep Settings-backed (namespaced) variables in sync so the Blizzard
  -- Settings controls match defaults on reload.
  local tracked = {
    "enabled",
    "showWorld",
    "showHousing",
    "showPvE",
    "showPvP",
    "showInCombat",
    "showWhileMouselooking",
    "reactiveCursor",
    "showGCDSpinner",
    "hideInMenus",
    "size",
    "useClassColor",
    "colorHex",
    "classicRingStyle",
  }

  for _, key in ipairs(tracked) do
    local nsKey = "HelloCursor_" .. key
    if HelloCursorDB[key] ~= nil then
      HelloCursorDB[nsKey] = HelloCursorDB[key]
    end
  end

  RefreshVisualsImmediate()
  UpdateVisibility()
  RefreshOptionsUI()
end

-- Legacy canvas-style panel. On modern clients this is registered as an
-- "advanced" sub-category underneath the vertical layout category so we
-- can keep the richer colour + utilities UI. When used as a top-level
-- category (older clients), it also shows the full set of toggles.
local function CreateSettingsPanelLegacy(parentCategory, isAdvanced)
  if not Settings or not Settings.RegisterCanvasLayoutCategory then return nil end

  local panel = CreateFrame("Frame")
  panel.name = "Hello Cursor"

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
  title:SetText(isAdvanced and "Advanced" or "Hello Cursor")

  if isAdvanced then
    title:SetFontObject("GameFontHighlightLarge") -- white
  end

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

  local previousAnchor = title

  if not isAdvanced then
    -- Visibility
    local visHeader = MakeHeader("Visibility", title, -18)

    cbWorldRef = MakeCheckbox(
      "Show in world",
      function() return HelloCursorDB.showWorld end,
      function(v) HelloCursorDB.showWorld = v end,
      visHeader, -10
    )

    cbHousingRef = MakeCheckbox(
      "Show in housing",
      function() return HelloCursorDB.showHousing end,
      function(v) HelloCursorDB.showHousing = v end,
      cbWorldRef, -10
    )

    cbPvERef = MakeCheckbox(
      "Show in dungeons / delves / raids",
      function() return HelloCursorDB.showPvE end,
      function(v) HelloCursorDB.showPvE = v end,
      cbHousingRef, -10
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
        HC.SnapToTargetMix()
      end
    )

    cbMouselookShowRef = MakeCheckbox(
      "Always show while mouselooking",
      function() return HelloCursorDB.showWhileMouselooking end,
      function(v) HelloCursorDB.showWhileMouselooking = v end,
      cbReactiveRef, -10,
      function()
        UpdateVisibility()
      end
    )

    cbGCDRef = MakeCheckbox(
      "Global cooldown (GCD) animation",
      function() return HelloCursorDB.showGCDSpinner end,
      function(v) HelloCursorDB.showGCDSpinner = v end,
      cbMouselookShowRef, -10,
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

    -- Appearance (basic)
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
      local snappedKey = NearestKey({ [96]=true,[128]=true,[192]=true }, value) or 96

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
    
    cbClassicStyleRef = MakeCheckbox(
      "Classic ring style",
      function() return HelloCursorDB.classicRingStyle end,
      function(v)
        HelloCursorDB.classicRingStyle = v and true or false
        HC.ApplyRingStyleChange()
      end,
      cbClassRef, -10
    )

    previousAnchor = cbClassicStyleRef
  end

  local colorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", previousAnchor, "BOTTOMLEFT", 0, -22)
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
    self:SetText(GetNormalizedColorHex())
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
      self:SetText(GetNormalizedColorHex())
    end
    self:ClearFocus()
  end)

  hexEditBox:SetScript("OnEscapePressed", function(self)
    self:SetText(GetNormalizedColorHex())
    self:ClearFocus()
  end)

  local hint = content:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hint:SetPoint("TOPLEFT", pickBtnRef, "BOTTOMLEFT", 0, -6)
  hint:SetText("Use RRGGBB (example: FF4FD8). Class colour disables picker & hex.")
  hint:SetTextColor(0.75, 0.75, 0.75)

  -- Advanced utility: reset hex to the default ring colour
  local resetHexBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  resetHexBtn:SetSize(120, 22)
  resetHexBtn:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
  resetHexBtn:SetText("Default")
  resetHexBtn:SetScript("OnClick", function()
    SetColorHex(DEFAULTS.colorHex)
  end)

  panel:HookScript("OnShow", function()
    RefreshOptionsUI()
    C_Timer.After(0, function()
      local last = resetHexBtn or hint
      if last and last.GetBottom then
        UpdateContentHeight(last, 28)
      end
    end)
  end)

  local category
  if parentCategory and Settings.RegisterCanvasLayoutSubcategory and isAdvanced then
    category = Settings.RegisterCanvasLayoutSubcategory(parentCategory, panel, "Advanced")
  else
    category = Settings.RegisterCanvasLayoutCategory(panel, "Hello Cursor")
    Settings.RegisterAddOnCategory(category)
  end

  RefreshOptionsUI()
  return category
end

local function CreateSettingsPanel()
  if HC.settingsCategory then return HC.settingsCategory end
  if not Settings then
    HC.settingsCategory = nil
    return HC.settingsCategory
  end

  -- Sync style flags early using the local function; the
  -- HC.SyncRingStyleFlags alias is only assigned later.
  SyncRingStyleFlags()

  -- If the vertical layout APIs aren't available, fall back to the
  -- full legacy canvas panel as the top-level category.
  if not (Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnSetting) then
    HC.settingsCategory = CreateSettingsPanelLegacy(nil, false)
    return HC.settingsCategory
  end

  local category, layout = Settings.RegisterVerticalLayoutCategory("Hello Cursor")
  HC.settingsCategory = category
  Settings.RegisterAddOnCategory(category)

  local HC_VAR_PREFIX = "HelloCursor_"

  local function VarTypeFor(v)
    if Settings.VarType then
      if type(v) == "boolean" then return Settings.VarType.Boolean end
      if type(v) == "number" then return Settings.VarType.Number end
    end
    return type(v)
  end

  local function RegisterSetting(key, name, defaultValue)
    local varName = HC_VAR_PREFIX .. key

    -- Seed the underlying storage from our existing DB field so the
    -- Settings panel reflects current values instead of always defaulting.
    if HelloCursorDB[varName] == nil then
      if HelloCursorDB[key] ~= nil then
        HelloCursorDB[varName] = HelloCursorDB[key]
      else
        HelloCursorDB[varName] = defaultValue
      end
    end

    local ok, setting = pcall(Settings.RegisterAddOnSetting,
      category,
      varName,     -- variable (must be globally unique)
      varName,     -- variableKey
      HelloCursorDB,
      VarTypeFor(defaultValue),
      name,
      defaultValue
    )
    if ok and setting then return setting end

    error(("HelloCursor: RegisterAddOnSetting failed for %s (%s): %s"):format(key, tostring(varName), tostring(setting)))
  end

  local function OnChangedFor(key, setting)
    if not (Settings.SetOnValueChangedCallback and setting and setting.GetValue) then return end

    local varName = HC_VAR_PREFIX .. key

    -- Guard against re-entrant callbacks (Reset to defaults can cause cascades)
    local inCallback = false

    local handler = function()
      if inCallback then return end
      inCallback = true

      local value = setting:GetValue()

      -- keep both in sync
      HelloCursorDB[varName] = value
      HelloCursorDB[key] = value

      if key == "size" then
        local v = Clamp(tonumber(HelloCursorDB.size) or DEFAULTS.size, 96, 192)
        local snappedKey = NearestKey({ [96]=true,[128]=true,[192]=true }, v) or 96

        HelloCursorDB.size = snappedKey
        HelloCursorDB[varName] = snappedKey

        RefreshSize()
        UpdateRingPosition()

      elseif key == "useClassColor" or key == "colorHex" then
        ApplyTintIfNeeded(true)
        RefreshColourUIEnabledState()

      elseif key == "reactiveCursor" then
        StopTween()
        HC.SnapToTargetMix()

      elseif key == "showGCDSpinner" then
        ApplyTintIfNeeded(true)
        if not HelloCursorDB.showGCDSpinner then
          HC.neonPulseStrength = 0

          HC.HideGCDSpinners()
          HC.gcdVisualActive = false
          HC.suppressFlatRing = false
          if SetMix then SetMix(HC.currentMix or 0) end
        end

      elseif key == "classicRingStyle" then
        HC.ApplyRingStyleChange()

      elseif key == "showWorld"
        or key == "showHousing"
        or key == "showPvE"
        or key == "showPvP"
        or key == "showInCombat"
        or key == "showWhileMouselooking"
        or key == "hideInMenus"
        or key == "enabled" then
        ForceVisibilityRecompute()
      end

      inCallback = false
    end

    -- Different client builds use different signatures here; try both.
    local ok = pcall(Settings.SetOnValueChangedCallback, setting, handler)
    if not ok then
      pcall(Settings.SetOnValueChangedCallback, varName, handler)
    end
  end

  -- Register colorHex so the Blizzard "Defaults" button resets it too,
  -- but we don't create a visible control in the main list.
  do
    local settingColorHex = RegisterSetting("colorHex", "Ring colour (hex)", DEFAULTS.colorHex)
    OnChangedFor("colorHex", settingColorHex)
  end

  local function CreateCheckboxControl(setting, tooltip)
    if Settings.CreateCheckbox then
      return Settings.CreateCheckbox(category, setting, tooltip)
    end
    if Settings.CreateCheckBox then
      return Settings.CreateCheckBox(category, setting, tooltip)
    end
  end

  local function AddCheckbox(key, name, tooltip)
    local defaultValue = DEFAULTS[key]
    if type(defaultValue) ~= "boolean" then
      defaultValue = HelloCursorDB[key] and true or false
    end

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)
    CreateCheckboxControl(setting, tooltip)
    return setting
  end

  local function AddSlider(key, name, tooltip, minValue, maxValue, step)
    local current = HelloCursorDB[key]
    if type(current) ~= "number" then current = DEFAULTS[key] or minValue end
    if current < minValue then current = minValue end
    if current > maxValue then current = maxValue end
    HelloCursorDB[key] = current

    local setting = RegisterSetting(key, name, DEFAULTS[key] or current)
    OnChangedFor(key, setting)

    if Settings.CreateSliderOptions and Settings.CreateSlider then
      local opts = Settings.CreateSliderOptions(minValue, maxValue, step)
      if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label and MinimalSliderWithSteppersMixin.Label.Right then
        opts:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
      end
      Settings.CreateSlider(category, setting, opts, tooltip)
    elseif Settings.CreateSlider then
      Settings.CreateSlider(category, setting, minValue, maxValue, step, tooltip)
    end

    return setting
  end

  -- Specialised dropdown for ring size (discrete options instead of a slider)
  local function AddSizeDropdown()
    local key = "size"
    local name = "Ring size"
    local tooltip = "Adjust the size of the cursor ring."

    local defaultValue = DEFAULTS[key] or 96
    local current = tonumber(HelloCursorDB[key]) or defaultValue

    -- Only allow the authored texture keys; fall back to default if needed
    if current ~= 96 and current ~= 128 and current ~= 192 then
      current = defaultValue
    end
    HelloCursorDB[key] = current

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)

    if Settings.CreateControlTextContainer and Settings.CreateDropdown then
      local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(96, "Small (96)")
        container:Add(128, "Medium (128)")
        container:Add(192, "Large (192)")
        return container:GetData()
      end

      Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    return setting
  end

  local function AddHeader(text)
    if layout and type(layout.AddInitializer) == "function"
      and type(CreateSettingsListSectionHeaderInitializer) == "function" then
      layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
  end

  AddCheckbox(
    "enabled",
    "Enable Hello Cursor",
    "Turns Hello Cursor on or off."
  )

  AddHeader("Visibility")

  AddCheckbox(
    "hideInMenus",
    "Hide while game menus are open",
    "Hide the cursor ring while the main game menus are open."
  )

  AddCheckbox(
    "showWorld",
    "Show in world",
    "Show the cursor ring in open world zones."
  )

  AddCheckbox(
    "showHousing",
    "Show in player housing",
    "Show the cursor ring while inside player housing (houses and neighbourhoods)."
  )

  AddCheckbox(
    "showPvE",
    "Show in dungeons, delves, and raids",
    "Show the cursor ring in dungeons, delves, and raids."
  )

  AddCheckbox(
    "showPvP",
    "Show in battlegrounds and arenas",
    "Show the cursor ring in battlegrounds and arenas."
  )

  AddCheckbox(
    "showInCombat",
    "Always show in combat",
    "Always show the cursor ring while you are in combat, regardless of location."
  )

  AddHeader("Appearance")

  AddCheckbox(
    "classicRingStyle",
    "Classic ring style",
    "Use a flat ring style without neon effects."
  )

  AddSizeDropdown()

  AddCheckbox(
    "useClassColor",
    "Use class colour",
    "Tint the ring using your class colour.\n\nCustom colour is configured in Advanced settings."
  )

  AddHeader("Behaviour")

  AddCheckbox(
    "showGCDSpinner",
    "Global cooldown animation",
    "Show an animation on the ring that tracks the global cooldown."
  )

  AddCheckbox(
    "reactiveCursor",
    "Shrink while mouselooking (RMB)",
    "Reduces the ring size while holding the right mouse button to turn the camera."
  )

  AddCheckbox(
    "showWhileMouselooking",
    "Show while mouselooking (RMB)",
    "Shows the ring while holding the right mouse button, even in zones where it would normally be hidden."
  )

  -- Advanced canvas-style subcategory (colour hex + utilities, legacy layout)
  CreateSettingsPanelLegacy(category, true)

  return HC.settingsCategory
end

HC.CreateSettingsPanel = CreateSettingsPanel
