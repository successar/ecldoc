/**
  Top Level Module with Args
*/
EXPORT Example(REAL8 arg_module_1) := MODULE

  /**
  	Record Example 1
  	@param f field_1
  	@param g field_2
  */
  EXPORT rec_1_ex := RECORD
    REAL8 f;
    REAL8 g;
  END;

  /**
  	Record Example 1
  	@param h field_1
  	@param g field_2
  */
  EXPORT rec_2_ex := RECORD
    REAL8 h := 2.0;
    REAL8 g;
  END;

  /**
  	Interface Example
  */
  EXPORT interface_ex := INTERFACE
  	EXPORT STRING20 iface_var_1;
  	EXPORT STRING2   iface_var_2;
  	EXPORT STRING25  iface_var_3 := '';
  END;

  /**
  	Function Example 1
  	@param x param_1
  	@param y param_2
  	@param d param_3
  	@return Dataset(rec_1_ex)
  */
  Export DATASET(rec_1_ex) function_ex(Real8 x, REAL8 y, DATASET({Real8 u}) d) := FUNCTION
  	RETURN DATASET([{1, 2}], rec_1_ex);
  END;

  /**
  	Module with Arguments
  	Transform within Module
  */
  Export mod_with_arg_ex(REAL8 a) := MODULE
  	EXPORT pi_w := 2.3;
  	EXPORT rec_1_ex tranform_ex_in_mod(rec_2_ex rec) := TRANSFORM
  		SELF.f := rec.h;
  		SELF.g := rec.g;
  	END;
  END;

  /**
  	Module without Args
  	Function within Module
  */

  EXPORT mod_without_arg_ex := MODULE
    EXPORT pi_wo := 2.3;
    EXPORT Unsigned4 function_in_mod_ex(DATASET(rec_1_ex) vars) := FUNCTION
    	RETURN 4;
    END;
  END;

  SHARED rec_2_ex tranform_ex(rec_1_ex rec) := TRANSFORM, SKIP(rec.f > 2)
    SELF.h := rec.f;
    SELF := rec;
  END;

  EXPORT REAL8 cpp_ex(REAL8 varcpp) := BEGINC++

  ENDC++;

  EXPORT function_macro_ex(num) := FUNCTIONMACRO
    LOCAL numPlus := num + 1;
    RETURN numPlus;
  ENDMACRO;

  EXPORT macro_ex(num_1, num_2) := MACRO
    EXPORT attrname := num_1 + num_2;
  ENDMACRO;

  EXPORT macro_without_args_ex := MACRO
  	EXPORT attr := 2.0;
  ENDMACRO;

END;