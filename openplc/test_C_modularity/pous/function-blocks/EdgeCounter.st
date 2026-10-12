FUNCTION_BLOCK EdgeCounter
VAR_INPUT
    In : BOOL;
END_VAR

VAR_IN_OUT
    Count : DINT;
END_VAR

VAR_OUTPUT
    Q : BOOL;
END_VAR

VAR
    prev : BOOL := FALSE;
END_VAR

(* Q vale TRUE soltanto nel ciclo del fronte di salita *)
Q := FALSE;

IF In AND NOT prev THEN
    Count := Count + 1;
    Q := TRUE;
END_IF;

prev := In;

END_FUNCTION_BLOCK