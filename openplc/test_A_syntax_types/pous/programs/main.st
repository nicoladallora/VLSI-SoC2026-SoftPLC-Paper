PROGRAM main
  VAR
    K : INT := 7;
    b1 : BOOL := TRUE;
    i1 : INT := -3;
    di : DINT := 100000;
    r1 : REAL := 3.5;
    t1 : TIME := T#150ms;
    p1 : TPOINT;
    c1 : COLOR := blue;
    arr : ARRAY[1..3] OF INT;
    sum : INT := 0;
    initDone : BOOL := FALSE;
    ok_scalar : BOOL := FALSE;
    ok_array : BOOL := FALSE;
    ok_struct : BOOL := FALSE;
    ok_enum : BOOL := FALSE;
    ok_time : BOOL := FALSE;
    ok_all : BOOL := FALSE;
  END_VAR

(* Inizializzazione al primo ciclo *)
IF NOT initDone THEN
    arr[1] := 1;
    arr[2] := 2;
    arr[3] := 3;

    p1.x := 2;
    p1.y := 5;

    initDone := TRUE;
END_IF;

(* Verifica degli scalari *)
ok_scalar := b1
    AND (i1 = -3)
    AND (di = 100000)
    AND (r1 >= 3.5)
    AND (r1 < 3.5001)
    AND (K = 7);

(* Verifica dell'array *)
sum := arr[1] + arr[2] + arr[3];
ok_array := (sum = 6);

(* Verifica della struttura *)
ok_struct := (p1.x * p1.y = 10);

(* Verifica dell'enumerazione *)
ok_enum := (c1 = blue);

(* Verifica del valore TIME *)
ok_time := (t1 = T#150ms);

(* Esito complessivo *)
ok_all := ok_scalar
    AND ok_array
    AND ok_struct
    AND ok_enum
    AND ok_time;

END_PROGRAM