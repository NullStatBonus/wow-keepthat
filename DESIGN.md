# Addon presentation and interaction design

Shared presentation contract **v1**, documented from KeepThat (KT) on 2026-11-15.

This is a shareable reference for consistent addon settings, tooltips, toasts, previews and positioning. It records the decisions implemented in KT and explains how to carry them into another addon. **Shared** means a common design vocabulary, not shared SavedVariables, a suite launcher or a required runtime library.

KT is the reference implementation. Other addons should adopt the principles while preserving their own gameplay, notification semantics, defaults, renderer and persistence scope. This document does not certify that CVN or another addon implements these decisions. CVN's dimensions have not been measured here.

## 1. Product principles

1. **Explain each decision.** State the page purpose, settings scope and next action. Keep the text short.
2. **Stay recognizably native.** Use existing Blizzard/Ace controls and tooltip chrome. Do not reskin the game or other addons.
3. **Keep the interface compact.** Size controls for their contents; use the available width for readable explanations, not oversized sliders and buttons.
4. **Use color for meaning.** Name the category or warning as well as coloring it. Brand color does not indicate severity.
5. **Preserve player choices.** Disabled controls retain their values. Appearance changes do not reset gameplay choices. Scope changes do not silently copy settings.
6. **Make experiments safe.** Previews use the real drawing code with isolated sample state. Move has an explicit save and rollback.
7. **Remain independently installable.** Missing APIs, fonts, item data or optional integrations must have a fallback or an explained unavailable action.

### Help text: ASD-STE100

Use ASD-STE100 principles for help text. Keep the context that a player needs to act. Remove repeated explanations.

- Use one instruction per sentence. Start with a command verb: Select, Clear, Set or Press.
- Use no more than 20 words in an instruction sentence. Use no more than 25 words in a descriptive sentence.
- Use short paragraphs. Keep page introductions to one or two sentences.
- Use active voice. Name the control or action.
- Use the same term for the same function. Match control labels exactly.
- Use approved vocabulary where applicable. Treat game terms, addon names and control labels as technical names.
- Do not use contractions, idioms or promotional claims.
- State the condition first when it changes the action.
- Explain disabled controls with a reason and one next action.
- Put detailed reference information in documentation. Do not repeat it beside every control.

Keep purpose, scope, prerequisites and action results visible. Put optional detail in hover help. Do not remove necessary context to reduce the word count.

| Context | Concise copy pattern |
| --- | --- |
| Page purpose | “Set colors, size and position here. Turn features on or off in Home.” |
| Disabled feature | “Icon tint is off. Turn it on in Home to change strength.” |
| Locked position | “Position is locked. Clear Lock position to move or reset it.” |
| Active Move | “Drag the sample. Select Done to save. Select Cancel or press Escape to discard changes.” |
| Reset result | “Reset position changes only the position.” |
| Preview | “Samples do not change settings. The tooltip uses a random material with sample skills and counts.” |
| Troubleshooting | “Turn recording on. Repeat the problem. Open the report. Press Ctrl+A, then Ctrl+C to copy it.” |

Use this writing standard in each addon. Review vocabulary and sentence length during localization and UI review.

## 2. Visual vocabulary

All dimensions below are logical UI units at normal addon scale, not physical monitor pixels. Blizzard UI scale and addon scale affect the rendered result.

| Role | Decision |
| --- | --- |
| Spacing base | 4 units |
| Compact inset | 8 units |
| Content inset token | 12 units |
| Section separation token | 16 units |
| Primary content | Approximately `#DDDDDD` |
| Supporting text | Approximately `#AAAAAA` |
| Recipe/guide annotations | Approximately `#999999` in KT settings and tooltips |
| Persistent custom surface | Pure black, `#000000` |
| Compact notification | 280 wide × at least 40 high |
| Compact item icon | 28 × 28 |
| Material detail icon | 32 × 32 |

The 12/16-unit values are shared layout tokens, not a claim that every native Ace widget uses those exact margins. KT settings delegate geometry to AceConfig; blank description rows separate sections. Custom toasts use explicit measured geometry.

### Typography

