# 22. Profile-mode performance harness on a real device

**Area:** performance (measurement) · **Line numbers:** `a0ee16b`

**Status:** not started. **Do this first.** Tasks 18–21 are judged against its numbers. It touches only `example/`, so it can run in parallel with anything.

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
