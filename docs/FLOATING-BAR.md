# Floating bar layouts and context menu

Choose **Settings → Timer → Orientation → Horizontal / Vertical**. Horizontal
remains the default. The expanded pill is 236 × 46 points horizontally, or
46 × 236 vertically. The same glass shape, colors and button sizes are retained.
Vertical controls run from top to bottom: progress ring, upright countdown and
phase, Start/Pause, Skip, Reset. Longer countdowns scale to fit; short phase
captions remain fully named for accessibility.

**Compact while running** keeps the ring, countdown and Start/Pause in both
layouts. It shortens the trailing edge to 172 points, hiding Skip and Reset under
the primary button. Hover, a paused timer, phase acknowledgement and VoiceOver
retain the existing expansion policy. The top/left edge and primary button stay
fixed throughout the compact morph. Reduce Motion retains its existing behavior.

Right-click anywhere on the visible pill, including its buttons, or use a
trackpad secondary click / Control-click:

- **Settings…** opens the existing Settings window.
- **Switch to Vertical / Horizontal** applies and persists the opposite layout.
- **Hide Floating Bar** hides its window and suspends its companion. The timer
  continues. Use **Show Floating Bar** in the menu bar to restore it.

The menu uses native macOS rows, separators and template icons. It follows the
pill's resolved appearance. Secondary clicks are handled before button actions
or drag events; transparent margins and hidden compact controls are excluded.

## Placement and compatibility

Switching layout preserves the visible pill's center when there is room and fits
the new extent onto the current display at screen edges. Dragging still uses
native event coordinates and the original multi-display rules. The stored
position remains the expanded pill's bottom-left origin, retaining compatibility
with existing saved horizontal positions. Orientation also persists across relaunch.

All six hanging companions support both layouts. Artwork remains upright; grips
slide along the long rim and center on short caps. Bounds correction and Lively
relocations use the actual drawn pill. The Character settings preview follows
orientation. Full-size performance art and timelines are unchanged.

## Implementation and checks

- `PillOrientation` stores `horizontal` / `vertical`; missing or unknown values
  fall back to horizontal.
- `PillLayout` owns dimensions, control positions, drag regions and conversion
  between SwiftUI's top-left and AppKit's bottom-left coordinates. The original
  horizontal metrics remain available through `FloatingBar.Metrics`.
- `onFloatingBarChange` handles orientation, compact mode and visibility separately
  from duration edits. These actions never reset a paused countdown or signal music.
- The floating panel resizes in place; orientation does not recreate the timer or
  window. Delayed compact hit-area updates cannot overwrite newer layout geometry.
- `PillOrientationTests`, `WindowDraggingTests`, and the companion tests cover
  both layouts, native input routing, menu actions, persistence, screen bounds,
  countdown preservation and all six characters. Run `swift test` for all checks.

Build and relaunch locally with `./Scripts/build.sh --no-install --run`. The build
workflow retains the default install behavior and signs the bundled companion
resources with the app. Widget geometry and original animation resources are
unchanged by the layout feature.
