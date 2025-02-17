(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Nomadic Development. <contact@tezcore.com>             *)
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

module type FILTER = sig
  module Proto : Registered_protocol.T

  module Mempool : sig
    type config

    val config_encoding : config Data_encoding.t

    val default_config : config

    type state

    val init :
      config ->
      ?validation_state:Proto.validation_state ->
      predecessor:Tezos_base.Block_header.t ->
      unit ->
      state tzresult Lwt.t

    val on_flush :
      config ->
      state ->
      ?validation_state:Proto.validation_state ->
      predecessor:Tezos_base.Block_header.t ->
      unit ->
      state tzresult Lwt.t

    val remove : filter_state:state -> Operation_hash.t -> state

    val precheck :
      config ->
      filter_state:state ->
      validation_state:Proto.validation_state ->
      Operation_hash.t ->
      Proto.operation ->
      nb_successful_prechecks:int ->
      [ `Passed_precheck of
        state
        * Proto.validation_state
        * [ `No_replace
          | `Replace of
            Operation_hash.t * Prevalidator_classification.error_classification
          ]
      | `Undecided
      | Prevalidator_classification.error_classification ]
      Lwt.t

    val pre_filter :
      config ->
      filter_state:state ->
      ?validation_state_before:Proto.validation_state ->
      Proto.operation ->
      [ `Passed_prefilter of Prevalidator_pending_operations.priority
      | Prevalidator_classification.error_classification ]
      Lwt.t

    val post_filter :
      config ->
      filter_state:state ->
      validation_state_before:Proto.validation_state ->
      validation_state_after:Proto.validation_state ->
      Proto.operation * Proto.operation_receipt ->
      [`Passed_postfilter of state | `Refused of tztrace] Lwt.t
  end
end

module type RPC = sig
  module Proto : Registered_protocol.T

  val rpc_services :
    Tp_environment.rpc_context RPC_directory.directory
end

module No_filter (Proto : Registered_protocol.T) = struct
  module Proto = Proto

  module Mempool = struct
    type config = unit

    let config_encoding = Data_encoding.empty

    let default_config = ()

    type state = unit

    let init _ ?validation_state:_ ~predecessor:_ () =
      Lwt_result_syntax.return_unit

    let remove ~filter_state _ = filter_state

    let on_flush _ _ ?validation_state:_ ~predecessor:_ () =
      Lwt_result_syntax.return_unit

    let precheck _ ~filter_state:_ ~validation_state:_ _ _
        ~nb_successful_prechecks:_ =
      Lwt.return `Undecided

    let pre_filter _ ~filter_state:_ ?validation_state_before:_ _ =
      Lwt.return @@ `Passed_prefilter (`Low [])

    let post_filter _ ~filter_state ~validation_state_before:_
        ~validation_state_after:_ _ =
      Lwt.return (`Passed_postfilter filter_state)
  end
end

module type METRICS = sig
  val hash : Protocol_hash.t

  val update_metrics :
    protocol_metadata:bytes ->
    Fitness.t ->
    (cycle:float -> consumed_gas:float -> round:float -> unit) ->
    unit Lwt.t
end

module Undefined_metrics_plugin (Proto : sig
  val hash : Protocol_hash.t
end) =
struct
  let hash = Proto.hash

  let update_metrics ~protocol_metadata:_ _ _ = Lwt.return_unit
end

let filter_table : (module FILTER) Protocol_hash.Table.t =
  Protocol_hash.Table.create 5

let rpc_table : (module RPC) Protocol_hash.Table.t =
  Protocol_hash.Table.create 5

let metrics_table : (module METRICS) Protocol_hash.Table.t =
  Protocol_hash.Table.create 5

let register_filter (module Filter : FILTER) =
  assert (not (Protocol_hash.Table.mem filter_table Filter.Proto.hash)) ;
  Protocol_hash.Table.add filter_table Filter.Proto.hash (module Filter)

let register_rpc (module Rpc : RPC) =
  assert (not (Protocol_hash.Table.mem rpc_table Rpc.Proto.hash)) ;
  Protocol_hash.Table.add rpc_table Rpc.Proto.hash (module Rpc)

let register_metrics (module Metrics : METRICS) =
  Protocol_hash.Table.replace metrics_table Metrics.hash (module Metrics)

let find_filter = Protocol_hash.Table.find filter_table

let find_rpc = Protocol_hash.Table.find rpc_table

let find_metrics = Protocol_hash.Table.find metrics_table

let safe_find_metrics hash =
  match find_metrics hash with
  | Some proto_metrics -> Lwt.return proto_metrics
  | None ->
      let module Metrics = Undefined_metrics_plugin (struct
        let hash = hash
      end) in
      Lwt.return (module Metrics : METRICS)
