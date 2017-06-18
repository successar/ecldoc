EXPORT Bundle := MODULE
	EXPORT rec_0 := ['ML_Core', 'PBBlas'];
	EXPORT rec_1 := 1.2;
	EXPORT rec_2 := 3.4;
	EXPORT att := OUTPUT(DATASET([{rec_1, rec_2}], {real8 u, real8 v}));
END;
