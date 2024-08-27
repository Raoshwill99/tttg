;; Time-Travel Trading Game
;; Phase 2: Advanced Time Travel Mechanics and Paradox Prevention (Third Error Fix)

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_TIME (err u101))
(define-constant ERR_PARADOX (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))

;; Define data variables
(define-data-var current-time uint u0)
(define-map player-balances principal uint)
(define-map historical-bitcoin-prices uint uint)
(define-map player-time-positions principal uint)

;; Time travel function with paradox prevention (Fixed)
(define-public (time-travel (new-time uint))
  (let ((player tx-sender)
        (current-position (default-to u0 (map-get? player-time-positions player))))
    (begin
      (asserts! (> new-time u0) ERR_INVALID_TIME)
      (asserts! (or (is-eq current-position u0) (> new-time current-position)) ERR_PARADOX)
      (map-set player-time-positions player new-time)
      (ok (var-set current-time new-time)))))

;; Get current time
(define-read-only (get-current-time)
  (ok (var-get current-time)))

;; Set historical Bitcoin price (only contract owner)
(define-public (set-bitcoin-price (timestamp uint) (price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set historical-bitcoin-prices timestamp price))))

;; Get historical Bitcoin price
(define-read-only (get-bitcoin-price (timestamp uint))
  (ok (default-to u0 (map-get? historical-bitcoin-prices timestamp))))

;; Initialize player
(define-public (initialize-player)
  (begin
    (map-set player-balances tx-sender u1000)
    (map-set player-time-positions tx-sender (var-get current-time))
    (ok true)))

;; Get player balance
(define-read-only (get-player-balance (player principal))
  (ok (default-to u0 (map-get? player-balances player))))

;; Trade function
(define-public (trade (amount uint) (is-buy bool))
  (let ((player tx-sender)
        (balance (default-to u0 (map-get? player-balances player)))
        (price (unwrap! (get-bitcoin-price (var-get current-time)) ERR_INVALID_TIME)))
    (if is-buy
      (begin
        (asserts! (<= (* amount price) balance) ERR_INSUFFICIENT_BALANCE)
        (map-set player-balances 
                 player 
                 (- balance (* amount price)))
        (ok true))
      (begin
        (map-set player-balances 
                 player 
                 (+ balance (* amount price)))
        (ok true)))))

;; Get player's current time position
(define-read-only (get-player-time-position (player principal))
  (ok (default-to u0 (map-get? player-time-positions player))))