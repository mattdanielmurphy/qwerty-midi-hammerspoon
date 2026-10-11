# E2E Test Infra: qwerty-midi-hammerspoon

## Test Philosophy
- Opaque-box, requirement-driven derived directly from `ORIGINAL_REQUEST.md`.
- Methodology: Category-Partition + Boundary Value Analysis + Pairwise Combinatorial + Real-World Workload Testing.
- Test Runner: `bun test` in project root.
- All test suites reside in `tests/` and execute in headless / simulated runtime with full assertion coverage.

## Feature Inventory & Test Matrix
| # | Feature | Source (requirement) | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|---------------------|:------:|:------:|:------:|:------:|
| 1 | Dedicated Track Volume Keys (R1) | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | ✓ |
| 2 | Asynchronous / Debounced Volume Persistence (R1) | ORIGINAL_REQUEST §R1 | 5 | 5 | ✓ | ✓ |
| 3 | Rich Arp Velocity Contours (R2) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | ✓ |
| 4 | Variable Arp Gate & Microtiming (R2) | ORIGINAL_REQUEST §R2 | 5 | 5 | ✓ | ✓ |
| 5 | Configurable Quantization Amount (R3) | ORIGINAL_REQUEST §R3 | 5 | 5 | ✓ | ✓ |
| 6 | Key Overlay Multi-line Wrapping (R4) | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ | ✓ |
| 7 | "Pass Through" Clutter Elimination (R4) | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ | ✓ |
| 8 | Modifier Contrast & Opacity (R4) | ORIGINAL_REQUEST §R4 | 5 | 5 | ✓ | ✓ |
| 9 | Real-Time State Indicators on Keys (R5) | ORIGINAL_REQUEST §R5 | 5 | 5 | ✓ | ✓ |
| 10 | Quantizer Staccato Re-trigger Safety (R6) | ORIGINAL_REQUEST §R6 | 5 | 5 | ✓ | ✓ |
| 11 | MIDI Voice Watchdog Loop (R6) | ORIGINAL_REQUEST §R6 | 5 | 5 | ✓ | ✓ |
| 12 | Tap Tempo Calculation & BPM Update (R7) | ORIGINAL_REQUEST §R7 | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Runner**: `bun test`
- **Pass/Fail Semantics**: 100% test pass, exit code 0.
- **Coverage Tiers**:
  - **Tier 1 (Feature Coverage)**: Isolated happy-path unit & contract checks verifying each feature in isolation (>= 5 cases per feature).
  - **Tier 2 (Boundary & Corner Cases)**: Edge cases, limits, zero/max volume (0..127), quantize strength limits (0%, 90%, 100%), rapid consecutive key intervals (<10ms), BPM boundaries (30..300), long label wrapping limits (>= 5 cases per feature).
  - **Tier 3 (Cross-Feature Combinations)**: Pairwise interactions — rapid volume adjustments while playing quantized notes (R1+R6), tap tempo updating active arpeggiators without dropped gates (R2+R7), modifier key switching while parameter states change (R4+R5), quantize legato sustaining without watchdog orphan triggers (R3+R6).
  - **Tier 4 (Real-World Application Scenarios)**: Realistic polyphonic multi-track performance, live tap tempo jamming with arpeggiator, and chaos keypress bursts under full quantization load.
  - **Tier 5 (Adversarial Coverage Hardening)**: White-box adversarial testing probing race conditions, timer leaks, and edge-case boundary conditions.

## Coverage Minimums
- Identified Features: 12
- Tier 1: ≥ 60 test cases
- Tier 2: ≥ 60 test cases
- Tier 3: ≥ 12 cross-feature interaction cases
- Tier 4: ≥ 6 real-world live performance scenarios
- Total Planned: ≥ 138 test cases across E2E test suites
