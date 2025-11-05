(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u113))
(define-constant err-already-claimed (err u114))
(define-constant err-threshold-not-met (err u115))

(define-map reward-pools
  { election-id: uint }
  {
    total-pool: uint,
    reward-per-voter: uint,
    turnout-threshold: uint,
    early-voter-bonus: uint,
    early-voter-deadline: uint,
    funded-by: principal,
    pool-active: bool
  }
)

(define-map voter-rewards
  { election-id: uint, voter: principal }
  {
    base-reward: uint,
    bonus-reward: uint,
    claimed-at: uint,
    is-claimed: bool
  }
)

(define-map reward-stats
  { election-id: uint }
  {
    total-claimed: uint,
    total-voters-rewarded: uint,
    remaining-pool: uint
  }
)

(define-public (create-reward-pool 
  (election-id uint)
  (reward-per-voter uint)
  (turnout-threshold uint)
  (early-voter-bonus uint)
  (early-voter-deadline uint))
  (let
    (
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
      (estimated-pool (* reward-per-voter turnout-threshold))
    )
    (asserts! (is-eq (get creator election) tx-sender) err-unauthorized)
    (try! (stx-transfer? estimated-pool tx-sender (as-contract tx-sender)))
    (map-set reward-pools
      { election-id: election-id }
      {
        total-pool: estimated-pool,
        reward-per-voter: reward-per-voter,
        turnout-threshold: turnout-threshold,
        early-voter-bonus: early-voter-bonus,
        early-voter-deadline: early-voter-deadline,
        funded-by: tx-sender,
        pool-active: true
      }
    )
    (map-set reward-stats
      { election-id: election-id }
      { total-claimed: u0, total-voters-rewarded: u0, remaining-pool: estimated-pool }
    )
    (ok true)
  )
)

(define-public (claim-voter-reward (election-id uint))
  (let
    (
      (pool (unwrap! (map-get? reward-pools { election-id: election-id }) err-not-found))
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
      (stats (unwrap! (map-get? reward-stats { election-id: election-id }) err-not-found))
      (has-voted (contract-call? .Election-Smart-Contract has-voted election-id tx-sender))
      (is-early (< stacks-block-height (get early-voter-deadline pool)))
      (base-reward (get reward-per-voter pool))
      (bonus (if is-early (get early-voter-bonus pool) u0))
      (total-reward (+ base-reward bonus))
    )
    (asserts! has-voted err-unauthorized)
    (asserts! (get pool-active pool) err-unauthorized)
    (asserts! (>= (get total-votes election) (get turnout-threshold pool)) err-threshold-not-met)
    (asserts! (is-none (map-get? voter-rewards { election-id: election-id, voter: tx-sender })) err-already-claimed)
    (asserts! (>= (get remaining-pool stats) total-reward) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? total-reward tx-sender tx-sender)))
    
    (map-set voter-rewards
      { election-id: election-id, voter: tx-sender }
      { base-reward: base-reward, bonus-reward: bonus, claimed-at: stacks-block-height, is-claimed: true }
    )
    (map-set reward-stats
      { election-id: election-id }
      { 
        total-claimed: (+ (get total-claimed stats) total-reward),
        total-voters-rewarded: (+ (get total-voters-rewarded stats) u1),
        remaining-pool: (- (get remaining-pool stats) total-reward)
      }
    )
    (ok total-reward)
  )
)

(define-read-only (get-reward-pool (election-id uint))
  (map-get? reward-pools { election-id: election-id })
)

(define-read-only (get-voter-reward-info (election-id uint) (voter principal))
  (map-get? voter-rewards { election-id: election-id, voter: voter })
)

(define-read-only (get-reward-statistics (election-id uint))
  (map-get? reward-stats { election-id: election-id })
)

(define-read-only (calculate-potential-reward (election-id uint))
  (match (map-get? reward-pools { election-id: election-id })
    pool
      (let
        (
          (is-early (< stacks-block-height (get early-voter-deadline pool)))
          (base (get reward-per-voter pool))
          (bonus (if is-early (get early-voter-bonus pool) u0))
        )
        (ok (+ base bonus))
      )
    err-not-found
  )
)