Use client font objects instead of shipping a new font or hard-coding a font file.

| Text role | KT implementation |
| --- | --- |
| Settings body | AceConfig medium description → `GameFontHighlight` |
| Settings help/scope | AceConfig small description → `GameFontHighlightSmall` |
| Large item/addon title | AceConfig large description → `GameFontHighlightLarge` |
| Section header | Native AceConfig header; retain its normal styling |
| Toast title and subtitle | `GameFontHighlightSmall`, with distinct ink colors |
| Native item title | Preserve the game's item-quality styling |

The local font resolver prefers the requested object, then `GameFontHighlightSmall`, then `GameFontNormal`. Missing preferred fonts must not require another addon. Essential copy must wrap or grow instead of relying on truncation or a hover tooltip.

### Semantic color

KT's defaults are Endgame purple `(0.64, 0.21, 0.93)` and Leveling green `(0.12, 1.00, 0.00)`. These are category colors, not success/error colors.

- Color the words **Endgame** and **Leveling**; keep item titles, profession names and explanations neutral.
- When both categories apply, name and color both. KT uses Endgame for the single toast accent and for icon tint when an item belongs to both.
- Material tree rows pair category swatches with the item name. A visible legend explains the swatches. Material detail titles retain native item-quality color when known.
- Integration failures use restrained amber with an explicit failure explanation and a route to the report.
- Each addon defines its own semantic categories. Do not copy KT's purple/green into unrelated warning states.

## 3. Settings window and control sizing

KT retains **AceConfig/AceGUI**, with a tree navigation sidebar and a scrolling content pane.

| Element | Current KT decision |
| --- | --- |
| Standalone initial window | **600 × 460** logical units |
| Window title | **KeepThat** only |
| Scope information | Visible page content, not a title suffix |
| Navigation | Ace tree; native initial sidebar width is 175 |
| Window behavior | Resizable; content remains reachable by scrolling |
| Appearance sliders | 1.5 Ace control widths |
| Longer action buttons | 1.5 Ace control widths |
| Ordinary Move/Done/Cancel and preview actions | Standard Ace control width |
| Tint location choices | Half-width checkboxes in a native multiselect group |
| Toggles with explanatory labels | Full width |
| Body/help/search content | Full width; prose wraps |
| Color pickers | Standard Ace width and native picker |

Ace's control-width multiplier is 170 units in the bundled renderer: 1.5 widths is approximately 255, and half width approximately 85. These are renderer-relative choices, not instructions to modify Ace libraries.

The previous standalone default was Ace's 700 × 500. Reducing it avoids a disproportionately large addon window while retaining a usable material tree and body column. This setting does not resize Blizzard's own Settings host.

### Choosing a control

- A boolean uses a checkbox; a bounded numeric adjustment uses a slider; a color uses the native color picker.
- KT's Bags/Bank/Merchant options are a checkbox group, not a dropdown. Three short choices can sit together without a large selection menu.
- Use a dropdown only when selecting from an actual list of alternatives. Give it enough width for meaningful labels; do not automatically stretch it across the page.
- Short actions should look like buttons, not full-page bars. Keep complete labels when translated; widen or reflow if necessary.
- Do not shrink fonts or remove context to make the default window fit. Wrap explanations and scroll long pages.

## 4. Page context and information architecture

Every top-level page, profession page and material detail must work when opened directly. The player should not need to remember a previous page or hover every control to understand the current page.

Show the active scope in Advanced, where players choose it. Repeat it only when it changes a decision. Do not add the same scope notice to every page.

The common reading order is:

1. Page heading or item identity.
2. A purpose statement of one or two short sentences.
3. Scope only when it helps explain a choice or consequence.
4. Sections for each task. State action results near the controls.
5. Current-state guidance where it changes the next action.

Scope copy should describe the effect, not expose a SavedVariables path. KT explains shared settings versus this-character settings and points to Advanced for changing scope. The window title remains the addon name in either case.

### Top-level pages

