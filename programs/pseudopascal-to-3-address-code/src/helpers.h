#ifndef HELPERS_H_
#define HELPERS_H_

#include <stddef.h>  // for ptrdiff_t

#include <algorithm>

#include "globals.h"

void align(ptrdiff_t& offset, int border) {
  // rounds the input N to the next multiple of BORDER
  auto modulus = offset % border;
  if (modulus != 0) {
    offset = offset + border - modulus;
  }
}

size_t newlabel() { return label_table.next_index(); }
void putcode(char* args[]) {
  // if a label is created, the second argument is a color
  bool create_label = args[1][0] == ':';
  if (create_label) {
    auto index = atoi(args[0]);
    label_table(index).program_counter = program_counter;
  }
}

int enter_var(Type type, std::string const& name, size_t n_components,
              int component_size, size_t type_index_of_component,
              size_t field_table_index) {
  type_table.emplace_back(type, name, n_components, component_size,
                          type_index_of_component, field_table_index);
  return type_table.size() - 1;
}

void enter_proc() {}
void enter_type() {}

void pushnametable() {
  name_table_stack.emplace_back(std::vector<NameTable>());
}

void popnametable() { name_table_stack.pop_back(); }

int enter_name(int depth, char const* name, int index) {
  auto table = name_table_stack[depth];
  if (std::find(table.begin(), table.end(),
                [&](std::pair<std::string, int> pair) {
                  pair.first == name;
                }) != table.end()) {
    // TODO entry already exists
  }
  table.emplace_back(std::pair{name, index});
}

int lookup(char const* name) {
  for (auto table = name_table_stack.rbegin(); table < name_table_stack.rend();
       ++table) {
    for (auto const& row : *table) {
      if (row.first == name) {
        return row.second;
      }
    }
  }
  // TODO name does not exist
}

int enter_field_name(int recordindex, char const* name, int index) {}

int lookup_fieldname(int recordindex, char const* name) {}

bool compatible(size_t type_index, size_t other_type_index) {
  // TODO
  return false;
}

size_t typemap(size_t type_index, int operation, size_t other_type_index) {
  // determines a return type for the given types and operation and returns its
  // index in the type table
  return 0;
}

#endif  // HELPERS_H_