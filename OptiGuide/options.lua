-- Blizzard options panel (Interface -> AddOns -> OptiGuide) with slash
-- fallback. Built defensively: if any widget template is missing on this
-- client, the panel still loads with what it could create.
local _, OG = ...

local built = false

local function mkCheck(parent, label, key, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(label)
  cb.tooltipText = tip or label
  cb:SetChecked(OG.db[key])
  cb:SetScript("OnClick", function(s) OG.db[key] = s:GetChecked(); OG:Retarget() end)
  return cb
end

local function mkSlider(parent, label, key, min, max, step)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:SetValue(OG.db[key] or min)
  s.Low:SetText(tostring(min))
  s.High:SetText(tostring(max))
  s.Text:SetText(label)
  s:SetScript("OnValueChanged", function(_, v)
    OG.db[key] = v
    if key == "opacity" and OG.arrowFrame then OG.arrowFrame:SetAlpha(v) end
    if key == "scale" and OG.arrowFrame then OG.arrowFrame:SetScale(v) end
  end)
  return s
end

function OG:BuildOptions()
  if built then return end
  built = true
  local p = CreateFrame("Frame", "OptiGuideOptionsPanel", UIParent)
  p.name = "OptiGuide"

  local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("OptiGuide")
  local prev = t

  local ok = pcall(function()
    local checks = {
      { "Waypoint arrow", "arrow" },
      { "Guide panel", "panel" },
      { "Zone route guidance", "zoneRoute" },
      { "Auto accept quests", "autoAccept" },
      { "Auto turn-in quests", "autoTurnin" },
      { "Auto single-option gossip", "autoGossip" },
      { "Notify on new step (chat)", "notify" },
      { "Sound on objective complete", "soundComplete" },
      { "Show objective progress on arrow", "arrowProgress" },
      { "Show XP/hour + level ETA", "showXP" },
      { "Show rested XP", "showRested" },
      { "Hide arrow in combat", "hideCombat" },
      { "Hide arrow in instances", "hideInstance" },
      { "Compact panel (1 line)", "compact" },
    }
    for i, c in ipairs(checks) do
      local cb = mkCheck(p, c[1], c[2])
      cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, (i % 2 == 1) and -8 or -8)
      if i % 2 == 1 then cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
      else cb:SetPoint("LEFT", prev, "RIGHT", 220, 0); prev = cb end
      prev = cb
    end
    local s1 = mkSlider(p, "Arrow scale", "scale", 0.5, 3, 0.1)
    s1:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -30); prev = s1
    local s2 = mkSlider(p, "Arrow opacity", "opacity", 0.2, 1, 0.05)
    s2:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -30); prev = s2
  end)
  if not ok then
    local w = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    w:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
    w:SetText("Option widgets unavailable on this client - use /og commands.")
  end

  if Settings and Settings.RegisterCanvasLayoutCategory then
    pcall(function()
      local cat = Settings.RegisterCanvasLayoutCategory(p, "OptiGuide")
      Settings.RegisterAddOnCategory(cat)
      OG.optionsCat = cat
    end)
  elseif InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, p)
  end
end

OG:RegisterEvent("PLAYER_LOGIN", function() pcall(OG.BuildOptions, OG) end)
