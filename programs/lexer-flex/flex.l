%{
#define OPEN 1000
#define CLOSE 1001
#define INTEGER 1002
#define REAL 1003
#define BOOLEAN 1004
#define STRING 1005
#define SYMBOL 1006
#define OPENTEXT 1007
#define CLOSETEXT 1008
#define TRUE 1
#define FALSE 0
char buffer[50];
char *s = buffer;
int yylval;
%}
sign            [+-]
letter          [A-Za-z]
digit           [0-9]
digits          [0-9]+
symchar         [^A-Za-z0-9 \t\n()\"]
emptyspace      [ \t\n]+
string          [^\"]*
%%
\(                                                 return(OPEN);
\)                                                 return(CLOSE);
{emptyspace}                                      ;
{sign}?{digits}                                   {yylval = IntAtom(atoi(yytext)); return(INTEGER);}
{sign}?{digits}\.{digits}?(E{sign}?{digits})?     {yylval = RealAtom(atof(yytext)); return(REAL);}
TRUE                                              {yylval = BoolAtom(TRUE); return(BOOLEAN);}
FALSE                                             {yylval = BoolAtom(FALSE); return(BOOLEAN);}
\"{string}\"                                      { if (yyleng-2 > 48) {/* handle error */}
                                                    else { s = strncpy(s, &yytext[1], yyleng-2);
                                                    yylval = StringAtom(s); return(STRING);}}
({letter}({letter}|{digit})*)|symchar+            { if (yyleng > 48) {/* handle error */}
                                                    else { s = strncpy(s, yytext, yyleng);
                                                    yylval = SymbolAtom(s); return(SYMBOL);}}


"<text>"                                          return(OPENTEXT);
"</text--->"                                      return(CLOSETEXT);
.                                                 return(yytext[0]);
%%
