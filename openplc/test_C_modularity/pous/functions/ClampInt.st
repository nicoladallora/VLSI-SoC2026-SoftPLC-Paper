FUNCTION ClampInt : INT
VAR_INPUT
    x : INT;
    minVal : INT;
    maxVal : INT;
END_VAR

IF x < minVal THEN
    ClampInt := minVal;
ELSIF x > maxVal THEN
    ClampInt := maxVal;
ELSE
    ClampInt := x;
END_IF;

END_FUNCTION