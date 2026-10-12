# Functional Specification Document (FSD)

**Project:** Sorting by Height (Advanced) — Ladder Diagram Control with OpenPLC and Node-RED Monitoring
**Author:** Olaf (Computer Engineering, Bina Nusantara University)
**Version:** 1.0
**Date:** 12 October 2026

---

## 1. Purpose

This document describes the functions that the PLC program (`main.ld`) must provide for the height-based box sorting system in the Factory I/O scene "Sorting by Height (Advanced)", together with the monitoring and control functions of the Node-RED dashboard over MQTT.

## 2. Scope

**Included:**

- Automatic control of the sorting process (one box per cycle) with Ladder Diagram (IEC 61131-3) in OpenPLC.
- Basic safety functions: Start, Stop, Emergency stop, Auto mode, Reset.
- A counter for the number of boxes sorted.
- Monitoring of all I/O and PLC states on a Node-RED dashboard over MQTT.
- Start, Stop and Reset control from the dashboard.

**Not included:**

- Manual mode.
- Handling of jammed boxes or timeout alarms.
- Physical hardware (this project is a simulation).
- Authentication on the MQTT broker.

## 3. System Overview

```
Factory I/O (Modbus server) <--- OpenPLC (Modbus master)
                                  OpenPLC (Modbus server :502) <--- Node-RED --- MQTT ---> Mosquitto
                                                                        |
                                                               Dashboard (node-red-dashboard)
```

| Component | Function |
|---|---|
| Factory I/O | Plant simulation (conveyors, turntable, sensors) |
| OpenPLC Runtime (Docker, Windows) | Runs the ladder program `main.ld` |
| Node-RED (macOS) | Reads PLC data over Modbus TCP, publishes/subscribes MQTT, hosts the dashboard |
| Mosquitto (Docker, macOS) | MQTT broker |

## 4. Process Description

Boxes of two heights are sent by the feeder conveyor to the entry conveyor. The `Low_Box` and `High_Box` sensors determine the box height. The box enters the turntable, the turntable rotates, and the box is pushed onto the left conveyor (low box) or the right conveyor (high box). The turntable then returns to its home position and the next cycle starts.

## 5. I/O List

OpenPLC uses bits 0–7 per byte, so `%IX0.8` in the Factory I/O list becomes `%IX1.0` in OpenPLC (the same applies to outputs).

### 5.1 Inputs

| Variable | Function | Address |
|---|---|---|
| `At_Entry` | Box at feeder entry | %IX0.0 |
| `Low_Box` | Height sensor (low) | %IX0.1 |
| `High_Box` | Height sensor (high) | %IX0.2 |
| `At_Turntable_Entry` | Box at turntable entry | %IX0.3 |
| `At_Load_Position` | Box at load position | %IX0.4 |
| `At_Unload_Position` | Box at unload position (not used yet) | %IX0.5 |
| `At_Front` | Front sensor (not used yet) | %IX0.6 |
| `At_Right_Entry` | Box entering right conveyor | %IX0.7 |
| `At_Left_Entry` | Box entering left conveyor | %IX1.0 |
| `At_Right_Exit` | Box at end of right conveyor (not used yet) | %IX1.1 |
| `At_Left_Exit` | Box at end of left conveyor (not used yet) | %IX1.2 |
| `Start_Button` | Start button | %IX1.3 |
| `Reset_Button` | Reset button | %IX1.4 |
| `Stop_Button` | Stop button (NC, TRUE = not pressed) | %IX1.5 |
| `Emergency_Stop` | Emergency stop (NC, TRUE = not pressed) | %IX1.6 |
| `Auto_Mode` | Auto selector | %IX1.7 |

### 5.2 Outputs

| Variable | Function | Address |
|---|---|---|
| `Feeder_Conveyor` | Feeder conveyor | %QX0.0 |
| `Entry_Conveyor` | Entry conveyor | %QX0.1 |
| `Load` | Turntable roller (load) | %QX0.2 |
| `Unload` | Turntable roller (unload) | %QX0.3 |
| `Turn` | Rotate turntable | %QX0.4 |
| `Left_Conveyor` | Left conveyor | %QX0.5 |
| `Right_Conveyor` | Right conveyor | %QX0.6 |
| `Green_Indicator` | Green lamp | %QX0.7 |
| `Yellow_Indicator` | Yellow lamp | %QX1.0 |
| `Red_Indicator` | Red lamp | %QX1.1 |
| `Start_Light` | Start light | %QX1.2 |
| `Reset_Light` | Reset light | %QX1.3 |
| `Stop_Light` | Stop light | %QX1.4 |
| `Counter` (INT) | Number of boxes sorted | %QW0 |

