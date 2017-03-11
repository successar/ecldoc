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

"'"   {yybegin(STRING_L);}
<STRING_L>[^'] {}
<STRING_L>"'" {yybegin(YYINITIAL);}

"/*"([^*]|\*+[^*/])*\*+"/" {}
{EndOfLineComment} {}

EXPORT  { System.out.println("EXPORT"); yybegin(ARGS_L); }
<ARGS_L>[^:]+ { System.out.println(yytext()); yybegin(YYINITIAL); }

":=" { System.out.println("ASSIGN"); yybegin(START_L); }

END     { nesting--; System.out.println("END " + nesting); }
{id}    {}

<START_L>{STARTsym}/[ \t\r\n\(,] { System.out.println(nesting + " START" + yytext()); nesting++; yybegin(YYINITIAL); }
<START_L>[ \t\r\n] {}
<START_L>[^ \t\r\n] { System.out.print("ATTR " + yytext()); yybegin(ATTR_L); }

<ATTR_L>[^;] { System.out.print(yytext()); }
<ATTR_L>";" { System.out.println(); yybegin(YYINITIAL); }

[ \t\r\n] {}
. {}
