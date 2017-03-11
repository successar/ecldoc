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

    String clean_string(StringBuffer obj, Boolean up, Boolean angle) {
      String tmp = obj.toString().trim().replaceAll("\\s+", " ");
      if(up) { tmp = tmp.toUpperCase(); }
      if(angle) { tmp = tmp.replaceAll("<", "&lt;").replaceAll(">", "&gt;"); }
      obj.setLength(0);
      return tmp;
    }

    Boolean debug = false;
    int nesting = 0;
%}
   
%xstates ARGS_L, C0, START_L, STRING_L, ATTR_L

LineTerminator = \r|\n|\r\n
InputCharacter = [^\r\n]
EndOfLineComment     = "//" {InputCharacter}* {LineTerminator}?
STARTsym = ("MODULE"|"RECORD"|"TRANSFORM"|"FUNCTION"|"INTERFACE"|"TYPE"|"MACRO"|"BEGINC++"|"FUNCTIONMACRO")
id = [A-Za-z_#][A-Za-z_0]+

%%

"/**" {buf.setLength(0); yybegin(C0); buf.append("<DESC>"); curr = "</DESC>"; }
"'"   {yybegin(STRING_L);}

<C0>[ \t\r\n]+ { buf.append(" "); }

<C0>@param { buf.append(curr + "<PARAM>"); curr = "</PARAM>"; }
<C0>@return { buf.append(curr + "<RETURN>"); curr = "</RETURN>"; }

<C0>"*" {}

<C0>.   { buf.append(yytext()); }

<C0>"*/" {yybegin(YYINITIAL); buf.setLength(0); }

<C0>"*/"/[ \t\r\n]*"EXPORT" {yybegin(YYINITIAL); buf.append(curr);  if (debug) System.out.println(buf); return symbol(sym.DOCSTRING ,clean_string(buf, false, false)); }


"/*" [^*] ~"*/" | "/*" "*"+ "/" {}
{EndOfLineComment} {}




<STRING_L>[^'] {}
<STRING_L>"'" {yybegin(YYINITIAL);}


EXPORT  { yybegin(ARGS_L); buf.setLength(0);  if (debug) System.out.println("EXPORT"); return symbol(sym.EXPORT); }

<ARGS_L>[^;]   { buf.append(yytext()); }
<ARGS_L>":="   { yybegin(YYINITIAL); yypushback(2); if (debug) System.out.println(buf); return symbol(sym.ARGS, clean_string(buf, false, false)); }
<ARGS_L>";"    { yybegin(YYINITIAL); if (debug) System.out.println(buf); return symbol(sym.ARGSD, clean_string(buf, false, false)); }

":=" { yybegin(START_L); return symbol(sym.ASSIGN); }

END|ENDMACRO|ENDC\+\+     {  if (debug) { System.out.println(nesting + " END"); nesting--; } return symbol(sym.END); }
{id}    {}

<START_L>{STARTsym}/[ \t\r\n\(,\/] { yybegin(YYINITIAL); buf.setLength(0); buf.append(yytext());  if (debug) { nesting++; System.out.println(nesting + " STR" + buf); } return symbol(sym.START ,clean_string(buf, true, false)); }

<START_L>[ \t\r\n] {}
<START_L>[^ \t\r\n] { yypushback(1); yybegin(YYINITIAL);  if (debug) System.out.println("ATTR"); return symbol(sym.ATTRIBUTE, "ATTRIBUTE"); }

<ATTR_L>[^;] { buf.append(yytext()); }
<ATTR_L>";" { yybegin(YYINITIAL);  if (debug) System.out.println("ATTR" + buf); return symbol(sym.ATTRIBUTE ,clean_string(buf, false, true)); }

[ \t\r\n] {}
. {}