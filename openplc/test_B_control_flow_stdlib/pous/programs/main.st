PROGRAM main
  VAR
    s_for : INT := 0;
    i : INT := 0;
    j : INT := 0;
    case_code : INT := 0;
    ok_if : BOOL := FALSE;
    ok_for : BOOL := FALSE;
    ok_while : BOOL := FALSE;
    ok_case : BOOL := FALSE;
    ton1 : TON;
    tp1 : TP;
    tof1 : TOF;
    one : BOOL := TRUE;
    seen_tp_true : BOOL := FALSE;
    seen_tp_false : BOOL := FALSE;
    seen_tof_hold : BOOL := FALSE;
    ok_ton : BOOL := FALSE;
    ok_tp : BOOL := FALSE;
    ok_tof : BOOL := FALSE;
    ok_B : BOOL := FALSE;
  END_VAR

(* Test FOR: somma 1 + 2 + 3 *)
s_for := 0;

FOR i := 1 TO 3 DO
    s_for := s_for + i;
END_FOR;

ok_for := (s_for = 6);


(* Test WHILE: incremento fino a 3 *)
j := 0;

WHILE j < 3 DO
    j := j + 1;
END_WHILE;

ok_while := (j = 3);


(* Test IF *)
IF s_for = 6 THEN
    ok_if := TRUE;
ELSE
    ok_if := FALSE;
END_IF;


(* Test CASE: selezione del ramo 3 *)
case_code := 3;

CASE case_code OF
    1:
        case_code := 1;
    2:
        case_code := 2;
    3:
        case_code := 3;
ELSE
    case_code := -1;
END_CASE;

ok_case := (case_code = 3);


(* TON: uscita TRUE dopo 150 ms *)
ton1(IN := TRUE, PT := T#150ms);

(* TP: impulso iniziale di 200 ms *)
tp1(IN := one, PT := T#200ms);

(* TOF: mantiene l'uscita per 100 ms
   dopo la fine dell'impulso TP *)
tof1(IN := tp1.Q, PT := T#100ms);


(* Memorizzazione delle fasi dell'impulso *)
IF tp1.Q THEN
    seen_tp_true := TRUE;
END_IF;

IF (NOT tp1.Q) AND seen_tp_true THEN
    seen_tp_false := TRUE;
END_IF;

(* Osservazione del ritardo allo spegnimento *)
IF tof1.Q AND (NOT tp1.Q) THEN
    seen_tof_hold := TRUE;
END_IF;


(* Risultati dei timer *)
ok_ton := ton1.Q;
ok_tp := seen_tp_true AND seen_tp_false;
ok_tof := seen_tof_hold;


(* Esito complessivo, conversioni escluse *)
ok_B := ok_if
    AND ok_for
    AND ok_while
    AND ok_case
    AND ok_ton
    AND ok_tp
    AND ok_tof;

END_PROGRAM