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
    use sui::event::Event;
    use sui::address;
    use std::vector;

    const FLOAT_SCALING: u64 = 1_000_000_000;

    struct Loan has copy, drop, store {
        id: UID,
        lender: address,
        borrower: address,
        amount: u64,
        interest_rate: u64, // Interest rate as a percentage scaled by FLOAT_SCALING
        due_date: u64,
        repaid: bool,
    }

    struct LoanRegistry has key, store {
        id: UID,
        loans: vector<Loan>,
    }

    struct UserReputation has key, store {
        id: UID,
        user: address,
        stars: u64,
        reviews: vector<vector<u8>>,
    }

    struct LoanRepaidEvent has drop {
        lender: address,
        borrower: address,
        amount: u64,
    }

    // Initializer
    public fun initialize(account: &signer, ctx: &mut TxContext) {
        transfer::share_object(
            LoanRegistry { id: UID::new(ctx), loans: vector::empty<Loan>() },
        );
        transfer::share_object(
            UserReputation { id: UID::new(ctx), user: sender(ctx), stars: 0, reviews: vector::empty<vector<u8>>() },
        );
    }

    // Create a new loan
    public fun create_loan(account: &signer, amount: u64, interest_rate: u64, due_date: u64, ctx: &mut TxContext) {
        let lender = sender(ctx);
        let loan = Loan { 
            id: UID::new(ctx),
            lender: lender,
            borrower: address::ZERO,
            amount: amount,
            interest_rate: interest_rate,
            due_date: due_date,
            repaid: false 
        };
        let loan_registry = borrow_global_mut<LoanRegistry>(lender);
        vector::push_back(&mut loan_registry.loans, loan);
    }

    // View available loans
    public fun view_available_loans(ctx: &mut TxContext): vector<Loan> {
        let loan_registry = borrow_global<LoanRegistry>(sender(ctx));
        let mut available_loans = vector::empty<Loan>();
        for loan in &loan_registry.loans {
            if loan.borrower == address::ZERO {
                vector::push_back(&mut available_loans, *loan);
            }
        }
        available_loans
    }

    // Take a loan
    public fun take_loan(account: &signer, lender: address, loan_id: UID, ctx: &mut TxContext) {
        let borrower = sender(ctx);
        let loan_registry = borrow_global_mut<LoanRegistry>(lender);
        let loan_index = find_loan_index_by_id(&loan_registry.loans, loan_id);
        assert!(loan_index.is_some(), 103); // Loan ID not found
        let loan = &mut loan_registry.loans[loan_index.unwrap()];
        assert!(loan.borrower == address::ZERO, 102); // Loan should be available
        loan.borrower = borrower;
        transfer::public_transfer(SUI::mint(loan.amount, ctx), borrower);
    }

    // Repay a loan
    public fun repay_loan(account: &signer, lender: address, loan_id: UID, ctx: &mut TxContext) {
        let borrower = sender(ctx);
        let loan_registry = borrow_global_mut<LoanRegistry>(lender);
        let loan_index = find_loan_index_by_id(&loan_registry.loans, loan_id);
        assert!(loan_index.is_some(), 103); // Loan ID not found
        let loan = &mut loan_registry.loans[loan_index.unwrap()];
        assert!(loan.borrower == borrower, 100); // Only the borrower can repay the loan
        assert!(!loan.repaid, 101); // Loan should not be already repaid

        let amount_due = loan.amount + calculate_interest(loan.amount, loan.interest_rate);
        transfer::public_transfer(SUI::mint(amount_due, ctx), lender);
        loan.repaid = true;

        Event::emit(LoanRepaidEvent { lender, borrower, amount: amount_due });
        add_star(borrower); // Add star to the borrower for timely repayment
    }

    // Get user loans
    public fun get_user_loans(ctx: &mut TxContext): (vector<Loan>, vector<Loan>, vector<Loan>, vector<Loan>) {
        let user = sender(ctx);
        let mut given_loans_unpaid = vector::empty<Loan>();
        let mut given_loans_paid = vector::empty<Loan>();
        let mut taken_loans_unpaid = vector::empty<Loan>();
        let mut taken_loans_paid = vector::empty<Loan>();

        let loan_registry = borrow_global<LoanRegistry>(user);
        for loan in &loan_registry.loans {
            if loan.lender == user {
                if loan.repaid {
                    vector::push_back(&mut given_loans_paid, *loan);
                } else {
                    vector::push_back(&mut given_loans_unpaid, *loan);
                }
            } else if loan.borrower == user {
                if loan.repaid {
                    vector::push_back(&mut taken_loans_paid, *loan);
                } else {
                    vector::push_back(&mut taken_loans_unpaid, *loan);
                }
            }
        }

        (given_loans_unpaid, given_loans_paid, taken_loans_unpaid, taken_loans_paid)
    }

    // Add a star to the user reputation
    public fun add_star(user: address) {
        let reputation = borrow_global_mut<UserReputation>(user);
        reputation.stars += 1;
    }

    // Add a review to the user reputation
    public fun add_review(user: address, review: vector<u8>, ctx: &mut TxContext) {
        let reputation = borrow_global_mut<UserReputation>(user);
        vector::push_back(&mut reputation.reviews, review);
    }

    // Get user reputation
    public fun get_reputation(user: address, ctx: &mut TxContext): (u64, vector<vector<u8>>) {
        let reputation = borrow_global<UserReputation>(user);
        (reputation.stars, reputation.reviews)
    }

    // Find loan index by ID
    fun find_loan_index_by_id(loans: &vector<Loan>, loan_id: UID): Option<u64> {
        for i in 0..vector::length(loans) {
            let loan = &loans[i];
            if loan.id == loan_id {
                return Option::some(i);
            }
        }
        Option::none()
    }

    // Calculate interest
    fun calculate_interest(amount: u64, interest_rate: u64): u64 {
        (amount * interest_rate) / FLOAT_SCALING
    }

    // Check due dates and apply penalties
    public fun check_due_dates(ctx: &mut TxContext) {
        let user = sender(ctx);
        let current_time = timestamp_ms(ctx);
        let loan_registry = borrow_global_mut<LoanRegistry>(user);
        for loan in &mut loan_registry.loans {
            if loan.due_date < current_time && !loan.repaid {
                penalize_borrower(loan.borrower);
                apply_late_fee(loan);
            }
        }
    }

    // Penalize borrower for late payment
    fun penalize_borrower(borrower: address) {
        let reputation = borrow_global_mut<UserReputation>(borrower);
        if reputation.stars > 0 {
            reputation.stars -= 1;
        }
    }

    // Apply late fee to the loan
    fun apply_late_fee(loan: &mut Loan) {
        let late_fee = loan.amount / 10; // 10% late fee
        loan.amount += late_fee;
    }

    // Handle loan repaid event
    public fun handle_loan_repaid_event(event: &LoanRepaidEvent) {
        // Notify lender
        notify_lender(event.lender, event.borrower, event.amount);

        // Update lender's reputation
        add_star(event.lender);
    }

    // Notify lender
    fun notify_lender(lender: address, borrower: address, amount: u64) {
        // Implementation for notifying the lender, e.g., sending a message
    }
}
