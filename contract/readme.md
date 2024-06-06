# Peer-to-Peer Lending Smart Contract

This module facilitates a peer-to-peer lending platform on the Sui blockchain. Users can lend and borrow SUI tokens, create and view loan offers, take and repay loans, and track their reputation based on their activity within the platform.

## Smart Contract Overview

The module defines the following primary structures:

- `Loan`: Represents a single loan with details about the lender, borrower, amount, due date, and repayment status.
- `LoanList`: Stores a list of loans for a user.
- `Reputation`: Tracks the reputation of a user, including their star rating and reviews.

### Functions

#### Initialize

```rust
public fun initialize(account: &signer, ctx: &mut TxContext)
```

Initializes the contract for a user by creating an empty `LoanList` and `Reputation` object.

#### Create Loan

```rust
public fun create_loan(account: &signer, amount: u64, due_date: u64, ctx: &mut TxContext)
```

Creates a new loan offer with the specified amount and due date. The loan is added to the lender's `LoanList`.

#### View Available Loans

```rust
public fun view_available_loans(ctx: &mut TxContext): vector<Loan>
```

Returns a list of available loans that have not been taken by a borrower.

#### Take Loan

```rust
public fun take_loan(account: &signer, lender: address, loan_id: UID, ctx: &mut TxContext)
```

Allows a borrower to take a loan from a specific lender. The loan's borrower field is updated, and the loan amount is transferred to the borrower.

#### Repay Loan

```rust
public fun repay_loan(account: &signer, lender: address, loan_id: UID, ctx: &mut TxContext)
```

Allows a borrower to repay a loan. The loan's repayment status is updated, and the loan amount is transferred back to the lender. A `LoanRepaidEvent` is emitted, and the borrower’s reputation is increased.

#### Get User Loans

```rust
public fun get_user_loans(ctx: &mut TxContext): (vector<Loan>, vector<Loan>, vector<Loan>, vector<Loan>)
```

Returns four lists of loans for the user: given loans unpaid, given loans paid, taken loans unpaid, and taken loans paid.

#### Reputation Management

```rust
public fun add_star(user: address)
public fun add_review(user: address, review: vector<u8>, ctx: &mut TxContext)
public fun get_reputation(user: address, ctx: &mut TxContext): (u64, vector<vector<u8>>)
```

Functions to manage and query user reputation. Users can receive stars for timely repayments and add reviews to each other’s profiles.

## Usage

### Setting Up

1. **Initialize the contract for a user:**

   Call `initialize` to set up the contract for the user's account.

   ```rust
   initialize(account, ctx);
   ```

### Creating and Managing Loans

2. **Create a loan offer:**

   Call `create_loan` with the desired amount and due date.

   ```rust
   create_loan(account, 1000, 1700000000, ctx);  // Amount: 1000 SUI, Due Date: 1700000000 (timestamp)
   ```

3. **View available loans:**

   Call `view_available_loans` to get a list of loans that are available for borrowing.

   ```rust
   let loans = view_available_loans(ctx);
   ```

4. **Take a loan:**

   Call `take_loan` with the lender's address and the loan ID.

   ```rust
   take_loan(account, lender_address, loan_id, ctx);
   ```

5. **Repay a loan:**

   Call `repay_loan` with the lender's address and the loan ID.

   ```rust
   repay_loan(account, lender_address, loan_id, ctx);
   ```

### Tracking Loans and Reputation

6. **Get user loans:**

   Call `get_user_loans` to retrieve the lists of given and taken loans, both unpaid and paid.

   ```rust
   let (given_unpaid, given_paid, taken_unpaid, taken_paid) = get_user_loans(ctx);
   ```

7. **Add a review and get reputation:**

   Call `add_review` to add a review for a user and `get_reputation` to retrieve a user's reputation details.

   ```rust
   add_review(user_address, review_text, ctx);
   let (stars, reviews) = get_reputation(user_address, ctx);
   ```

## Conclusion

This module provides a robust framework for peer-to-peer lending on the Sui blockchain. Users can create loan offers, borrow funds, repay loans, and build their reputations based on their activities. By following the usage instructions, users can effectively participate in and benefit from the lending platform.

For further details and in-depth explanations of the functions and structures, refer to the module source code.
