(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2022 Nomadic Labs. <contact@nomadic-labs.com>               *)
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

open Environment_context
open Environment_protocol_T

module type T = sig
  include
    Tp_environment_sigs.V8.T
      with type Format.formatter = Format.formatter
       and type 'a Seq.node = 'a Seq.node
       and type 'a Seq.t = unit -> 'a Seq.node
      (* This ['a Seq.t = unit -> 'a Seq.node] cannot be replaced by the
         simpler ['a Seq.t = 'a Seq.t] (which one could think is equivalent)
         because this makes [Seq.t] abstract in the protocol environment.
         Specifically, with the [= 'a Seq.t] constraints sequences can be
         passed to [fold], [iter] and other such functions, but they cannot
         be traversed manually. *)
       and type 'a Data_encoding.t = 'a Data_encoding.t
       and type 'a Data_encoding.Compact.t = 'a Data_encoding.Compact.t
       and type 'a Data_encoding.lazy_t = 'a Data_encoding.lazy_t
       and type 'a Lwt.t = 'a Lwt.t
       and type ('a, 'b) Pervasives.result = ('a, 'b) result
       and type Chain_id.t = Chain_id.t
       and type Block_hash.t = Block_hash.t
       and type Operation_hash.t = Operation_hash.t
       and type Operation_list_hash.t = Operation_list_hash.t
       and type Operation_list_list_hash.t = Operation_list_list_hash.t
       and type Context.t = Context.t
       and type Context.cache_key = Environment_context.Context.cache_key
       and type Context.cache_value = Environment_context.Context.cache_value
       and type Context_hash.t = Context_hash.t
       and type Context_hash.Version.t = Context_hash.Version.t
       and type Context.config = Tezos_context_sigs.Config.t
       and module Context.Proof = Environment_context.Context.Proof
       and type Protocol_hash.t = Protocol_hash.t
       and type Time.t = Time.Protocol.t
       and type Operation.shell_header = Operation.shell_header
       and type Operation.t = Operation.t
       and type Block_header.shell_header = Block_header.shell_header
       and type Block_header.t = Block_header.t
       and type 'a RPC_directory.t = 'a RPC_directory.t
       and type Ed25519.Public_key_hash.t = Ed25519.Public_key_hash.t
       and type Ed25519.Public_key.t = Ed25519.Public_key.t
       and type Ed25519.t = Ed25519.t
       and type Secp256k1.Public_key_hash.t = Secp256k1.Public_key_hash.t
       and type Secp256k1.Public_key.t = Secp256k1.Public_key.t
       and type Secp256k1.t = Secp256k1.t
       and type P256.Public_key_hash.t = P256.Public_key_hash.t
       and type P256.Public_key.t = P256.Public_key.t
       and type P256.t = P256.t
       and type Bls.Public_key_hash.t = Bls.Public_key_hash.t
       and type Bls.Public_key.t = Bls.Public_key.t
       and type Bls.t = Bls.t
       and type Signature.public_key_hash = Signature.public_key_hash
       and type Signature.public_key = Signature.public_key
       and type Signature.t = Signature.t
       and type Signature.watermark = Signature.watermark
       and type Micheline.canonical_location = Micheline.canonical_location
       and type 'a Micheline.canonical = 'a Micheline.canonical
       and type Z.t = Z.t
       and type Q.t = Q.t
       and type ('a, 'b) Micheline.node = ('a, 'b) Micheline.node
       and type Data_encoding.json_schema = Data_encoding.json_schema
       and type ('a, 'b) RPC_path.t = ('a, 'b) RPC_path.t
       and type RPC_service.meth = RPC_service.meth
       and type (+'m, 'pr, 'p, 'q, 'i, 'o) RPC_service.t =
        ('m, 'pr, 'p, 'q, 'i, 'o) RPC_service.t
       and type Error_monad.shell_tztrace = Error_monad.tztrace
       and type 'a Error_monad.shell_tzresult = ('a, Error_monad.tztrace) result
       and type Timelock.chest = Timelock.chest
       and type Timelock.chest_key = Timelock.chest_key
       and type Timelock.opening_result = Timelock.opening_result
       and module Sapling = Tezos_sapling.Core.Validator
       and type ('a, 'b) Either.t = ('a, 'b) Stdlib.Either.t
       and type Bls.Primitive.Fr.t = Bls12_381.Fr.t
       and type Plonk.proof = Tp_environment_structs.V8.Plonk.proof
       and type Plonk.public_parameters =
        Tp_environment_structs.V8.Plonk.verifier_public_parameters
        * Tp_environment_structs.V8.Plonk.transcript
       and type Dal.parameters = Tezos_crypto_dal.Cryptobox.Verifier.parameters
       and type Dal.commitment = Tezos_crypto_dal.Cryptobox.Verifier.commitment
       and type Dal.page_proof = Tezos_crypto_dal.Cryptobox.Verifier.page_proof
       and type Bounded.Non_negative_int32.t =
        Tezos_base.Bounded.Non_negative_int32.t
       and type Wasm_2_0_0.input = Tezos_scoru_wasm.Wasm_pvm_state.input_info
       and type Wasm_2_0_0.output = Tezos_scoru_wasm.Wasm_pvm_state.output_info
       and type Wasm_2_0_0.input_hash =
        Tezos_scoru_wasm.Wasm_pvm_state.input_hash
       and type Wasm_2_0_0.reveal = Tezos_scoru_wasm.Wasm_pvm_state.reveal
       and type Wasm_2_0_0.input_request =
        Tezos_scoru_wasm.Wasm_pvm_state.input_request
       and type Wasm_2_0_0.info = Tezos_scoru_wasm.Wasm_pvm_state.info

  (** An [Ecoproto_error e] is a shell error that carry a protocol error.

      Each protocol has its own error-monad (instantiated when this module here
      is applied) with a fresh extensible error type. This protocol-specific
      error type is incompatible with the shell's. The [Ecoproto_error]
      constructor belongs to the shell's error type and it carries the errors of
      the protocol's specific error type back into the shell's.

      The function [wrap_tz*] below provide wrappers for three different levels:
      errors, traces, and tzresults. They are used within the implementation of
      the environment to translate some return values from the protocol's error
      monad into the shell's. They are exported because they can be useful for
      writing tests for the protocol (i.e., for the tests located in
      [src/proto_*/lib_protocol/test/]) and for writing protocol-specific
      support libraries and binaries (i.e., for the code in
      [src/proto_*/lib_{client,delegate,etc.}]). *)
  type error += Ecoproto_error of Error_monad.error

  (** [wrap_tzerror e] is a shell error wrapping the protocol error [e].
      (It is [Ecoproto_error e].) *)
  val wrap_tzerror : Error_monad.error -> error

  (** [wrap_tztrace t] is a shell trace composed of the wrapped errors of the
      protocol trace [t]. *)
  val wrap_tztrace : Error_monad.error Error_monad.trace -> error trace

  (** [wrap_tzresult r] is a shell tzresult that carries the same result as or a
      wrapped trace of the protocol tzresult [r].
      (It is [Ok x] if [r] is [Ok x], it is [Error (wrap_tztrace t)] if [r] is
      [Error t].) *)
  val wrap_tzresult : 'a Error_monad.tzresult -> 'a tzresult

  module Lift (P : Updater.PROTOCOL) :
    PROTOCOL
      with type block_header_data = P.block_header_data
       and type block_header_metadata = P.block_header_metadata
       and type block_header = P.block_header
       and type operation_data = P.operation_data
       and type operation_receipt = P.operation_receipt
       and type operation = P.operation
       and type validation_state = P.validation_state
       and type application_state = P.application_state

  class ['chain, 'block] proto_rpc_context :
    Tezos_rpc.RPC_context.t
    -> (unit, (unit * 'chain) * 'block) RPC_path.t
    -> ['chain * 'block] RPC_context.simple

  class ['block] proto_rpc_context_of_directory :
    ('block -> RPC_context.t)
    -> RPC_context.t RPC_directory.t
    -> ['block] RPC_context.simple
end

module Make (Param : sig
  val name : string
end)
() :
  T
    with type Updater.validation_result = validation_result
     and type Updater.quota = quota
     and type Updater.rpc_context = rpc_context
