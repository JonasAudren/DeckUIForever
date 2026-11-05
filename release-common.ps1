<#
Shared by package.ps1 and bump-version.ps1 (dot-sourced): the addon
folders a release is made of, and reading a .toc header. A new module is
added here once instead of in both scripts.

The list stays explicit rather than being read off the folders: package.ps1
checks the archive against it, and a stray DeckForever_* folder with a .toc
must not ship just because it exists.
#>

# The modules join this list as they are ported from DeckUI
# (DECKFOREVER_BERICHT.md, phases 2-5); D.MODULE_ADDONS in DeckForever/core.lua
# names them already.
$addons = @("DeckForever", "DeckForever_Orbs", "DeckForever_Bars", "DeckForever_Spec", "DeckForever_Bags", "DeckForever_Quests", "DeckForever_Map", "DeckForever_Tooltip", "DeckForever_Nav", "DeckForever_Week")

function Get-TocField($path, $field) {
    foreach ($line in Get-Content $path) {
        if ($line -match "^##\s+$field\s*:\s*(.+?)\s*$") { return $matches[1] }
    }
    return $null
}
