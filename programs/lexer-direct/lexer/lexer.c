#include "lexer.h"

#include <stdio.h>
#include <stdlib.h> /* atof */
#include <string.h> /* memcpy */

#define TRUE 1
#define BUFFERSIZE 1024  // should be bigger than largest token expected
char buffer[BUFFERSIZE];
size_t buffer_max;  // shows how much chars are available in the buffer
int state;          // current state
int start_state;    // start state of the current diagram
int pos = 0;        // position of next char in buffer
int start_pos = 0;  // position of first char of current token in buffer
int lex_value;      // token attribute value
FILE* f;

// dummy implementation, so the code from the script works
int IntAtom(int i) { return 0; }
// dummy implementation, so the code from the script works
int FloatAtom(double d) { return 0; }

int next_diagram() {
  // returns start state number of the next token to check
  pos = start_pos;  // back to the start of the token string
  switch (start_state) {
    case 0:
      // OPEN failed, try CLOSE
      start_state = 2;
      break;
    case 2:
      // CLOSE failed, try delimiter
      start_state = 4;
      break;
    case 4:
      // delimiter failed, try BOOLEAN
      start_state = 20;
      break;
    case 20:
      // BOOLEAN failed, try OPENTEXT
      start_state = 35;
      break;
    case 35:
      // OPENTEXT failed, try CLOSETEXT
      start_state = 42;
      break;
    case 42:
      // CLOSETEXT failed, try SYMBOL
      start_state = 31;
      break;
    case 31:
      // SYMBOL failed, try STRING
      start_state = 28;
      break;
    case 28:
      // STRING failed, try REAL
      start_state = 11;
      break;
    case 11:
      // REAL failed, try INTEGER
      start_state = 7;
      break;
    case 7:
      // INTEGER failed, just return char as token
      start_state = 53;
  }
  return (start_state);
}

char nextchar() {
  if (pos >= buffer_max) {
    // we may need to step back to the start, so keep everything after start_pos
    // and move it to the front of the buffer
    memcpy(buffer, &buffer[start_pos], BUFFERSIZE - start_pos);
    pos = pos - start_pos;
    start_pos = 0;
    size_t bytes_read = fread(&buffer[pos], sizeof(char), BUFFERSIZE - pos, f);
    buffer_max = pos + bytes_read;
  }
  return buffer[pos++];
}

int isdelim(char const c) { return c == ' ' || c == '\t' || c == '\n'; }

int isdigit(char const c) { return '0' <= c && c <= '9'; }

int issign(char const c) { return c == '-' || c == '+'; }

int isletter(char const c) {
  return ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z');
}

int issym(char const c) {
  return !(isletter(c) || isdigit(c) || isdelim(c) || c == '(' || c == ')' ||
           c == '\"');
}

void stepback() { --pos; }

