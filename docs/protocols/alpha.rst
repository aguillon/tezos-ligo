Protocol Alpha
==============

This page contains all the relevant information for protocol Alpha
(see :ref:`naming_convention`).

The code can be found in the :src:`src/proto_alpha` directory of the
``master`` branch of Tezos.

This page documents the changes brought by protocol Alpha with respect
to Hangzhou.

.. contents::

New Environment Version (V4)
----------------------------

This protocol requires a different protocol environment than Hangzhou.
It requires protocol environment V4, compared to V3 for Hangzhou.
(MRs :gl:`!3379`, :gl:`!3468`)

- Move BLS12-381 to blst backend. (MR :gl:`!3296`)

- Expose BLS signature module. (MR :gl:`!3470`)

- Remove Error-monad compat layer. (MR :gl:`!3575`)

- Allow different type of error categories in the different error monads.
  (MR :gl:`!3664`)

- Fix interface of Hex. (MR :gl:`!3267`)

- Fix use of micheline canonical encoding. (MR :gl:`!3764`)

Tenderbake
----------

- A replacement of Emmy* in order to provide deterministic finality. (MR :gl:`!3738`)

Tickets Strengthening
---------------------

- Add ticket-balance storage module. (MR :gl:`!3495`)

- API for scanning values for tickets. (MR :gl:`!3591`)

Michelson
---------

- A new ``SUB_MUTEZ`` instruction has been added, it is similar to the
  ``mutez`` case of the ``SUB`` instruction but its return type is
  ``option mutez`` instead of ``mutez``. This allows subtracting
  ``mutez`` values without failing in case of underflow. (MR :gl:`!3079`)

- The ``SUB`` instruction on type ``mutez`` is deprecated. It can be
  replaced by ``SUB_MUTEZ; ASSERT_SOME`` (and ``SUB; DROP`` can be
  replaced by ``ASSERT_CMPGE``). (MR :gl:`!3079`)

Bug Fixes
---------

- Use Cache_costs.cache_find in cache find. (MR :gl:`!3752`)

Minor Changes
-------------

- Update and simplify fixed constants. (MR :gl:`!3454`)

- Simplify pack cost. (MR :gl:`!3620`)

- Do not play with locations inside protocol. (MR :gl:`!3667`)

- Remove the optional entrypoint in ticketer address. (MR :gl:`!3570`)

- Make delegate optional for bootstrap contracts. (MR :gl:`!3584`)

- Fix interface of Hex. (MR :gl:`!3267`)

- Update migration for protocol "I". (MR :gl:`!3668`)

- Make `max_operations_ttl` a parametric constant of the protocol, now called `max_operations_time_to_live`. (MR :gl:`!3709`)

- ``NOW`` and ``LEVEL`` are now passed to the Michelson interpreter as
  step constants instead of being read from the context each time
  these instructions are executed. (MR :gl:`!3524`)

- Other internal refactorings or documentation. (MRs :gl:`!3506`, :gl:`!3550`,
  :gl:`!3593`, :gl:`!3552`, :gl:`!3588`, :gl:`!3612`, :gl:`!3575`,
  :gl:`!3622`, :gl:`!3631`, :gl:`!3630`, :gl:`!3707`, :gl:`!3644`,
  :gl:`!3529`, :gl:`!3739``, :gl:`!3741`, :gl:`!3695`, :gl:`!3763`)
