#include <stddef.h>  // for ptrdiff_t

#include <string>
// declares data structures that contain attributes
// for terminals and non-terminals

enum class DeclType { Variable, RecordField };

struct Declaration {
  ptrdiff_t offset;
  DeclType type;
  size_t parent_record_index;  // if type is RECORDFIELD, this points to the
                               // containing record in the type table
};

struct TypeExpression {
  size_t size;
  int alignment;
  size_t index;  // index into type table
};

struct Parameter {
  ptrdiff_t offset;
  size_t number;
  std::string procedure_name;
};

struct Expression {
  size_t variable_index;
  ptrdiff_t offset; /* offset from the start byte of the variable to access the
                correct field or index */
  bool indirect;    /* determines if variable is a pointer */
  size_t type_index;
};
