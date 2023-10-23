(namespace "free")

(define-keyset "free.academy-token-keyset" (read-keyset "academy-token-keyset"))

(module academy-token GOVERNANCE

    (defcap GOVERNANCE()
        @doc "Give the admin full access to call and upgrade the module"
        (enforce-keyset "free.academy-token-keyset")
    )
    
    ;; table schema
    (defschema academy-token-schema
        @doc "Table holding the academy-token data"
        guard:guard
        balance:decimal)
    
    (deftable academy-token-table:{academy-token-schema})

    (implements fungible-v2)

    (defun create-account:string(account:string guard:guard)
        @doc "Create an account with a given guard"
        (insert academy-token-table account {
            "balance": 0.0,
            "guard": guard
        })
    )

    (defun rotate:string(account:string new-guard:guard)
        (with-read academy-token-table account
            {"guard":= current-guard}
            (enforce-guard current-guard) 
            (enforce-guard new-guard)
            (update academy-token-table account 
                {"guard": new-guard}))
    )

    (defun TRANSFER-mgr:decimal(managed:decimal requested:decimal)
            (let ((new-balance:decimal (- managed requested)))
                ;  (enforce-unit requested)
                (enforce (>= new-balance 0.0) "Insufficient funds")        
            new-balance))
    
    (defun enforce-unit:bool(amount:decimal)
        @doc "Enforce that the amount is a valid unit"
        (enforce (= (floor amount DECIMALS) amount) "Amount provied is too precise"))

    (defconst DECIMALS 14 
        "Specifies the minimum denomination for token transactions")

    (defcap TRANSFER:bool(sender:string receiver:string amount:decimal)
        @doc "Capability to perform transfer between two accounts"
        (enforce (not (= sender receiver)) "Cannot transfer to self")
        (enforce-unit amount)
        (enforce (> amount 0) "Amount must be positive")
        (compose-capability CANDEBIT)
        (compose-capability CANCREDIT))

    (defun transfer-create:string (sender:string receiver:string receiver-guard:guard amount:decimal)
        @doc "Transfer tokens from one account to another"
        ;  @model [
        ;      (property (conserves-mass amount))
        ;      (property (valid-account-id sender))
        ;      (property (valid-account-id receiver)) ]
        (with-capability (TRANSFER sender receiver amount)
            (debit sender amount)
            (credit receiver receiver-guard amount)))

    (defun transfer:string(sender:string receiver:string amount:decimal)
        @doc "Transfer tokens from one account to another"
        ;  @model [
        ;  (property (conserves-mass amount))
        ;  (property (valid-account-id sender))
        ;  (property (valid-account-id receiver)) ]
        (with-read academy-token-table receiver
            { "guard":= receiver-guard }
            (transfer-create sender receiver receiver-guard amount)))

    (defun enforce-account-id(account:string guard:guard) true)

    (defcap CANDEBIT(account:string)
        @doc "Allows the account to send tokens"
        (enforce-guard (at 'guard (read academy-token-table account))))

    (defcap CANCREDIT(account:string)
        (with-read academy-token-table account {
            "guard":= guard
        }
        (enforce-account-id account guard)))
)

(create-table academy-token-table)