| Order | KT page | Purpose and ownership |
| --- | --- | --- |
| 1 | Home | Choose what is recommended and where recommendations appear |
| 2 | Materials | Review individual items, needs, recipes and stock |
| 3 | Integrations | Understand each optional addon's contribution and actual availability |
| 4 | Appearance | Colors, dimming, scale, position and focused previews |
| 5 | Advanced | Settings scope and troubleshooting |
| 6 | About | Purpose, version, page orientation and command discovery |

Other addons retain their own feature pages between Home and Appearance. A shared vocabulary does not require inventing irrelevant Materials or Integrations pages.

### Home

Home describes the outcome: KT recommends crafting materials; it never sells or moves items for the player.

- **What to mark:** Endgame and Leveling, with a short explanation of high-level crafting versus skill-based route counts.
- **Where to show it:** Tooltip line, Loot toast and Icon tint. Explain the difference before the toggles.
- **Tint locations:** Bags, Bank and Merchant, disabled while tint is off. Explain how to enable them and that their saved values remain.
- **Empty states:** If both categories are off, say no materials are marked and point to the category controls. If all display options are off, explain that recommendations are hidden and Materials remains available for review.
- **Next steps:** Direct players to Materials, Integrations and Appearance for their distinct tasks.

### Materials and profession pages

The hierarchy is **Materials → profession → item**. The list follows the categories enabled on Home; if both are off, all items remain reviewable with an explanation that none are being marked.

- Search accepts part of a client-localized or English item name. It persists only for the session and follows the player into profession pages.
- Show an explicit search-result count, no-match explanation and Clear search action. The standalone footer also offers Clear search while filtering.
- Each profession page explains what can be reviewed and offers category-specific Auctionator exports.
- Explain that an export creates or replaces the category's KeepThat list. If export is unavailable, show the reason next to the disabled action.

### Material details

Start with the real item icon and quality-colored name. Below that, show the profession context before the keep toggles. Explain the active scope only if it changes how those choices apply.

The important consequence is explicit: an item's category toggle applies to that material **in every profession**, within the active settings scope. The corresponding Home category must also be enabled for marks to appear.

Sections answer concrete questions in this order:

1. Keep for endgame / Keep for leveling, as applicable.
2. **Used for** — why this profession uses the material.
3. **How many** — remaining leveling needs, ranges, intermediate materials and guide sources, when applicable.
4. **Recipes that use it** — recipe names, quantity per craft and required skill.
5. **For leveling in other professions**, when relevant.
6. **Your stock** — bags and bank, with unknown bank data explained.
7. **Wowhead link** — a clearly labeled copy action.

Do not display unknown stock as zero. Explain when the player's skill has passed all relevant steps. Keep the existing material content and quality semantics when sharing the surrounding visual design.

### Integrations

Each row explains **what the integration contributes**, then shows its permission toggle and actual status. A checked toggle means support is allowed, not that the other addon is installed or functioning.

KT distinguishes bag tint integrations, shopping-list export and additional profession guidance. Explain prerequisites such as enabling Icon tint on Home. Preserve detected/working/off/error states and client limitations. Classic Era displays the current unavailability explanation instead of implying that disabled toggles can enable support there.

### Appearance

Keep visual choices separate from feature activation. Sections are:

1. **Category colors** — where the colors appear and what they mean.
2. **Icon tint** — strength, its effect on the original icon and the feature-off prerequisite.
3. **Loot toast** — independent background and content dimming, plus scale.
4. **Toast position** — lock, Move, Done, Cancel and Reset position.
5. **Preview without changing your settings** — separately labeled toast, item-tooltip and tint samples.

Enabling instructions are state-dependent: show “turn it on in Home” while the feature is off, then remove that obsolete instruction when enabled. Position guidance distinguishes locked, idle and actively moving states. Changes must update visible guidance and controls immediately.

### Advanced

Explain both settings ownership and the complete troubleshooting workflow.

- KT uses the shared Default profile unless the player opts into a character profile.
- Switching scope selects the other saved profile; it does not clone current settings. Explain this before confirmation, retain both profiles and restore their previous values when switching back.
- Troubleshooting reads: **record → repeat the problem → show report → Ctrl+A/Ctrl+C → turn recording off**.
- Diagnostic clearing requires confirmation and leaves gameplay data and settings intact.

