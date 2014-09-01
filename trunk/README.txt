MacroTranslator
==================

Translates the spell and item names in your macros when you switch game
languages. It currently works on regular macros and Clique macros.


Download
-----------

* [WoWInterface](http://www.wowinterface.com/downloads/info22721-MacroTranslator)
* [Curse](http://www.curse.com/addons/wow/macrotranslator)


Notes & Limitations
----------------------

For items, you can actually write "item:6948" instead of "Hearthstone",
but there is no equivalent "spell:id" format for spell names, and
personally I'd rather write out the item name if space permits, so this
addon will let you keep your macros readable and functional when you
switch to a different language.


### Limitations

Due to the way the Blizzard functions for getting information about
spells and items by name works, the translation will only work for
spells that have been seen in your spellbook, and for items that have
been seen in your bags, in each language you play in.

Normally, the addon only runs its translation routine when you log in.
If you need to run it manually for some reason (maybe you had a macro
for using an item that you didn't have in your bags when you logged in,
but picked up later, for example) you can use the `/macrotrans` command.


### How to back up your macros:

If you'd like to back up your macros before using this addon, they are
stored in the following locations:

* Account-wide:
  `World of Warcraft » WTF » Account » 123456#1 » macros-cache.txt`
* Character-specific:
  `World of Warcraft » WTF » Account » 123456#1 » RealmName » CharacterName » macros-cache.txt`


Feedback
-----------

Post a ticket on either download site, or a comment on WoWInterface.

If you are reporting a bug, please include directions I can follow to
reproduce the bug, whether it still happens when all other addons are
disabled, and the exact text of the related error message (if any) from
[BugSack](http://www.wowinterface.com/downloads/info5995-BugSack.html).

If you need to contact me privately, you can send me a private message
on either download site, or email me at <addons@phanx.net>.


License
----------

Copyright (c) 2014 Phanx. All rights reserved.  
See the accompanying LICENSE file for information about the conditions
under which redistribution and modification may be allowed.
