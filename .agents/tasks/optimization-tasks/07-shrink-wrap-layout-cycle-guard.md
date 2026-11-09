# 7. Add a layout-cycle guard to the shrink-wrap viewport

**Area:** correctness · **Line numbers:** `598e545`

**Status:** done in agent/list-state-followups — `_maxLayoutCycles = 10` cap and the debug `FlutterError` mirrored from `viewport.dart`; `effectiveExtent` is now computed after every attempt so it stays assigned if the cap ends the loop in release. Regression test uses a sliver that requests 20 corrections (no error before the fix).

- **File:** `lib/src/wrapping.dart:199-230`, `CustomRenderShrinkWrappingViewport.performLayout`
- **Problem:** the `do { ... } while (true)` loop has no cycle cap. `UnboundedRenderViewport` (`viewport.dart:150-194`) caps at `_maxLayoutCycles = 10` and throws a descriptive error in debug. If corrections keep happening, shrink-wrap mode hangs forever instead.
- **Fix:** mirror the `_maxLayoutCycles` counter and the debug `FlutterError` from `viewport.dart`. Leave the normal path unchanged.
