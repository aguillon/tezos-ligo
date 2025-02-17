(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2020 Metastate AG <hello@metastate.dev>                     *)
(* Copyright (c) 2018-2021 Nomadic Labs, <contact@nomadic-labs.com>          *)
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

open Validation_errors

type 'protocol_operation operation = {
  hash : Operation_hash.t;
  raw : Operation.t;
  protocol : 'protocol_operation;
  count_successful_prechecks : int;
}

type error += Endorsement_branch_not_live

let () =
  register_error_kind
    `Permanent
    ~id:"prevalidation.endorsement_branch_not_live"
    ~title:"Endorsement branch not live"
    ~description:"Endorsement's branch is not in the live blocks"
    ~pp:(fun ppf () ->
      Format.fprintf ppf "Endorsement's branch is not in the live blocks")
    Data_encoding.(empty)
    (function Endorsement_branch_not_live -> Some () | _ -> None)
    (fun () -> Endorsement_branch_not_live)

module type CHAIN_STORE = sig
  type chain_store

  val context :
    chain_store ->
    Store.Block.t ->
    Tp_environment.Context.t tzresult Lwt.t

  val chain_id : chain_store -> Chain_id.t
end

module type T = sig
  type protocol_operation

  type operation_receipt

  type validation_state

  type chain_store

  type t

  val parse :
    Operation_hash.t -> Operation.t -> protocol_operation operation tzresult

  val increment_successful_precheck :
    protocol_operation operation -> protocol_operation operation

  val create :
    chain_store ->
    predecessor:Store.Block.t ->
    live_operations:Operation_hash.Set.t ->
    timestamp:Time.Protocol.t ->
    unit ->
    t tzresult Lwt.t

  type result =
    | Applied of t * operation_receipt
    | Branch_delayed of tztrace
    | Branch_refused of tztrace
    | Refused of tztrace
    | Outdated of tztrace

  val apply_operation : t -> protocol_operation operation -> result Lwt.t

  val validation_state : t -> validation_state

  val set_validation_state : t -> validation_state -> t

  val pp_result : Format.formatter -> result -> unit

  module Internal_for_tests : sig
    val to_applied :
      t -> (protocol_operation operation * operation_receipt) list
  end
end

(** Doesn't depend on heavy [Registered_protocol.T] for testability. *)
let safe_binary_of_bytes (encoding : 'a Data_encoding.t) (bytes : bytes) :
    'a tzresult =
  let open Result_syntax in
  match Data_encoding.Binary.of_bytes_opt encoding bytes with
  | None -> tzfail Parse_error
  | Some protocol_data -> return protocol_data

module MakeAbstract
    (Chain_store : CHAIN_STORE)
    (Proto : Tp_environment.PROTOCOL) :
  T
    with type protocol_operation = Proto.operation
     and type operation_receipt = Proto.operation_receipt
     and type validation_state = Proto.validation_state
     and type chain_store = Chain_store.chain_store = struct
  type protocol_operation = Proto.operation

  type operation_receipt = Proto.operation_receipt

  type validation_state = Proto.validation_state

  type chain_store = Chain_store.chain_store

  type t = {
    validation_state : validation_state;
    application_state : Proto.application_state;
    applied : (protocol_operation operation * Proto.operation_receipt) list;
    live_operations : Operation_hash.Set.t;
  }

  type result =
    | Applied of t * Proto.operation_receipt
    | Branch_delayed of tztrace
    | Branch_refused of tztrace
    | Refused of tztrace
    | Outdated of tztrace

  let parse_unsafe (proto : bytes) : Proto.operation_data tzresult =
    safe_binary_of_bytes Proto.operation_data_encoding proto

  let parse hash (raw : Operation.t) =
    let open Result_syntax in
    let size = Data_encoding.Binary.length Operation.encoding raw in
    if size > Proto.max_operation_data_length then
      tzfail (Oversized_operation {size; max = Proto.max_operation_data_length})
    else
      let+ protocol_data = parse_unsafe raw.proto in
      {
        hash;
        raw;
        protocol = {Proto.shell = raw.Operation.shell; protocol_data};
        (* When an operation is parsed, we assume that it has never been
           successfully prechecked. *)
        count_successful_prechecks = 0;
      }

  let increment_successful_precheck op =
    (* We avoid {op with ...} to get feedback from the compiler if the record
       type is extended/modified in the future. *)
    {
      hash = op.hash;
      raw = op.raw;
      protocol = op.protocol;
      count_successful_prechecks = op.count_successful_prechecks + 1;
    }

  let create chain_store ~predecessor ~live_operations ~timestamp () =
    (* The prevalidation module receives input from the system byt handles
       protocol values. It translates timestamps here. *)
    let open Lwt_result_syntax in
    let* predecessor_context = Chain_store.context chain_store predecessor in
    let predecessor_hash = Store.Block.hash predecessor in
    let*! predecessor_context =
      Block_validation.update_testchain_status
        predecessor_context
        ~predecessor_hash
        timestamp
    in
    let chain_id = Chain_store.chain_id chain_store in
    let mode = Proto.Partial_construction {predecessor_hash; timestamp} in
    let predecessor = (Store.Block.header predecessor).shell in
    let* validation_state =
      Proto.begin_validation
        predecessor_context
        chain_id
        mode
        ~predecessor
        ~cache:`Lazy
    in
    let* application_state =
      Proto.begin_application
        predecessor_context
        chain_id
        mode
        ~predecessor
        ~cache:`Lazy
    in
    return {validation_state; application_state; applied = []; live_operations}

  let apply_operation pv op =
    let open Lwt_syntax in
    if Operation_hash.Set.mem op.hash pv.live_operations then
      (* As of November 2021, it is dubious that this case can happen.
         If it can, it is more likely to be because of a consensus operation;
         hence the returned error. *)
      Lwt.return (Outdated [Endorsement_branch_not_live])
    else
      let+ r =
        protect (fun () ->
            let open Lwt_result_syntax in
            let* validation_state =
              Proto.validate_operation pv.validation_state op.hash op.protocol
            in
            let* application_state, receipt =
              Proto.apply_operation pv.application_state op.hash op.protocol
            in
            return (validation_state, application_state, receipt))
      in
      match r with
      | Ok (validation_state, application_state, receipt) -> (
          let pv =
            {
              validation_state;
              application_state;
              applied = (op, receipt) :: pv.applied;
              live_operations =
                Operation_hash.Set.add op.hash pv.live_operations;
            }
          in
          match
            Data_encoding.Binary.(
              of_bytes_exn
                Proto.operation_receipt_encoding
                (to_bytes_exn Proto.operation_receipt_encoding receipt))
          with
          | receipt -> Applied (pv, receipt)
          | exception exn ->
              Refused
                [Validation_errors.Cannot_serialize_operation_metadata; Exn exn]
          )
      | Error trace -> (
          match classify_trace trace with
          | Branch -> Branch_refused trace
          | Permanent -> Refused trace
          | Temporary -> Branch_delayed trace
          | Outdated -> Outdated trace)

  let validation_state {validation_state; _} = validation_state

  let set_validation_state t validation_state = {t with validation_state}

  let pp_result ppf =
    let open Format in
    function
    | Applied _ -> pp_print_string ppf "applied"
    | Branch_delayed err -> fprintf ppf "branch delayed (%a)" pp_print_trace err
    | Branch_refused err -> fprintf ppf "branch refused (%a)" pp_print_trace err
    | Refused err -> fprintf ppf "refused (%a)" pp_print_trace err
    | Outdated err -> fprintf ppf "outdated (%a)" pp_print_trace err

  module Internal_for_tests = struct
    let to_applied {applied; _} = applied
  end
end

module Production_chain_store :
  CHAIN_STORE with type chain_store = Store.chain_store = struct
  type chain_store = Store.chain_store

  let context = Store.Block.context

  let chain_id = Store.Chain.chain_id
end

module Make (Proto : Tp_environment.PROTOCOL) :
  T
    with type protocol_operation = Proto.operation
     and type operation_receipt = Proto.operation_receipt
     and type validation_state = Proto.validation_state
     and type chain_store = Production_chain_store.chain_store =
  MakeAbstract (Production_chain_store) (Proto)

module Internal_for_tests = struct
  let to_raw {raw; _} = raw

  let hash_of {hash; _} = hash

  let make_operation op oph data =
    (* When we build an operation, we assume that it has never been
       successfully prechecked. *)
    {hash = oph; raw = op; protocol = data; count_successful_prechecks = 0}

  let safe_binary_of_bytes = safe_binary_of_bytes

  module type CHAIN_STORE = CHAIN_STORE

  module Make = MakeAbstract
end
