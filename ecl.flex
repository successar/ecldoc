import java_cup.runtime.*;
      
%%
   
%class Lexer

%line
%column
%ignorecase
    
%cup
   
%{   
    private Symbol symbol(int type) {
        //System.out.println(type);
        return new Symbol(type, yyline, yycolumn);
    }
    
    private Symbol symbol(int type, Object value) {
        //System.out.println(type + " " + (String) value);
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

    int nesting = 0;
%}
   
%xstates ARGS_L, C0, C1, START_L, STRING_L, C2

SPECIAL = ":="
SC   = ";"
LineTerminator = \r|\n|\r\n
InputCharacter = [^\r\n]
EndOfLineComment     = "//" {InputCharacter}* {LineTerminator}?

%%

"/**" {buf.setLength(0); yybegin(C0); buf.append("<DESC>"); curr = "</DESC>"; }
"'"   {yybegin(STRING_L);}

<C0>[ \t\r\n]+ { buf.append(" "); }

<C0>@param { buf.append(curr + "<PARAM>"); curr = "</PARAM>"; }

<C0>@return { buf.append(curr + "<RETURN>"); curr = "</RETURN>"; }

<C0>"*" {}

<C0>.   { buf.append(yytext()); }

<C0>"*/" {yybegin(YYINITIAL); buf.setLength(0); }

<C0>"*/"/[ \t\r\n]*"EXPORT" {yybegin(YYINITIAL); buf.append(curr); return symbol(sym.DOCSTRING ,clean_string(buf, false)); }


"/*" [^*] ~"*/" | "/*" "*"+ "/" {}
{EndOfLineComment} {}




<STRING_L>[^'] {}

<STRING_L>"'" {yybegin(YYINITIAL);}

{SPECIAL} {}

"EXPORT" { yybegin(ARGS_L); buf.setLength(0); return symbol(sym.EXPORT); }

<ARGS_L>. { buf.append(yytext()); }

<ARGS_L>{SPECIAL} { yybegin(START_L); return symbol(sym.ARGS, clean_string(buf, false)); }

<START_L>"MODULE"|"RECORD"|"TRANSFORM"|"FUNCTION"|"INTERFACE"|"TYPE"|"MACRO"|"BEGINC++" { yybegin(YYINITIAL); buf.setLength(0); buf.append(yytext()); return symbol(sym.START ,clean_string(buf, true)); }

<START_L>[^;\n] { buf.append(yytext()); }

<START_L>(;|\n) { yybegin(YYINITIAL); return symbol(sym.ATTRIBUTE ,clean_string(buf, false)); }

{SPECIAL}[ \t\n\r]*("MODULE"|"RECORD"|"TRANSFORM"|"FUNCTION"|"INTERFACE"|"TYPE"|"MACRO"|"BEGINC++")[ \t\r\n]+ { return symbol(sym.SHARED); }

[ \t\r\n]+("END"|"ENDMACRO"|"ENDC++")[ \t\r\n]*{SC} { return symbol(sym.END); }

[ \t\n\r]+         {} 
.          {}
