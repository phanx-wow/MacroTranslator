--[[--------------------------------------------------------------------
	MacroTranslator
	Translates spell and item names in macros when you switch game languages.
	Copyright 2014 Phanx <addons@phanx.net>
	Do not redistribute. See the accompanying LICENSE files for details.
	http://www.wowinterface.com/downloads/info22721-MacroTranslator
	http://www.curse.com/addons/wow/macrotranslator
----------------------------------------------------------------------]]

local ADDON, Addon = ...
MacroTranslatorDB = {}

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

------------------------------------------------------------------------
--	Map spell names to IDs for the current locale at logout

function Addon:FindSpell(name)
	--print("FindSpell", name)
	local maxSpellIndex
	local a, b, arch, fish, cook, faid = GetProfessions()
	local highestProfessionTab = max(max(max(max(max(max(a or 0, b or 0), arch or 0), fish or 0), cook or 0, faid or 0)))
	if highestProfessionTab > 0 then
		local _, _, offset, numSpells = GetSpellTabInfo(highestProfessionTab)
		maxSpellIndex = 1 + offset + numSpells
	else
		local highestTab = GetNumSpellTabs()
		local _, _, offset, numSpells = GetSpellTabInfo(highestTab)
		maxSpellIndex = 1 + offset + numSpells
		-- might miss a few, but they should only be passives
	end
	for i = 1, maxSpellIndex do
		local skillType, skillID = GetSpellBookItemInfo(i, "spell")
		if skillType == "FLYOUT" then
			local _, _, num = GetFlyoutInfo(skillID)
			for j = 1, num do
				local spellID, _, _, spell = GetFlyoutSlotInfo(skillID, j)
				if spell and strlower(spell) == name then
					--print("    FindSpell =>", spell, "=> flyout")
					return GetSpellLink(spellID)
				end
			end
		else
			local spell = GetSpellBookItemName(i, "spell")
			if spell and strlower(spell) == name then
				--print("    FindSpell =>", spell, "=> spellbook")
				return GetSpellLink(i, "spell")
			end
		end
	end
	--print("    FindSpell =>", spell, "=> no match")
end

function Addon:SaveNameToID(name)
	name = strlower(name)
	--print("SaveNameToID:", name)
	--print("         checking name:", format("%q", name))
	local link = GetSpellLink(name) or select(2, GetItemInfo(name)) or self:FindSpell(name)
	if link then
		local id = strmatch(link, "|H(.-:%d+)")
		--print("found", id, link)
		--print("            found:", link, id)
		MacroTranslatorDB[name] = id
		return id
	end
	--print("no match")
	--	print("            no match for:", name)
end

function Addon:SaveMacroText(body)
	body = self:CleanMacro(body)
	--print("    ")
	--print("processing macro:", i, macro)
	for line in gmatch(body, "[^\n]+") do
		--print("   processing line:", line)
		local div = (strmatch(line, SLASH_CASTSEQUENCE1) or strmatch(line, SLASH_CASTSEQUENCE2)) and "[^,;]+" or "[^;]+"
		for name in gmatch(line, div) do
			--print("      processing part:", format("%q", name))
			--name = strlower(name)
			name = gsub(name, ".+%]", "")
			name = gsub(name, "[#/]%S+", "")
			name = gsub(name, "reset=%S+ ?", "") -- TODO: localize?
			name = strtrim(name)
			if strlen(name) > 0 then
				self:SaveNameToID(name)
			--else
			--	print("         skipping zero length")
			end
		end
	end
end

function Addon:SaveMacro(i) -- /run MacroTranslator:SaveMacro(45) /run MacroTranslator:PLAYER_LOGOUT()
	if type(i) ~= "number" or i < 1 or i > 72 then return end
	local macro, _, body = GetMacroInfo(i)
	if not macro then return end
	self:SaveMacroText(body)
end

------------------------------------------------------------------------

function Addon:TranslateName(name)
	name = strlower(name)
	--print("TranslateName:", name)
	local data = MacroTranslatorDB[name]
	if data then
		--print("found data:", data)
		local type, id, newname = strsplit(":", data)
		if type == "spell" then
			newname = GetSpellInfo(id)
		elseif type == "item" then
			newname = GetItemInfo(id)
		end
		if newname then
			MacroTranslatorDB[strlower(newname)] = data
			return newname, tonumber(id)
		end
	end
	--print("no match")
end

function Addon:RestoreMacroText(body)
	body = self:CleanMacro(body)
	local newbody = body
	--print("    ")
	--print("processing macro:", i, macro)
	for line in gmatch(newbody, "[^\n]+") do
		--print("   processing line:", line)
		local div = (strmatch(line, SLASH_CASTSEQUENCE1) or strmatch(line, SLASH_CASTSEQUENCE2)) and "[^,;]+" or "[^;]+"
		for name in gmatch(line, div) do
			--print("      processing part:", format("%q", name))
			name = gsub(name, ".+%]", "")
			name = gsub(name, "[#/]%S+", "")
			name = gsub(name, "[Rr][Ee][Ss][Ee][Tt]=%S+ ?", "") -- TODO: check if localization is possible
			name = strtrim(name)
			local oldname = name -- after stripping extras, but before strlowering
			if strlen(name) > 0 then
				local newname = self:TranslateName(name)
				if newname then
					newbody = gsub(newbody, oldname, newname)
			--		print("         replaced", oldname, "=>", newname)
			--	else
			--		print("         no match for", oldname)
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
		print("Can't update macro in combat!") -- TODO: queue
	else
		--print("updating macro!")
		icon = gsub(icon, ".+\\", "")
		EditMacro(i, macro, icon, newbody, isLocal, i > 36)
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
		function Clique:AddBinding(entry) --print("Clique:AddBinding")
			if entry.spell then
				Addon:SaveNameToID(entry.spell)
			elseif entry.macrotext then
				Addon:SaveMacroText(entry.macrotext)
			end
			AddBinding(self, entry)
		end

		local loading

		local BINDINGS_CHANGED = Clique.BINDINGS_CHANGED
		function Clique:BINDINGS_CHANGED() --print("Clique:BINDINGS_CHANGED", loading)
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
end

function f:PLAYER_LOGIN()
	local global, char = GetNumMacros() --print("PLAYER_LOGIN", global + char, "macros found")
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
	self:RegisterEvent("ADDON_LOADED")
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
	local name, type, id = strmatch(strtrim(strlower(cmd), "(.+) (%S+) (%d+)$"))
	if name and (type == "spell" or type == "item") and id then
		MacroTranslatorDB[name] = type..":"..id
	end

	f:PLAYER_LOGOUT()
	print("|cffffb000"..ADDON..":|r", MESSAGE_SAVED)
	f:PLAYER_LOGIN()
	print("|cffffb000"..ADDON..":|r", MESSAGE_RESTORED)
end