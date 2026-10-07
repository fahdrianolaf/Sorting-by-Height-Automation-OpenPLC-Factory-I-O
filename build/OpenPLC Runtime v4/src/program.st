PROGRAM main
  VAR
    Fault_Latch : BOOL;
    System_Run : BOOL;
    S0_Idle : BOOL;
    S1_Transport : BOOL;
    S2_Load : BOOL;
    S3_Turn : BOOL;
    S4_Unload : BOOL;
    S5_Delivered : BOOL;
    Box_Tall : BOOL;
    Box_Short : BOOL;
    Height_OK : BOOL;
    Side_Entry_Det : BOOL;
    Side_Seen : BOOL;
    T_Turn : TON;
    T_Return : TON;
    T_Load_Delay : TON;
    T_Side_Delay : TON;
    C_Boxes : CTU;
  END_VAR
  VAR
    At_Entry AT %IX0.0 : BOOL;
    Low_Box AT %IX0.1 : BOOL;
    High_Box AT %IX0.2 : BOOL;
    At_Turntable_Entry AT %IX0.3 : BOOL;
    At_Load_Position AT %IX0.4 : BOOL;
    At_Unload_Position AT %IX0.5 : BOOL;
    At_Front AT %IX0.6 : BOOL;
    At_Right_Entry AT %IX0.7 : BOOL;
    At_Left_Entry AT %IX1.0 : BOOL;
    At_Right_Exit AT %IX1.1 : BOOL;
    At_Left_Exit AT %IX1.2 : BOOL;
    Start_Button AT %IX1.3 : BOOL;
    Reset_Button AT %IX1.4 : BOOL;
    Stop_Button AT %IX1.5 : BOOL;
    Emergency_Stop AT %IX1.6 : BOOL;
    Auto_Mode AT %IX1.7 : BOOL;
    Feeder_Conveyor AT %QX0.0 : BOOL;
    Entry_Conveyor AT %QX0.1 : BOOL;
    Load AT %QX0.2 : BOOL;
    Unload AT %QX0.3 : BOOL;
    Turn AT %QX0.4 : BOOL;
    Left_Conveyor AT %QX0.5 : BOOL;
    Right_Conveyor AT %QX0.6 : BOOL;
    Green_Indicator AT %QX0.7 : BOOL;
    Yellow_Indicator AT %QX1.0 : BOOL;
    Red_Indicator AT %QX1.1 : BOOL;
    Start_Light AT %QX1.2 : BOOL;
    Reset_Light AT %QX1.3 : BOOL;
    Stop_Light AT %QX1.4 : BOOL;
    Counter AT %QW0 : INT;
  END_VAR

  Fault_Latch := NOT(Emergency_Stop) OR NOT(Reset_Button) AND Fault_Latch;
  System_Run := NOT(Fault_Latch) AND Auto_Mode AND Stop_Button AND (Start_Button OR System_Run);
  S0_Idle := NOT(S5_Delivered) AND NOT(S4_Unload) AND NOT(S3_Turn) AND NOT(S2_Load) AND NOT(S1_Transport);
  Box_Tall := NOT(S0_Idle) AND (Box_Tall OR S1_Transport AND High_Box);
  Box_Short := NOT(S0_Idle) AND (Box_Short OR S1_Transport AND NOT(High_Box) AND Low_Box);
  Height_OK := Box_Short OR Box_Tall;
  S1_Transport := NOT(Reset_Button) AND NOT(S2_Load) AND (S1_Transport OR System_Run AND At_Entry AND S0_Idle);
  S2_Load := NOT(Reset_Button) AND NOT(S3_Turn) AND (S2_Load OR System_Run AND Height_OK AND At_Turntable_Entry AND S1_Transport);
  T_Load_Delay(IN := S2_Load, PT := T#1700ms);
  S3_Turn := NOT(Reset_Button) AND NOT(S4_Unload) AND (S3_Turn OR System_Run AND T_Load_Delay.Q AND At_Load_Position AND S2_Load);
  T_Turn(IN := S3_Turn, PT := T#1700ms);
  S4_Unload := NOT(Reset_Button) AND NOT(S5_Delivered) AND (S4_Unload OR System_Run AND T_Turn.Q AND S3_Turn);
  Side_Entry_Det := At_Left_Entry OR At_Right_Entry;
  Side_Seen := NOT(Reset_Button) AND NOT(S5_Delivered) AND (Side_Seen OR Side_Entry_Det AND S4_Unload);
  T_Side_Delay(IN := Side_Seen, PT := T#1700ms);
  S5_Delivered := NOT(Reset_Button) AND NOT(T_Return.Q) AND (S5_Delivered OR T_Side_Delay.Q AND S4_Unload);
  T_Return(IN := S5_Delivered, PT := T#1700ms);
  C_Boxes(CU := S5_Delivered, R := Reset_Button, PV := 32767);
  Counter := C_Boxes.CV;
  Feeder_Conveyor := System_Run AND (S0_Idle OR S1_Transport);
  Entry_Conveyor := System_Run AND (S1_Transport OR S2_Load);
  Load := System_Run AND (S2_Load OR Box_Tall AND S4_Unload);
  Unload := System_Run AND NOT(Box_Tall) AND Box_Short AND S4_Unload;
  Turn := NOT(Fault_Latch) AND (S3_Turn OR S4_Unload);
  Left_Conveyor := System_Run;
  Right_Conveyor := System_Run;
  Green_Indicator := System_Run;
  Yellow_Indicator := NOT(Fault_Latch) AND NOT(System_Run);
  Red_Indicator := Fault_Latch;
  Start_Light := System_Run;
  Reset_Light := Fault_Latch;
  Stop_Light := NOT(System_Run);
END_PROGRAM


CONFIGURATION Config0

  RESOURCE Res0 ON PLC
    TASK task0(INTERVAL := T#20ms,PRIORITY := 1);
    PROGRAM instance0 WITH task0 : main;
  END_RESOURCE
END_CONFIGURATION
