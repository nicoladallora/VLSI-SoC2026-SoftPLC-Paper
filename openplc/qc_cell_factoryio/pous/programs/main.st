PROGRAM main
VAR CONSTANT
    X_PICK : REAL := 35.0;
    X_PLACE : REAL := 75.0;
    X_REWORK : REAL := 15.0;

    Z_UP : REAL := 90.0;
    Z_DOWN : REAL := 12.0;

    T_GRIP : TIME := T#120ms;
    T_DWELL : TIME := T#200ms;
END_VAR

VAR

    StartBtn : BOOL;
    StopBtn : BOOL;
    ResetBtn : BOOL;
    AutoSel : BOOL;
    ManualSel : BOOL;

    Estop : BOOL;
    SafetyDoor : BOOL;

    ItemAtEntry : BOOL;
    ItemAtExit : BOOL;
    VisionOK : BOOL;
    PP_MovingX : BOOL;
    PP_MovingZ : BOOL;
    PP_ItemDet : BOOL;

    ConvEntry : BOOL;
    ConvExit : BOOL;
    StopGate : BOOL;

    Grab : BOOL;
    GripCW : BOOL;
    GripCCW : BOOL;
    RotCW : BOOL;
    RotCCW : BOOL;

    L_Red : BOOL;
    L_Yellow : BOOL;
    L_Green : BOOL;
    Siren : BOOL;

    X_SP : REAL;
    Z_SP : REAL;

    State : INT := 0;
    PrevState : INT := 0;
    Run : BOOL := FALSE;
    Paused : BOOL := FALSE;
    Fault : BOOL := FALSE;

    EStart : R_TRIG;
    EStopTrig : R_TRIG;
    EReset : R_TRIG;

    StartR : BOOL;
    StopR : BOOL;
    ResetR : BOOL;

    tGrip : TON;
    tDwell : TON;

    ConvPermit : BOOL;
END_VAR

(* Consenso generale *)
ConvPermit := (NOT Estop) AND (NOT SafetyDoor);

(* Fronti dei pulsanti *)
EStart(CLK := StartBtn);
StartR := EStart.Q;

EStopTrig(CLK := StopBtn);
StopR := EStopTrig.Q;

EReset(CLK := ResetBtn);
ResetR := EReset.Q;


(* Reset *)
IF ResetR THEN
    Run := FALSE;
    Paused := FALSE;
    Fault := FALSE;
    State := 0;
    PrevState := -1;
END_IF;

(* Stop: logica originale della tesi.
   Non sospende il CASE negli stati attivi. *)
IF StopR THEN
    Run := FALSE;
    Paused := TRUE;
END_IF;

(* Avvio automatico *)
IF StartR AND AutoSel AND ConvPermit THEN
    Run := TRUE;
    Paused := FALSE;
END_IF;

(* Emergenza o porta aperta *)
IF Estop OR SafetyDoor THEN
    Run := FALSE;
    Fault := TRUE;
    State := 900;
END_IF;


(* Sequenza principale *)
CASE State OF

    (* Attesa e posizione iniziale *)
    0:
        L_Green := FALSE;
        L_Yellow := NOT Run;
        L_Red := Fault;
        Siren := Fault;

        ConvEntry := FALSE;
        ConvExit := FALSE;
        StopGate := TRUE;

        Grab := FALSE;
        GripCW := FALSE;
        GripCCW := FALSE;
        RotCW := FALSE;
        RotCCW := FALSE;

        X_SP := X_PICK;
        Z_SP := Z_UP;

        IF Run THEN
            State := 10;
        END_IF;


    (* Alimentazione del pezzo *)
    10:
        L_Green := TRUE;
        L_Yellow := FALSE;
        L_Red := FALSE;
        Siren := FALSE;

        StopGate := TRUE;
        ConvEntry := NOT ItemAtEntry;
        ConvExit := FALSE;

        X_SP := X_PICK;
        Z_SP := Z_UP;

        IF ItemAtEntry THEN
            State := 20;
        END_IF;


    (* Presa del pezzo *)
    20:
        StopGate := TRUE;
        ConvEntry := FALSE;

        X_SP := X_PICK;
        Z_SP := Z_DOWN;

        tGrip(IN := TRUE, PT := T_GRIP);

        IF tGrip.Q THEN
            Grab := TRUE;

            tDwell(IN := TRUE, PT := T_DWELL);

            IF tDwell.Q THEN
                Z_SP := Z_UP;

                tGrip(IN := FALSE);
                tDwell(IN := FALSE);

                State := 30;
            END_IF;
        END_IF;


    (* Decisione sulla qualità *)
    30:
        IF VisionOK THEN
            State := 40;
        ELSE
            State := 60;
        END_IF;


    (* Deposito del pezzo conforme *)
    40:
        X_SP := X_PLACE;
        Z_SP := Z_UP;

        ConvExit := TRUE;
        ConvEntry := FALSE;

        IF NOT PP_MovingX THEN
            Z_SP := Z_DOWN;

            tDwell(IN := TRUE, PT := T_DWELL);

            IF tDwell.Q THEN
                Grab := FALSE;
                Z_SP := Z_UP;
                ConvExit := TRUE;

                tDwell(IN := FALSE);

                IF ItemAtExit THEN
                    ConvExit := FALSE;
                END_IF;

                State := 80;
            END_IF;
        END_IF;


    (* Ricircolo del pezzo non conforme *)
    60:
        X_SP := X_REWORK;
        Z_SP := Z_UP;

        ConvEntry := TRUE;
        ConvExit := FALSE;

        IF NOT PP_MovingX THEN
            Z_SP := Z_DOWN;

            tDwell(IN := TRUE, PT := T_DWELL);

            IF tDwell.Q THEN
                Grab := FALSE;
                Z_SP := Z_UP;

                tDwell(IN := FALSE);

                State := 80;
            END_IF;
        END_IF;


    (* Ritorno alla posizione di presa *)
    80:
        X_SP := X_PICK;
        Z_SP := Z_UP;
        StopGate := FALSE;

        IF NOT PP_MovingX THEN
            StopGate := TRUE;
            State := 10;
        END_IF;


    (* Stato di guasto *)
    900:
        L_Red := TRUE;
        L_Green := FALSE;
        L_Yellow := FALSE;
        Siren := TRUE;

        ConvEntry := FALSE;
        ConvExit := FALSE;
        StopGate := TRUE;
        Grab := FALSE;

        IF ResetR AND ConvPermit THEN
            Fault := FALSE;
            Siren := FALSE;
            State := 0;
        END_IF;

END_CASE;

END_PROGRAM