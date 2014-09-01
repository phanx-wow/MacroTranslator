--[[--------------------------------------------------------------------
	MacroTranslator
	Translates spell and item names in macros when you switch game languages.
	Copyright (c) 2014 Phanx. All rights reserved.
	See the accompanying README and LICENSE files for details.
	http://www.wowinterface.com/downloads/info22721-MacroTranslator
	http://www.curse.com/addons/wow/macrotranslator
----------------------------------------------------------------------]]

local ADDON, Addon = ...
MacroTranslatorDB = {}
MacroTranslator = Addon -- #DEBUG

local isWOD = select(4, GetBuildInfo()) >= 60000

------------------------------------------------------------------------
--	General utilities

function Addon:CleanMacro(body)
	if type(body) ~= "string" then return "" end
	local length = strlen(body)
	if strsub(body, length, length) == "\n" then
		body = strsub(body, 1, length - 1)
	end
	body = gsub(body, "; ", ";")
	body = gsub(body, "%] ", "]")
	body = gsub(body, "%[(^%]+), ", "[%1,")
	return body
end

local spellbook = {}

function Addon:ScanSpellbook()
	--print("Collecting spell names...")

	local p1, p2, p3, p4, p5, p6 = GetProfessions()
	local numTabs = max(p1 or 0, p2 or 0, p3 or 0, p4 or 0, p5 or 0, p6 or 0)
	if numTabs == 0 then
		numTabs = GetNumSpellTabs()
	end

	local _, _, offset, numSpells = GetSpellTabInfo(numTabs)
	for i = 1, offset + numSpells do
		local skillType, id = GetSpellBookItemInfo(i, "spell")
		if skillType == "FLYOUT" then
			local _, _, numFlyoutSpells = GetFlyoutInfo(id)
			for j = 1, numFlyoutSpells do
				local id, _, _, name = GetFlyoutSlotInfo(id, j)
				spellbook[strlower(name)] = GetSpellLink(id)
			end
		else
			local name = GetSpellBookItemName(i, "spell")
			spellbook[strlower(name)] = GetSpellLink(id)
		end
	end

	if isWOD then
		local talentGroup = GetActiveSpecGroup(false)
		GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
		for i = 1, MAX_NUM_TALENT_TIERS * NUM_TALENT_COLUMNS do
			GameTooltip:SetTalent(i)
			local name, _, id = GameTooltip:GetSpell()
			spellbook[strlower(name)] = GetSpellLink(id)
		end
		GameTooltip:Hide()
	else
		local talentGroup = GetActiveSpecGroup(false)
		GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
		for i = 1, GetNumTalents() do
			GameTooltip:SetTalent(i, nil, talentGroup)
			local name, _, id = GameTooltip:GetSpell()
			spellbook[strlower(name)] = GetSpellLink(id)
		end
		GameTooltip:Hide()
	end

	--print("Done.")
end

------------------------------------------------------------------------
--	Map spell names to IDs for the current locale at logout

function Addon:FindSpell(name)
	--print("FindSpell:", name)
	name = strlower(name)

	if not next(spellbook) then
		self:ScanSpellbook()
	end

	local link = spellbook[name]
	if link then
		--print("    ", spell, "=> spellbook")
		return link
	else
		--print("    ", spell, "=> no match")
		return
	end
end

function Addon:SaveNameToID(name)
	--print("SaveNameToID:", name)
	--print("         checking name:", format("%q", name))
	local link = GetSpellLink(name) or select(2, GetItemInfo(name)) or self:FindSpell(name)
	if link then
		local id = strmatch(link, "|H(.-:%d+)")
		--print("found", id, link)
		MacroTranslatorDB[strlower(name)] = id
		return id
	end
	--print("no match")
	--print("            no match for:", name)
end

function Addon:SaveMacroText(body)
	--body = self:CleanMacro(body)
	for line in gmatch(body, "[^\n]+") do
		--print("   processing line:", line)
		local div = (strmatch(line, SLASH_CASTSEQUENCE1) or strmatch(line, SLASH_CASTSEQUENCE2)) and "[^,;]+" or "[^;]+"
		for name in gmatch(line, div) do
			--print("      processing part:", format("%q", name))
			--name = strlower(name)
			name = gsub(name, ".+%]", "")
			name = gsub(name, "[#/]%S+", "")
			name = gsub(name, "reset=%S+ ?", "")
			name = strtrim(name)
			if strlen(name) > 0 then
				self:SaveNameToID(name)
			else
				--print("         skipping zero length")
			end
		end
	end
end

function Addon:SaveMacro(i) -- /run MacroTranslator:SaveMacro(50) /run MacroTranslator:PLAYER_LOGOUT()
	if type(i) ~= "number" or i < 1 or i > 72 then return end
	local macro, _, body = GetMacroInfo(i)
	if not macro then return end
	--print("    ")
	--print("SaveMacro:", i, macro)
	self:SaveMacroText(body)
end

------------------------------------------------------------------------

function Addon:TranslateName(name)
	name = strlower(name)
	--print("TranslateName:", name)
	local data = MacroTranslatorDB[name]
	if data then
		--print("found data:", data)
		local nameType, id, name = strsplit(":", data)
		id = tonumber(id)
		if nameType == "spell" then
			name = GetSpellInfo(id)
		elseif nameType == "item" then
			name = GetItemInfo(id)
		end
		if name then
			MacroTranslatorDB[strlower(name)] = data
			return name, id
		end
	end
	--print("no match")
end