Do not require players to understand profile implementation details to make this choice.

### About

Show addon name, runtime TOC version and a short purpose statement. Orient players to the pages, then show common commands with short explanations. Group deeper command help by appearance, domain and diagnostics rather than presenting one dense command paragraph.

## 5. Toast geometry and behavior

KT's loot toast is informational and mouse-transparent. It is not a purchase prompt or an acceptance dialog.

| Part | Current geometry / behavior |
| --- | --- |
| Panel | 280 wide; minimum height 40; pure black background |
| Category accent | 2 × 24; left inset 1; category color at base alpha 0.45 |
| Icon | 28 × 28; left inset 8; centered vertically |
| Icon crop | Texture coordinates 0.08–0.92 on each axis |
| Title | Left 44, top inset 8; neutral item name and count |
| Subtitle | 4 below title; category words colored, remaining copy neutral |
| Text width | 228 units, leaving an 8-unit right inset |
| Height | `max(40, titleHeight + subtitleHeight + 20)` |
| Stack | Downward, measured previous-frame height plus 8-unit gap |
| Default anchor | TOP, x = 0, y = −140 |
| Visible limit | Three live toasts; additional eligible entries queue |
| Lifetime | Four seconds total |
| Fade in | First 0.15 seconds |
| Fade out | Last one second |

Long titles and subtitles wrap and grow the panel. Never clip the category or essential recommendation to maintain a fixed 40-unit height. The older 46-unit fallback spacing is used only when a frame cannot provide its height; real frames use measured height.

KT shows these only for the player's loot messages, not purchases, crafting, mail or trades. Additional pickups combine into a currently active entry's count; an item is otherwise deduplicated for the session. These are KT gameplay rules, not universal rules for every addon's notifications.

An addon with an interactive warning must preserve its action semantics. Do not convert a consequential prompt into a disappearing, mouse-transparent toast merely to match this geometry.

## 6. Opacity, scale and migration

Use the same labels wherever applicable:

| Control | KT public units | New-install default |
| --- | --- | --- |
| Background opacity | Integer 0–100 | 100 |
| Text and icon opacity | Integer 0–100 | 100 |
| Scale | Integer 50–200; 100 is normal | 100 |
| Lock position | on/off | off |
| Icon tint strength | 0–100% in the native percent slider, 5% steps | 40% |

Background opacity applies to the custom panel **and decorative accent**. At zero, neither draws. Text/icon opacity is independent and affects both existing and newly created elements. The lifetime fade multiplies both layers; it is not another saved opacity setting. Native tooltip chrome is outside custom toast opacity controls.

KT stores opacity and scale internally as fractions, converting at the UI/CLI boundary. Feature-off sliders remain visible but disabled with a reason; previews and unlocked positioning remain available while real notifications are off.

Old whole-toast opacity must migrate into **both** new layers using its exact value, including zero and fractional values. Do not brighten existing installs by resetting either layer to 100. Preserve colors, position, feature states and profile data. Migration runs on initialization/profile changes; a read-only get command does not perform migration writes.

## 7. Tooltips and icon tints

### Live item tooltip

Retain the native item tooltip and other addons' content. Append KT's recommendation without rebuilding unrelated rows.

- The main line names the category and professions; only category words carry semantic color.
- A Shift hint indicates that more details are available.
- Shift shows reasons, real recipes, needs, counts and sources using the same neutral/supporting ink hierarchy as the material pages.
- Changes must not accumulate duplicate rows when Shift is toggled or tooltip data refreshes.

### Icon tint

KT adds an ADD-blend color texture over supported item icons while keeping stack counts and quality borders readable. It does not replace the icon or reskin its owning addon. Tint strength is independent of toast dimming. Existing integrations own their supported locations and refresh behavior.

### Isolated tint sample

The preview uses an independent 180 × 64 frame centered on screen, with a 28 × 28 item icon at left inset 8 and a labeled supporting-text area starting at x = 44 with width 128. The sample uses the chosen category color and tint strength and closes after four seconds. It has no inventory actions or attachment to a real item button.

