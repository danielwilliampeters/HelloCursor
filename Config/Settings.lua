-- Hello Cursor settings & options UI

local ADDON_NAME = ...

HelloCursor = HelloCursor or {}
local HC = HelloCursor

local DEFAULTS = HC.DEFAULTS
local NormalizeHex = HC.NormalizeHex

local CaptureCursorNow = HC.CaptureCursorNow
local RefreshVisualsImmediate = HC.RefreshVisualsImmediate
local UpdateVisibility = HC.UpdateVisibility
local ApplyTintIfNeeded = HC.ApplyTintIfNeeded
local SyncRingStyleFlags = HC.SyncRingStyleFlags

local HexToRGBA = HC.HexToRGBA
local RGBAtoHex = HC.RGBAtoHex
local GetNormalizedColorHex = HC.GetNormalizedColorHex

local RefreshSize = HC.RefreshSize
local UpdateRingPosition = HC.UpdateRingPosition
local StopTween = HC.StopTween
local SetMix = HC.SetMix

local ForceVisibilityRecompute = HC.ForceVisibilityRecompute
local SetForceShowWhilePickingColor = HC.SetForceShowWhilePickingColor
local StartPickerCursorDriver = HC.StartPickerCursorDriver
local StopPickerCursorDriver = HC.StopPickerCursorDriver
local ResyncGCDVisualsAfterPicker = HC.ResyncGCDVisualsAfterPicker

local function DeriveMouselookModeFromFlags(reactive, showML)
  reactive = reactive and true or false
  showML = showML and true or false

  if reactive and showML then
    return "show_shrink"
  elseif reactive then
    return "shrink"
  elseif showML then
    return "show"
  end

  return DEFAULTS.mouselookMode or "none"
end

local function ApplyMouselookModeToFlags(mode)
  mode = tostring(mode or DEFAULTS.mouselookMode)

  local reactive = (mode == "shrink" or mode == "show_shrink")
  local showML = (mode == "show" or mode == "show_shrink")

  HelloCursorDB.reactiveCursor = reactive
  HelloCursorDB.showWhileMouselooking = showML

  HelloCursorDB["HelloCursor_reactiveCursor"] = reactive
  HelloCursorDB["HelloCursor_showWhileMouselooking"] = showML
end

local function DeriveInstanceHideModeFromFlags(doNotShowPvE, doNotShowPvP)
  doNotShowPvE = doNotShowPvE and true or false
  doNotShowPvP = doNotShowPvP and true or false

  if doNotShowPvE and doNotShowPvP then
    return "all"
  elseif doNotShowPvE then
    return "pve"
  elseif doNotShowPvP then
    return "pvp"
  end

  return "none"
end

local function ApplyInstanceHideModeToFlags(mode)
  mode = tostring(mode or DeriveInstanceHideModeFromFlags(DEFAULTS.doNotShowPvE, DEFAULTS.doNotShowPvP))

  local doNotShowPvE, doNotShowPvP
  if mode == "all" then
    doNotShowPvE, doNotShowPvP = true, true
  elseif mode == "pve" then
    doNotShowPvE, doNotShowPvP = true, false
  elseif mode == "pvp" then
    doNotShowPvE, doNotShowPvP = false, true
  else
    doNotShowPvE, doNotShowPvP = false, false
  end

  HelloCursorDB.doNotShowPvE = doNotShowPvE
  HelloCursorDB.doNotShowPvP = doNotShowPvP

  HelloCursorDB["HelloCursor_doNotShowPvE"] = doNotShowPvE
  HelloCursorDB["HelloCursor_doNotShowPvP"] = doNotShowPvP
end

-- ---------------------------------------------------------------------
-- Settings UI (Blizzard Settings panel)
-- ---------------------------------------------------------------------

local hexEditBox
local pickBtnRef

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

