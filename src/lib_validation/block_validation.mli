(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2018-2021 Nomadic Labs. <contact@nomadic-labs.com>          *)
(* Copyright (c) 2020 Metastate AG <hello@metastate.dev>                     *)
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

(** This module is a proxy for the shell of the protocol (for the application
    part). The main function of this module is [apply] whichs calls the one of
    the protocol. *)

type validation_store = {
  context_hash : Context_hash.t;
  timestamp : Time.Protocol.t;
  message : string option;
  max_operations_ttl : int;
  last_allowed_fork_level : Int32.t;
      (** Oldest block for which reorganizations can happen *)
}

val may_patch_protocol :
  user_activated_upgrades:User_activated.upgrades ->
  user_activated_protocol_overrides:User_activated.protocol_overrides ->
  level:Int32.t ->
  Tp_environment.validation_result ->
  Tp_environment.validation_result Lwt.t

val update_testchain_status :
  Tp_environment.Context.t ->
  predecessor_hash:Block_hash.t ->
  Time.Protocol.t ->
  Tp_environment.Context.t Lwt.t

(** [check_proto_environment_version_increasing hash before after]
    returns successfully if the environment version stays the same or
    increases from [before] to [after]. Otherwise, an
    [Invalid_protocol_environment_transition] error is returned. *)
val check_proto_environment_version_increasing :
  Block_hash.t -> Protocol.env_version -> Protocol.env_version -> unit tzresult

(** [init_test_chain] must only be called on a forking block. *)
val init_test_chain :
  Chain_id.t ->
  Tp_environment.Context.t ->
  Block_header.t ->
  Block_header.t tzresult Lwt.t

type operation_metadata = Metadata of Bytes.t | Too_large_metadata

val operation_metadata_encoding : operation_metadata Data_encoding.t

type ops_metadata =
  | No_metadata_hash of operation_metadata list list
  | Metadata_hash of (operation_metadata * Operation_metadata_hash.t) list list

type result = {
  validation_store : validation_store;
  block_metadata : bytes * Block_metadata_hash.t option;
  ops_metadata : ops_metadata;
}

type apply_result = {
  result : result;
  cache : Tp_environment.Context.cache;
}

val result_encoding : result Data_encoding.t

val preapply_result_encoding :
  (Block_header.shell_header * error Preapply_result.t list) Data_encoding.t

(** [check_liveness live_blocks live_operations hash ops] checks
    there is no duplicate operation and that is not out-of-date *)
val check_liveness :
  live_blocks:Block_hash.Set.t ->
  live_operations:Operation_hash.Set.t ->
  Block_hash.t ->
  Operation.t list list ->
  unit tzresult

type apply_environment = {
  max_operations_ttl : int;  (** time to live of an operation *)
  chain_id : Chain_id.t;  (** chain_id of the current branch *)
  predecessor_block_header : Block_header.t;
      (** header of the predecessor block being validated *)
  predecessor_context : Tp_environment.Context.t;
      (** context associated to the predecessor block *)
  predecessor_block_metadata_hash : Block_metadata_hash.t option;
      (** hash of block header metadata of the predecessor block *)
  predecessor_ops_metadata_hash : Operation_metadata_list_list_hash.t option;
      (** hash of operation metadata of the predecessor block *)
  user_activated_upgrades : User_activated.upgrades;
      (** user activated upgrades *)
  user_activated_protocol_overrides : User_activated.protocol_overrides;
      (** user activated protocol overrides *)
  operation_metadata_size_limit : int option;
      (** size limit for operation metadata that should be written on disk *)
}

(** Default size limit for operation metadata *)
val default_operation_metadata_size_limit : int option

(** [apply env header ops] gets the protocol [P] of the context of the
    predecessor block and calls successively:
    1. [P.begin_application]
    2. [P.apply]
    3. [P.finalize_block]

    If [simulate] is true, the context resulting from the application
    is not committed to disk using `Context.commit`, only the commit
    hash is computed, using `Context.hash`. Set to false by default.

    Hypothesis: we assume that the given block has already been
                validated -- E.g. by calling [precheck]. *)
val apply :
  ?simulate:bool ->
  ?cached_result:apply_result * Tp_environment.Context.t ->
  apply_environment ->
  cache:Tp_environment.Context.source_of_cache ->
  Block_header.t ->
  Operation.t list list ->
  apply_result tzresult Lwt.t

(** [precheck chain_id ~predecessor_block_header
   ~predecessor_block_hash ~predecessor_context ~cache header ops]
   gets the protocol [P] of the context of the predecessor block and
   calls successively:
   1. [P.begin_validate]
   2. [P.validate_operation]
   3. [P.finalize_validation] *)
val precheck :
  chain_id:Chain_id.t ->
  predecessor_block_header:Block_header.t ->
  predecessor_block_hash:Block_hash.t ->
  predecessor_context:Tp_environment.Context.t ->
  cache:Tp_environment.Context.source_of_cache ->
  Block_header.t ->
  Operation.t list list ->
  unit tzresult Lwt.t

val preapply :
  chain_id:Chain_id.t ->
  user_activated_upgrades:Tezos_base.User_activated.upgrades ->
  user_activated_protocol_overrides:Tezos_base.User_activated.protocol_overrides ->
  operation_metadata_size_limit:int option ->
  timestamp:Time.Protocol.t ->
  protocol_data:bytes ->
  live_blocks:Block_hash.Set.t ->
  live_operations:Operation_hash.Set.t ->
  predecessor_context:Tp_environment.Context.t ->
  predecessor_shell_header:Block_header.shell_header ->
  predecessor_hash:Block_hash.t ->
  predecessor_max_operations_ttl:int ->
  predecessor_block_metadata_hash:Block_metadata_hash.t option ->
  predecessor_ops_metadata_hash:Operation_metadata_list_list_hash.t option ->
  Operation.t list list ->
  ((Block_header.shell_header * error Preapply_result.t list)
  * (apply_result * Tp_environment.Context.t))
  tzresult
  Lwt.t

(** Hypothesis: we assume that the given block has already been
                validated -- E.g. by calling [precheck]. *)
val recompute_metadata :
  chain_id:Chain_id.t ->
  predecessor_block_header:Block_header.t ->
  predecessor_context:Tp_environment.Context.t ->
  predecessor_block_metadata_hash:Block_metadata_hash.t option ->
  predecessor_ops_metadata_hash:Operation_metadata_list_list_hash.t option ->
  block_header:Block_header.t ->
  operations:Operation.t trace trace ->
  cache:Tp_environment.Context.source_of_cache ->
  ((bytes * Block_metadata_hash.t option) * ops_metadata) tzresult Lwt.t