### Copy and diagnostic dialogs

Use native patterns: KT's link copy box uses StaticPopup with a selected edit box, a Ctrl+C hint and Close/Enter/Escape dismissal. Its edit box is 350 units wide. Accidental edits restore the original link. Diagnostic reports use a standard AceGUI Frame with a fill-layout MultiLineEditBox, focused and selected on opening. The footer explains Ctrl+A/Ctrl+C, the edit action button is disabled and attempted edits restore the original report. This report window keeps AceGUI sizing; the 600 × 460 decision applies to settings only. Destructive diagnostic clearing uses a separate explicit confirmation with Cancel/Escape rollback.

The settings window's conditional Clear search footer action uses a 100 × 20 native button immediately left of Close. It appears only while filtering, narrows the status area to make room and is cleaned up when the pooled AceGUI window is released, so it cannot remain in another addon's window.

## 8. Preview and demo fidelity

A preview must look like the production surface because it uses the **same renderer**, not a second approximation of that renderer.

| Entry point | KT output |
| --- | --- |
| Appearance: Preview loot toast | One synthetic toast using current appearance |
| Appearance: Preview item tooltip | A native tooltip for a random real material |
| Appearance: Preview icon tint | A tint on an isolated sample icon |
| `/kt preview` | Lists toast, tooltip, tint and copy kinds |
| `/kt preview <kind>` | One focused sample |
| `/kt demo` | Three toasts (Endgame, Leveling, both), random item tooltip and isolated tint |
| Legacy `/kt test toast`, `tooltip`, `copy` | Remain supported |

Toast/tint samples last four seconds; the tooltip lasts fifteen. Repeating replaces the corresponding samples and restarts their lifetime. Samples remain labeled and work even when the real feature is disabled. Do not silently enable a feature to preview it.

### Realistic item preview

KT chooses from the union of the active catalog's endgame materials and leveling-route items. The native item tooltip provides the real item's identity, quality and description when cached. Until then, show the catalog name safely and refresh when item data arrives.

Only the hypothetical character state is synthetic:

- Both categories are enabled in a private classification context.
- Profession skills start at the selected item's real route steps.
- Recipes, guide names and required quantities come from real addon data.
- The preview injects a bag count of 12 instead of reading the character's inventory.
- A footer identifies the sample skills and bag counts.

Live and preview use the same `Tooltip.Draw` function, including row colors and Shift expansion. The private tooltip bypasses production classification hooks, so it cannot add duplicate real recommendations or leak sample state into live items.

### Isolation and restoration

Keep samples separate from live queues, cooldowns, deduplication and saved settings. KT pools sample frames separately and lets live entries continue aging while sample toasts temporarily cover their presentation; it resumes current live state afterward rather than replaying a stale snapshot.

Never invoke purchase, navigation, acceptance, export or other gameplay callbacks from sample buttons. An isolated tint must not attach to a real inventory button or change its classification. Integration tests may exercise actual integrations, but must remain distinct from safe visual previews.

## 9. Transactional positioning

Use the terms **Move**, **Done**, **Cancel**, **Lock position**, **Reset position**.

| State/action | Required result |
| --- | --- |
| Start Move | Snapshot the original anchor and active scope; show a clamped placeholder |
| Drag | Change only tentative position; do not save on drag stop |
| Done | Save the final clamped anchor, then leave Move |
| Right-click in KT mover | Alias for Done |
| Cancel or Escape | Discard tentative position and retain the original anchor |
| Enable Lock position | Cancel any active Move |
| Locked | Refuse Move, drag, direct anchor save and Reset position; explain unlocking |
| Scope change | Cancel the old transaction; never write its coordinates into either profile |
| Reset position | After unlocking, reset only the anchor |
| Normal notification | Keep production toasts mouse-transparent |

KT's placeholder uses the toast drawing component at DIALOG strata. Native Done/Cancel buttons sit 8 units below it, each 100 × 24, with an 8-unit gap. The settings page also exposes Done/Cancel and updates its instructions when Move state changes. Non-Escape keyboard input propagates to the game. If required frame/keyboard controls are unavailable, explain why Move cannot start.

