
#[lint_allow(self_transfer)]
module p2plending::p2plending {
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::bag::{Self, Bag};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::sui::{SUI};
    use sui::clock::{Clock, timestamp_ms};

    use std::vector;

    const FLOAT_SCALING: u64 = 1_000_000_000;

    struct Loan has copy, drop, store {
        lender: address,
        borrower: address,
        amount: u64,
        due_date: u64,
        repaid: bool,
    }

    struct LoanList has key, store {
        id: UID,
        loans: vector<Loan>,
    }

    struct Reputation has key, store {
        id: UID,
        user: address,
        stars: u64,
        reviews: vector<vector<u8>>,
    }

    public fun initialize(account: &signer, ctx: &mut TxContext) {
        transfer::share_object(
            LoanList { id: UID::new(ctx), loans: vector::empty<Loan>() },
        );
        transfer::share_object(
            Reputation { id: UID::new(ctx), user: tx_context::sender(ctx), stars: 0, reviews: vector::empty<vector<u8>>() },
        );
    }

    public fun create_loan(account: &signer, amount: u64, due_date: u64, ctx: &mut TxContext) {
        let lender = tx_context::sender(ctx);
        let loan = Loan { 
            lender: lender,
             borrower: address::ZERO, amount, due_date, repaid: false };
        let loan_list = borrow_global_mut<LoanList>(lender);
        vector::push_back(&mut loan_list.loans, loan);
    }

    public fun view_available_loans(ctx: &mut TxContext): vector<Loan> {
        let loan_list = borrow_global<LoanList>(tx_context::sender(ctx));
        let mut available_loans = vector::empty<Loan>();
        for loan in &loan_list.loans {
            if loan.borrower == address::ZERO {
                vector::push_back(&mut available_loans, loan);
            }
        }
        available_loans
    }

    public fun take_loan(account: &signer, lender: address, loan_id: UID, ctx: &mut TxContext) {
        let borrower = tx_context::sender(ctx);
        let loan_list = borrow_global_mut<LoanList>(lender);
        let loan_index = find_loan_index_by_id(&loan_list.loans, loan_id);
        let loan = &mut loan_list.loans[loan_index];
        assert!(loan.borrower == address::ZERO, 102); // Loan should be available
        loan.borrower = borrower;
        transfer::public_transfer(SUI::mint(loan.amount, ctx), borrower);
    }

    public fun repay_loan(account: &signer, lender: address, loan_id: UID, ctx: &mut TxContext) {
        let borrower = tx_context::sender(ctx);
        let loan_list = borrow_global_mut<LoanList>(lender);
        let loan_index = find_loan_index_by_id(&loan_list.loans, loan_id);
        let loan = &mut loan_list.loans[loan_index];
        assert!(loan.borrower == borrower, 100);
        assert!(!loan.repaid, 101);
        transfer::public_transfer(SUI::mint(loan.amount, ctx), lender);
        loan.repaid = true;
        Event::emit(LoanRepaidEvent { lender, borrower, amount: loan.amount });
        add_star(borrower); // Add star to the borrower for timely repayment
    }

    struct LoanRepaidEvent has drop {
        lender: address,
        borrower: address,
        amount: u64,
    }

    // New functions to get user loans
    public fun get_user_loans(ctx: &mut TxContext): (vector<Loan>, vector<Loan>, vector<Loan>, vector<Loan>) {
        let user = tx_context::sender(ctx);
        let mut given_loans_unpaid = vector::empty<Loan>();
        let mut given_loans_paid = vector::empty<Loan>();
        let mut taken_loans_unpaid = vector::empty<Loan>();
        let mut taken_loans_paid = vector::empty<Loan>();

        let loan_list = borrow_global<LoanList>(user);
        for loan in &loan_list.loans {
            if loan.lender == user {
                if loan.repaid {
                    vector::push_back(&mut given_loans_paid, loan);
                } else {
                    vector::push_back(&mut given_loans_unpaid, loan);
                }
            } else if loan.borrower == user {
                if loan.repaid {
                    vector::push_back(&mut taken_loans_paid, loan);
                } else {
                    vector::push_back(&mut taken_loans_unpaid, loan);
                }
            }
        }

        (given_loans_unpaid, given_loans_paid, taken_loans_unpaid, taken_loans_paid)
    }

    // Reputation functions
    public fun add_star(user: address) {
        let reputation = borrow_global_mut<Reputation>(user);
        reputation.stars += 1;
    }

    public fun add_review(user: address, review: vector<u8>, ctx: &mut TxContext) {
        let reputation = borrow_global_mut<Reputation>(user);
        vector::push_back(&mut reputation.reviews, review);
    }

    public fun get_reputation(user: address, ctx: &mut TxContext): (u64, vector<vector<u8>>) {
        let reputation = borrow_global<Reputation>(user);
        (reputation.stars, reputation.reviews)
    }

    // Helper function to find loan index by id
    fun find_loan_index_by_id(loans: &vector<Loan>, loan_id: UID): u64 {
        let index = 0;
        for i in 0..vector::length(loans) {
            let loan = &loans[i];
            if loan.id == loan_id {
                index = i;
                break;
            }
        }
        index
    }
}
