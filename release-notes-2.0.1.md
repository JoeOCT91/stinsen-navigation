## Bug Fixes

- **Fixed root function navigation stack issue**: Root functions now properly clear the navigation stack when switching roots
- **Improved root switching**: Calling `root()` functions now correctly updates the navigation stack and adds new roots to the navigation hierarchy
- **Navigation stack clearing**: Added `stack.value.removeAll()` in both `_root()` function variants to ensure proper navigation stack clearing during root transitions

## What's Changed
This release resolves the core issue where calling `root()` functions didn't properly alter the navigation stack and add new roots to the navigation hierarchy. This was particularly problematic when switching between authentication states or different root coordinators.

## Technical Details
- Enhanced `_root<Output: Coordinatable, Input>()` function to clear navigation stack before root switching
- Enhanced `_root<Output: View, Input>()` function to clear navigation stack before root switching
- Prevents old navigation items from remaining when switching between roots
- Ensures consistent navigation state during root transitions

This is a patch release that maintains full backward compatibility while fixing critical navigation behavior. 