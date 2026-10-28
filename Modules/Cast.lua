local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("cast")
local media = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local castLatency, castSent
local castFrame
local castBarHidden
local options
local ringMod

local defaults = {
	profile = {
		barColor = {r=1, g=1, b=1, a=0.8},
		backgroundColor = {r=0.4, g=0.4, b=0.4, a=0.8},
		sparkColor = {r = 0.9, g = 0.8, b = 1, a = 1},
		latencyColor = {r=1, g=0, b=0, a=1},
		radius = 22,
		thickness = 25,
		sparkOnly = false,
		spellText = {
			enabled = false,
			font = "Calibri",
			fontSize = 12
		},
		hideCastBar = false
	}
}

function module:FixDatabase()
	if self.db.profile.version then
		-- nothing to do yet
	end
	self.db.profile.version = dbVersion
end

function module:OnInitialize()
	self.db = addon.db:RegisterNamespace("Cast", defaults)
	self:FixDatabase()
	ringMod = addon:GetModule("ring", true)
end

function module:GetOptions()
	options = {
		name = L["Casttime"],
		type = "group",
		args = {
			sparkOnly = {
				name = L["Show spark only"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.sparkOnly end,
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
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.radius end,
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
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.thickness end,
				set = function(info, val)
							self.db.profile.thickness = val
							self:ApplyOptions()
						end,
				order = 3
			},
			colors = {
				name = L["Colors"],
				type = "header",
				order = 20
			},
			barColor = {
				name = L["Bar"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.barColor.r, self.db.profile.barColor.g, self.db.profile.barColor.b, self.db.profile.barColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.barColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 21
			},
			bgColor = {
				name = L["Background"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.backgroundColor.r, self.db.profile.backgroundColor.g, self.db.profile.backgroundColor.b, self.db.profile.backgroundColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.backgroundColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 22
			},
			sparkColor = {
				name = L["Spark"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.sparkColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 23
			},
			latencyColor = {
				name = L["Latency color"],
				type = "color",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.latencyColor.r, self.db.profile.latencyColor.g, self.db.profile.latencyColor.b, self.db.profile.latencyColor.a end,
				set = function(info, r, g, b, a)
							self.db.profile.latencyColor = {r=r, g=g, b=b, a=a}
							self:ApplyOptions()
						end,
				hasAlpha = true,
				order = 24
			},
			spellText = {
				name = L["Spell Text"],
				type = "header",
				order = 30
			},
			spellTextEnabled = {
				name = L["Enabled"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.spellText.enabled end,
				set = function(info,val)
						self.db.profile.spellText.enabled = val
						self:ApplyOptions()
					end,
				order = 31
			},
			font = {
				name = L["Font"],
				type = "select",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				dialogControl = 'LSM30_Font',
				get = function() return self.db.profile.spellText.font end,
				set = function(_, value)
							self.db.profile.spellText.font = value
							self:ApplyOptions()
						end,
				values = media:HashTable("font"),
				order = 32
			},
			fontSize = {
				name = L["Font Size"],
				type = "range",
				disabled = function() return (not addon.db.profile.modules.cast or not self.db.profile.spellText.enabled) end,
				min = 1,
				max = 30,
				step = 1,
				get = function() return self.db.profile.spellText.fontSize end,
				set = function(_, value)
							self.db.profile.spellText.fontSize = value
							self:ApplyOptions()
						end,
				order = 33
			},
			misc = {
				name = L["Miscellaneous"],
				type = "header",
				order = 40
			},
			defaults = {
				name = L["Restore defaults"],
				type = "execute",
				disabled = function() return not addon.db.profile.modules.cast end,
				func = function()
							self.db:ResetProfile()
							self:ApplyOptions()
						end,
				order = 41
			},
			hideCastBar = {
				name = L["Hide default castbar"],
				type = "toggle",
				disabled = function() return not addon.db.profile.modules.cast end,
				get = function(info) return self.db.profile.hideCastBar end,
				set = function(info,val)
						self.db.profile.hideCastBar = val
						self:UpdateCastBar()
					end,
				order = 42
			}
		}
	}
	return options
end

function module:OnEnable()
	self:ApplyOptions()
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_START")
	self:RegisterEvent("UNIT_SPELLCAST_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
	-- Evokers' empowered spells
	self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
	self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
	self:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")
end

function module:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
	self:UpdateCastBar()
end

function module:Show()
	addon:Show("cast")
	if ringMod and ringMod:IsEnabled() then ringMod:Show("cast") end
	if self.db.profile.spellText.enabled then
		castFrame.spellText:Show()
	else
		castFrame.spellText:Hide()
	end

	castFrame:Show()
	castFrame.donut:Show()
	castFrame.latencyDonut:Show()
	castFrame.latencyDonut:SetAngle(castLatency * 360)
end

function module:Hide()
	castFrame:Hide()
	castFrame.donut:Hide()
	castFrame.latencyDonut:Hide()

	if ringMod and ringMod:IsEnabled() then ringMod:Hide("cast") end
	addon:Hide("cast")
end

-- The player's own casts aren't secret, but a spell can be flagged to be; such
-- a cast just isn't shown.
local function IsSecret(...)
	if not issecretvalue then return false end
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

-- The cast's name, and when it started and ends (ms).
local function CastTimes(event)
	local name, startTime, endTime, _
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
		name, _, _, startTime, endTime = UnitCastingInfo("player")
	else
		name, _, _, startTime, endTime = UnitChannelInfo("player")
		-- An empowered spell can be held at full power past its end.
		if endTime and (event == "UNIT_SPELLCAST_EMPOWER_START" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE") then
			endTime = endTime + GetUnitEmpowerHoldAtMaxTime("player")
		end
	end
	if not startTime or not endTime or IsSecret(startTime, endTime) then return end
	return name, startTime, endTime
end

local function StartCast(event)
	local name, startTime, endTime = CastTimes(event)
	if not name then return end
	local castDuration = endTime - startTime
	if castDuration <= 0 then return end

	-- Time from asking for the spell to the server starting it.
	local sendLag = castSent and (GetTime() * 1000 - castSent) or 0
	castSent = nil
	if sendLag > castDuration then sendLag = castDuration end
	castLatency = sendLag / castDuration

	castFrame.spellText:SetText(name)
	castFrame.donut:Start(startTime / 1000, castDuration / 1000)
	module:Show()
end

-- The same cast, moved: pushed back, or a channel or empower changed.
local function UpdateCast(event)
	local _, startTime, endTime = CastTimes(event)
	if startTime and castFrame:IsShown() then
		castFrame.donut:Start(startTime / 1000, (endTime - startTime) / 1000)
	end
end

function module:UNIT_SPELLCAST_SENT(_, unit)
	if unit ~= 'player' then return end
	castSent = GetTime() * 1000
end

function module:UNIT_SPELLCAST_START(event, unit)
	if unit ~= 'player' then return end
	StartCast(event)
end

module.UNIT_SPELLCAST_CHANNEL_START = module.UNIT_SPELLCAST_START
module.UNIT_SPELLCAST_EMPOWER_START = module.UNIT_SPELLCAST_START

function module:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= 'player' then return end
	UpdateCast(event)
end

module.UNIT_SPELLCAST_CHANNEL_UPDATE = module.UNIT_SPELLCAST_DELAYED
module.UNIT_SPELLCAST_EMPOWER_UPDATE = module.UNIT_SPELLCAST_DELAYED

function module:UNIT_SPELLCAST_STOP(_, unit)
	if unit ~= 'player' then return end
	self:Hide()
end

module.UNIT_SPELLCAST_INTERRUPTED = module.UNIT_SPELLCAST_STOP
module.UNIT_SPELLCAST_CHANNEL_STOP = module.UNIT_SPELLCAST_STOP
module.UNIT_SPELLCAST_EMPOWER_STOP = module.UNIT_SPELLCAST_STOP

-- Hide Blizzard's cast bar by giving it no unit, and give it the player back
-- only if we took it away.
function module:UpdateCastBar()
	if self.db.profile.hideCastBar and self:IsEnabled() then
		PlayerCastingBarFrame:SetUnit(nil)
		castBarHidden = true
	elseif castBarHidden then
		PlayerCastingBarFrame:SetUnit("player", true, false)
		castBarHidden = nil
	end
end

function module:ApplyOptions()
	local anchor = addon.anchor
	if self:IsEnabled() then
		if not castFrame then
			castFrame = CreateFrame("Frame")
			castFrame:SetParent(anchor)
			castFrame:SetAllPoints()

			local donut = addon.donut:New(false, self.db.profile.radius, self.db.profile.thickness, self.db.profile.latencyColor, self.db.profile.backgroundColor)
			donut:AttachTo(castFrame)
			castFrame.latencyDonut = donut

			local bgcm = {r = 0, g = 0, b = 0, a = 0}
			donut = addon.donut:New(true, self.db.profile.radius, self.db.profile.thickness, self.db.profile.barColor, bgcm)
			donut:AttachTo(castFrame)
			-- Over the latency ring.
			donut.bgFrame:SetFrameLevel(castFrame.latencyDonut.bgFrame:GetFrameLevel() + 2)
			donut:SetSpark(true)
			donut:SetOnDone(function() module:Hide() end)
			castFrame.donut = donut

			castFrame.spellText = castFrame:CreateFontString(nil, "OVERLAY")
		end
		self:Hide()

		local donut = castFrame.donut
		donut:SetRadius(self.db.profile.radius)
		donut:SetThickness(self.db.profile.thickness)
		donut:SetBarColor(self.db.profile.barColor)
		donut:SetSparkColor(self.db.profile.sparkColor)
		donut:SetSparkOnly(self.db.profile.sparkOnly)

		-- The latency sits under the bar, on the background ring.
		donut = castFrame.latencyDonut
		donut:SetRadius(self.db.profile.radius)
		donut:SetThickness(self.db.profile.thickness)
		donut:SetBarColor(self.db.profile.latencyColor)
		donut:SetBackgroundColor(self.db.profile.backgroundColor)
		donut:SetSparkOnly(self.db.profile.sparkOnly)

		local spellText = castFrame.spellText
		spellText:ClearAllPoints()
		spellText:SetPoint("BOTTOM", castFrame, "CENTER", 0, self.db.profile.radius + 5)
		spellText:SetFont(media:Fetch("font", self.db.profile.spellText.font), self.db.profile.spellText.fontSize)
	end
	self:UpdateCastBar()
end

function module:Unlock(cursor)
	if not self.db.profile.sparkOnly then
		castFrame:SetParent(cursor)
		castFrame:SetAllPoints()
		castFrame:Show()
		castFrame.donut:Show()
		castFrame.latencyDonut:Show()
		castFrame.donut:SetAngle(320)
		castFrame.latencyDonut:SetAngle(60)
	end
end

function module:Lock()
	if not self.db.profile.sparkOnly then
		self:Hide()
		castFrame:SetParent(addon.anchor)
		castFrame:SetAllPoints()
	end
end
