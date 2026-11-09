# 5. Element registry keeps stale entries after reparenting

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state-followups — reproduced at unit level (a `GlobalKey` subtree moved between two `RegistryWidget`s stayed in the old registry); `_register` now removes the element from its previous registry, and `_registryWidgetState` is nullable. Not reachable through the public API (each item's `RegisteredElementWidget` has a `ValueKey`, and nested lists have their own registry), so this is defensive.

- **File:** `lib/src/element_registry.dart`, `_RegisteredElement._register` / `didChangeDependencies`
- **Problem:** if a registered element moves under a different `RegistryWidget` (GlobalKey reparenting), `_register` adds it to the new registry but never removes it from the old one. The old list then reports positions for an item it no longer contains.
- **Fix:** in `_register`, if `_registryWidgetState` is already set and differs from the new one, remove `this` from the old set first. Make `_registryWidgetState` nullable instead of `late`.
- **Acceptance:** this is unit-level. The rare scenario needs a test using a `GlobalKey`-keyed item moved between two lists. Keep the fix minimal.
