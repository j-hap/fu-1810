%{
int n_lines = 0;
int n_words = 0;
int n_chars = 0;
%}
wordchar [^ \t\n]
%%

\n           {++n_lines; n_chars += 1;}
{wordchar}+  {++n_words; n_chars += yyleng;}
.             ++n_chars;

%%
int main(int argc, char **argv) {
  yylex(); // need only be called once, because no return
  printf("# of lines = %d, # of words = %d, # of chars = %d\n", n_lines, n_words, n_chars);
}