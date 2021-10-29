(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2021 Nomadic Labs, <contact@nomadic-labs.com>               *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

(** Invariants on the string: 1 <= length <= 31 *)
include Compare.String

let default = "default"

let is_default name = name = default

let root = "root"

type of_string_result =
  | Ok of t
  | Too_long  (** length > 31 *)
  | Got_default
      (** Got exactly "default", which can be an error in some cases or OK in others *)

let of_string str =
  if str = "" then
    (* The empty string always means the default entrypoint *)
    Ok default
  else if Compare.Int.(String.length str > 31) then Too_long
  else if is_default str then Got_default
  else Ok str

let of_string_strict' str =
  match of_string str with
  | Too_long -> Error "Entrypoint name too long"
  | Got_default -> Error "Unexpected annotation: default"
  | Ok name -> Ok name

let of_string_strict_exn str =
  match of_string_strict' str with Ok v -> v | Error err -> invalid_arg err

let pp = Format.pp_print_string

let in_memory_size name =
  Cache_memory_helpers.string_size_gen (String.length name)

module Set = Set.Make (String)
module Map = Map.Make (String)
