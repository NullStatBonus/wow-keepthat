# icon-mask Specification

## Purpose

Defines the optional colored tint on item icons for marked materials, where it appears, and how it works with Blizzard's bags and the supported bag addons without ever breaking them.

## Requirements

### Requirement: Icon mask off by default
The icon mask SHALL be off by default and SHALL draw nothing until the player turns it on.

#### Scenario: Default settings
- **WHEN** settings are default and the player opens their bags holding Arcanite Bar
- **THEN** no icon is tinted

### Requirement: Tint marked item icons
When the icon mask is on, each marked item's icon SHALL show a colored overlay in the endgame color (default purple) or the leveling color (default green). An item in both categories SHALL use the endgame color. The overlay SHALL leave the icon, count and quality border readable.

#### Scenario: Endgame item in bags
- **WHEN** the icon mask is on and the player opens their bags holding Arcanite Bar
- **THEN** the Arcanite Bar icon shows a purple overlay and its stack count stays readable

#### Scenario: Custom color
- **WHEN** the player sets the endgame color to orange
- **THEN** endgame icons that are already showing switch to orange without a reload

#### Scenario: Item moved or sold
- **WHEN** a marked item leaves a slot and an unmarked item takes its place
- **THEN** the slot shows no overlay

### Requirement: Locations chosen by the player
The overlay SHALL appear only in the locations enabled in "Show marks in": bags, bank and merchant, all enabled by default. The merchant location covers the items a merchant sells and the merchant's buyback tab, on both clients.

#### Scenario: Location off
- **WHEN** the icon mask is on and Merchant is unchecked in "Show marks in"
- **THEN** merchant item icons show no overlay

#### Scenario: Material sold at a merchant
- **WHEN** the icon mask is on and a merchant sells a marked material (for example a vendor selling Crystal Vial)
- **THEN** that item's icon in the merchant window shows the overlay

#### Scenario: Material sold by mistake
- **WHEN** the icon mask is on and the player opens the merchant's buyback tab holding a marked material they sold
- **THEN** that item's icon shows the overlay

### Requirement: Supported bag interfaces
The overlay SHALL work in Blizzard's default bags and bank, Baganator, Bagnon and EllesmereUI Bags, each detected automatically, each with its own on/off toggle on the Integrations page.

#### Scenario: Baganator installed
- **WHEN** Baganator is loaded and the icon mask is on
- **THEN** marked items in Baganator's bag and bank views show the overlay

#### Scenario: Integration turned off
- **WHEN** the player turns off the Bagnon integration
- **THEN** Bagnon shows no overlay, and the other integrations are unaffected

### Requirement: Integration failure is contained
If a bag addon cannot be integrated with, for example because it is a version with a different layout, the addon SHALL disable that integration for the session, leave the bag addon working normally, show no error to the player, and record the failure in the debug report.

#### Scenario: Unexpected bag addon version
- **WHEN** EllesmereUI Bags is loaded but its item buttons are not where the integration expects them
- **THEN** EllesmereUI Bags works normally without overlays, no Lua error is shown, and the debug report names the disabled integration
