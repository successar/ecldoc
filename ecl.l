%{
#include <string>
#include <algorithm>
#include <regex>
using namespace std;
#include "ecl.tab.h"


int nesting = 0;
int i = 0;
int has_begin = 0;
string* buf = new string("");
string curr = "";

void clean_string(string* s, bool up=false) {
	*s = regex_replace(*s, std::regex("^ +| +$|( ) +"), "$1");
	if (up) {
		transform(buf->begin(), buf->end(),buf->begin(), ::toupper);
	}
}
%}

%x ARGS_L
%x C0
%x  C1
%x START_L
%x STRING_L
%x C2
SPECIAL  ":="
SC 		";"

%%

"/**" {buf->clear(); BEGIN(C0); *buf += "<DESC>"; curr = "</DESC>"; }
"/*"  {BEGIN(C1);}
"'"	  {BEGIN(STRING_L);}

<C0>[ \t\r\n]+ { *buf += " "; }
<C0>@param { *buf += curr + "<PARAM>"; curr = "</PARAM>"; }
<C0>@return { *buf += curr + "<RETURN>"; curr = "</RETURN>"; }
<C0>"*" ;
<C0>.   { *buf += yytext; }
<C0>"*/" {BEGIN(INITIAL); buf->clear(); }
<C0>"*/"/[ \t\r\n]*EXPORT {BEGIN(INITIAL); *buf += curr; clean_string(buf); yylval.sval = new string(*buf); buf->clear(); return DOCSTRING; }

<C1>.   {yymore();}
<C1>"*/" {BEGIN(INITIAL);}
<C1>\n  {yymore();}

"//".*\n   ;


<STRING_L>[^'] ;
<STRING_L>"'" {BEGIN(INITIAL);}

{SPECIAL} ; 
EXPORT { BEGIN(ARGS_L); buf->clear(); return EXPORT; }
<ARGS_L>. { *buf += yytext; }
<ARGS_L>{SPECIAL} { clean_string(buf); yylval.sval = new string(*buf); BEGIN(START_L); buf->clear(); return ARGS; }

<START_L>(?i:(MODULE|RECORD|TRANSFORM|FUNCTION|INTERFACE|TYPE|MACRO|BEGINC\+\+)) { buf->clear(); *buf += yytext; clean_string(buf, true); yylval.sval = new string(*buf); BEGIN(INITIAL); return START; }
<START_L>[^;\n] { *buf += yytext; }
<START_L>(;|\n) { BEGIN(INITIAL); clean_string(buf); yylval.sval = new string(*buf); return ATTRIBUTE; }

{SPECIAL}[ \t\n\r]*(MODULE|RECORD|TRANSFORM|FUNCTION|INTERFACE|TYPE|MACRO|BEGINC\+\+) { return SHARED; }

[ \t\r\n]+(END|ENDMACRO|ENDC\+\+)[ \t\r\n]*{SC} { return END; }

[ \t\n\r]+          /* eat up whitespace */
.          ;

%%

