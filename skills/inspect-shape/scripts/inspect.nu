#!/usr/bin/env -S nu --stdin
use std help
# Inspect the shape of pipeline input data.
def main [
  --max-rows (-m): int = 3 # Rows to include in the `value` field for `list` and `table` values
]: [
  table -> record<type: string, length: int, value: table>
  list -> record<type: string, length: int, value: list>
  nothing -> record<type: string>
  any -> record<type: string, value: any>
] {
  collect {|x|
    | describe --detailed
    | match $in {
      nothing => { wrap type | return $in }
      {type: closure} => { do --capture-errors $x | main | return $in }
      {type: $t} if $t =~ '^(list|table)' => { update value { $x | first $max_rows } }
      _ => { }
    } | reject type rust_type
    | rename --column={detailed_type: type}
    | compact
  }
}
