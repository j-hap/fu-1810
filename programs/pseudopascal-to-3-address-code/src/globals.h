#ifndef GLOBALS_H_
#define GLOBALS_H_

#include <cstddef>  // for size_t
#include <string>
#include <vector>
// global variables
size_t depth = 0;
size_t program_counter = 0;

struct Label {
  size_t index;
  size_t program_counter;
  std::string name;
};

class LabelTable {
 private:
  std::vector<Label> labels;

 public:
  size_t next_index() {
    labels.emplace_back();
    return labels.size() - 1;
  };
  Label& operator()(int index) { return labels[index]; }
} label_table;  // declares AND creates one instance

// possible entries in first column of the types table
enum class Type { Integer, Real, Boolean, Char, Array, Record, Pointer };

// possible entries in the first column of the variables table
enum class VariableType {
  Constant,
  Variable,
  RecordField,
  ReferenceParameter,
  ValueParameter
};

struct TypeEntry {
  Type type;
  std::string name;
  size_t n_components;
  int component_size;
  size_t type_index_of_component;
  size_t field_table_index;
};

// class TypeTable {
//  private:
//   ;

//  public:
// }

std::vector<TypeEntry> type_table;

using NameTable = std::vector<std::pair<std::string, int>>;
std::vector<NameTable> name_table_stack;

#endif  // GLOBALS_H_