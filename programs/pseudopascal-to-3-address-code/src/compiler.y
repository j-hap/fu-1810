%{
    #include "attributes.h"
    #include "helpers.h"
    #include "globals.h"

    // inserts the basic data types into the type_table
    type_table.emplace_back();
    type_table.emplace_back();
    type_table.emplace_back();
    type_table.emplace_back();
%}

%token DO
%token OR
%token AND
%token NOT
%token COMPAREOP
%token ADDOP
%token MULOP
%token ARRAY
%token BEGIN
%token BOOLEAN
%token CHAR
%token ELSE
%token END
%token FUNCTION
%token ID
%token IF
%token INTCONST
%token INTEGER
%token OF
%token POINTER
%token PROCEDURE
%token REAL
%token RECORD
%token RETURN
%token THEN
%token TO
%token TYPE
%token VAR
%token WHILE
%token DEREF
%token ASSIGN

%union {
    Declaration* declaration;
    size_t offset;
    Parameter* parameter;
    TypeExpression* type;
    Expression* expression;
}

%type <declaration> declaration_list
%type <declaration> declaration
%type <offset> variables
%type <parameter> param
%type <type> simpletype
%type <type> typeident
%type <expression> expr
%type <expression> var
%type <expression> simple
%type <expression> term

%%

program
  : {
      depth = 0;
      $variables.offset = 0;
      auto start_label = newlabel();
      putcode('goto' start_label); // TODO
    }
    types variables[variables] procedure_list
    {
      /* now that all declared procedures are placed in the code block, the start label for the main
       program is placed afterwards */
      putcode(start_label ':' noop);
      temp_offset = $variables.offset;
    }
    stmt '.'
    {
      mainsize = newtemp(integer);
      align(temp_offset, 8);
      /* const forces an integer literal, otherwise it would be interpreted as index into the
      variable table */
      putcode(mainsize ":=" const(temp_offset));
      putcode('init_stack' mainsize);
    }
  ;

types
  : TYPE ID '=' typeexpr
    {
      if ($typeexpr.typeindex > 4) {
        /* not an atomic type, but it already exists in the table, because the type expression rule
        created it */
        type_table[$typeexpr.typeindex].name = $ID.name;
      } else {
        auto used_type = type_table[$typeexpr.typeindex].type;
        enter_type(used_type, $ID.name, -, -, -, -);
      }
    }
    ';' types
  | /* nothing */
  ;

variables[variables]
  : VAR
    {
      $decls.offset = $variables.offset;
      $decls.type = var;
      $decls.recordindex = 0;
    }
    declaration_list[decls] ';'
    {
      $variables.offset = $decls.offset;
      align($variables.offset, 8);
    }
  |
  ;

declaration_list
  : {
      $declaration.offset = $declaration_list.offset;
    }
    declaration
    {
      $declaration_list.offset = $declaration.offset;
    }
  | {
      $rest.offset = $declaration_list.offset;
    }
    declaration_list[rest] ';'
    {
      $declaration_list.offset = $rest.offset;
    }
    declaration
    {
      $declaration_list.offset = $declaration.offset;
    }
  ;

declaration
  : ID ':' typeexpr
    {
        align($declaration.offset, $typeexpr.alignment);
        index = enter_var($declaration.type, $ID.name, depth, $declaration.offset, $typeexpr.size, -, $typeexpr.alignment, $typeexpr.typeindex);
        $declaration.offset = $declaration.offset + $typeexpr.size;
        if ($declaration.type == DeclType::Variable) {
          enter_name(depth, $ID.name, index);
        } else {
          enter_fieldname($declaration.recordindex,  $ID.name, index);
        }
    }
  ;

typeexpr
  : simpletype
    {
      $typeexpr.size = $simpletype.size;
      $typeexpr.alignment = $simpletype.alignment;
      $typeexpr.index = $simpletype.index;
    }
  | ARRAY '[' INTCONST ']' OF typeexpr[arraytype]
    {
      index = enter_type(array, -, $INTCONST.value, $arraytype.size, t$arraytype.typeindex, -);
      $typeexpr.size = $INTCONST.value * $arraytype.size;
      align($typeexpr.size, 8);
      $typeexpr.alignment = 8;
      $typeexprtypeindex = index;
    }
  | RECORD
    {
      // all declarations following the record field will have the type recordfield
      $declaration_list.type = recordfield;
      $declaration_list.offset = 0;
      auto index = enter_type(Type::Record,-,-,-,-,-);
      $declaration_list.recordindex = index;
    }
    declaration_list END
    {
      $typeexpr.size = $declaration_list.offset;
      align($typeexpr.size, 8);
      $typeexpr.alignment = 8;
      $typeexpr.typeindex = $declaration_list.recordindex;
    }
  | POINTER TO typeexpr[unterlying]
    {
      $typeexpr.typeindex= enter_type(Type::Pointer, -, -, -, $unterlying.typeindex, -);
      $typeexpr.size = 4;
      $typeexpr.alignment = 4;
    }
  | typeident
    {
     typeexpr.* = typeident.*; // TODO
    }
  ;