local function RefreshColorUIEnabledState()
  local mode = HelloCursorDB and HelloCursorDB.colorMode or "default"
  local enabled = (mode ~= "class")
  if pickBtnRef then pickBtnRef:SetEnabled(enabled) end
  if hexEditBox then
    hexEditBox:SetEnabled(enabled)
    hexEditBox:SetAlpha(enabled and 1 or 0.5)
  end
end

local function RefreshOptionsUI()
  if hexEditBox then
    hexEditBox:SetText(GetNormalizedColorHex())
  end

  RefreshColorUIEnabledState()
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
  if HelloCursorDB.colorMode == "class" then return end

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

  -- While picking a color, show the ring even if menus are open
  SetForceShowWhilePickingColor(true)
  CaptureCursorNow()
  StopTween()
  SetMix(0)
  UpdateVisibility()
  StartPickerCursorDriver()

  -- Turn the override off when the picker closes (hook once)
  if not ColorPickerFrame.__HelloCursorHooked then
    ColorPickerFrame.__HelloCursorHooked = true
    ColorPickerFrame:HookScript("OnHide", function()
      SetForceShowWhilePickingColor(false)
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

  HelloCursorDB.useNeonRing = nil
  
  HelloCursorDB.colorHex = DEFAULTS.colorHex
  HelloCursorDB.size = DEFAULTS.size
  HelloCursorDB.colorMode = DEFAULTS.colorMode

  -- Keep instance visibility dropdown in sync with PvE/PvP defaults
  HelloCursorDB.instanceHideMode = DeriveInstanceHideModeFromFlags(
    HelloCursorDB.doNotShowPvE,
    HelloCursorDB.doNotShowPvP
  )

  -- Keep legacy mouselook booleans in sync with the new mode
  ApplyMouselookModeToFlags(HelloCursorDB.mouselookMode)

  -- Ensure style flags are consistent (classic vs neon + legacy useNeonRing)
  SyncRingStyleFlags()

  -- Keep Settings-backed (namespaced) variables in sync so the Blizzard
  -- Settings controls match defaults on reload.
  local tracked = {
    "enabled",
    "alwaysShow",
    "showInCombat",
    "hideInMenus",
    "doNotShowWorld",
    "doNotShowHousing",
    "doNotShowPvE",
    "doNotShowPvP",
    "instanceHideMode",
    "mouselookMode",
    "showGCDSpinner",
    "size",
    "colorMode",
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

  -- For legacy/canvas layout, we only use this panel for the
  -- color picker and related utilities. All other options live
  -- in the modern vertical layout Settings panel.

  local colorLabel = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  colorLabel:SetPoint("TOPLEFT", previousAnchor, "BOTTOMLEFT", 0, -22)
  colorLabel:SetText("Ring Color")

  pickBtnRef = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
  pickBtnRef:SetSize(120, 22)
  pickBtnRef:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -6)
  pickBtnRef:SetText("Pick Color...")
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
    RefreshColorUIEnabledState()
  end)

  hexEditBox:SetScript("OnEnterPressed", function(self)
    if HelloCursorDB.colorMode == "class" then
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
  hint:SetText("Use RRGGBB (example: FF4FD8). Class color mode disables picker & hex.")
  hint:SetTextColor(0.75, 0.75, 0.75)

  -- Advanced utility: reset hex to the default ring color
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
        local v = tonumber(HelloCursorDB.size) or DEFAULTS.size
        if v ~= 64 and v ~= 80 and v ~= 96 and v ~= 128 then
          v = DEFAULTS.size or 80
        end

        HelloCursorDB.size = v
        HelloCursorDB[varName] = v

        RefreshSize()
        UpdateRingPosition()

      elseif key == "colorMode" or key == "colorHex" then
        if key == "colorMode" then
          local isClass = (HelloCursorDB.colorMode == "class") and true or false
          HelloCursorDB.useClassColor = isClass
          HelloCursorDB["HelloCursor_useClassColor"] = isClass
        end

        ApplyTintIfNeeded(true)
  RefreshColorUIEnabledState()

      elseif key == "mouselookMode" then
        ApplyMouselookModeToFlags(HelloCursorDB.mouselookMode)
        StopTween()
        HC.SnapToTargetMix()
        ForceVisibilityRecompute()

      elseif key == "showGCDSpinner" then
        ApplyTintIfNeeded(true)
        if not HelloCursorDB.showGCDSpinner then
          if HC.HideGCDSpinners then
            HC.HideGCDSpinners()
          end
          if SetMix then SetMix(HC.currentMix or 0) end
        end

      elseif key == "classicRingStyle" then
        HC.ApplyRingStyleChange()

      elseif key == "instanceHideMode" then
        ApplyInstanceHideModeToFlags(HelloCursorDB.instanceHideMode)
        ForceVisibilityRecompute()

      elseif key == "doNotShowWorld"
        or key == "doNotShowHousing"
        or key == "doNotShowPvE"
        or key == "doNotShowPvP"
        or key == "showInCombat"
        or key == "hideInMenus"
        or key == "alwaysShow"
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
    local settingColorHex = RegisterSetting("colorHex", "Ring Color (Hex)", DEFAULTS.colorHex)
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

  local function AddSizeDropdown()
    local key = "size"
    local name = "Cursor Ring Size"
    local tooltip = "Adjust the size of the Cursor Ring."

    local defaultValue = DEFAULTS[key] or 96
    local current = tonumber(HelloCursorDB[key]) or defaultValue

    -- Only allow the authored texture keys; fall back to default if needed
    if current ~= 64 and current ~= 80 and current ~= 96 and current ~= 128 then
      current = defaultValue
    end
    HelloCursorDB[key] = current

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)

    if Settings.CreateControlTextContainer and Settings.CreateDropdown then
      local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(64,  "Compact")
        container:Add(80,  "Standard")
        container:Add(96,  "Medium")
        container:Add(128, "Large")
        return container:GetData()
      end

      Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    return setting
  end

  local function AddStyleDropdown()
    local key = "classicRingStyle"
    local name = "Cursor Ring Appearance"
    local tooltip = "Choose the visual style of the Cursor Ring."

    local defaultValue = DEFAULTS[key] and true or false

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)

    if Settings.CreateControlTextContainer and Settings.CreateDropdown then
      local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add(false, "Modern")
        container:Add(true, "Classic")
        return container:GetData()
      end

      Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    return setting
  end

  local function AddInstanceModeDropdown()
    local key = "instanceHideMode"
    local name = "Do Not Show inside Instances"
    local tooltip =
      "Controls where the Cursor Ring is hidden in instanced content.\n" ..
      "None: Show in all instances.\n" ..
      "PvE Instances: Hide in dungeons, delves, and raids.\n" ..
      "PvP Instances: Hide in battlegrounds and arenas.\n" ..
      "All Instances: Hide in all instanced content."

    local defaultValue = DeriveInstanceHideModeFromFlags(
      DEFAULTS.doNotShowPvE,
      DEFAULTS.doNotShowPvP
    )
    if defaultValue ~= "none" and defaultValue ~= "pve" and defaultValue ~= "pvp" and defaultValue ~= "all" then
      defaultValue = "none"
    end

    -- Derive from the authoritative PvE/PvP flags first so that
    -- legacy showPvE/showPvP values (migrated into doNotShow*)
    -- correctly drive the initial dropdown selection.
    local derived = DeriveInstanceHideModeFromFlags(
      HelloCursorDB.doNotShowPvE,
      HelloCursorDB.doNotShowPvP
    )
    if derived ~= "none" and derived ~= "pve" and derived ~= "pvp" and derived ~= "all" then
      derived = defaultValue
    end

    local current = HelloCursorDB[key]
    if type(current) ~= "string" or (current ~= "none" and current ~= "pve" and current ~= "pvp" and current ~= "all") then
      current = derived
    else
      -- If a previously saved value disagrees with the flags,
      -- treat the flags as ground truth and repair the stored mode.
      if current ~= derived then
        current = derived
      end
    end
    HelloCursorDB[key] = current

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)

    if Settings.CreateControlTextContainer and Settings.CreateDropdown then
      local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("none", "None")
        container:Add("pve", "PvE Instances")
        container:Add("pvp", "PvP Instances")
        container:Add("all", "All Instances")
        return container:GetData()
      end

      Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    return setting
  end

  local function AddMouselookModeDropdown()
    local key = "mouselookMode"
    local name = "Mouselook Behaviour (RMB)"
    local tooltip = "Controls how the Cursor Ring behaves while holding the right mouse button to turn the camera."

    local defaultValue = DEFAULTS[key] or "none"
    local current = HelloCursorDB[key]
    if type(current) ~= "string" then
      current = defaultValue
    end
    HelloCursorDB[key] = current

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)

    if Settings.CreateControlTextContainer and Settings.CreateDropdown then
      local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("none",        "None")
        container:Add("show",        "Show While Mouselooking")
        container:Add("shrink",      "Shrink While Mouselooking")
        container:Add("show_shrink", "Show and Shrink While Mouselooking")
        return container:GetData()
      end

      Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    return setting
  end

  local function AddColorModeDropdown()
    local key = "colorMode"
    local name = "Ring Color"
    local tooltip =
      "Default uses your configured color (Advanced).\n" ..
      "Class color uses class specific colors."

    local defaultValue = DEFAULTS[key] or "default"
    local current = HelloCursorDB[key]
    if current ~= "default" and current ~= "class" then
      current = defaultValue
    end
    HelloCursorDB[key] = current

    local setting = RegisterSetting(key, name, defaultValue)
    OnChangedFor(key, setting)

    if Settings.CreateControlTextContainer and Settings.CreateDropdown then
      local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        container:Add("default", "Default")
        container:Add("class", "Class Color")
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

  AddCheckbox(
    "alwaysShow",
    "Always Show Cursor Ring",
    "Always show the Cursor Ring in all locations except those you explicitly disable below."
  )

  AddCheckbox(
    "showInCombat",
    "Always Show in Combat",
    "Forces the cursor ring to show during combat. Overrides \"Do Not Show\" options. Ignored when \"Always Show\" is enabled."
  )

  AddCheckbox(
    "doNotShowWorld",
    "Do Not Show Outside Instances",
    "Do not show the Cursor Ring outside dungeons, raids, battlegrounds, and arenas."
  )

  AddInstanceModeDropdown()

  AddCheckbox(
    "doNotShowHousing",
    "Do Not Show in Player Housing",
    "Do not show the Cursor Ring while inside player housing (houses and neighbourhoods)."
  )

  AddCheckbox(
    "hideInMenus",
    "Do Not Show in Menus",
    "Do not show the Cursor Ring while menus (Esc, Settings, Options) are open."
  )

  AddMouselookModeDropdown()

  AddCheckbox(
    "showGCDSpinner",
    "Global Cooldown Animation",
    "Show an animation on the ring that tracks the global cooldown."
  )

  AddSizeDropdown()

  AddStyleDropdown()

  AddColorModeDropdown()

  -- Advanced canvas-style subcategory (color hex + utilities, legacy layout)
  CreateSettingsPanelLegacy(category, true)

  return HC.settingsCategory
end

HC.CreateSettingsPanel = CreateSettingsPanel

-- Global handler for the AddOn Compartment button
function HelloCursor_OpenSettings(addonName, buttonName)
  if not (HelloCursor and Settings and Settings.OpenToCategory) then return end
  local HC = HelloCursor

  -- Ensure settings category exists
  if not HC.settingsCategory and HC.CreateSettingsPanel then
    HC.settingsCategory = HC.CreateSettingsPanel()
  end

  local cat = HC.settingsCategory
  if not cat then return end

  -- Open it
  Settings.OpenToCategory(cat.GetID and cat:GetID() or cat)
end
