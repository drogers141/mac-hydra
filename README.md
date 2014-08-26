# Mac-hydra

## Mac Desktop Utility Layer
This work is part of my ongoing effort to enable powerful customization and window manipulation for OS X for my needs.  
Some goals:

- arbitrary window movement and resizing with keybindings
- awareness of state of windows in differing contexts
  - state of windows on a particular desktop, i.e. Space in Mac-speak
  - awareness of different screens in combination with desktop state
      - i.e. - number-of-contexts = number-of-screens - number-of-desktops
- create a functionality layer with above that allows arbitrary scripting as needed

## Previous Implementation
Previously, I accomplished this using Slate: https://github.com/jigish/slate which is a fine set of utilities, but not under active development.  In particular I used the javascript api to implement some of my own stuff.

## Current Implementation - Hydra
This implementation is targeted toward Hydra, which was a lua-based effort that is undergoing renaming and code changes.  

## Future - Mjolnir
Hydra has morphed to PenKnife, then Mjolnir, which I believe will probably stabilize after a bit.  Once a stable release happens in Mjolnir, I'll update to that.

Mjolnir is at https://github.com/mjolnir-io/mjolnir

