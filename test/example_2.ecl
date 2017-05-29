EXPORT example_2 := MODULE

	EXPORT rec_1 := RECORD
		Real8 v1;
	END;
	EXPORT rec_2 := RECORD(rec_1)
		Real8 v2;
	END;


	EXPORT abc := MODULE, VIRTUAL
		EXPORT unsigned4 sig;
		EXPORT sig_2 := 9.9;
	END;

	EXPORT def := MODULE(abc)
		EXPORT sig_2 := 10.0;
	END;

	EXPORT ghi := MODULE(def)
		EXPORT sig := 9.0;
		EXPORT sig_2 := 10.0;
	END;
END;