function Addon:RestoreMacroText(body)
	-- body = self:CleanMacro(body)
	local newbody = body
	--print("    ")
	--print("RestoreMacroText:", i, macro)
	for line in gmatch(newbody, "[^\n]+") do
		--print("   processing line:", line)
		local div = (strmatch(line, SLASH_CASTSEQUENCE1) or strmatch(line, SLASH_CASTSEQUENCE2)) and "[^,;]+" or "[^;]+"
		for name in gmatch(line, div) do
			--print("      processing part:", format("%q", name))
			name = gsub(name, ".+%]", "")
			name = gsub(name, "[#/]%S+", "")
			name = gsub(name, "[Rr][Ee][Ss][Ee][Tt]=%S+ ?", "")
			name = strtrim(name)
			local oldname = name -- after stripping extras, but before strlowering
			if strlen(name) > 0 then
				local newname = self:TranslateName(name)
				if newname then
					newbody = gsub(newbody, oldname, newname)
					--print("         replaced", oldname, "=>", newname)
				else
					--print("         no match for", oldname)
				end
			end
		end
	end
	--print("new:", newbody)
	if newbody ~= body then
		return newbody
	end
end

function Addon:RestoreMacro(i) -- /run MacroTranslator:RestoreMacro(46)
	if type(i) ~= "number" or i < 1 or i > 72 then return end
	local macro, icon, body, isLocal = GetMacroInfo(i)
	if not macro then return end
	local newbody = self:RestoreMacroText(body)
	if not newbody then return end
	if InCombatLockdown() then
		--print("Can't update macro in combat!") -- TODO: queue
	else
		--print("updating macro!")
		icon = gsub(icon, ".+\\", "")
		self.editing = true
		EditMacro(i, macro, icon, newbody, isLocal, i > 36)
		self.editing = nil
	end
end

------------------------------------------------------------------------

local f = CreateFrame("Frame", ADDON)
f:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LOGOUT")
Addon.EventFrame = f

------------------------------------------------------------------------

local addons = {
	Clique = function()
		local AddBinding = Clique.AddBinding
		function Clique:AddBinding(entry)
			--print("Clique:AddBinding")
			if entry.spell then
				Addon:SaveNameToID(entry.spell)
			elseif entry.macrotext then
				Addon:SaveMacroText(entry.macrotext)
			end
			AddBinding(self, entry)
		end

		local loading

		local BINDINGS_CHANGED = Clique.BINDINGS_CHANGED
		function Clique:BINDINGS_CHANGED()
			--print("Clique:BINDINGS_CHANGED", loading)
			local bindings = Clique.bindings
			for i = 1, #bindings do
				local entry = bindings[i]
				if entry.spell then
					local name = Addon:TranslateName(entry.spell)
					--print("spell", entry.spell, "->", name)
					entry.spell = name or entry.spell
				elseif entry.macrotext then
					Addon:SaveMacroText(entry.macrotext)
					local text = Addon:RestoreMacroText(entry.macrotext)
					--print("macro", entry.macrotext)
					--print("   ->", text)
					entry.macrotext = text or entry.macrotext
				end
			end
			if not loading then
				BINDINGS_CHANGED(self)
			end
		end

		if Clique.bindings then
			--loading = true
			Clique:BINDINGS_CHANGED()
			loading = nil
		end
	end
}

function f:ADDON_LOADED(addon)
	local func = addons[addon]
	if func then
		addons[addon] = nil
		func()
	end
	if not next(addons) then
		self:UnregisterEvent("ADDON_LOADED")
	end
end

function f:PLAYER_LOGIN()
	local global, char = GetNumMacros()
	--print("PLAYER_LOGIN", global + char, "macros found")
	for i = 1, global do
		Addon:RestoreMacro(i)
	end
	for i = 1, char do
		Addon:RestoreMacro(i + 36)
	end

	for addon, func in pairs(addons) do
		if IsAddOnLoaded(addon) then
			addons[addon] = nil
			func()
		end
	end
	if next(addons) then
		self:RegisterEvent("ADDON_LOADED")
	end
end

function f:PLAYER_LOGOUT()
	local global, char = GetNumMacros()
	for i = 1, global do
		Addon:SaveMacro(i)
	end
	for i = 1, char do
		Addon:SaveMacro(i + 36)
	end
end

hooksecurefunc("EditMacro", function(i)
	if self.editing then return end
	--print("EditMacro", i)
	if type(i) == "string" then
		i = GetMacroIndexByName(i)
	end
	if i > 0 then
		Addon:SaveMacro(i)
	end
end)

------------------------------------------------------------------------

local MESSAGE_SAVED = "Spell and item names for the current language have been saved."
local MESSAGE_RESTORED = "Your macros have been updated."
if GetLocale() == "deDE" then
	MESSAGE_SAVED = "Zauber- und Gegenstandsnamen der aktuellen Sprache wurden gespiechert."
	MESSAGE_RESTORED = "Eure Makros wurden aktualisiert."
elseif GetLocale():match("^es") then
	MESSAGE_SAVED = "Los nombres de hechizos y objetos en el idioma actual han sido guardados."
	MESSAGE_RESTORED = "Tus macros han sido actualizados."
end

SLASH_MACROTRANSLATOR1 = "/macrotrans"
SlashCmdList.MACROTRANSLATOR = function(cmd)
	local type, id, name = strmatch(strlower(cmd), "^%s*(%S+)%s*(%d+)%s*(.+)%s*$")
	if id and name and (type == "spell" or type == "item") then
		MacroTranslatorDB[name] = type..":"..id
	end
	f:PLAYER_LOGOUT()
	print("|cffffb000"..ADDON..":|r", MESSAGE_SAVED)
	f:PLAYER_LOGIN()
	print("|cffffb000"..ADDON..":|r", MESSAGE_RESTORED)
end