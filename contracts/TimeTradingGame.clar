;; Time-Travel Trading Game
;; Initial Commit

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_TIME (err u101))

;; Define data variables
(define-data-var current-time uint u0)
(define-map player-balances principal uint)
(define-map historical-bitcoin-prices uint uint)

;; Time travel function
(define-public (time-travel (new-time uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> new-time u0) ERR_INVALID_TIME)
    (ok (var-set current-time new-time))))

;; Get current time
(define-read-only (get-current-time)
  (ok (var-get current-time)))

;; Set historical Bitcoin price
(define-public (set-bitcoin-price (timestamp uint) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set historical-bitcoin-prices timestamp price))))

;; Get historical Bitcoin price
(define-read-only (get-bitcoin-price (timestamp uint))
  (ok (default-to u0 (map-get? historical-bitcoin-prices timestamp))))

;; Initialize player balance
(define-public (initialize-player)
  (ok (map-set player-balances tx-sender u1000)))

;; Get player balance
(define-read-only (get-player-balance (player principal))
  (ok (default-to u0 (map-get? player-balances player))))