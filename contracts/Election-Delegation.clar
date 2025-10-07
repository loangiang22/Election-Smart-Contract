(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-operation (err u111))
(define-constant err-delegation-loop (err u112))

(define-map delegations
  { election-id: uint, delegator: principal }
  { 
    proxy: principal,
    delegated-at: uint,
    is-active: bool,
    delegation-depth: uint
  }
)

(define-map delegation-count
  { election-id: uint, proxy: principal }
  { count: uint }
)

(define-map delegation-chain
  { election-id: uint, proxy: principal, delegator: principal }
  { chain-position: uint }
)

(define-public (delegate-voting-power (election-id uint) (proxy principal))
  (let
    (
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
      (existing-delegation (map-get? delegations { election-id: election-id, delegator: tx-sender }))
      (proxy-delegation (map-get? delegations { election-id: election-id, delegator: proxy }))
      (current-count (default-to u0 (get count (map-get? delegation-count { election-id: election-id, proxy: proxy }))))
    )
    (asserts! (not (is-eq tx-sender proxy)) err-invalid-operation)
    (asserts! (< stacks-block-height (get start-block election)) err-invalid-operation)
    (asserts! (is-none existing-delegation) err-already-exists)
    (asserts! (is-none proxy-delegation) err-delegation-loop)
    (asserts! (not (contract-call? .Election-Smart-Contract has-voted election-id tx-sender)) err-invalid-operation)
    
    (map-set delegations
      { election-id: election-id, delegator: tx-sender }
      {
        proxy: proxy,
        delegated-at: stacks-block-height,
        is-active: true,
        delegation-depth: u1
      }
    )
    (map-set delegation-count
      { election-id: election-id, proxy: proxy }
      { count: (+ current-count u1) }
    )
    (ok true)
  )
)

(define-public (revoke-delegation (election-id uint))
  (let
    (
      (delegation (unwrap! (map-get? delegations { election-id: election-id, delegator: tx-sender }) err-not-found))
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
      (proxy (get proxy delegation))
      (current-count (default-to u1 (get count (map-get? delegation-count { election-id: election-id, proxy: proxy }))))
    )
    (asserts! (get is-active delegation) err-invalid-operation)
    (asserts! (< stacks-block-height (get end-block election)) err-invalid-operation)
    
    (map-set delegations
      { election-id: election-id, delegator: tx-sender }
      (merge delegation { is-active: false })
    )
    (map-set delegation-count
      { election-id: election-id, proxy: proxy }
      { count: (- current-count u1) }
    )
    (ok true)
  )
)

(define-read-only (get-delegation (election-id uint) (delegator principal))
  (map-get? delegations { election-id: election-id, delegator: delegator })
)

(define-read-only (get-proxy-power (election-id uint) (proxy principal))
  (default-to u0 (get count (map-get? delegation-count { election-id: election-id, proxy: proxy })))
)

(define-read-only (has-delegated (election-id uint) (voter principal))
  (match (map-get? delegations { election-id: election-id, delegator: voter })
    delegation (get is-active delegation)
    false
  )
)

(define-read-only (get-delegation-stats (election-id uint) (proxy principal))
  (ok {
    proxy: proxy,
    delegations-received: (get-proxy-power election-id proxy),
    total-voting-power: (+ u1 (get-proxy-power election-id proxy))
  })
)

