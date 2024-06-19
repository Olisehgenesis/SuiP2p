module p2plending::p2plending {
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::bag::{Self, Bag};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::clock::{Clock, timestamp_ms};
    use sui::event;
    use std::vector;

    const FLOAT_SCALING: u64 = 1_000_000_000;

    const ERROR_INSUFFICENT_BALANCE: u64 = 0;

    public struct Loan has key, store {
        id: UID,
        lender: address,
        borrower: address,
        amount: u64,
        interest_rate: u64, // Interest rate as a percentage scaled by FLOAT_SCALING
        current_date: u64,
        due_date: u64,
        repaid: bool,
    }

    public struct LoanRegistry has key, store {
        id: UID,
        loans: Table<ID, Loan>,
        balance: Balance<SUI>
    }

    public struct UserReputation has key, store {
        id: UID,
        user: address,
        stars: u64,
    }

    public struct LoanRepaidEvent has copy, drop {
        lender: address,
        borrower: address,
        amount: u64,
    }

    // Initializer
    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            LoanRegistry { id: object::new(ctx), loans: table::new(ctx), balance: balance::zero()},
        );
        transfer::share_object(
            UserReputation { id: object::new(ctx), user: sender(ctx), stars: 0},
        );
    }

    // Create a new loan
    public fun create_loan(self: &mut LoanRegistry, amount: u64, interest_rate: u64, due_date: u64, ctx: &mut TxContext) {
        let lender = ctx.sender();
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let loan = Loan { 
            id: id_,
            lender: lender,
            borrower: lender,
            amount: amount,
            interest_rate: interest_rate,
            current_date: 0,
            due_date: due_date,
            repaid: false 
        };
        table::add(&mut self.loans, inner_, loan);
    }

    // Take a loan
    public fun take_loan(self: &mut LoanRegistry, loan_id: ID, coin_: Coin<SUI>, c: &Clock, ctx: &mut TxContext) : Loan {
        let mut loan = table::remove(&mut self.loans, loan_id);
        loan.current_date = timestamp_ms(c);
        assert!(coin_.value() > loan.amount, ERROR_INSUFFICENT_BALANCE);
        coin::put(&mut self.balance, coin_);
        loan
    }

    // Repay a loan
    public fun repay_loan(self: &mut LoanRegistry, loan: Loan, c: &Clock, ctx: &mut TxContext) : Coin<SUI> {
        let previous = loan.current_date;
        let interest = (timestamp_ms(c) - previous) * (calculate_interest(loan.amount, loan.interest_rate));
        let coin_ = coin::take(&mut self.balance, loan.amount - interest, ctx);
        table::add(&mut self.loans, object::id(&loan), loan);
        coin_
    }

    // Calculate interest
    fun calculate_interest(amount: u64, interest_rate: u64): u64 {
        (amount * interest_rate) / FLOAT_SCALING
    }
}
