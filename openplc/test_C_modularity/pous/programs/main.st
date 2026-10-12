PROGRAM main
  VAR
    tp1 : TP;
    one : BOOL := TRUE;
    ec1 : EdgeCounter;
    edgeCount : DINT := 0;
    edgeQ : BOOL := FALSE;
    cf1 : INT := 0;
    cf2 : INT := 0;
    ok_func : BOOL := FALSE;
    ok_fb : BOOL := FALSE;
    ok_C : BOOL := FALSE;
  END_VAR

(* Impulso iniziale di 100 ms *)
tp1(IN := one, PT := T#100ms);

(* Test della funzione: valore sotto il minimo *)
cf1 := ClampInt(
    x := -3,
    minVal := 0,
    maxVal := 10
);

(* Test della funzione: valore dentro l'intervallo *)
cf2 := ClampInt(
    x := 5,
    minVal := 0,
    maxVal := 10
);

ok_func := (cf1 = 0) AND (cf2 = 5);

(* Il blocco modifica direttamente edgeCount *)
ec1(In := tp1.Q, Count := edgeCount);

edgeQ := ec1.Q;

(* Verifica del conteggio *)
ok_fb := (edgeCount >= 1);

(* Esito complessivo *)
ok_C := ok_func AND ok_fb;

END_PROGRAM