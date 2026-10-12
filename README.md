<div align="center">
  <a href="https://www.youtube.com/watch?v=3Rn_7Q1jHdE">
    <img src="https://youtube.com" alt="Sorting by Height Automation - OpenPLC & Factory I/O (Simulation)" width="600">
  </a>
  <p>🎥 <b><a href="https://www.youtube.com/watch?v=3Rn_7Q1jHdE">Click here to watch the full OpenPLC & Factory I/O Automation Simulation Demo</a></b></p>
</div>

# Sorting by Height (Advanced) — Ladder Diagram Control with OpenPLC

An industrial automation simulation project: a system that sorts boxes by height (low / high) using a turntable, controlled by a Ladder Diagram program (IEC 61131-3) in OpenPLC and simulated in Factory I/O. A Node-RED dashboard monitors and controls the PLC over MQTT.

| | |
|---|---|
| Name | Olaf |
| Study program | Computer Engineering, Bina Nusantara University (BINUS) |
| Project type | Personal / portfolio project (simulation, no physical hardware) |
| Programming language | Ladder Diagram (IEC 61131-3) |
| Tools | OpenPLC Editor, OpenPLC Runtime (Docker), Factory I/O, Node-RED, Mosquitto |
| Communication | Modbus TCP/IP (Factory I/O as server, OpenPLC as master; OpenPLC also acts as a Modbus server for Node-RED), MQTT |

> Add here: a screenshot of the Factory I/O scene and of the ladder in OpenPLC Editor (2–3 images recommended), plus a demo video link if you have one.

See also [`FSD_EN.md`](FSD_EN.md) for the functional specification.

---

## 1. Background and Objectives

Sorting items by size is a common process in production lines and warehouses. This project simulates that process with a virtual PLC so the control logic can be designed and tested without hardware.

Objectives:

1. Design a Ladder Diagram program that runs the sorting process automatically (one box per cycle).
2. Implement basic safety functions: Start, Stop, Emergency stop, Auto mode, and Reset.
3. Connect OpenPLC with Factory I/O over Modbus TCP/IP.
4. Monitor and control the PLC from a Node-RED dashboard over MQTT.

## 2. Process Description

Boxes of two heights are sent by the feeder conveyor. The `Low_Box` and `High_Box` sensors detect the box height as it passes along the entry conveyor. The box then enters the turntable, the turntable rotates, and the box is pushed onto the left conveyor (low box) or the right conveyor (high box).

Short flow:

```
Feeder -> Entry conveyor -> (height detection) -> Turntable
                                                      |
                                     turn + unload    |
                          Left conveyor <-- low   high --> Right conveyor
```

## 3. I/O List

Address note: OpenPLC only uses bits 0–7 per byte, so `%IX0.8` in the Factory I/O list becomes `%IX1.0` in OpenPLC (and so on). Modbus addresses stay sequential from 0.

### Inputs

| Variable | Function | OpenPLC address | Modbus (discrete input) |
|---|---|---|---|
| `At_Entry` | Box at feeder entry | %IX0.0 | 0 |
| `Low_Box` | Height sensor (low) | %IX0.1 | 1 |
| `High_Box` | Height sensor (high) | %IX0.2 | 2 |
| `At_Turntable_Entry` | Box at turntable entry | %IX0.3 | 3 |
| `At_Load_Position` | Box at load position | %IX0.4 | 4 |
| `At_Unload_Position` | Box at unload position | %IX0.5 | 5 |
| `At_Front` | Front sensor | %IX0.6 | 6 |
| `At_Right_Entry` | Box entering right conveyor | %IX0.7 | 7 |
| `At_Left_Entry` | Box entering left conveyor | %IX1.0 | 8 |
| `At_Right_Exit` | Box at end of right conveyor | %IX1.1 | 9 |
| `At_Left_Exit` | Box at end of left conveyor | %IX1.2 | 10 |
| `Start_Button` | Start button | %IX1.3 | 11 |
| `Reset_Button` | Reset button | %IX1.4 | 12 |
| `Stop_Button` | Stop button (NC) | %IX1.5 | 13 |
| `Emergency_Stop` | Emergency stop (NC) | %IX1.6 | 14 |
| `Auto_Mode` | Auto selector | %IX1.7 | 15 |

### Outputs

