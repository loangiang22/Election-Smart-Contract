(define-constant err-not-found (err u101))
(define-constant err-security-breach (err u150))

(define-data-var security-alert-counter uint u0)
(define-data-var global-threat-level uint u0)

(define-map election-security-metrics
  { election-id: uint }
  {
    security-score: uint,
    suspicious-activity-count: uint,
    last-security-check: uint,
    threat-level: uint,
    monitoring-enabled: bool
  }
)

(define-map security-alerts
  { alert-id: uint }
  {
    election-id: uint,
    alert-type: (string-ascii 30),
    severity: uint,
    detected-at: uint,
    details-hash: (buff 32),
    resolved: bool
  }
)

(define-map voting-pattern-analysis
  { election-id: uint }
  {
    burst-vote-count: uint,
    last-burst-detection: uint,
    average-vote-interval: uint,
    pattern-anomaly-score: uint
  }
)

(define-public (initialize-security-monitoring (election-id uint))
  (begin
    (map-set election-security-metrics
      { election-id: election-id }
      {
        security-score: u100,
        suspicious-activity-count: u0,
        last-security-check: stacks-block-height,
        threat-level: u0,
        monitoring-enabled: true
      }
    )
    (map-set voting-pattern-analysis
      { election-id: election-id }
      {
        burst-vote-count: u0,
        last-burst-detection: u0,
        average-vote-interval: u0,
        pattern-anomaly-score: u0
      }
    )
    (ok true)
  )
)

(define-public (analyze-vote-security (election-id uint) (voter principal))
  (let
    (
      (current-metrics (unwrap! (map-get? election-security-metrics { election-id: election-id }) err-not-found))
      (pattern-data (unwrap! (map-get? voting-pattern-analysis { election-id: election-id }) err-not-found))
      (current-block stacks-block-height)
      (time-since-last (- current-block (get last-burst-detection pattern-data)))
      (is-burst-vote (< time-since-last u5))
    )
    (if is-burst-vote
      (let
        (
          (new-burst-count (+ (get burst-vote-count pattern-data) u1))
          (anomaly-increase (if (> new-burst-count u10) u15 u5))
        )
        (map-set voting-pattern-analysis
          { election-id: election-id }
          (merge pattern-data {
            burst-vote-count: new-burst-count,
            last-burst-detection: current-block,
            pattern-anomaly-score: (+ (get pattern-anomaly-score pattern-data) anomaly-increase)
          })
        )
        (if (> new-burst-count u15)
          (begin
            (try! (trigger-security-alert election-id "burst-voting-detected" u3))
            (ok true)
          )
          (ok true)
        )
      )
      (ok true)
    )
  )
)

(define-private (trigger-security-alert (election-id uint) (alert-type (string-ascii 30)) (severity uint))
  (let
    (
      (alert-id (+ (var-get security-alert-counter) u1))
      (details-hash (sha256 (concat (unwrap-panic (to-consensus-buff? election-id)) (unwrap-panic (to-consensus-buff? alert-type)))))
    )
    (begin
      (map-set security-alerts
        { alert-id: alert-id }
        {
          election-id: election-id,
          alert-type: alert-type,
          severity: severity,
          detected-at: stacks-block-height,
          details-hash: details-hash,
          resolved: false
        }
      )
      (var-set security-alert-counter alert-id)
      (try! (update-security-score election-id severity))
      (ok alert-id)
    )
  )
)

(define-private (update-security-score (election-id uint) (threat-impact uint))
  (let
    (
      (current-metrics (unwrap! (map-get? election-security-metrics { election-id: election-id }) err-not-found))
      (score-reduction (* threat-impact u5))
      (new-score (if (>= (get security-score current-metrics) score-reduction)
                    (- (get security-score current-metrics) score-reduction)
                    u0))
    )
    (map-set election-security-metrics
      { election-id: election-id }
      (merge current-metrics {
        security-score: new-score,
        suspicious-activity-count: (+ (get suspicious-activity-count current-metrics) u1),
        last-security-check: stacks-block-height,
        threat-level: (if (< new-score u50) u3 (if (< new-score u75) u2 u1))
      })
    )
    (ok true)
  )
)

(define-read-only (get-security-status (election-id uint))
  (map-get? election-security-metrics { election-id: election-id })
)

(define-read-only (get-security-alert (alert-id uint))
  (map-get? security-alerts { alert-id: alert-id })
)

(define-read-only (get-pattern-analysis (election-id uint))
  (map-get? voting-pattern-analysis { election-id: election-id })
)

(define-read-only (calculate-integrity-score (election-id uint))
  (match (map-get? election-security-metrics { election-id: election-id })
    metrics
      (let
        (
          (base-score (get security-score metrics))
          (threat-penalty (* (get threat-level metrics) u10))
          (activity-penalty (* (get suspicious-activity-count metrics) u2))
        )
        (ok (if (>= base-score (+ threat-penalty activity-penalty))
               (- base-score threat-penalty activity-penalty)
               u0))
      )
    err-not-found
  )
)