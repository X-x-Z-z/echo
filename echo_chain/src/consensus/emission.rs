// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2026 Lostecho.

//! Block reward schedule.
//!
//! Reward halves with every state expansion (`log_slots += 1`), floored at 1 ECHO.
//!
//! ```text
//! log_slots | expansion | reward
//! ----------|-----------|-------
//!    24      |     0     | 50.000000 ECHO  (genesis)
//!    25      |     1     | 25.000000 ECHO
//!    26      |     2     | 12.500000 ECHO
//!    27      |     3     |  6.250000 ECHO
//!    28      |     4     |  3.125000 ECHO
//!    29      |     5     |  1.562500 ECHO
//!    30+     |     6+    |  1.000000 ECHO  (floor, forever)
//! ```
//!
//! Anti-spam property: state expands only when ~75% capacity is reached.
//! Filling slots to trigger expansion halves the miner reward.
//! The natural economic consequence of network growth is decreasing inflation.

use crate::consensus::fees::claimable_fee_for_tx_body;
use crate::consensus::params::{
    BASE_REWARD_MICROECHO, FLOOR_REWARD_MICROECHO, LOG_SLOTS_GENESIS, MICROECHO_PER_ECHO,
};
use echo_tx::types::TxBody;

/// Compute the block reward in μECHO for the given `log_slots` value.
///
/// `log_slots` is the current state capacity exponent from the block header.
/// Halves once per state expansion, never below `FLOOR_REWARD_MICROECHO`.
///
/// # Examples
///
/// ```
/// use echo_chain::consensus::emission::block_reward;
/// assert_eq!(block_reward(24), 50_000_000); // 50 ECHO at genesis
/// assert_eq!(block_reward(25), 25_000_000); // 25 ECHO after first expansion
/// assert_eq!(block_reward(30), 1_000_000);  // 1 ECHO floor
/// assert_eq!(block_reward(32), 1_000_000);  // 1 ECHO still
/// ```
pub fn block_reward(log_slots: u32) -> u64 {
    let expansions = log_slots.saturating_sub(LOG_SLOTS_GENESIS);
    BASE_REWARD_MICROECHO
        .checked_shr(expansions)
        .unwrap_or(0)
        .max(FLOOR_REWARD_MICROECHO)
}

/// Sum all gross transaction fees (non-coinbase) in μECHO.
///
/// A block can contain 255 `u64` fees, so aggregation uses `u128`; consensus
/// predicates never silently saturate a monetary total. This is accounting
/// data, not a coinbase ceiling: deterministic state-growth burn must first be
/// removed via [`claimable_fee_for_tx_body`].
pub fn total_fees(txs: &[TxBody]) -> u128 {
    txs.iter()
        .filter(|tx| !tx.is_coinbase)
        .map(|tx| u128::from(tx.fee))
        .sum()
}

/// Maximum value the coinbase output is permitted to carry (μECHO).
///
/// Only miner-claimable fees are included. The deterministic state-growth
/// component is burned and can never be recovered through coinbase.
pub fn max_coinbase_value(
    child_height: u64,
    child_log_slots: u32,
    parent_active_slot_count: u64,
    parent_log_slots: u32,
    non_coinbase_txs: &[TxBody],
) -> u128 {
    let claimable_fee_sum: u128 = non_coinbase_txs
        .iter()
        .filter(|tx| !tx.is_coinbase)
        .map(|tx| {
            u128::from(claimable_fee_for_tx_body(
                tx,
                parent_active_slot_count,
                parent_log_slots,
            ))
        })
        .sum();
    max_coinbase_value_from_claimable_fee_sum(child_height, child_log_slots, claimable_fee_sum)
}

/// Same as [`max_coinbase_value`] but accepts an already checked sum of
/// miner-claimable fees (paid fee minus deterministic burn).
///
/// Used by `validate_block_consensus` to avoid cloning all non-coinbase
/// bodies just to repeat fee accounting.
#[inline]
pub fn max_coinbase_value_from_claimable_fee_sum(
    child_height: u64,
    child_log_slots: u32,
    claimable_fee_sum: u128,
) -> u128 {
    u128::from(crate::consensus::development_allocation::miner_subsidy(
        child_height,
        child_log_slots,
    )) + claimable_fee_sum
}

/// Format a μECHO amount as a human-readable string (not consensus-critical).
pub fn format_echo(microecho: u64) -> String {
    let whole = microecho / MICROECHO_PER_ECHO;
    let frac = microecho % MICROECHO_PER_ECHO;
    format!("{}.{:06} ECHO", whole, frac)
}

#[cfg(test)]
mod tests {
    use super::*;
    use echo_poseidon2b::primitives::Address;
    use echo_tx::{output_bitmap_bit, TxBody, TxInput, TxOutput, TX_INPUTS, TX_OUTPUTS};

    fn fee_body(fee: u64, coinbase: bool) -> TxBody {
        TxBody {
            epoch_anchor: [1u8; 32],
            fee: if coinbase { 0 } else { fee },
            input_owner: Address([0u8; 32]),
            inputs: [TxInput::dummy(); TX_INPUTS],
            outputs: [TxOutput::dummy(); TX_OUTPUTS],
            validity_bitmap: 0,
            is_coinbase: coinbase,
        }
    }

    #[test]
    fn reward_halves_with_expansion_and_has_floor() {
        assert_eq!(block_reward(LOG_SLOTS_GENESIS), BASE_REWARD_MICROECHO);
        assert_eq!(
            block_reward(LOG_SLOTS_GENESIS + 1),
            BASE_REWARD_MICROECHO / 2
        );
        assert_eq!(
            block_reward(LOG_SLOTS_GENESIS + 100),
            FLOOR_REWARD_MICROECHO
        );
    }

    #[test]
    fn total_fees_excludes_coinbase_without_u64_saturation() {
        assert_eq!(
            total_fees(&[fee_body(7, false), fee_body(0, true), fee_body(9, false),]),
            16
        );
        assert_eq!(
            total_fees(&[fee_body(u64::MAX, false), fee_body(1, false)]),
            u128::from(u64::MAX) + 1
        );
    }

    #[test]
    fn coinbase_ceiling_excludes_state_growth_burn() {
        let mut tx = fee_body(9_000, false);
        tx.inputs[0].slot_index = 1;
        tx.outputs[0].slot_index = 2;
        tx.outputs[1].slot_index = 3;
        tx.validity_bitmap = 1 | output_bitmap_bit(0) | output_bitmap_bit(1);
        let ceiling = max_coinbase_value(1, LOG_SLOTS_GENESIS, 0, LOG_SLOTS_GENESIS, &[tx]);
        assert_eq!(
            ceiling,
            u128::from(
                crate::consensus::development_allocation::miner_subsidy(1, LOG_SLOTS_GENESIS,)
                    + 6_500,
            )
        );
        assert_eq!(
            ceiling,
            max_coinbase_value_from_claimable_fee_sum(1, LOG_SLOTS_GENESIS, 6_500)
        );
    }
}
