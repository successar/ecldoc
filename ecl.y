%{
#include <iostream>
#include <string>
using namespace std;

extern int yylex();
extern "C" FILE *yyin;
void yyerror(char*);
string* output;
%}

%union {
    string* sval;
};

%token EXPORT END SHARED
%token <sval> DOCSTRING ARGS START ATTRIBUTE
%type <sval> exportt func functions

%%

input : functions       { output = $1; }

functions :  { $$ = new string(""); }
        | func functions       { $$ = new string(*$1 + *$2); delete $1; delete $2; }


func : exportt ARGS START functions END             { $$ = new string(*$1 + " <ARGS> " + *$2 + " </ARGS> <START> " + *$3 + " </START> " + *$4 + "</EXPORT>" + "\n"); delete $1; delete $4; delete $2; delete $3;}
        | exportt ARGS ATTRIBUTE                    { $$ = new string(*$1 + " <ARGS> " + *$2 + " </ARGS> <ATTR> " + *$3 + "</ATTR> </EXPORT>\n"); delete $1; delete $2; delete $3;}
        | SHARED functions END                      { $$ = new string("<SHARED></SHARED>\n"); }

exportt : DOCSTRING EXPORT                          { $$ = new string(string("<EXPORT> <COMMENT> ") + *$1 + " </COMMENT>\n"); delete $1;}
        | EXPORT                                    { $$ = new string("<EXPORT>") ;}


%%
int main( int argc, char**argv )
{
    ++argv, --argc;  /* skip over program name */
    if ( argc > 0 )
            yyin = fopen( argv[0], "r" );
    else
            yyin = stdin;

    //extern int yydebug;
    //yydebug=1;

    yyparse();
    cout << *output << endl;
    return 0;
   }

void yyerror(char *s) {
    cout << "Error" << endl;
}