| Variable | Function | OpenPLC address | Modbus (coil) |
|---|---|---|---|
| `Feeder_Conveyor` | Feeder conveyor | %QX0.0 | 0 |
| `Entry_Conveyor` | Entry conveyor | %QX0.1 | 1 |
| `Load` | Turntable roller (load) | %QX0.2 | 2 |
| `Unload` | Turntable roller (unload) | %QX0.3 | 3 |
| `Turn` | Rotate turntable | %QX0.4 | 4 |
| `Left_Conveyor` | Left conveyor | %QX0.5 | 5 |
| `Right_Conveyor` | Right conveyor | %QX0.6 | 6 |
| `Green_Indicator` | Green lamp | %QX0.7 | 7 |
| `Yellow_Indicator` | Yellow lamp | %QX1.0 | 8 |
| `Red_Indicator` | Red lamp | %QX1.1 | 9 |
| `Start_Light` | Start light | %QX1.2 | 10 |
| `Reset_Light` | Reset light | %QX1.3 | 11 |
| `Stop_Light` | Stop light | %QX1.4 | 12 |
| `Counter` (INT) | Number of boxes sorted | %QW0 | Holding register 0 |

`At_Front`, `At_Unload_Position`, `At_Left_Exit`, and `At_Right_Exit` are mapped but not used in the logic.

### Internal variables

Variables mapped to `%MX` can be read/written over Modbus (coil 8192 and up on OpenPLC Runtime v4) and are used by Node-RED (see section 10).

| Variable | Address | Function |
|---|---|---|
| `Cmd_Start`, `Cmd_Stop`, `Cmd_Reset` | %MX0.0 – %MX0.2 (coil 8192–8194) | Commands from the dashboard (written by Node-RED as a 300 ms pulse) |
| `Fault_Latch` | %MX1.0 (coil 8200) | Latch set when Emergency stop is pressed, cleared by Reset |
| `System_Run` | %MX1.1 (coil 8201) | System running (Start, Stop OK, Auto on, no fault) |
| `S0_Idle` … `S5_Delivered` | %MX1.2 – %MX1.7 (coil 8202–8207) | Process sequence steps |
| `Box_Tall`, `Box_Short`, `Height_OK` | %MX2.0 – %MX2.2 (coil 8208–8210) | Stores the height detection result while the box moves |
| `Side_Seen` | %MX2.3 (coil 8211) | Box detected entering left/right conveyor (latched) |
| `Start_Req`, `Reset_Req` | - | Start / Reset from the physical button OR from the dashboard |
| `Side_Entry_Det` | - | `At_Left_Entry` OR `At_Right_Entry` |
| `T_Load_Delay`, `T_Turn`, `T_Side_Delay`, `T_Return` | - | TON timers, each `T#1700ms` |
| `C_Boxes` | - | CTU counter, its value is sent to `Counter` (%QW0) |

## 4. Control Logic

The program uses a step sequence pattern with self-holding (seal-in) coils. Only one box is processed at a time.

| Step | Entry condition | Action |
|---|---|---|
| S0 Idle | No step active | Feeder runs, waiting for a box at `At_Entry` |
| S1 Transport | S0, `At_Entry`, `System_Run` | Feeder + entry conveyor run; `High_Box` latches `Box_Tall`, `Low_Box` without `High_Box` latches `Box_Short` |
| S2 Load | S1, `At_Turntable_Entry`, height known | Entry conveyor + `Load` run; `T_Load_Delay` starts |
| S3 Turn | S2, `At_Load_Position`, `T_Load_Delay.Q` | `Turn` on; `T_Turn` starts |
| S4 Unload | S3, `T_Turn.Q` | Low box: `Unload` (to the left). High box: `Load` (to the right) |
| S5 Delivered | S4, `T_Side_Delay.Q` (delay after the left/right entry sensor) | Counter +1, `Turn` off (turntable returns), `T_Return`, then back to S0 |

Safety functions:

- **Emergency stop** (NC): `Fault_Latch` is set, `System_Run` turns off, the red lamp turns on. Reset (after the button is released) clears the fault.
- **Stop** (NC) or `Cmd_Stop` from the dashboard: `System_Run` turns off; steps are kept and the process continues when Start is pressed again.
- **Auto**: the system only runs while `Auto_Mode` is on (manual mode is not implemented).
- **Reset** (button or `Cmd_Reset`): clears the fault, returns the sequence to S0, and clears the counter. If the physical Emergency stop is still pressed, a Reset from the dashboard will not clear the fault.
- **Start** can come from the physical button or `Cmd_Start` (through `Start_Req`); Emergency stop and Auto stay on the Factory I/O side only.

### Example rung (step S3 Turn)

Logic: the turntable may only rotate when the box is at the load position **and** the delay has finished, so the box is not left behind.

```
|  S2_Load  At_Load_Position  T_Load_Delay.Q  System_Run   S4_Unload  Reset_Req            |
+--| |-----------| |--------------| |-----------| |----+----|/|--------|/|-----------( S3_Turn )
|                                                      |
+--| |------ S3_Turn ------------------------------------+
```

