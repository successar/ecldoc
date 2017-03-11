%%
   
%class Lexer

%line
%column
%ignorecase
    
%standalone
   
%{   

int nesting = 0;

%}
   
%xstates ARGS_L, C0, START_L, STRING_L, ATTR_L

LineTerminator = \r|\n|\r\n
InputCharacter = [^\r\n]
EndOfLineComment     = "//" {InputCharacter}* {LineTerminator}?
STARTsym = ("MODULE"|"RECORD"|"TRANSFORM"|"FUNCTION"|"INTERFACE"|"TYPE"|"MACRO"|"BEGINC++"|"FUNCTIONMACRO")
id = [A-Za-z_#][A-Za-z_0]+

%%

"/**" { yybegin(C0); System.out.println("<DESC>"); }

<C0>[ \t\r\n]+ { System.out.println(" "); }

<C0>@param { System.out.println("PARAM"); }
<C0>@return { System.out.println("RETURN"); }

<C0>"*" {}

<C0>.   { System.out.print(yytext()); }

<C0>"*/" { yybegin(YYINITIAL);  }

<C0>"*/"/[ \t\r\n]*"EXPORT" { yybegin(YYINITIAL); System.out.println("</DESC>"); }


"/*" [^*] ~"*/" | "/*" "*"+ "/" {}
{EndOfLineComment} {}

"'"   {yybegin(STRING_L);}
<STRING_L>[^'] {}
<STRING_L>"'" {yybegin(YYINITIAL);}

EXPORT  { System.out.println("EXPORT"); yybegin(ARGS_L); }
<ARGS_L>[^:;]+ { System.out.println(yytext()); yybegin(YYINITIAL); }

":=" { System.out.println("ASSIGN"); yybegin(START_L); }

END|ENDMACRO|ENDC\+\+     { nesting--; System.out.println("ENDTOC " + nesting); }
{id}    {}

<START_L>{STARTsym}/[ \t\r\n\(,] { System.out.println(nesting + " START" + yytext()); nesting++; yybegin(YYINITIAL); }
<START_L>[ \t\r\n] {}
<START_L>[^ \t\r\n] { yypushback(1); yybegin(YYINITIAL); System.out.println("ATTRIBUTE"); }

<ATTR_L>[^;] { System.out.print(yytext()); }
<ATTR_L>";" { System.out.println(); yybegin(YYINITIAL); }

[ \t\r\n] {}
. {}
