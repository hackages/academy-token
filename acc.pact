(module acc-testing GAP
    (defcap GAP() true)
    
    (defschema account
        @doc "user accounts with balances"
        @model [(invariant (>= balance 0))]
        
        balance:integer
        ks:keyset)
    
    (deftable accounts:{account})

    (defun transfer (from:string amount:integer)
        @doc "transfer money between accounts"
        @model [(property (row-enforced account 'ks from))]

        (with-read account from {'balance := from-bal, 'ks := from-ks}
            (with-read accounts to {'balance := to-bal }
                (enforce-keyset from-ks) 
                (enforce (>= from-bal amount) "Insufficient Funds")
                (update accounts from { 'balance': (- from-bal amount)})
                (update account to {'balance': (+ to-bal amount)})
            )
        )
    )
)

(create-table accounts)