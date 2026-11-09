# 22. Profile-mode performance harness on a real device

**Area:** performance (measurement) · **Line numbers:** `a0ee16b`

**Status:** done. The harness runs in profile mode on a real Android device (Redmi Note 15) and writes JSON summaries; baseline below. Scenario 6 (`itemExtent`) is waiting on [task 20](20-fixed-extent-mode.md), which should add it when it lands.

- **Problem:** `benchmark/scroll_benchmark_test.dart` runs under the `flutter test` binding: debug-compiled (JIT), with no real rasterization. It's useful for comparing Dart build and layout time between two commits on one machine, but it can't measure GPU (raster) time, missed frames or jank, which is what users actually notice.
- **Fix direction:**
  - Add `integration_test` (SDK) as a dev dependency in `example/pubspec.yaml`.
  - Add `example/integration_test/perf_test.dart` using `IntegrationTestWidgetsFlutterBinding` and `binding.watchPerformance(...)`, which reports frame-timing summaries: average, p90 and p99 build and raster times, and missed frames.
  - Add `example/test_driver/perf_driver.dart` using `integrationDriver(responseDataCallback: ...)` to write the results to `example/build/perf/*.json`.
  - Scenarios, each on a 10,000-item list:
    1. drag/fling scroll **with** an `itemPositionsListener`
    2. the same drag **without** a listener (the baseline for [task 19](19-lazy-position-computation.md))
    3. short `scrollTo` (target about 1 screen away, direct animation)
    4. long `scrollTo` (target thousands of items away, crossfade)
    5. the same as 1 and 4 with `.separated`
    6. once [task 20](20-fixed-extent-mode.md) lands, 1 and 4 with `itemExtent`
  - Run with: `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d <device>` from `example/`.
- **Results:** add a "Baseline" section to this file with the device, Flutter version, commit and the table of numbers. Later tasks add their before/after rows to their own files.
- **If no physical device is available:** say so in the status line, record numbers from `flutter test benchmark/scroll_benchmark_test.dart` instead, and note that they're relative-only.
- **Acceptance:** the harness runs in profile mode on at least one real Android or iOS device and produces the JSON summaries. `flutter test` at the root and in `example/` still passes, and the harness isn't picked up by either. `flutter analyze` is clean. Not wired into CI (CI has no device), but the README of this directory explains how to run it.

## What was built

- `example/integration_test/perf_test.dart`: six scenarios on a 10,000-item list of `ListTile`s (about 72 dp tall) inside a `SafeArea`. Each scenario has a warm-up pass that isn't measured, then runs inside `binding.watchPerformance`. The frame policy is `fullyLive`, so frames run at the display's vsync.
  - `drag_with_listener` / `drag_without_listener` / `drag_with_listener_separated`: 6 rounds of a 1.5 s, 1500 px slow drag plus a fling, alternating direction. The listener computes the first visible index on every notification.
  - `short_scroll_to`: 10 × `scrollTo` between items 100 and 112 (600 ms each). The target is already laid out, so this is the direct `animateTo` path.
  - `long_scroll_to` / `long_scroll_to_separated`: 10 × `scrollTo` between items 100 and 5000 (600 ms each), which is the crossfade path.
- `example/test_driver/perf_driver.dart`: writes `example/build/perf/<scenario>.json` (the full `FrameTimingSummarizer` output, including per-frame lists) and prints a Markdown table of the key numbers. `build/` is already git-ignored.
- `integration_test` (SDK) was added to `example/pubspec.yaml` dev dependencies.

**`--no-dds` is required.** `watchPerformance` also counts GCs by tracing the timeline through the VM service. With DDS on, that websocket connection is reset, and every test fails with `HttpException: Connection reset by peer`.

**Caveat on "missed" counts:** `FrameTimingSummarizer` uses a fixed 16 ms budget. On a 120 Hz panel the real budget is 8.3 ms, so compare p90/p99/worst times rather than relying only on the missed counts.

## Baseline

- **Device:** Redmi Note 15 (`2510DRA23E`, MediaTek MT6789), Android 16 (API 36), 120 Hz, 1080×2392
- **Flutter:** 3.47.7 stable (framework `abaf9c5237`, Dart 3.13.5), Impeller, profile mode
- **Package commit:** `a0ee16b` (`lib/` unchanged by this task)
- **Command:** `fvm flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart --target=integration_test/perf_test.dart -d m74hz9mfv4h6gmmz`

All times are in ms. These are from run 2 of 2; run 1 is summarised underneath.

| scenario | frames | build avg | build p90 | build p99 | build worst | raster avg | raster p90 | raster p99 | raster worst | missed build | missed raster |
|---|---|---|---|---|---|---|---|---|---|---|---|
| drag_with_listener | 2349 | 1.26 | 2.92 | 4.44 | 5.82 | 3.28 | 4.72 | 7.13 | 12.36 | 0 | 0 |
| drag_with_listener_separated | 2324 | 1.42 | 3.10 | 4.83 | 7.08 | 3.61 | 5.07 | 7.42 | 14.55 | 0 | 0 |
| drag_without_listener | 2347 | 1.32 | 2.97 | 4.46 | 8.61 | 3.47 | 4.84 | 6.82 | 11.02 | 0 | 0 |
| long_scroll_to | 621 | 4.17 | 5.42 | 71.12 | 80.65 | 3.20 | 4.82 | 7.13 | 12.08 | 21 | 0 |
| long_scroll_to_separated | 604 | 4.57 | 5.90 | 75.56 | 93.76 | 3.22 | 4.35 | 9.01 | 14.83 | 23 | 0 |
| short_scroll_to | 799 | 1.27 | 2.11 | 3.27 | 7.50 | 3.23 | 4.45 | 6.14 | 11.50 | 0 | 0 |

Run 1 (same build) gave build avg / p99 of 1.20 / 4.09 (drag with listener), 1.28 / 4.19 (drag without), 3.91 / 61.78 (long scrollTo), 1.25 / 2.93 (short scrollTo). **Expect roughly 5–10 % run-to-run noise on averages and more on p99/worst.** Run each side at least twice before calling something a gain.

**What the baseline already shows:**
- **The long-scroll crossfade is the only real jank.** About 2 frames per `scrollTo` take 60–95 ms to build, which is when the secondary list is built and laid out. Every other frame is well under budget. This is the target for [task 21](21-transition-cost.md), and probably for [task 18](18-default-cache-extent.md), since the secondary list builds its whole cache extent in that frame.
- **The `itemPositionsListener` costs nothing measurable while dragging.** "With" and "without" are within noise of each other. [Task 19](19-lazy-position-computation.md) should expect a small gain in this harness, if any.
- `.separated` adds about 10 % build time.
