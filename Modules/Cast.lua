local addon = LibStub("AceAddon-3.0"):GetAddon("CC")
local module = addon:NewModule("cast")
local media = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CC")
local dbVersion = 1

local GetTime = GetTime
local castStartTime, castEndTime, castDuration, castInterrupted, castLatency, castSent, isCasting
local castFrame
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
						if val then
							PlayerCastingBarFrame:UnregisterAllEvents()
							PlayerCastingBarFrame:Hide()
						else
							PlayerCastingBarFrame:UnregisterAllEvents()
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
							PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
						end
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
	self:RegisterEvent("UNIT_SPELLCAST_FAILED")
	self:RegisterEvent("UNIT_SPELLCAST_DELAYED")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
	self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
end

function module:OnDisable()
	self:UnregisterAllEvents()
	self:Hide()
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

	local angle = castLatency * 360
	if not module.db.profile.sparkOnly then
		castFrame.latencyDonut:SetAngle(angle)
	end
end

function module:Hide()
	castFrame:Hide()

	if ringMod and ringMod:IsEnabled() then ringMod:Hide("cast") end
	addon:Hide("cast")
end

local function OnUpdate(self, elapsed)
	local castPerc = (1000 * GetTime() - castStartTime) / castDuration
	if castDuration ~= 0 and castPerc < 1 then
		local angle = castPerc * 360
		if not module.db.profile.sparkOnly then
			castFrame.donut:SetAngle(angle)
		end
		angle = 360 -(-90 + angle)

		local x = cos(angle) * module.db.profile.radius * 0.95
		local y = sin(angle) * module.db.profile.radius * 0.95
		local spark = castFrame.sparkTexture
		spark:SetRotation(rad(angle+90))
		spark:ClearAllPoints()
		spark:SetPoint("CENTER", castFrame, "CENTER", x, y)

		if module.db.profile.sparkOnly and castPerc > 1-castLatency then
			spark:SetVertexColor(module.db.profile.latencyColor.r, module.db.profile.latencyColor.g, module.db.profile.latencyColor.b, module.db.profile.latencyColor.a)
		else
			spark:SetVertexColor(module.db.profile.sparkColor.r, module.db.profile.sparkColor.g, module.db.profile.sparkColor.b, module.db.profile.sparkColor.a)
		end
	else
		module:Hide()
	end
end

function module:UNIT_SPELLCAST_SENT(_, unit)
	if unit ~= 'player' then return end
	castSent = GetTime() * 1000
end

function module:UNIT_SPELLCAST_START(_, unit, action)
	if unit ~= 'player' then return end
	_, _, _, castStartTime, castEndTime, _, _, _, spellid = UnitCastingInfo(unit)
	spell = C_Spell.GetSpellInfo(spellid).name
	sendLag = (castSent and castSent > 0) and GetTime() * 1000 - castSent or 0
	castDuration = castEndTime and castEndTime - castStartTime or 0
	sendLag = sendLag > castDuration and castDuration or sendLag
	castLatency = sendLag / castDuration
	if castFrame.spellText then
		castFrame.spellText:SetText(spell)
	end
	self:Show()
end

function module:UNIT_SPELLCAST_STOP(_, unit)
	if unit ~= 'player' then return end
	self:Hide()
end

function module:UNIT_SPELLCAST_FAILED(event, unit)
	if unit ~= 'player' then return end
	--self:Hide()
end

function module:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= 'player' then return end
	self:Hide()
end

function module:UNIT_SPELLCAST_DELAYED(event, unit)
	if unit ~= 'player' then return end
	_, _, _, _, castStartTime, castEndTime = UnitCastingInfo(unit)
	castDuration = castEndTime and castEndTime - castStartTime or 0
end

function module:UNIT_SPELLCAST_CHANNEL_START(event,unit)
	if unit ~= 'player' then return end

	spell, _, _, castStartTime, castEndTime = UnitChannelInfo(unit)
	sendLag = (castSent and castSent > 0) and GetTime() * 1000 - castSent or 0
	castDuration = castEndTime and castEndTime - castStartTime or 0
	sendLag = sendLag > castDuration and castDuration or sendLag
	castLatency = sendLag / castDuration
	castFrame.spellText:SetText(spell)
	self:Show()
end

function module:UNIT_SPELLCAST_CHANNEL_STOP(event,unit)
	if unit ~= 'player' then return end
	self:Hide()
