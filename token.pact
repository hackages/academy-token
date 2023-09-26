(namespace 'free)

(define-keyset "free.academy-token-keyset" (read-keyset 'academy-token-keyset))

(module academy-token "free.academy-token-keyset"
  @doc
    "Kadena Academy Token smart contract"
  @model [
    (defproperty conserves-mass (amount:decimal)
      (= (column-delta academy-token-table 'balance) 0.0))
    (defproperty valid-account-id(account-id:string)
      (and
        (>= (length account-id) ACCOUNT_MIN_LENGTH)
        (<= (length account-id) ACCOUNT_MAX_LENGTH))) ]

  (implements fungible-v2)

  ; -----------------
  ; Schema
  ; -----------------
  (defschema academy-token-schema
    @doc "Table holding the academy-token"
    balance:decimal
    guard:guard
  )
  (deftable academy-token-table:{academy-token-schema})


  (defschema crosschain-schema
    @doc "Schema holding data for a crosschain transfer"
    receiver:string
    receiver-guard:guard
    amount:decimal)

  (defschema safe-crosschain-schema
    @doc "Schema holding data for a crosschain transfer"
    receiver:string
    sender:string
    expiration:integer
    amount:decimal)

  ; -----------------
  ; Constants
  ; -----------------
  (defconst BURN_START_DATE (time "2023-01-01T00:00:00Z")
    "The date when the coins start getting burned")
  (defconst MAX_TOKENS 100000.0
    "The amount of coins to start with")
  (defconst ACCOUNT_MIN_LENGTH 4
    "The minimum length of an account id")
  (defconst ACCOUNT_MAX_LENGTH 256
    "The maximum length of an account id")
  (defconst ACCOUNT_CHAR_SET CHARSET_LATIN1
    "The character set that is allowed in an account id")
  (defconst ACCOUNT_ID_PROHIBITED_CHARACTER "$"
    "This is a prohibited character because it is used to separate the account id from the chain id")
  (defconst DECIMALS 1.0
    " Specifies the minimum denomination for token transactions. ")
  ; -----------------
  ; Capabilities
  ; -----------------
  (defcap GOVERNANCE()
    @doc "Give the admin full access to call and upgrade the module."
    (enforce-keyset "free.academy-token-keyset"))

  (defcap DEBIT(account:string)
    @doc "Allows the account to spend tokens"
    (enforce-guard (at 'guard (read academy-token-table account))))

  (defcap CREDIT(account:string)
    @doc "Allows the account to receive tokens"
    (with-read academy-token-table account { "guard" := guard }
      (enforce-account-id account guard)))

  (defcap TRANSFER:bool(sender:string receiver:string amount:decimal)
    @doc "Capability to perform transfer between two accounts."
    @model [ (property (valid-account-id sender))
             (property (valid-account-id receiver)) ]
    @managed amount TRANSFER-mgr

    (enforce-unit amount)
    (enforce (> amount 0.0) "Amount must be positive"))

  ; -----------------
  ; Utility functions
  ; -----------------
  ;  (defun get-burned-tokens:integer()
  ;    (floor (/
  ;      (diff-time (at "block-time" (chain-data)) BURN_START_DATE)
  ;      (* (* 60 60) 24))))

  ;  (defun get-remaining-tokens:decimal()
  ;    @doc "Get the remaining tokens that can be minted \
  ;          \Update the new balance with the burned tokens deducted"
  ;    (with-capability (GOVERNANCE)
  ;      (with-read academy-token-table "keoy" {
  ;        "balance":= balance
  ;      }
  ;        (let ((new-balance:decimal (- balance (get-burned-tokens))))
  ;          ; update the balance with the burned tokens deducted
  ;          new-balance
  ;        )
  ;      )))

  (defun check-balance()
    (with-capability (GOVERNANCE)
      (read academy-token-table "academy-token")))

  (defun enforce-account-id(account-id:string guard:guard)
    @doc "Enforce that the account id is valid"
    (enforce (is-charset ACCOUNT_CHAR_SET account-id)
      (format "Account id contains characters outside of this charset {}" [ACCOUNT_CHAR_SET]))
    (enforce (not (contains ACCOUNT_ID_PROHIBITED_CHARACTER account-id))
      (format "Account id contains prohibited characters {}" [ACCOUNT_ID_PROHIBITED_CHARACTER]))
    (enforce-account-length (length account-id))
    (enforce-account-protocol account-id guard))

  (defun enforce-account-length(account-length)
    (enforce (>= account-length ACCOUNT_MIN_LENGTH)
      (format "Account id is too short, must be at least {} characters" [ACCOUNT_MIN_LENGTH]))
    (enforce (<= account-length ACCOUNT_MAX_LENGTH)
      (format "Account id is too long, must be at most {} characters" [ACCOUNT_MAX_LENGTH])))

  (defun enforce-account-protocol(account-id:string guard:guard)
    @doc "Enforce that the account id is valid"
    ; if account id contains no a colon on the second character, continue
    (enforce-one "Should either contain no protocol or adhere to the single key account protocol" [
      (enforce (not (contains ":" (take 2 account-id))) "Account id contains no protocol")
      (enforce
        (and
          (= "k" (take 1 account-id))
          (= (format "{}" [guard])
            (format "KeySet {keys: [{}],pred: keys-all}" [(drop 2 account-id)])))
        "Single key account violation")]))

  ; -----------------
  ; v2-fungible functions
  ; -----------------
  (defun get-balance:decimal(account:string)
    @doc "Get the balance of an account"
    (at "balance" (read academy-token-table account ["balance"])))

  (defun details:object{fungible-v2.account-details}(account:string)
    @doc "Get the account information"
    (with-read academy-token-table account
      { "balance" := balance
      , "guard"   := guard }
      { "account" : account
      , "balance" : balance
      , "guard"   : guard }))

  (defun create-account:string(account:string guard:guard)
    @doc "Create an account with a given guard"
    @model [ (property (valid-account-id account)) ]
    (enforce-account-id account guard)

    (insert academy-token-table account
      { "balance" : 0.0
      , "guard"   : guard })
    "Account created")

  (defun rotate:string(account:string new-guard:guard)
    (with-read academy-token-table account
      { "guard":= old-guard }

      (enforce-guard old-guard)
      (enforce-guard new-guard)
      (update academy-token-table account
        { "guard": new-guard })))

  (defun precision:integer()
    @doc "Provide the precision of the fungible token to the v2-fungible interface"
    DECIMALS)

  (defun enforce-unit:bool(amount:decimal)
    @doc "Enforce that the amount is a valid unit"
    (enforce (= (floor amount DECIMALS) amount) "Amount provided is too precise"))

  (defun TRANSFER-mgr:decimal(managed:decimal requested:decimal)
    (let ((new-balance:decimal (- managed requested)))
      ; (enforce-unit requested)
      (enforce (>= new-balance 0.0) "Insufficient funds")
      new-balance))

  (defun transfer:string(sender:string receiver:string amount:decimal)
    @doc "Transfer tokens from one account to another"
    @model [
      (property (conserves-mass amount))
      (property (valid-account-id sender))
      (property (valid-account-id receiver)) ]
      (with-read academy-token-table receiver
        { "guard":= receiver-guard }
        (transfer-create sender receiver receiver-guard amount)))

  (defun direct-safe-transfer:string(sender:string receiver:string amount:decimal)
    (with-read academy-token-table receiver
      { "guard":= receiver-guard }
      (enforce-guard receiver-guard)
      (transfer-create sender receiver receiver-guard amount)))

  (defun safe-transfer:string(sender:string receiver:string amount:decimal expiration:integer)
    @doc "Transfer tokens from one account to another"
    @model [
      (property (valid-account-id sender))
      (property (valid-account-id receiver)) ]
      (debit sender amount)
      )

  (defun transfer-create:string (sender:string receiver:string receiver-guard:guard amount:decimal)
    @doc "Transfer tokens from one account to another"
    @model [
      (property (conserves-mass amount))
      (property (valid-account-id sender))
      (property (valid-account-id receiver)) ]
    (with-capability (TRANSFER sender receiver amount)
      (debit sender amount)
      (credit receiver receiver-guard amount)))

  (defun debit:string(account:string amount:decimal)
    @doc "Debit an account"
    @model [
      (property (> amount 0.0))
      (property (valid-account-id account))
    ]
    (enforce (>= amount 0.0) "Amount must be positive")
    (with-read academy-token-table account
      { "balance":= balance, "guard":= guard }
      (enforce-account-id account guard)
      (update academy-token-table account
        { "balance": (- balance amount) })))

  (defun credit:string(account:string guard:guard amount:decimal)
    (with-read academy-token-table account
      { "balance":= balance }
      (update academy-token-table account
        { "balance": (+ balance amount) })))

  ; -----------------
  ; v2 fungible cross chain steps
  ; -----------------
  (defpact transfer-crosschain:string(sender:string receiver:string receiver-guard:guard target-chain:string amount:decimal)
    @model [
      (property (> amount 0.0))
      (property (valid-account-id sender))
      (property (valid-account-id receiver))
    ]

    (step
      (with-capability (DEBIT sender)
        (enforce (!= target-chain "") "Target chain must be specified")
        (enforce (!= (at 'chain-id (chain-data)) target-chain) "Target chain must be different from current chain")
        (enforce (>= amount 0.0) "Amount must be positive")
        (enforce-unit amount)

        (debit sender amount)
        (let
         ((crosschain-details:object{crosschain-schema}
          { "receiver"       : receiver
          , "receiver-guard" : receiver-guard
          , "amount"         : amount
          }))
          (yield crosschain-details target-chain))))
    (step
      (resume
        { "receiver"       := receiver
        , "receiver-guard" := receiver-guard
        , "amount"         := amount }
      (with-capability (CREDIT receiver)
        (credit receiver receiver-guard amount)))))

  (defpact safe-transfer-crosschain(sender:string receiver:string target-chain:string amount:decimal expiration:integer)
    (step
      (with-capability (DEBIT sender)
        (enforce (!= target-chain "") "Target chain must be specified")
        (enforce (!= (at 'chain-id (chain-data)) target-chain) "Target chain must be different from current chain")
        (enforce (>= amount 0.0) "Amount must be positive")
        (enforce-unit amount)

        (debit sender amount)
        (let
         ((crosschain-details:object{safe-crosschain-schema}
          { "sender"         : sender
          , "receiver"       : receiver
          , "amount"         : amount
          , "expiration"     : expiration
          }))
          (yield crosschain-details target-chain)))))

  ; -----------------
  ; Admin functions
  ; -----------------
  (defun init(guard:guard)
    @doc "Initialize the academy-token token contract"

    (with-capability (GOVERNANCE)
      (insert academy-token-table "academy-token"
      { "balance" : MAX_TOKENS
      , "guard"   : guard }))
  )

  (defun get-remaining-tokens:decimal()
    @doc "Get the remaining tokens that can be minted \
          \Update the new balance with the burned tokens deducted"
    100000.0)

  (defun grant-tokens(user:string guard:guard amount:decimal)
    @doc "Grant academy-token tokens to a user"

    (with-capability (GOVERNANCE)
      (with-default-read academy-token-table user
        { "balance" : -1.0
        , "guard"   : guard }
        { "balance" := balance
        , "guard"   := saved-guard }
          (enforce (= saved-guard guard) "Guard mismatch")

          (let ((remaining-tokens:decimal (get-remaining-tokens)))
            (enforce (>= remaining-tokens amount) "Not enough tokens remaining")

            (let ((is-new (= balance -1.0)))
              ; Use write as it acts as an upsert
              ; TODO - implement account name verification
              ; see https://github.com/Thanos420NoScope/Anedak/blob/master/Contracts/anedak.pact#L267
              (write academy-token-table user
                { "balance" : (if is-new amount (+ balance amount))
                , "guard"   : saved-guard })
              (update academy-token-table "academy-token"
                { "balance" : (- (get-balance "academy-token") amount) })
              (read academy-token-table user))))))
)

; Initialize tables
(create-table academy-token-table)