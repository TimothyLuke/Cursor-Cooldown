local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("gcd")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

-- The global cooldown's own spell: every spell on the GCD shares its cooldown.
local GCD_SPELL = 61304
local gcdFrame
local options
local ringMod

local defaults = {
  profile = {
    barColor = {r = 1, g = 1, b = 1, a = 0.8},
    backgroundColor = {r = 0.4, g = 0.4, b = 0.4, a = 0.8},
    sparkColor = {r = 0.9, g = 0.8, b = 1, a = 1},
    radius = 23,
    thickness = 25,
    sparkOnly = false
  }
}

function module:OnEnable()
  self:ApplyOptions()
  self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN")
end

function module:OnDisable()
  self:UnregisterAllEvents()
  self:Hide()
end

function module:FixDatabase()
  if self.db.profile.version then
  -- nothing to do yet
  end
  self.db.profile.version = dbVersion
end

function module:OnInitialize()
  self.db = addon.db:RegisterNamespace("CC", defaults)
  self:FixDatabase()
  ringMod = addon:GetModule("ring", true)
end

function module:GetOptions()
  options = {
    name = "CC",
    type = "group",
    args = {
      sparkOnly = {
        name = L["Show spark only"],
        type = "toggle",
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        get = function(info)
          return self.db.profile.sparkOnly
        end,
        set = function(info, val)
          self.db.profile.sparkOnly = val
          self:ApplyOptions()
        end,
        order = 1
      },
      radius = {
        name = L["Radius"],
        type = "range",
        min = 10,
        max = 256,
        step = 1,
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        get = function(info)
          return self.db.profile.radius
        end,
        set = function(info, val)
          self.db.profile.radius = val
          self:ApplyOptions()
        end,
        order = 2
      },
      thickness = {
        name = L["Thickness"],
        type = "range",
        min = 15,
        max = 25,
        step = 5,
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        get = function(info)
          return self.db.profile.thickness
        end,
        set = function(info, val)
          self.db.profile.thickness = val
          self:ApplyOptions()
        end,
        order = 3
      },
      colors = {
        name = L["Colors"],
        type = "header",
        order = 10
      },
      barColor = {
        name = L["Bar"],
        type = "color",
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        get = function(info)
          return self.db.profile.barColor.r, self.db.profile.barColor.g, self.db.profile.barColor.b, self.db.profile.barColor.a
        end,
        set = function(info, r, g, b, a)
          self.db.profile.barColor = {r = r, g = g, b = b, a = a}
          self:ApplyOptions()
        end,
        hasAlpha = true,
        order = 11
      },
      bgColor = {
        name = L["Background"],
        type = "color",
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        get = function(info)
          return self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a
        end,
        set = function(info, r, g, b, a)
          self.db.profile.backgroundColor = {r = r, g = g, b = b, a = a}
          self:ApplyOptions()
        end,
        hasAlpha = true,
        order = 12
      },
      sparkColor = {
        name = L["Spark"],
        type = "color",
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        get = function(info)
          return self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a
        end,
        set = function(info, r, g, b, a)
          self.db.profile.sparkColor = {r = r, g = g, b = b, a = a}
          self:ApplyOptions()
        end,
        hasAlpha = true,
        order = 13
      },
      misc = {
        name = L["Miscellaneous"],
        type = "header",
        order = 20
      },
      defaults = {
        name = L["Restore defaults"],
        type = "execute",
        disabled = function()
          return not addon.db.profile.modules.gcd
        end,
        func = function()
          self.db:ResetProfile()
          self:ApplyOptions()
        end,
        order = 21
      }
    }
  }
  return options
end

function module:Show()
  addon:Show("gcd")
  if ringMod and ringMod:IsEnabled() then
    ringMod:Show("gcd")
  end
  gcdFrame:Show()
  gcdFrame.donut:Show()
end

function module:Hide()
  gcdFrame:Hide()
  gcdFrame.donut:Hide()

  if ringMod and ringMod:IsEnabled() then
    ringMod:Hide("gcd")
  end
  addon:Hide("gcd")
end

function module:ApplyOptions()
  local anchor = addon.anchor
  if self:IsEnabled() then
    if not gcdFrame then
      gcdFrame = CreateFrame("Frame")
      gcdFrame:SetParent(anchor)
      gcdFrame:SetAllPoints()

      local donut =
        addon.donut:New(
        true,
        self.db.profile.radius,
        self.db.profile.thickness,
        self.db.profile.barColor,
        self.db.profile.backgroundColor
      )
      donut:AttachTo(gcdFrame)
      donut:SetSpark(true)
      donut:SetOnDone(
        function()
          module:Hide()
        end
      )
      gcdFrame.donut = donut
    end
    self:Hide()

    local donut = gcdFrame.donut
    donut:SetRadius(self.db.profile.radius)
    donut:SetThickness(self.db.profile.thickness)
    donut:SetBarColor(self.db.profile.barColor)
    donut:SetBackgroundColor(self.db.profile.backgroundColor)
    donut:SetSparkColor(self.db.profile.sparkColor)
    donut:SetSparkOnly(self.db.profile.sparkOnly)
  end
end

-- isActive is never secret, so it can say whether the GCD is running; the
-- times themselves go to the ring as a duration object.
function module:SPELL_UPDATE_COOLDOWN()
  local info = C_Spell.GetSpellCooldown(GCD_SPELL)
  if info and info.isActive then
    gcdFrame.donut:StartDuration(C_Spell.GetSpellCooldownDuration(GCD_SPELL))
    self:Show()
  end
end

function module:Unlock(cursor)
  if not self.db.profile.sparkOnly then
    gcdFrame:SetParent(cursor)
    gcdFrame:SetAllPoints()
    gcdFrame:Show()
    gcdFrame.donut:Show()
    gcdFrame.donut:SetAngle(195)
  end
end

function module:Lock()
  if not self.db.profile.sparkOnly then
    self:Hide()
    gcdFrame:SetParent(addon.anchor)
    gcdFrame:SetAllPoints()
  end
end
