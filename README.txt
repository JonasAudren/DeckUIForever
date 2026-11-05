DeckForever
===========

DeckUI for World of Warcraft: Forever - a compact, controller-friendly
interface for the Steam Deck that also works on the PC with your normal
key bindings.

DeckForever is a hub with load-on-demand modules, carried over from DeckUI
(the retail and Mists of Pandaria Classic addon) one by one. Enable or
disable each module on its own page in /df; what you do not use is never
loaded.

  DeckForever          the hub: device detection, settings window, movable
                       frames, loot, merchant, nameplates, server info,
                       main menu, auction prices
  DeckForever Orbs     round unit frames or Final Fantasy's bars, party
                       list, raid frames, buff bar, your debuffs
  DeckForever Cross    cross hotbar                       (not ported yet)
  DeckForever Bars     the eight action bars in Final Fantasy XIV's hotbar
                       look, for keyboard and mouse
                                               (off until you switch it on)
  DeckForever Spec     one-click talent group switcher (dual talents)
  DeckForever Bags     all bags and the keyring in one window, the bank
                       with its bag slots      (off until you switch it on)
  DeckForever Quests   a compact objective tracker with quest timers
                                               (off until you switch it on)
  DeckForever Map      a square or round minimap and a smaller world map
                       (off until you switch it on in /df)
  DeckForever Tooltip  the mouse-over tooltip in DeckForever's style
                       (off until you switch it on in /df)
  DeckForever Nav      a compass bar, the navigation target, /way waypoints
                       (off until you switch it on in /df)
  DeckForever Week     the week at a glance: raid lockouts, Legacy and PvP
                       renown, dailies, weekly quests, reputation and
                       currencies for every character
                                               (off until you switch it on)

Runs in World of Warcraft: Forever (1.60.1, Interface 16001) only. For
Retail and Mists of Pandaria Classic use DeckUI.
License: MIT, see LICENSE.txt.


Installation
------------
1. Quit the game completely.
2. Copy the addon folders into

     World of Warcraft\_forever_\Interface\AddOns\

   so that you end up with AddOns\DeckForever (and, as they are ported,
   AddOns\DeckForever_Orbs and the others).
3. Start the game. In the addon list on the character screen, DeckForever
   and its modules must be checked. The modules are marked "load on
   demand" and depend on the hub - if the hub is unchecked, nothing loads.
4. Log in.

A full restart is needed after installing or updating; /reload is not
enough for new folders or textures.


First steps
-----------
  /df                      opens the settings window
  /df build                compares the addon's interface number with the client
  minimap button           left-click settings, right-click unlock/lock,
                           drag to move the button itself