simpletype
  : INTEGER
    {
      $simpletype.size = 4;
      $simpletype.alignment = 4;
      $simpletype.typeindex = 1
    }
  | REAL
    {
      $simpletype.size = 4;
      $simpletype.alignment = 4;
      $simpletype.typeindex = 2
    }
  | BOOLEAN
    {
      $simpletype.size = 1;
      $simpletype.alignment = 1;
      $simpletype.typeindex = 3
    }
  | CHAR
    {
      $simpletype.size = 1;
      $simpletype.alignment = 1;
      $simpletype.typeindex = 4
    }
  ;

typeident
  : // TODO muss irgendwas aus der typtabelle ziehen
  ;

procedure_list
  : procedure procedure_list
  | function procedure_list
  | /* nothing */
  ;

procedure
  : PROCEDURE ID
    {
      depth = depth + 1;
      pushnametable();
      $parameters.procname = $ID.name
    }
    parameters
    {
      /* parameters of the procedure take up space in the stack frame that is recorded in the offset
      attribute. the variables in the procedure are placed behind the parameters in the stack frame,
      therefore the variables need an initial offset
      */
      $variables.offset = $parameters.offset;
    }
    ';' variables procedure_list
    {
      // after translating the variables
      temp_offset = $variables.offset;
      $procedure.start = program_counter;
    }
    stmt ';'
    {
      depth -= 1;
      popnametable();
      auto static_size = temp_offset;
      align(static_size, 8);
      // creates entry in procedure table
      auto index = enter_proc($ID.name, depth, static_size, $procedure.start, -);
      // enters the procedure name in the name table stack
      enter_name(depth, $ID.name, index);
    }
  ;

parameters
  : '(' param_list ')'
  | /* nothing */
  ;

param_list
  : param
  | param_list ';' param
  ;

param
  : VAR ID ':' paramtype
    {
      align($param.offset, 4);
      index = enter_var(VariableType::ReferenceParameter, $ID.name, depth, $param.offset, 4, -, 4, $paramtype.typeindex);
      /* parameter identified by position and procedure name on the same name level as the procedure
      to identify parameters by position */
      enter_name(depth - 1, $param.procedure_name + "#" + $param.number, index);
      enter_name(depth, $ID.name, index);
      $param.offset += 4;
    }
  | ID ':' paramtype
    {
      align($param.offset, $paramtype.alignment);
      index = enter_var(VariableType::ValueParameter, $ID.name, depth, $param.offset, $paramtype.size, -, $paramtype.alignment, $paramtype.typeindex);
      /* parameter identified by position and procedure name on the same name level as the procedure
      to identify parameters by position */
      enter_name(depth - 1, $param.procedure_name + "#" + $param.number, index);
      enter_name(depth, $ID.name, index);
      $param.offset += $paramtype.size;
    }
  ;

paramtype
  : simpletype
  | typeident
  ;

function
  : FUNCTION ID parameters ':' paramtype ';' variables procedure_list stmt ';'
  ;

functioncall
  : ID '(' args ')'
  ;

args
  : arg argrest
  ;

argrest
  : ',' arg argrest
  |
  ;

arg
  : expr
  ;

proccall
  : ID '(' args ')'
  ;

return
  : RETURN
  | RETURN expr
  ;

stmt
  : assignment
  | cond
  | loop
  | proccall
  | return
  | block
  ;

block
  : BEGIN stmt_list END
  ;

stmt_list
  : stmt
  | stmt_list ';' stmt
  ;

cond
  : IF boolexpr THEN stmt ELSE stmt END
  | IF boolexpr THEN stmt END
  ;

loop
  : WHILE
    {
      start := newlabel();
      boolexpr.true := newlabel();
      boolexpr.false := newlabel();
      putcode(start ':' noop);
    }
    boolexpr DO
    {
      putcode(boolexpr.true ':' noop);
    }
    stmt END
    {
      putcode('goto' start);
      putcode(boolexpr.false ':' noop);
    }
  ;

expr
  : simple
    {
      expr.* := simple.*
    }
  | {
      boolexpr.true := newlabel();
      boolexpr.false := newlabel()
    }
    boolexpr
    {
      expr.var := newtemp(boolean);
      expr.type := boolean;
      after := newlabel();
      putcode(boolexpr.true ':'
      expr.var ':-' '1');
      putcode('goto' after);
      putcode(boolexpr.false ':'
      expr.var :- '0');
      putcode(after ':' noop);
    }

simple
  : term
    {
      simple.* := term.*;
    }
  | simple[operand] ADDOP term
    {
      $simple.type_index := typemap($operand.type, $ADDOP.op, $term.type);
      // return of zero is an invalid type
      if ($simple.type_index != 0) {
        $$.var := newtemp($$.type);
        putcode($$.var ':=' $1.var $2.op $3.var)
      } else {
        error;
      }
    }
  ;

