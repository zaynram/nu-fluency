#!/usr/bin/env nu --stdin
use std/math

def main []: [
  oneof<any, nothing> -> record<type: string, len?: int, sample: any>
] {
  let x = $in
  try {
    let len = $x | length
    let n = $len - 1 | append 3 | math min
    {len: $len sample: ($x | first $n)}
  } catch { {sample: $x} }
  | insert type ($x | describe)
}