Do not change colors, opacity, scale, locks or gameplay settings when resetting position. Another addon may retain existing unlocked drag shortcuts outside explicit Move; those shortcuts must still respect its lock and persistence rules.

## 10. Commands, settings parity and diagnostics

Use a common discoverable vocabulary, substituting each addon's own slash prefix:

| Verb | Purpose |
| --- | --- |
| settings [page] | Open Home or a named feature/settings page |
| help [topic] | Explain appearance, diagnostics or domain commands |
| status [topic] | Report effective settings, scope and availability |
| get / set | Read or change a stable allowlisted public key |
| preview [kind] | Discover or show one safe visual sample |
| demo | Show representative synthetic visuals together |
| debug on/off | Control diagnostic recording |
| log | Open the copyable report |
| log clear | Confirm diagnostic-only clearing |

Preserve valid legacy commands and the addon's existing bare-command behavior. KT's bare `/kt` opens Home. Normalize command words/enums, but preserve user-entered item names and search text.

UI and CLI share validators, units and refresh behavior. Reject unknown keys, invalid enums, fractional integers, out-of-range values, missing arguments and surplus input without writes. A successful new setter gives one concise acknowledgement. Do not accept arbitrary Lua paths or executable input.

KT's public keys are `toast`, `tooltip`, `appearance.toast.background-opacity`, `appearance.toast.text-opacity`, `appearance.toast.scale` and `appearance.toast.locked`. These are KT identifiers; sibling addons define their own stable keys for supported features. Reports include every saved setting plus presentation contract version, effective scope, sample count and Move state.

## 11. Reuse boundaries and validation

Adopt the shared terms, roles and interaction contracts locally. Preserve each addon's gameplay defaults and existing persistence scope. Do not add inert controls for features it does not have. Record intentional differences with their reason and acceptance scenario. Warning/Toast choices or interactive prompts in another addon require that addon's own specification; KT does not define them here.

KT's implementation sources:

- [Settings and page content](KeepThat/Options/Options.lua)
- [Local tokens, registry and migration](KeepThat/Core/Presentation.lua)
- [Toast and Move rendering](KeepThat/UI/Toast.lua)
- [Shared live/preview tooltip rendering](KeepThat/UI/Tooltip.lua)
- [Native tooltip adapter](KeepThat/Core/Adapter_Tooltip.lua)
- [Native dialogs and isolated tint sample](KeepThat/Core/Adapter.lua)
- [Copyable report window](KeepThat/Debug/Export.lua)
- [Measured/source-reviewed contracts](docs/contracts.md)
- [Recommendation coverage and pending acceptance](openspec/changes/cohesive-addon-presentation/coverage.md)

The native-control references inspected here are the bundled AceGUI Button, Frame and Label widgets and AceConfigDialog's layout/width handling. No sibling-addon UI source was used to establish exact visual parity.

Automated validation uses `make test`, `make check` and strict OpenSpec validation. Harness coverage includes the real AceConfig schema, migration, scope, UI/CLI parity, preview/live row-color parity, sample isolation and Move rollback. This document does not substitute for client rendering checks.

Before claiming visual acceptance, review on each supported client at matching UI scale:

- All six pages and nested details opened directly; purpose, scope and next action are apparent.
- Compact window, resizing, scrolling, long translations and complete control labels.
- Every owned surface, standalone installation and optional integrations missing/present.
- Opacity independently at 0/80/100; addon scale at 100/150, plus supported bounds.
- Long item names/recommendations, missing icons, uncached items and font/API fallbacks.
- Native/third-party tooltip coexistence, Shift toggling and realistic preview parity.
- Disabled-feature samples, repeat/expiry and concurrent real updates.
- Move edge clamping, Done/Cancel/Escape, lock, scope changes, keyboard propagation and combat.
- Two-character persistence and diagnostic confirmation/copy behavior.

Capture comparable Home, Appearance, tooltip, toast and relevant prompt screenshots. KT's detailed checklist is in [docs/test-plan.md](docs/test-plan.md). In-game captures and exact comparison against CVN remain pending; the values above describe code decisions, not measured screenshots.