term
  : factor
    {
      term.* := factor.*;
    }
  | term MULOP factor
    {
      $$.type := typemap($1.type, $2.op, $3.type);
      if ($$.type != 0) {
        $$.var := newtemp($$.type);
        putcode($$.var ':=' $1.var $2.op $3.var)
      } else {
        error;
      }
    }
  ;

factor
  : var[var]
    {
      if (width($var.type) == 1) {
        ass = ":-";
        } else {
          ass = ':='
        } if (var.indirect) {
          factor.var := newtemp(var.type);
          if (var.offset == 0) {
            putcode(factor.var ass '*' var.var);
          } else {
            putcode(factor.var ass '*' var.var '[' var.offset ']');
          }
        } else {
          if (var.offset = 0) {
            // no "offset" var
            factor.var := var.var;
          } else {
            factor.var := newtemp(var.type);
            putcode(factor.var ass var.var '[' var.offset ']');
          }
        }
        factor.type := var.type
    }
  | '(' expr ')'
    {
      factor.* := expr.*;
    }
  | '(' '-' factor ')'
    {
      if (type(factor1.type) == "integer") || type(factor1.type) == "real") {
        factor.* := factor1.*;
        putcode(factor.var ':=' '-' factor1.var);
      } else {
        error;
      }
    }
  | functioncall
  ;

boolexpr
  : {
      boolterm.* := boolexpr.*
    }
    boolterm
    {
        boolexpr1.true := boolexpr.true;
        boolexpr1.false := newlabel();
    }
  | boolexpr OR boolterm
    {
        putcode(boolexpr1.false ':' noop);
        boolterm.* := boolexpr.*;
    }
  ;

boolterm
  : boolfactor
  | boolterm AND boolfactor
  ;

boolfactor
  : {
      boolfactor1.true = boolfactor.false;
    }
    NOT boolfactor
  | simple
    {
    if (type(simple.type) == BOOLEAN) {
      putcode('if' simple.var '=' '0' 'goto' boolfactor.false);
      putcode('goto' boolfactor.true);
    } else {
      error;
    }
    }
  | simple COMPAREOP simple
    {
      if (typemap(simple1.type, cop.op, simple2.type) == BOOLEAN) {
        putcode('if' simple1.var cop.op simple2.var 'goto' boolfactor.true);
        putcode('goto' boolfactor.false);
      } else {
        error;
      }
    }
  ;

assignment
  : var ASSIGN expr
    {
      if compatible($var.type, $expr.type) {
        if (width($var.type) = 1) {
          ass = ":-";
        } else {
          ass = ":=";
        }
        if (!var.indirect) {
          if (var.offset = 0) {
            // no variable "offset" exists
            putcode(var.var ass expr.var);
          } else {
            putcode(var.var '[' var.offset ']' ass expr.var);
          }
        } else {
          if (var.offset = 0) {
            putcode('*' var.var ass expr.var);
          } else {
            putcode('*' var.var '[' var.offset ']' ass expr.var);
          }
        }
      } else {
        error;
      }
    }
  ;

var
  : ID
    {
      auto variable_index = lookup($ID.name);
      $var.var = variable_index;
      $var.offset = 0;
      $var.indirect = false;
      $var.type_index = typeindex(variable_index);
    }
  | var '[' intexpr ']' /* array access */
    {
      if (type(var1.type) == ARRAY) {
        // range checking
        y = intexpr.var;
        x = newtemp(integer);
        putcode(x ':=' const(n_comps(var1.type)));
        putcode('if' y '<' '0' 'goto' RangeErr);
        putcode('if' y '>=' x 'goto' RangeErr);
        if (var1.offset == 0) {
          var.offset := newtemp(integer);
          putcode(var.offset ':=' '0')
        } else {
          var.offset := var1.offset
        }
        z = newtemp(integer);
        putcode(z ':=' const(compsize(var1.type)) '*' y);
        putcode(var.offset ':=' var.offset '+' z);
        var.var := var1.var;
        var.indirect := var1.indirect;
        var.type := compindex(var1.type)
      } else {
        error;
      }
    }
  | var '.' ID /* record field access */
    {
      var.offset = var1.offset+ID.offset;
      var.type = ID.type;
      var.indirect = var1.indirect;
    }
  | var DEREF /* pointer access */
    {
      if (type(var1.type) == POINTER) {
        z = newtemp(pointer);
        if (!var1.indirect) {
          if (var1.offset == 0) {
            // no offset var
            putcode(z := var1.var);
          } else {
            putcode(z := var1.var '[' var1.offset ']')
          }
        } else {
            if (var1.offset == 0) {
              // no offset var
              putcode(z := '*' var1.var);
            } else {
              putcode(z := '*' var1.var '[' var1.offset ']')
            }
        }
        var.var := z;
        var.offset := 0;
        var.indirect := true;
        var.type := compindex(var1.type)
      } else {
        error;
      }
    }
  ;

intexpr
  : expr
    {
      if (type(expr.type) == INTEGER) {
          intexpr.* := expr.*
      } else {
          error;
      }
    }
  ;