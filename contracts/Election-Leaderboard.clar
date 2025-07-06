(define-constant err-not-found (err u101))
(define-constant err-division-by-zero (err u110))

(define-read-only (get-candidate-percentage (election-id uint) (candidate-id uint))
  (let
    (
      (candidate (unwrap! (contract-call? .Election-Smart-Contract get-candidate election-id candidate-id) err-not-found))
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
      (total-votes (get total-votes election))
      (candidate-votes (get vote-count candidate))
    )
    (if (is-eq total-votes u0)
      (ok u0)
      (ok (/ (* candidate-votes u100) total-votes))
    )
  )
)

(define-read-only (get-top-candidate (election-id uint))
  (let
    (
      (candidate-count (contract-call? .Election-Smart-Contract get-candidate-count election-id))
    )
    (fold find-highest-voted 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
      { election-id: election-id, max-votes: u0, winner-id: u0, candidate-count: candidate-count }
    )
  )
)

(define-private (find-highest-voted (candidate-id uint) (state { election-id: uint, max-votes: uint, winner-id: uint, candidate-count: uint }))
  (if (> candidate-id (get candidate-count state))
    state
    (match (contract-call? .Election-Smart-Contract get-candidate (get election-id state) candidate-id)
      candidate
        (let ((votes (get vote-count candidate)))
          (if (> votes (get max-votes state))
            { 
              election-id: (get election-id state),
              max-votes: votes,
              winner-id: candidate-id,
              candidate-count: (get candidate-count state)
            }
            state
          )
        )
      state
    )
  )
)

(define-read-only (get-election-stats (election-id uint))
  (let
    (
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
      (candidate-count (contract-call? .Election-Smart-Contract get-candidate-count election-id))
      (leader-info (get-top-candidate election-id))
      (total-votes (get total-votes election))
      (is-active (contract-call? .Election-Smart-Contract is-election-active election-id))
    )
    (ok {
      election-id: election-id,
      title: (get title election),
      total-votes: total-votes,
      candidate-count: candidate-count,
      leading-candidate: (get winner-id leader-info),
      leading-votes: (get max-votes leader-info),
      is-active: is-active,
      blocks-remaining: (if (> (get end-block election) stacks-block-height)
                          (- (get end-block election) stacks-block-height)
                          u0)
    })
  )
)

(define-read-only (get-leaderboard (election-id uint))
  (let
    (
      (candidate-count (contract-call? .Election-Smart-Contract get-candidate-count election-id))
      (election (unwrap! (contract-call? .Election-Smart-Contract get-election election-id) err-not-found))
    )
    (ok {
      election-title: (get title election),
      total-votes: (get total-votes election),
      candidates: (map get-candidate-rank-info 
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
        (list election-id election-id election-id election-id election-id 
              election-id election-id election-id election-id election-id))
    })
  )
)

(define-private (get-candidate-rank-info (candidate-id uint) (election-id uint))
  (match (contract-call? .Election-Smart-Contract get-candidate election-id candidate-id)
    candidate
      (some {
        candidate-id: candidate-id,
        name: (get name candidate),
        votes: (get vote-count candidate),
        percentage: (unwrap-panic (get-candidate-percentage election-id candidate-id))
      })
    none
  )
)