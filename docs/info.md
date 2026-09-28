<!---
This file is used to generate your project datasheet.
-->

## How it works

This project is the controller for a current-limiting high-side load switch built around an external
P-channel MOSFET. It is meant to power a Raspberry Pi by backfeeding the 5V pins (2 and 4) of the Pi's
40-way header while a Pi GPIO controls the switch.

The 5A load current never goes through the Tiny Tapeout chip (the analog pins are rated for only a few mA).
The chip only senses the voltage across an external shunt resistor and drives the MOSFET gate through a small
external N-MOSFET level shifter:

```
 5V supply ──┬── Rs 20mΩ ──┬── P-MOSFET (S)      (D) ──> Pi header 5V (pins 2/4)
             │             │        (G)
          10.4k           10k        ├── 1k ── (S)
             ├── SNS_A     ├── SNS_B └── BSS138 (D)
           10k    ║       10k               (G) ── GATE     (1M GATE -> GND)
             │   1nF ─ GATE│                (S) ── 330Ω ── GND
            GND            GND                         CT ── 10nF ── GND
```

* **Current limit.** SNS_A and SNS_B are both about 2.5V. The two external dividers are deliberately
  mismatched (10.4k/10k versus 10k/10k), so SNS_B sits above SNS_A until the shunt drop cancels the
  difference. A two-stage error amplifier with Miller compensation, running from the 3.3V supply (VAPWR),
  drives GATE. When the load current reaches the limit, the amplifier reduces the BSS138 drive, and that
  moves the P-MOSFET into its linear region and holds the current at the limit. The limit is

  I_lim = V_IN * (k_B - k_A) / (k_B * Rs), where k_A = 10k/20.4k and k_B = 10k/20k.

  This gives about 4.9A with a 5.1V supply and a 20 mΩ shunt. The 1nF capacitor from GATE to SNS_A turns the
  loop into an integrator and keeps it stable with a wide range of load capacitance.
* **Fault timer.** A replica of the amplifier's output stage detects when the amplifier is actively limiting,
  which asserts ILIM. While ILIM is high, an on-chip current source of about 1.3µA charges the capacitor on CT.
  When CT reaches the Schmitt-trigger threshold (about 2V), the FAULT latch sets and the switch turns off. With
  10nF this takes about 16ms, long enough for the inrush into a Pi's input capacitors. CT is discharged
  whenever the switch is not limiting. Tying CT to GND disables the fault latch, so the switch just limits
  current indefinitely. Only do that if the MOSFET can dissipate (V_IN − V_OUT) × I_lim.
* **Control logic.** The logic is built from custom 5V-rated sky130 transistors on the 3.3V supply, with level shifters to the 1.8V project I/O.
  - The OFF input sets an OFF latch, and power stays off even after OFF returns low.
  - WAKE or a low rst_n clears both the OFF latch and the FAULT latch.
  - Because it is latched, OFF works with the Pi's `gpio-poweroff` overlay. The Pi drives the pin high at
    shutdown and power stays off after the Pi loses power and its GPIO floats low.

## How to test

Simulations are in `sim/` (ngspice, sky130A models; `sim/models/ext.lib` contains approximate models of
the external MOSFETs):

* `tb_seq.spice`: the switch starts latched off. WAKE turns it on into 100µF plus 2Ω. An overload
  (about 9A demand) is then limited to about 4.9A, and after about 16ms FAULT latches off. WAKE restarts it,
  and a GPIO OFF pulse latches it off again.
* `run_corners.sh`: overload and short-circuit current limit across process, temperature and VAPWR corners.

On hardware:

1. Build the external circuit above, with the load resistor or electronic load on the P-MOSFET drain.
   Connect ui_in[0] (OFF) to a Pi GPIO or a switch, and ui_in[1] (WAKE) to a push button.
2. Select the project and release reset. PWR_ON (uo_out[0]) goes high and the output comes up.
3. Increase the load past 5A. ILIM (uo_out[1]) goes high and the current stays at the limit. After the CT
   timeout, FAULT (uo_out[2]) goes high and the output turns off. Press WAKE to restart.
4. Pulse OFF high. The output turns off and stays off until WAKE is pressed or the project is reset.

## External hardware

* P-MOSFET, ≥20V V_DS, ≤10mΩ at V_GS = −4.5V, rated for the power dissipated while limiting
  (for example AO4407A or DMP3013). Put it on a copper area that can take (5V × I_lim) during the CT timeout.
* BSS138 (or similar logic-level N-MOSFET), with 1k from the P-MOSFET gate to its source, 330Ω source
  resistor, and 1M from GATE to GND so that the switch is off when the chip is unpowered.
* 20mΩ shunt resistor (0.5W or more).
* Sense dividers: 10.4k/10k (SNS_A, supply side) and 10k/10k (SNS_B, MOSFET source side). Use 0.1%
  resistors (a mismatch of 0.1% shifts the limit by roughly 10%), or trim the 10.4k to set the limit.
* 1nF from GATE to SNS_A, and 10nF from CT to GND.
* Raspberry Pi: connect the switched 5V to header pin 2 or 4 and GND to pin 6, and connect Pi GND to the
  Tiny Tapeout board GND. Backfeeding the header bypasses the Pi's input protection, so do not also connect a
  USB power supply to the Pi. To cut power at shutdown, add `dtoverlay=gpio-poweroff,gpiopin=<N>` to
  `config.txt` and wire that GPIO to OFF. Note that the Pi's USB-C, HDMI and similar connections still share GND.