### 5.3 Internal variables exposed over Modbus (`%MX`)

| Variable | Address | Function |
|---|---|---|
| `Cmd_Start`, `Cmd_Stop`, `Cmd_Reset` | %MX0.0 – %MX0.2 | Commands from the dashboard |
| `Fault_Latch` | %MX1.0 | Fault caused by Emergency stop |
| `System_Run` | %MX1.1 | System running |
| `S0_Idle` … `S5_Delivered` | %MX1.2 – %MX1.7 | Process sequence steps |
| `Box_Tall`, `Box_Short`, `Height_OK` | %MX2.0 – %MX2.2 | Height detection result |
| `Side_Seen` | %MX2.3 | Box has been detected at left/right entry |

## 6. Functional Requirements

### 6.1 System control

| ID | Requirement |
|---|---|
| FR-01 | The system runs (`System_Run`) when Start is pressed (button or `Cmd_Start`) and keeps running (seal-in) while Stop is not active, `Auto_Mode` is on, and there is no fault. |
| FR-02 | Stop (`Stop_Button` NC or `Cmd_Stop`) turns off `System_Run`. Process steps are not cleared, and the process continues when Start is pressed again. |
| FR-03 | A pressed Emergency stop (NC) sets `Fault_Latch` and turns off `System_Run`. |
| FR-04 | `Fault_Latch` is only cleared by Reset (button or `Cmd_Reset`), and only after the Emergency stop is released. |
| FR-05 | The system only runs while `Auto_Mode` is on. |
| FR-06 | Reset returns the sequence to S0, clears the step latches, and clears `Counter`. |

### 6.2 Process sequence

| ID | Step | Entry condition | Action |
|---|---|---|---|
| FR-07 | S0 Idle | No other step active | Feeder conveyor runs, waiting for a box at `At_Entry` |
| FR-08 | S1 Transport | S0, `At_Entry`, `System_Run` | Feeder and entry conveyors run; box height is detected and latched |
| FR-09 | S2 Load | S1, `At_Turntable_Entry`, height known, `System_Run` | Entry conveyor and `Load` run; `T_Load_Delay` starts |
| FR-10 | S3 Turn | S2, `At_Load_Position`, `T_Load_Delay` done, `System_Run` | `Turn` on; `T_Turn` starts |
| FR-11 | S4 Unload | S3, `T_Turn` done, `System_Run` | Low box: `Unload` (to the left). High box: `Load` (to the right) |
| FR-12 | S5 Delivered | S4, `Side_Seen`, `T_Side_Delay` done | `Counter` +1, `Turn` off (turntable returns); after `T_Return` back to S0 |

### 6.3 Height detection

| ID | Requirement |
|---|---|
| FR-13 | `Box_Tall` is latched when `High_Box` is active during step S1. |
| FR-14 | `Box_Short` is latched when `Low_Box` is active without `High_Box` during step S1. |
| FR-15 | If both latches are set, the box is treated as tall (`Unload` is only active for `Box_Short` and not `Box_Tall`). |
| FR-16 | Both latches are cleared when the system returns to S0. |

### 6.4 Outputs

| Output | Condition |
|---|---|
| `Feeder_Conveyor` | `System_Run` and (S0 or S1) |
| `Entry_Conveyor` | `System_Run` and (S1 or S2) |
| `Load` | `System_Run` and (S2, or S4 with `Box_Tall`) |
| `Unload` | `System_Run`, S4, `Box_Short`, not `Box_Tall` |
| `Turn` | No `Fault_Latch`, and (S3 or S4) |
| `Left_Conveyor`, `Right_Conveyor` | `System_Run` |
| `Green_Indicator`, `Start_Light` | `System_Run` |
| `Yellow_Indicator` | Not `System_Run` and no fault |
| `Red_Indicator`, `Reset_Light` | `Fault_Latch` |
| `Stop_Light` | Not `System_Run` |

### 6.5 Timers and counter

| Name | Type | Value | Function |
|---|---|---|---|
| `T_Load_Delay` | TON | 1700 ms | Wait after the box is at the turntable entry before the turntable rotates |
| `T_Turn` | TON | 1700 ms | Turntable rotation time before unload |
| `T_Side_Delay` | TON | 1700 ms | Wait after the box is at left/right entry before the turntable returns |
| `T_Return` | TON | 1700 ms | Turntable return time before a new cycle |
| `C_Boxes` | CTU | PV 32767 | Counts step S5; its value is sent to `Counter` (%QW0); cleared by Reset |

The 1700 ms value was tuned in the simulation (originally 3000 ms, reduced because the motion is smoother).

## 7. Communication Interfaces

### 7.1 Modbus TCP (OpenPLC as server, port 502)