### Example cycle (tall box)

1. The box arrives at `At_Entry` -> S1; `High_Box` goes active -> `Box_Tall` is latched.
2. The box reaches `At_Turntable_Entry` -> S2; `Load` and the entry conveyor run, `T_Load_Delay` counts 1700 ms.
3. `At_Load_Position` goes active and the delay finishes -> S3; `Turn` is on.
4. After `T_Turn` -> S4; because of `Box_Tall`, `Load` is on and the box moves onto the right conveyor.
5. `At_Right_Entry` goes active -> `Side_Seen` -> after 1700 ms -> S5; counter +1, turntable returns.

## 5. Testing

| No | Scenario | Expected result | Result |
|---|---|---|---|
| 1 | Start with Auto on | Feeder starts running | Passed |
| 2 | Low box | Goes onto the left conveyor | Passed |
| 3 | High box | Goes onto the right conveyor | Passed |
| 4 | Several boxes in a row | Processed one at a time, counter increases | Passed |
| 5 | Stop while the process is running | Conveyors stop, resume on Start | *(fill in after testing)* |
| 6 | Emergency stop | Everything stops, red lamp on, Reset needed | *(fill in after testing)* |
| 7 | Reset | Back to S0, counter 0 | *(fill in after testing)* |

## 6. Problems and Solutions

**Problem:** in the first test, the turntable rotated too fast, so the box was not fully on the turntable yet.

**Solution:** two TON timer delays were added: one after the box is detected at `At_Turntable_Entry` before the turntable rotates, and one after the box is detected at `At_Left_Entry`/`At_Right_Entry` before the turntable returns. The delays were originally 3000 ms and were then reduced to 1700 ms because the motion is smoother.

## 7. Assumptions and Limitations

- Only one box is processed per cycle (the feeder stops while a box is on the turntable).
- A tall box triggers `High_Box` and `Low_Box`; a short box only triggers `Low_Box`.
- The sorting direction is set by the roller direction (`Unload` = left for low boxes, `Load` = right for high boxes).
- There is no manual mode and no handling of jammed boxes.
- After an Emergency stop, a box left on the turntable must be cleared manually before pressing Start again.

## 8. Future Work

- Use `At_Left_Exit` / `At_Right_Exit` to stop the conveyors or count boxes leaving.
- Add a timeout/alarm if a box does not reach a sensor within a set time.
- Add a manual mode.
- Store counter data in a database for production history.
- Add authentication to the MQTT broker.

## 9. How to Run

1. Open `main.ld` in OpenPLC Editor, compile, and upload the program to OpenPLC Runtime.
2. Start OpenPLC Runtime and open the **Sorting by Height (Advanced)** scene in Factory I/O.
3. In Factory I/O: Drivers -> Modbus TCP/IP Server, then set the number of inputs/outputs according to the I/O table and connect all tags. In OpenPLC Editor, Factory I/O is added as a slave device (OpenPLC acts as the Modbus master).
4. Run the scene, turn on Auto, and press Start.

## 10. Node-RED and MQTT Integration (Monitoring + Control)

The PLC (OpenPLC) cannot publish MQTT by itself, so Node-RED is used as a bridge: it reads data from OpenPLC over Modbus TCP and publishes it to the MQTT broker (Mosquitto). The dashboard only reads from MQTT, so other MQTT clients (for example MQTT Explorer) can also monitor and send commands.

```
Factory I/O (Modbus server) <--Modbus-- OpenPLC (master) ... OpenPLC (Modbus server :502) <--Modbus-- Node-RED --MQTT--> Mosquitto
                                                                          |
                                                                 Dashboard (node-red-dashboard)
```

### 10.1 Data flow

- **Monitoring:** Node-RED reads discrete inputs 0–15, coils 0–12, holding register 0, and coils 8200–8211 (internal status) every 500 ms. Values are published only when they change (retained), and refreshed fully every 30 seconds.
- **Control:** dashboard buttons publish to `sorting/cmd/start|stop|reset`. Node-RED receives those topics and writes a 300 ms pulse to coils 8192–8194 (`Cmd_Start`, `Cmd_Stop`, `Cmd_Reset`).
- Outputs such as `Feeder_Conveyor` are **not** written directly from the dashboard because the ladder would overwrite them every scan. The dashboard only sends commands to the command bits, and the ladder decides.

### 10.2 MQTT topics

