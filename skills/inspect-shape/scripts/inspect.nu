#!/usr/bin/env -S nu --stdin

const EMPTY: record<type: string> = {type: nothing sample: null}
const PRIMITIVES: list<string> = [
  number
  string
  record
  datetime
  duration
  filesize
]

def main [
  --max-rows (-m): int = 3 # Rows to include in the `value` field for `list` and `table` values
]: [
  closure -> oneof<record<type: string, value: nothing>, record<type: string, length: int, value: nothing>>
  nothing -> record<type: string, value: nothing>
  number -> record<type: string, value: number>
  string -> record<type: string, value: string>
  record -> record<type: string, value: record>
  datetime -> record<type: string, value: datetime>
  duration -> record<type: string, value: duration>
  filesize -> record<type: string, value: filesize>
  list<any> -> record<type: string, length: int, value: list<any>>
  table -> record<type: string, length: int, value: table>
] {
  let x: any = collect
  let desc: record = $x | describe --detailed
  if $desc.type == closure { return (do --capture-errors $x | main) }
  match $desc {
    nothing => { return $EMPTY }
    {type: closure} => { do --capture-errors $x | main }
    {type: $t} if $t =~ '^(list|table)' => { $desc | update value { $x | first $max_rows } }
    _ => $desc
  }
  | reject type rust_type
  | rename --column={detailed_type: type}
  | compact
}