Addresses follow the OpenPLC Editor Address Mapping Reference.

| Data | Modbus type | Address (offset) |
|---|---|---|
| Inputs `%IX` | Discrete input | 0–15 |
| Outputs `%QX` | Coil | 0–12 |
| `Counter` (`%QW0`) | Holding register | 0 |
| `Cmd_Start`, `Cmd_Stop`, `Cmd_Reset` | Coil (write) | 8192, 8193, 8194 |
| Status `%MX1.0` – `%MX2.3` | Coil (read) | 8200 – 8211 |

The `%MX` Buffer Mapping in the OpenPLC Editor must be greater than 0 (64 bits are used).

### 7.2 MQTT (Node-RED <-> Mosquitto)

| Topic | Payload | Direction |
|---|---|---|
| `sorting/status/input/<name>` | `true` / `false` | PLC -> dashboard |
| `sorting/status/output/<name>` | `true` / `false` | PLC -> dashboard |
| `sorting/status/state/<name>` | `true` / `false` | PLC -> dashboard |
| `sorting/status/counter` | number | PLC -> dashboard |
| `sorting/status/step` | `S0 Idle` … `S5 Delivered` | PLC -> dashboard |
| `sorting/status/box_height` | `Tall` / `Short` / `-` | PLC -> dashboard |
| `sorting/status/mode` | `RUNNING` / `STOPPED` / `FAULT / E-STOP` | PLC -> dashboard |
| `sorting/system/plc` | `connected` / `disconnected` | Node-RED -> dashboard |
| `sorting/cmd/start`, `/stop`, `/reset` | `1` | dashboard -> PLC |

Node-RED polls every 500 ms, publishes only when a value changes (retained), and refreshes everything every 30 seconds. Dashboard commands are sent as a 300 ms pulse to the `Cmd_*` coils.

## 8. Dashboard

| Section | Content |
|---|---|
| Control | START, STOP, RESET buttons; text for Mode, Active step, Box height, Counter, PLC link and Node-RED status |
| Sequence | LEDs for the 12 internal states |
| Sensors & buttons | LEDs for the 16 inputs (Stop and Emergency stop: green = normal) |
| Actuators | LEDs for the 13 outputs |

## 9. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-01 | Only one box is processed at a time. |
| NFR-02 | Emergency stop comes only from the physical Factory I/O input; the dashboard and MQTT are not safety devices. |
| NFR-03 | Reset from the dashboard must not clear the fault while the Emergency stop is still pressed. |
| NFR-04 | PLC outputs are not written directly from the dashboard; the dashboard only sends commands to the `Cmd_*` bits. |
| NFR-05 | 500 ms polling is for monitoring and supervisory control only, not for fast interlocks. |

## 10. Assumptions and Limitations

- A tall box triggers both `High_Box` and `Low_Box`; a short box triggers only `Low_Box`. The height sensors are located between `At_Entry` and `At_Turntable_Entry`.
- The sorting direction is set by the turntable roller direction: `Unload` = left (low box), `Load` = right (high box).
- `Stop_Button` and `Emergency_Stop` are normally-closed.
- `Auto_Mode` comes only from Factory I/O; it cannot yet be changed from the dashboard.
- `Turn` is not turned off by Stop, only by Emergency stop (`Fault_Latch`).
- There is no manual mode, timeout, or jam detection.
- After an Emergency stop, any box left on the turntable is cleared manually before Start is pressed again.
- Mosquitto runs without authentication (simulation on a local network only).
- `At_Front`, `At_Unload_Position`, `At_Left_Exit`, `At_Right_Exit` are mapped but not yet used.

## 11. Acceptance Criteria

| No | Test | Expected result |
|---|---|---|
| 1 | Start with Auto on | Feeder runs, green lamp on |
| 2 | Low box | Goes onto the left conveyor |
| 3 | High box | Goes onto the right conveyor |
| 4 | Several boxes in a row | Processed one at a time, `Counter` increases |
| 5 | Stop | Conveyors stop, resume on Start |
| 6 | Emergency stop then Reset | Everything stops, red lamp on; Reset (after E-stop released) clears the fault |
| 7 | Reset | Back to S0, `Counter` = 0 |
| 8 | START/STOP/RESET from the dashboard | Same behavior as the physical buttons |
| 9 | Status on the dashboard | Matches the state in Factory I/O |
| 10 | OpenPLC stopped | `sorting/system/plc` = `disconnected` |

## 12. Related Files

| File | Content |
|---|---|
| `main.ld` | Ladder Diagram program for OpenPLC |
| `flows_sorting_nodered.json` | Node-RED flow (Modbus -> MQTT -> dashboard) |
| `README.md` | Project summary and run instructions |