end

function module:UNIT_SPELLCAST_CHANNEL_UPDATE(event,unit)
	if unit ~= 'player' then return end
	_, _, _, castStartTime, castEndTime = UnitChannelInfo(unit)
	castDuration = castEndTime - castStartTime
end

function module:ApplyOptions()
	local anchor = addon.anchor
	if self:IsEnabled() then
		if not castFrame then
			castFrame = CreateFrame("Frame")
			castFrame:SetParent(anchor)
			castFrame:SetAllPoints()

			castFrame.sparkTexture = castFrame:CreateTexture(nil, 'OVERLAY')
			castFrame.sparkTexture:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
			castFrame.sparkTexture:SetBlendMode("ADD")
		end
		self:Hide()

		if not self.db.profile.sparkOnly then
			if not castFrame.donut then
				local donut = addon.donut:New(false, self.db.profile.radius, self.db.profile.thickness, self.db.profile.latencyColor, self.db.profile.backgroundColor)
				donut:AttachTo(castFrame)
				castFrame.latencyDonut = donut

				local bgcm = {}
				bgcm.r = 0
				bgcm.g = 0
				bgcm.b = 0
				bgcm.a = 0
				donut = addon.donut:New(true, self.db.profile.radius, self.db.profile.thickness, self.db.profile.barColor, bgcm, donut.frame)
				donut:AttachTo(castFrame)
				castFrame.donut = donut
			else
				local donut = castFrame.donut
				donut:SetRadius(self.db.profile.radius)
				donut:SetThickness(self.db.profile.thickness)
				donut:SetBarColor(self.db.profile.barColor)
				donut:SetBackgroundColor(self.db.profile.backgroundColor)

				donut = castFrame.latencyDonut
				donut:SetRadius(self.db.profile.radius)
				donut:SetThickness(self.db.profile.thickness)
				donut:SetBarColor(self.db.profile.latencyColor)
				donut:SetBackgroundColor(self.db.profile.backgroundColor)
			end

			castFrame:SetScript("OnShow", function(self) self.donut:Show() self.latencyDonut:Show() end)
			castFrame:SetScript("OnHide", function(self) self.donut:Hide() self.latencyDonut:Hide() end)
		elseif castFrame.donut then
			castFrame.donut:Hide()
			castFrame.latencyDonut:Hide()
			castFrame:SetScript("OnShow", nil)
			castFrame:SetScript("OnHide", nil)
		end

		castFrame.sparkTexture:SetVertexColor(self.db.profile.sparkColor.r, self.db.profile.sparkColor.g, self.db.profile.sparkColor.b, self.db.profile.sparkColor.a)
		castFrame.sparkTexture:SetWidth(self.db.profile.radius)
		castFrame.sparkTexture:SetHeight(self.db.profile.radius)
		castFrame.sparkTexture:Show()

		if self.db.profile.spellText then
			local spellText = castFrame.spellText or castFrame:CreateFontString(nil, "OVERLAY")
			spellText:ClearAllPoints()
			spellText:SetPoint("BOTTOM", castFrame, "CENTER", 0, self.db.profile.radius + 5)
			spellText:SetFont(media:Fetch("font", self.db.profile.spellText.font), self.db.profile.spellText.fontSize)
			spellText:Show()
			castFrame.spellText = spellText
		elseif castFrame.spellText then
			castFrame.spellText:ClearAllPoints()
			castFrame.spellText:Hide()
		end

		if self.db.profile.hideCastBar then
			PlayerCastingBarFrame:UnregisterAllEvents()
			PlayerCastingBarFrame:Hide()
		else
			PlayerCastingBarFrame:UnregisterAllEvents()
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
			PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
		end

		castFrame:SetScript('OnUpdate', OnUpdate)
	end
end

function module:Unlock(cursor)
	if not self.db.profile.sparkOnly then
		castFrame:SetScript("OnUpdate", nil)
		castFrame.donut:SetAngle(320)
		castFrame.latencyDonut:SetAngle(60)
		castFrame:SetParent(cursor)
		castFrame:SetAllPoints()
		castFrame:Show()
	end
end

function module:Lock()
	if not self.db.profile.sparkOnly then
		castFrame:Hide()
		castFrame:SetParent(addon.anchor)
		castFrame:SetAllPoints()
		castFrame:SetScript("OnUpdate", OnUpdate)
	end
end
