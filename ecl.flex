import java_cup.runtime.*;
      
%%
   
%class Lexer

%line
%column
%ignorecase
    
%cup
   
%{   
    private Symbol symbol(int type) {
        // if (debug) System.out.println(type);
        return new Symbol(type, yyline, yycolumn);
    }
    
    private Symbol symbol(int type, Object value) {
        // if (debug) System.out.println(type + " " + (String) value);
        return new Symbol(type, yyline, yycolumn, value);
    }

    StringBuffer buf = new StringBuffer("");
    String curr = "</DESC>";

    String clean_string(StringBuffer obj, Boolean up) {
      String tmp = obj.toString().trim().replaceAll("\\s+", " ");
      if(up) { tmp = tmp.toUpperCase(); }
      obj.setLength(0);
      return tmp;
    }

    Boolean debug = false;
%}
   
%xstates ARGS_L, C0, C1, START_L, STRING_L, C2

SPECIAL = ":="
SC   = ";"
LineTerminator = \r|\n|\r\n
InputCharacter = [^\r\n]
EndOfLineComment     = "//" {InputCharacter}* {LineTerminator}?
STARTsym = ("MODULE"|"RECORD"|"TRANSFORM"|"FUNCTION"|"INTERFACE"|"TYPE"|"MACRO"|"BEGINC++"|"FUNCTIONMACRO")

%%

"/**" {buf.setLength(0); yybegin(C0); buf.append("<DESC>"); curr = "</DESC>"; }
"'"   {yybegin(STRING_L);}

<C0>[ \t\r\n]+ { buf.append(" "); }

<C0>@param { buf.append(curr + "<PARAM>"); curr = "</PARAM>"; }

<C0>@return { buf.append(curr + "<RETURN>"); curr = "</RETURN>"; }

<C0>"*" {}

<C0>.   { buf.append(yytext()); }

<C0>"*/" {yybegin(YYINITIAL); buf.setLength(0); }

<C0>"*/"/[ \t\r\n]*"EXPORT" {yybegin(YYINITIAL); buf.append(curr);  if (debug) System.out.println(buf); return symbol(sym.DOCSTRING ,clean_string(buf, false)); }


"/*" [^*] ~"*/" | "/*" "*"+ "/" {}
{EndOfLineComment} {}




<STRING_L>[^'] {}

<STRING_L>"'" {yybegin(YYINITIAL);}

{SPECIAL} {}

"EXPORT"/[ \t\r\n] { yybegin(ARGS_L); buf.setLength(0);  if (debug) System.out.println("EXPORT"); return symbol(sym.EXPORT); }

<ARGS_L>. { buf.append(yytext()); }

<ARGS_L>{SPECIAL} { yybegin(START_L);  if (debug) System.out.println(buf); return symbol(sym.ARGS, clean_string(buf, false)); }

<START_L>[ \t\n\r]*{STARTsym}/[ \t\r\n\(,] { yybegin(YYINITIAL); buf.setLength(0); buf.append(yytext());  if (debug) System.out.println("STR" + buf); return symbol(sym.START ,clean_string(buf, true)); }

<START_L>[^;\n] { buf.append(yytext()); }

<START_L>(;|\n) { yybegin(YYINITIAL);  if (debug) System.out.println("ATT" + buf); return symbol(sym.ATTRIBUTE ,clean_string(buf, false)); }

{SPECIAL}[ \t\n\r]*{STARTsym}/[ \t\r\n\(,] {  if (debug) System.out.println("SHA" + yytext()); return symbol(sym.SHARED); }

[ \t\r\n]*("END"|"ENDMACRO"|"ENDC++")[ \t\r\n]*{SC} {  if (debug) System.out.println("END"); return symbol(sym.END); }

[ \t\n\r]+         {} 

.          {}
