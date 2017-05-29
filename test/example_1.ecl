EXPORT Example_1 := MODULE
	EXPORT rec_1_ex_1 := RECORD
		REAL8 f2_r1e1 ;
		REAL8 f1_r1e1;
	END;
	EXPORT REAL8 function_ex1(REAL8 num) := FUNCTION
		RETURN 2*num;
	END;
END;