// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 Lostecho.

//! # echo_rpc — JSON-RPC Server for Lostecho Full Node

pub mod api;
pub mod server;
pub mod types;
pub mod wallet_ops;
pub mod wallet_submit;

pub use server::{start_rpc_server, ExternalMiningAttemptInvalidator};
pub use wallet_ops::WalletOps;
pub use wallet_submit::WalletOperationGate;
