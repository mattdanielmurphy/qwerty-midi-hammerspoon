# HUD Key Flickering Fix

- Root cause:  was resetting  on every HUD payload update tick, stripping status classes (, , , , ) and immediately re-adding them. This forced the browser to constantly recalculate styles and re-evaluate CSS transitions/animations on unchanged state. Additionally,  used sequential / calls instead of atomic boolean toggling.
- Fix: Cached base layout class strings using  so  is only updated when key layout attributes actually change. Replaced class stripping with atomic  calls for status state flags in both  and .
- Synced  to  and  via .
