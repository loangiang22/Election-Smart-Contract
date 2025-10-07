(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))

(define-data-var audit-entry-counter uint u0)

(define-map audit-entries
  { entry-id: uint }
  {
    election-id: uint,
    action-type: (string-ascii 20),
    actor: principal,
    block-height: uint,
    data-hash: (buff 32),
    timestamp: uint
  }
)

(define-map election-audit-count
  { election-id: uint }
  { count: uint }
)

(define-public (log-election-created (election-id uint) (creator principal))
  (let
    (
      (entry-id (+ (var-get audit-entry-counter) u1))
      (data-string (concat "created-" (int-to-ascii election-id)))
      (data-hash (sha256 (concat (unwrap-panic (to-consensus-buff? creator)) (unwrap-panic (to-consensus-buff? data-string)))))
    )
    (map-set audit-entries
      { entry-id: entry-id }
      {
        election-id: election-id,
        action-type: "election-created",
        actor: creator,
        block-height: stacks-block-height,
        data-hash: data-hash,
        timestamp: stacks-block-height
      }
    )
    (update-election-count election-id)
    (var-set audit-entry-counter entry-id)
    (ok entry-id)
  )
)

(define-public (log-candidate-added (election-id uint) (candidate-id uint) (creator principal))
  (let
    (
      (entry-id (+ (var-get audit-entry-counter) u1))
      (data-string (concat "candidate-" (int-to-ascii candidate-id)))
      (data-hash (sha256 (concat (unwrap-panic (to-consensus-buff? creator)) (unwrap-panic (to-consensus-buff? data-string)))))
    )
    (map-set audit-entries
      { entry-id: entry-id }
      {
        election-id: election-id,
        action-type: "candidate-added",
        actor: creator,
        block-height: stacks-block-height,
        data-hash: data-hash,
        timestamp: stacks-block-height
      }
    )
    (update-election-count election-id)
    (var-set audit-entry-counter entry-id)
    (ok entry-id)
  )
)

(define-public (log-vote-cast (election-id uint) (voter principal))
  (let
    (
      (entry-id (+ (var-get audit-entry-counter) u1))
      (data-string "vote-cast")
      (data-hash (sha256 (concat (unwrap-panic (to-consensus-buff? voter)) (unwrap-panic (to-consensus-buff? data-string)))))
    )
    (map-set audit-entries
      { entry-id: entry-id }
      {
        election-id: election-id,
        action-type: "vote-cast",
        actor: voter,
        block-height: stacks-block-height,
        data-hash: data-hash,
        timestamp: stacks-block-height
      }
    )
    (update-election-count election-id)
    (var-set audit-entry-counter entry-id)
    (ok entry-id)
  )
)

(define-private (update-election-count (election-id uint))
  (let
    (
      (current-count (default-to u0 (get count (map-get? election-audit-count { election-id: election-id }))))
    )
    (map-set election-audit-count
      { election-id: election-id }
      { count: (+ current-count u1) }
    )
  )
)

(define-read-only (get-audit-entry (entry-id uint))
  (map-get? audit-entries { entry-id: entry-id })
)

(define-read-only (get-election-audit-count (election-id uint))
  (default-to u0 (get count (map-get? election-audit-count { election-id: election-id })))
)

(define-read-only (get-total-audit-entries)
  (var-get audit-entry-counter)
)

(define-read-only (verify-audit-chain (election-id uint))
  (let
    (
      (audit-count (get-election-audit-count election-id))
    )
    (ok { election-id: election-id, total-entries: audit-count, verified: true })
  )
)