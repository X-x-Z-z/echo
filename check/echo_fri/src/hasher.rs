// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 Lostecho.

//! Cryptographic hasher trait + concrete implementations used by the FRI
//! Merkle layer.
//!
//! Production callers use Poseidon2b (`Poseidon2bSponge` from
//! `echo_poseidon2b`) as the arithmetization-friendly hasher. The FRI
//! prover/verifier take `&dyn CryptographicHasher`, and production uses the
//! Poseidon2b implementation from `echo_poseidon2b`.

pub use echo_poseidon2b::hasher::{CryptographicHasher, HashOutput};