| Topic | Payload | Direction |
|---|---|---|
| `sorting/status/input/<name>` (e.g. `at_entry`, `low_box`) | `true` / `false` | PLC -> dashboard |
| `sorting/status/output/<name>` (e.g. `feeder_conveyor`, `turn`) | `true` / `false` | PLC -> dashboard |
| `sorting/status/state/<name>` (e.g. `system_run`, `s3_turn`, `box_tall`) | `true` / `false` | PLC -> dashboard |
| `sorting/status/counter` | number | PLC -> dashboard |
| `sorting/status/step` | `S0 Idle` … `S5 Delivered` | PLC -> dashboard |
| `sorting/status/box_height` | `Tall` / `Short` / `-` | PLC -> dashboard |
| `sorting/status/mode` | `RUNNING` / `STOPPED` / `FAULT / E-STOP` | PLC -> dashboard |
| `sorting/system/plc` | `connected` / `disconnected` | Node-RED -> dashboard |
| `sorting/system/status` | `online` / `offline` (birth/will message) | Node-RED -> dashboard |
| `sorting/cmd/start`, `sorting/cmd/stop`, `sorting/cmd/reset` | `1` | dashboard -> PLC |

### 10.3 How to run

**OpenPLC setup (one time):**

1. In OpenPLC Editor, add a **Server** (Modbus/TCP protocol) to the project, port `502`, interface `0.0.0.0`, then turn on **Enable Server**.
2. In Buffer Mapping, the `%MX` coil count must be greater than 0 (64 bits are used), because `%MX` is not exposed if the count is 0.
3. The OpenPLC container must publish port 502 (`-p 502:502`), and Windows Firewall must allow TCP 502 from the local network.
4. Modbus addresses follow the Address Mapping Reference in the Editor: `%IX` -> discrete input (offset 0), `%QX` -> coil (offset 0), `%MX` -> coil (offset 8192, after the 8192 `%QX` bits), `%QW0` -> holding register 0.

**Node-RED:**

1. Make sure Mosquitto is running (e.g. via Docker) at `localhost:1883`.
2. Install the nodes in Node-RED: `node-red-contrib-modbus` and `node-red-dashboard` (Menu -> Manage palette).
3. Upload the new `main.ld` to OpenPLC Runtime and start the PLC. Run Factory I/O as usual.
4. In Node-RED: Menu -> Import -> choose `flows_sorting_nodered.json`.
5. Check the **OpenPLC** config node (host = IP of the Windows laptop, default `192.168.18.47`; port `502`; unit id 1) and the **Mosquitto** config node; adjust them if the laptop's IP changes, then Deploy.
6. Open the dashboard at `http://localhost:1880/ui`.

### 10.4 Testing

| No | Scenario | Expected result | Result |
|---|---|---|---|
| 1 | Subscribe to `sorting/status/#` in MQTT Explorer | All topics appear and are retained | *(fill in after testing)* |
| 2 | START button on the dashboard | `mode` = RUNNING, feeder runs | *(fill in after testing)* |
| 3 | STOP button on the dashboard | `mode` = STOPPED, conveyors stop | *(fill in after testing)* |
| 4 | Emergency stop in Factory I/O | `mode` = FAULT / E-STOP, red LED | *(fill in after testing)* |
| 5 | RESET button after E-stop is released | Fault cleared, counter 0 | *(fill in after testing)* |
| 6 | Counter while boxes are sorted | Dashboard value matches `Counter` in Factory I/O | *(fill in after testing)* |
| 7 | Stop OpenPLC Runtime | `sorting/system/plc` = disconnected | *(fill in after testing)* |

### 10.5 Safety notes and limitations

- The dashboard/MQTT is **not** a safety device. Emergency stop stays on the physical input (Factory I/O) only, and a Reset from the dashboard cannot clear the fault while the E-stop is still pressed.
- Data is polled every 500 ms, so this is suitable for monitoring and supervisory control, not fast interlocks.
- Mosquitto in this setup has no authentication (simulation on localhost/local network only).
- `Auto_Mode` stays a Factory I/O switch and cannot yet be controlled from the dashboard.

> Add dashboard screenshots (while running and during a fault) and a screenshot of MQTT Explorer.

## 11. Summary for CV

- Designed a Ladder Diagram (IEC 61131-3) program in OpenPLC for a height-based sorting system, covering a step sequence, Start/Stop/Emergency stop interlocks, timers, and a counter.
- Integrated OpenPLC with Factory I/O over Modbus TCP/IP (16 inputs, 13 outputs, 1 holding register).
- Performed commissioning and tuning in simulation (added timer delays so the turntable motion matches the box position).
- Built a PLC monitoring and control bridge to MQTT with Node-RED (Modbus TCP -> Mosquitto -> dashboard): 41 I/O statuses shown in real time, and Start/Stop/Reset commands sent from the dashboard over MQTT.
