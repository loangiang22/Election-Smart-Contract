(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-time (err u104))
(define-constant err-election-not-active (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-not-registered (err u107))
(define-constant err-election-ended (err u108))
(define-constant err-invalid-candidate (err u109))

(define-data-var election-counter uint u0)

(define-map elections
  { election-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    start-block: uint,
    end-block: uint,
    is-active: bool,
    total-votes: uint,
    registration-required: bool
  }
)

(define-map candidates
  { election-id: uint, candidate-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    vote-count: uint
  }
)

(define-map candidate-counter
  { election-id: uint }
  { count: uint }
)

(define-map registered-voters
  { election-id: uint, voter: principal }
  { registered-at: uint, is-verified: bool }
)

(define-map votes
  { election-id: uint, voter: principal }
  { candidate-id: uint, voted-at: uint }
)

(define-map voter-verification
  { election-id: uint, voter: principal }
  { verification-hash: (buff 32) }
)

(define-public (create-election 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (start-block uint)
  (end-block uint)
  (registration-required bool))
  (let
    (
      (election-id (+ (var-get election-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (> start-block current-block) err-invalid-time)
    (asserts! (> end-block start-block) err-invalid-time)
    (map-set elections
      { election-id: election-id }
      {
        title: title,
        description: description,
        creator: tx-sender,
        start-block: start-block,
        end-block: end-block,
        is-active: true,
        total-votes: u0,
        registration-required: registration-required
      }
    )
    (map-set candidate-counter
      { election-id: election-id }
      { count: u0 }
    )
    (var-set election-counter election-id)
    (ok election-id)
  )
)

(define-public (add-candidate
  (election-id uint)
  (name (string-ascii 50))
  (description (string-ascii 200)))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) err-not-found))
      (current-count (default-to u0 (get count (map-get? candidate-counter { election-id: election-id }))))
      (candidate-id (+ current-count u1))
    )
    (asserts! (is-eq (get creator election) tx-sender) err-unauthorized)
    (asserts! (get is-active election) err-election-not-active)
    (asserts! (< stacks-block-height (get start-block election)) err-invalid-time)
    (map-set candidates
      { election-id: election-id, candidate-id: candidate-id }
      {
        name: name,
        description: description,
        vote-count: u0
      }
    )
    (map-set candidate-counter
      { election-id: election-id }
      { count: candidate-id }
    )
    (ok candidate-id)
  )
)

(define-public (register-voter (election-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) err-not-found))
    )
    (asserts! (get registration-required election) err-unauthorized)
    (asserts! (get is-active election) err-election-not-active)
    (asserts! (< stacks-block-height (get start-block election)) err-invalid-time)
    (asserts! (is-none (map-get? registered-voters { election-id: election-id, voter: tx-sender })) err-already-exists)
    (map-set registered-voters
      { election-id: election-id, voter: tx-sender }
      { registered-at: stacks-block-height, is-verified: false }
    )
    (ok true)
  )
)

(define-public (verify-voter (election-id uint) (voter principal))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) err-not-found))
      (registration (unwrap! (map-get? registered-voters { election-id: election-id, voter: voter }) err-not-found))
    )
    (asserts! (is-eq (get creator election) tx-sender) err-unauthorized)
    (asserts! (get is-active election) err-election-not-active)
    (map-set registered-voters
      { election-id: election-id, voter: voter }
      { registered-at: (get registered-at registration), is-verified: true }
    )
    (ok true)
  )
)

(define-public (cast-vote (election-id uint) (candidate-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) err-not-found))
      (candidate (unwrap! (map-get? candidates { election-id: election-id, candidate-id: candidate-id }) err-invalid-candidate))
      (current-block stacks-block-height)
    )
    (asserts! (get is-active election) err-election-not-active)
    (asserts! (>= current-block (get start-block election)) err-invalid-time)
    (asserts! (< current-block (get end-block election)) err-election-ended)
    (asserts! (is-none (map-get? votes { election-id: election-id, voter: tx-sender })) err-already-voted)
    
    (if (get registration-required election)
      (let
        (
          (registration (unwrap! (map-get? registered-voters { election-id: election-id, voter: tx-sender }) err-not-registered))
        )
        (asserts! (get is-verified registration) err-unauthorized)
        true
      )
      true
    )
    
    (map-set votes
      { election-id: election-id, voter: tx-sender }
      { candidate-id: candidate-id, voted-at: current-block }
    )
    
    (map-set candidates
      { election-id: election-id, candidate-id: candidate-id }
      {
        name: (get name candidate),
        description: (get description candidate),
        vote-count: (+ (get vote-count candidate) u1)
      }
    )
    
    (map-set elections
      { election-id: election-id }
      {
        title: (get title election),
        description: (get description election),
        creator: (get creator election),
        start-block: (get start-block election),
        end-block: (get end-block election),
        is-active: (get is-active election),
        total-votes: (+ (get total-votes election) u1),
        registration-required: (get registration-required election)
      }
    )
    
    (ok true)
  )
)

(define-public (end-election (election-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) err-not-found))
    )
    (asserts! (is-eq (get creator election) tx-sender) err-unauthorized)
    (asserts! (get is-active election) err-election-not-active)
    (map-set elections
      { election-id: election-id }
      {
        title: (get title election),
        description: (get description election),
        creator: (get creator election),
        start-block: (get start-block election),
        end-block: (get end-block election),
        is-active: false,
        total-votes: (get total-votes election),
        registration-required: (get registration-required election)
      }
    )
    (ok true)
  )
)

(define-read-only (get-election (election-id uint))
  (map-get? elections { election-id: election-id })
)

(define-read-only (get-candidate (election-id uint) (candidate-id uint))
  (map-get? candidates { election-id: election-id, candidate-id: candidate-id })
)

(define-read-only (get-candidate-count (election-id uint))
  (default-to u0 (get count (map-get? candidate-counter { election-id: election-id })))
)

(define-read-only (get-voter-registration (election-id uint) (voter principal))
  (map-get? registered-voters { election-id: election-id, voter: voter })
)

(define-read-only (has-voted (election-id uint) (voter principal))
  (is-some (map-get? votes { election-id: election-id, voter: voter }))
)

(define-read-only (get-election-count)
  (var-get election-counter)
)

(define-read-only (is-election-active (election-id uint))
  (match (map-get? elections { election-id: election-id })
    election (and 
      (get is-active election)
      (>= stacks-block-height (get start-block election))
      (< stacks-block-height (get end-block election))
    )
    false
  )
)

(define-read-only (get-election-results (election-id uint))
  (let
    (
      (election (unwrap! (map-get? elections { election-id: election-id }) err-not-found))
      (candidate-count (get-candidate-count election-id))
    )
    (ok {
      election: election,
      candidate-count: candidate-count
    })
  )
)
