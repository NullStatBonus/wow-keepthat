# Adding a language

The addon's own text is English. Item and profession names come from the game, so on a client in another language the tooltip line, toasts and material pages already use that language's names where the game provides them. A translation file changes the addon's sentences: settings, tooltip lines, toasts and chat replies.

## How it works

Every sentence the player reads is written in the code as `L["English sentence"]`. English is the key, so a sentence without a translation shows as written and a missing entry never raises an error. A language is one file in `KeepThat/Locales/` that assigns translations when the game runs in that locale.

## Steps

1. Create `KeepThat/Locales/<locale>.lua`, using the game's locale name: `deDE`, `frFR`, `esES`, `esMX`, `itIT`, `ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`. Start it with:

   ```lua
   if GetLocale() ~= "deDE" then return end   -- your locale here
   local _, ns = ...
   local L = ns.L
   ```

2. Add one line per sentence: `L["English sentence"] = "Your translation"`. Copy the English exactly, including punctuation, from the code or from `grep -rhoE 'L\["[^"]*"\]' KeepThat --include='*.lua'`.
3. List the file in **both** `KeepThat_Vanilla.toc` and `KeepThat_Camelot.toc`, right after `Locales\enUS.lua`.
4. Run `make test` (or `luajit tests/run.lua locale`). It fails if a key is not a sentence the code asks for, or if a translation has a different number of `%s`/`%d` than its English.

You do not have to translate everything. Anything you leave out shows in English.

## Rules for translators

- **Keep placeholders.** `%s` and `%d` are replaced with a name or a number. Keep the same count. When the order has to change, use positions: `"%2$s costs %1$s."`.
- **Keep markup.** Do not add `|c...|r` color codes to a translation. In chat text, a literal `|` is written `||`.
- **Whole sentences.** Each key is a complete sentence so it can be reordered; do not split one.
- **Item and profession names** are not translated here. The game supplies them: profession names in "Endgame: <Profession>" come from the client's own trade skill or profession spell names, and item names from the client's item cache (the English name from the data shows only until the game has the item).
- **List separator.** `L[", "]` joins short lists inside one sentence (the "for <item>" parts); translate it if your language uses another separator.
- **Debug text** (`/kt log`) stays English so reports are readable by everyone.

## Nothing is matched by English text

Materials, recipes and professions are recognised by ID, never by name, so the marks work on a client in any language. Only the addon's own sentences need translating.
