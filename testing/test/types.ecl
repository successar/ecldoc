EXPORT types := MODULE
	EXPORT v1 := RECORD
		REAL8 u;
		REAL8 v;
	END;

	EXPORT DATASET(v1) mod_1 := DATASET([{1, 2}], v1);

	EXPORT DATASET({STRING20 a}) mod_2 := DATASET([], {STRING20 a});

	EXPORT mod_3 := ENUM(UNSIGNED8, a, b, c, d);

	EXPORT mod_4 := mod_3;

	EXPORT mod_5(REAL8 x) := MODULE
		EXPORT v6 := x * 4;
	END;

	EXPORT mod_6(REAL8 x) := mod_5(x);

	EXPORT mod_7(mod_5 y, REAL8 z) := FUNCTION
		RETURN y(0.5).v6 + z;
	END;

	EXPORT mod_8(mod_3 a1) := a1 * 9;

	EXPORT mod_9(mod_7 x) := x(mod_5, 3.0);

	EXPORT ScaleInt := TYPE
        EXPORT REAL LOAD(INTEGER4 I ) := I / 100;
        EXPORT INTEGER4 STORE(REAL R) := ROUND(R * 100);
    END;

    EXPORT mod_10 := RECORD
    	ScaleInt y;
    END;

    EXPORT mod_11(DATASET(mod_10) y) := y;

    EXPORT D1 := DATASET([{1, 2, 3}], {UNSIGNED4 F1, REAL8 f2, REAL8 f3});

    EXPORT mod_12 := RECORD
    	D1.F1;
    	gcount := COUNT(GROUP);
    END;

    EXPORT mod_13 := TABLE(D1, mod_12, F1);

    EXPORT v2 := RECORD
    	UNSIGNED4 w1;
    	UNSIGNED4 w2;
    	UNSIGNED4 w3;
    END;

    EXPORT v2 v1tov2(v1 x) := TRANSFORM
    	SELF.w1 := x.v;
    	SELF.w2 := x.u;
    	SELF.w3 := x.u * x.v;
    END;

    EXPORT TYPEOF(mod_1) mod_14 := DATASET([{1, 3}], v1);

    v3 := RECORD
    	REAL8 w1;
    END;
    EXPORT DATASET(v3) mod_15 := DATASET([{1}], v3);

    EXPORT mod_16(v1tov2 tr, DATASET(v1) x) := PROJECT(x, tr);

    EXPORT v4 := RECORD(v2)
    	REAL8 w4;
    END;

    EXPORT v5 := RECORD
    	v1 OR v2;
    	REAL8 w4;
    	DATASET(v2) w5;
    END;

END;