int gettoken() {
  // int c; // like in the script
  char c;  // works as well
  state = 0;
  start_state = 0;
  start_pos = pos;
  while (TRUE) {
    switch (state) {
      case 0:
        // start state for OPEN token
        c = nextchar();
        if (c == '(')
          state = 1;
        else
          state = next_diagram();  // not an OPEN token
        break;
      case 1:
        // accept state for OPEN token
        return OPEN;
      case 2:
        // start state for CLOSE token
        c = nextchar();
        if (c == ')')
          state = 3;
        else
          state = next_diagram();  // not a CLOSE token
        break;
      case 3:
        // accept state for CLOSE token
        return CLOSE;
      case 4:
        // start state for delimiter
        c = nextchar();
        if (isdelim(c))
          state = 5;
        else
          state = next_diagram();  // not a delimiter
        break;
      case 5:
        // middle state for delimiter (eats all the delimiters)
        c = nextchar();
        if (isdelim(c))
          state = 5;
        else
          state = 6;
        break;
      case 6:
        // accept state for delimiter
        stepback();
        start_state = 0;  // back to the top
        state = 0;        // back to the top
        start_pos = pos;
        break;  // whitespace is not tokenized
      case 7:
        // start state for INTEGER token
        c = nextchar();
        if (isdigit(c))
          state = 8;
        else if (issign(c))
          state = 9;
        else
          state = next_diagram();  // not an INTEGER token
        break;
      case 8:
        // middle state for INTEGER (eats all the digits)
        c = nextchar();
        if (isdigit(c))
          state = 8;
        else
          state = 10;
        break;
      case 9:
        c = nextchar();
        if (isdigit(c))
          state = 8;
        else
          state = next_diagram();  // not an INTEGER token
        break;
      case 10:
        // accept state for INTEGER token, must also return the integer itself
        stepback();
        lex_value = IntAtom(atoi(&buffer[start_pos]));
        return INTEGER;
      case 11:
        // start state for REAL token
        c = nextchar();
        if (isdigit(c))
          state = 12;
        else if (issign(c))
          state = 13;
        else
          state = next_diagram();  // not a REAL token
        break;
      case 12:
        // middle state for REAL (eats all the digits before decimal point)
        c = nextchar();
        if (isdigit(c))
          state = 12;
        else if (c == '.')
          state = 14;
        else
          state = next_diagram();
        break;
      case 13:
        // middle state for REAL (after sign)
        c = nextchar();
        if (isdigit(c))
          state = 12;
        else
          state = next_diagram();  // not an INTEGER token
        break;
      case 14:
        // middle state for REAL (after decimal point)
        c = nextchar();
        if (isdigit(c))
          state = 15;
        else if (c == 'E')
          state = 17;
        else
          state = 16;
        break;
      case 15:
        // middle state for REAL (eats all the digits after decimal point)
        c = nextchar();
        if (isdigit(c))
          state = 15;
        else if (c == 'E')
          state = 17;
        else
          state = 16;
        break;
      case 16:
        // accept state for REAL token
        stepback();
        lex_value = FloatAtom(atof(&buffer[start_pos]));
        return REAL;
      case 17:
        // middle state for REAL (after scientific notation E)
        c = nextchar();
        if (isdigit(c))
          state = 18;
        else if (issign(c))
          state = 19;
        else
          state = next_diagram();
        break;
      case 18:
        // middle state for REAL (eats all the digits scientific notation E)
        c = nextchar();
        if (isdigit(c))
          state = 18;
        else
          state = 16;
        break;
      case 19:
        // middle state for REAL (after sign for scientific notation)
        c = nextchar();
        if (isdigit(c))
          state = 18;
        else
          state = next_diagram();
        break;
      case 20:
        // start state for BOOLEAN token
        c = nextchar();
        if (c == 'T')
          state = 21;
        else if (c == 'F')
          state = 25;
        else
          state = next_diagram();  // not a BOOLEAN token
        break;
      case 21:
        // middle state for BOOLEAN token, TRUE branch, after T
        c = nextchar();
        if (c == 'R')
          state = 22;
        else
          state = next_diagram();  // not a BOOLEAN token
      case 22:
        // middle state for BOOLEAN token, TRUE branch, after R
        c = nextchar();
        if (c == 'U')
          state = 23;
        else
          state = next_diagram();  // not a BOOLEAN token
      case 23:
        // middle state for BOOLEAN token, TRUE branch, after U
        // middle state for BOOLEAN token, FALSE branch, after S
        c = nextchar();
        if (c == 'E')
          state = 24;
        else
          state = next_diagram();  // not a BOOLEAN token
      case 24:
        // accept state for BOOLEAN token
        return BOOLEAN;
      case 25:
        // middle state for BOOLEAN token, FALSE branch, after F
        c = nextchar();
        if (c == 'A')
          state = 26;
        else
          state = next_diagram();  // not a BOOLEAN token
      case 26:
        // middle state for BOOLEAN token, FALSE branch, after A
        c = nextchar();
        if (c == 'L')
          state = 27;
        else
          state = next_diagram();  // not a BOOLEAN token
      case 27:
        // middle state for BOOLEAN token, FALSE branch, after L
        c = nextchar();
        if (c == 'S')
          state = 23;
        else
          state = next_diagram();  // not a BOOLEAN token
        break;
      case 28:
        // start state for STRING token
        c = nextchar();
        if (c == '"')
          state = 29;
        else
          state = next_diagram();
        break;
      case 29:
        // middle state for STRING token, eats all characters except "
        c = nextchar();
        if (c == '"')
          state = 30;
        else
          state = 29;
        break;
      case 30:
        // accept state for STRING token
        return STRING;
      case 31:
        // start state for SYMBOL token
        c = nextchar();
        if (isletter(c))
          state = 32;
        else if (issym(c))
          state = 33;
        else
          state = next_diagram();
        break;
      case 32:
        // middle state for SYMBOL token with leading letter
        c = nextchar();
        if (isletter(c) || isdigit(c))
          state = 32;
        else
          state = 34;
        break;
      case 33:
        // middle state for SYMBOL token with leading symbol
        c = nextchar();
        if (issym(c))
          state = 33;
        else
          state = 34;
        break;
      case 34:
        // accept state for SYMBOL token
        stepback();
        return SYMBOL;
      case 35:
        // start state for OPENTEXT token
        c = nextchar();
        if (c == '<')
          state = 36;
        else
          state = next_diagram();
        break;
      case 36:
        // middle state for OPENTEXT token, after <
        c = nextchar();
        if (c == 't')
          state = 37;
        else
          state = next_diagram();
        break;
      case 37:
        // middle state for OPENTEXT token, after t
        c = nextchar();
        if (c == 'e')
          state = 38;
        else
          state = next_diagram();
        break;
      case 38:
        // middle state for OPENTEXT token, after e
        c = nextchar();
        if (c == 'x')
          state = 39;
        else
          state = next_diagram();
        break;
      case 39:
        // middle state for OPENTEXT token, after x
        c = nextchar();
        if (c == 't')
          state = 40;
        else
          state = next_diagram();
        break;
      case 40:
        // middle state for OPENTEXT token, after t
        c = nextchar();
        if (c == '>')
          state = 41;
        else
          state = next_diagram();
        break;
      case 41:
        // accept state for OPENTEXT token
        return OPENTEXT;
      case 42:
        // start state for CLOSETEXT token
        c = nextchar();
        if (c == '<')
          state = 43;
        else
          state = next_diagram();
        break;
      case 43:
        // middle state for CLOSETEXT token, after <
        c = nextchar();
        if (c == '/')
          state = 44;
        else
          state = next_diagram();
        break;
      case 44:
        // middle state for CLOSETEXT token, after </
        c = nextchar();
        if (c == 't')
          state = 45;
        else
          state = next_diagram();
        break;
      case 45:
        // middle state for CLOSETEXT token, after </t
        c = nextchar();
        if (c == 'e')
          state = 46;
        else
          state = next_diagram();
        break;
      case 46:
        // middle state for CLOSETEXT token, after </te
        c = nextchar();
        if (c == 'x')
          state = 47;
        else
          state = next_diagram();
        break;
      case 47:
        // middle state for CLOSETEXT token, after </tex
        c = nextchar();
        if (c == 't')
          state = 48;
        else
          state = next_diagram();
        break;
      case 48:
        // middle state for CLOSETEXT token, after </text
        c = nextchar();
        if (c == '-')
          state = 49;
        else
          state = next_diagram();
        break;
      case 49:
        // middle state for CLOSETEXT token, after </text-
        c = nextchar();
        if (c == '-')
          state = 50;
        else
          state = next_diagram();
        break;
      case 50:
        // middle state for CLOSETEXT token, after </text--
        c = nextchar();
        if (c == '-')
          state = 51;
        else
          state = next_diagram();
        break;
      case 51:
        // middle state for CLOSETEXT token, after </text---
        c = nextchar();
        if (c == '>')
          state = 52;
        else
          state = next_diagram();
        break;
      case 52:
        // accept state for CLOSETEXT token
        return CLOSETEXT;
      case 53:
        c = nextchar();
        return c;
    }
  }
}

int main(int argc, char** argv) {
  // skips over program name
  ++argv;
  --argc;
  if (argc > 0) {
    printf("Scanning %s\n", argv[0]);
    f = fopen(argv[0], "r");
  } else {
    f = stdin;
  }
  // fill buffer for the first time
  buffer_max = fread(buffer, sizeof(char), BUFFERSIZE, f);
  do {
    printf("%i\n", gettoken());
  } while (!(feof(f) && pos >= buffer_max));
  if (argc > 0) {
    fclose(f);
  }
}
