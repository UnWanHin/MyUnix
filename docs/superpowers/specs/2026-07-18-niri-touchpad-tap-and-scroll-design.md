# Niri Touchpad Tap And Scroll Design

## Context

The Fedora Niri session uses a GXTP5100 touchpad. The device supports
tap-to-click, but its default libinput state leaves it disabled. The Niri base
configuration declares `tap`, while MyUnix's later touchpad fragment is used by
the `Mod+F8` toggle and currently writes an empty enabled `touchpad` block.
That later fragment can discard the base behavior after the touchpad is toggled
back on. The desired behavior is Windows-style single-finger tap-to-click and
reverse (natural) vertical scrolling.

## Decision

Make the MyUnix-owned touchpad fragment the single owner of persistent
touchpad preferences. Its enabled state explicitly enables `tap` and
`natural-scroll`; its disabled state contains only `off`.

The toggle helper must write the same explicit enabled fragment, so `Mod+F8`
changes only whether the touchpad is usable and never silently resets
tap-to-click or scrolling direction. Remove the duplicated base touchpad
preferences from the Niri configuration template. Keep the binding in DMS's
managed binds file.

## Scope

- Update the Niri-DMS template, toggle helper, and active user configuration.
- Add focused tests that assert enabled and disabled fragments preserve the
  intended settings.
- Export the resulting configuration through the existing Niri-DMS module.

## Non-Goals

- Per-device input profiles; Niri currently applies the touchpad section to all
  touchpads.
- Changes to mouse or trackpoint scrolling.
- Kernel, driver, or libinput package changes.

## Verification

- `niri validate` accepts the active configuration.
- The module test suite verifies the enabled fragment contains `tap` and
  `natural-scroll`, and the disabled fragment contains `off`.
- Reload Niri configuration, then manually verify a light one-finger tap
  produces a left click and two-finger vertical scrolling follows the reverse
  direction.
