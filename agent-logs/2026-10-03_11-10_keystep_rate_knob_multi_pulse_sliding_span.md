# KeyStep 32 Rate Knob Multi-Pulse Sliding Span & Jitter-Free Continuous Tracking

## Summary
Diagnosed and resolved the root cause of the KeyStep 32 Rate knob jumping erratically between ~65%, 80%, and 100% with no in-between steps, while performing sluggishly at high rates compared to low rates. Replaced single-pulse delta measurements ($t_{i+1} - t_i$) with adaptive multi-pulse sliding spans ($S = 4..16$ pulses, ~200ms duration) and removed the 2-value CC deadband filter, enabling smooth, continuous, sub-BPM tracking and responsive sweeps across the entire 30..240 BPM range.

## Root Cause Analysis
1. **MIDI Clock Protocol Reality**: KeyStep transmits standard MIDI 1.0 Timing Clock (`0xF8` / `systemTimingClock`, 24 PPQN). In the MIDI 1.0 standard, this is a single raw byte with **no payload or tempo value**. All receiving devices must compute tempo via $\text{BPM} = \frac{60}{24 \times \Delta t}$.
2. **Adjacent-Pulse Quantization at High Tempo**:
   - At 240 BPM, pulses arrive every $10.42\text{ ms}$.
   - macOS runloop dispatch and USB polling introduce $\approx 1.5\text{--}2.5\text{ ms}$ of callback jitter.
   - On an adjacent-pulse interval ($t_{i+1} - t_i$), a $2\text{ ms}$ jitter is a massive $20\%$ error, quantizing intervals into runloop quanta:
     - $\Delta t \approx 15.0\text{ ms} \implies 166.7\text{ BPM} \implies \mathbf{65\%}$ Rate (CC 83)
     - $\Delta t \approx 12.5\text{ ms} \implies 200.0\text{ BPM} \implies \mathbf{80\%}$ Rate (CC 102)
     - $\Delta t \approx 10.4\text{ ms} \implies 240.0\text{ BPM} \implies \mathbf{100\%}$ Rate (CC 127)
   - Taking the median of adjacent intervals simply selected the median quantized interval, locking the upper range into discrete steps with no intermediate values.
   - Conversely, at 30–60 BPM, pulse intervals are $41\text{--}83\text{ ms}$, so $1.5\text{ ms}$ jitter is only $1.8\%$ error ($< 0.6\text{ BPM}$), which is why the lower end appeared smooth while the upper end was broken.

## Solution
1. **Multi-Pulse Sliding Span ($S = 4..16$)**:
   - Instead of adjacent pulses, measured duration across sliding spans of $S$ pulses:
     $$\Delta t_{\text{pulse}} = \frac{t_i - t_{i-S}}{S}$$
   - Telescoping intermediate pulses completely cancels runloop bunching between endpoints:
     $(t_1 - t_0) + (t_2 - t_1) + \dots + (t_S - t_{S-1}) = t_S - t_0$.
   - Any endpoint jitter is divided by $S$. At 240 BPM with $S = 16$ ($166\text{ ms}$ span), runloop jitter error drops from $20\%$ to $< 0.8\%$ ($< 2\text{ BPM}$), restoring 25x higher resolution.
   - Preserves rapid response: at 240 BPM, 16 pulses arrive in just $166\text{ ms}$, tracking $4\times$ faster than at 60 BPM.
2. **Expanded History Buffer**:
   - Increased `CLOCK_HISTORY_MAX` from 24 to 36 to ensure sufficient sliding spans are available for median filtering even at high tempos.
3. **Continuous CC 107 Output (`RATE_CC_DEADBAND = 0`)**:
   - Removed the 2-value CC deadband in `sendRateCc` that previously dropped 1-step and 2-step CC adjustments. Combined with steady-state hysteresis in `handleClock`, every single integer CC value from 0 to 127 is emitted cleanly without duplicates or skipped values.

## Verification
- Added simulation unit test in `tests/keystep_interceptor.test.js` validating monotonic progression and $< 2.5\text{ BPM}$ error under 2ms discrete runloop quantization across 160..240 BPM.
- All 36 Bun tests pass cleanly (`bun test`).
- Bundled and reloaded Hammerspoon via `bin/bundle_and_reload.sh`.
- Live verified active KeyStep connection and telemetry in Hammerspoon (`hs -c`).
