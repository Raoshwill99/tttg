;; Time-Travel Trading Game
;; Phase 3: Final Implementation

;; Define constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_TIME (err u101))
(define-constant ERR_PARADOX (err u102))
(define-constant ERR_INSUFFICIENT_BALANCE (err u103))
(define-constant ERR_INVALID_ORDER_TYPE (err u104))
(define-constant ERR_COOLDOWN (err u105))
(define-constant TRADING_FEE_RATE u005) ;; 0.5% fee
(define-constant TIME_TRAVEL_COOLDOWN u86400) ;; 24 hours in seconds

;; Define data variables
(define-data-var current-time uint u0)
(define-map player-balances principal uint)
(define-map player-time-positions principal uint)
(define-map time-travel-cooldowns principal uint)
(define-map player-scores principal uint)
(define-data-var top-players (list 10 {player: principal, score: uint}) (list))

;; New data structure for detailed historical Bitcoin prices
(define-map detailed-bitcoin-prices uint {open: uint, high: uint, low: uint, close: uint, volume: uint})

;; Function to upload historical data (admin only)
(define-public (bulk-upload-bitcoin-data (data (list 200 {timestamp: uint, open: uint, high: uint, low: uint, close: uint, volume: uint})))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (fold upload-single-datapoint data (ok true))))

(define-private (upload-single-datapoint (datapoint {timestamp: uint, open: uint, high: uint, low: uint, close: uint, volume: uint}) (previous-result (response bool uint)))
  (begin
    (map-set detailed-bitcoin-prices (get timestamp datapoint) 
             {open: (get open datapoint), 
              high: (get high datapoint), 
              low: (get low datapoint), 
              close: (get close datapoint), 
              volume: (get volume datapoint)})
    (ok true)))

;; Updated function to get detailed Bitcoin price data
(define-read-only (get-detailed-bitcoin-price (timestamp uint))
  (ok (default-to 
       {open: u0, high: u0, low: u0, close: u0, volume: u0} 
       (map-get? detailed-bitcoin-prices timestamp))))

;; Update the existing get-bitcoin-price function to use the new detailed data
(define-read-only (get-bitcoin-price (timestamp uint))
  (let ((detailed-price (unwrap! (get-detailed-bitcoin-price timestamp) ERR_INVALID_TIME)))
    (ok (get close detailed-price))))

;; Enhanced time travel function with cooldown
(define-public (time-travel (new-time uint))
  (let ((player tx-sender)
        (current-position (default-to u0 (map-get? player-time-positions player)))
        (last-travel-time (default-to u0 (map-get? time-travel-cooldowns player))))
    (begin
      (asserts! (> new-time u0) ERR_INVALID_TIME)
      (asserts! (or (is-eq current-position u0) (> new-time current-position)) ERR_PARADOX)
      (asserts! (>= (- block-height last-travel-time) TIME_TRAVEL_COOLDOWN) ERR_COOLDOWN)
      (map-set player-time-positions player new-time)
      (map-set time-travel-cooldowns player block-height)
      (ok (var-set current-time new-time)))))

;; Get current time
(define-read-only (get-current-time)
  (ok (var-get current-time)))

;; Initialize player
(define-public (initialize-player)
  (begin
    (map-set player-balances tx-sender u1000)
    (map-set player-time-positions tx-sender (var-get current-time))
    (map-set player-scores tx-sender u0)
    (ok true)))

;; Get player balance
(define-read-only (get-player-balance (player principal))
  (ok (default-to u0 (map-get? player-balances player))))

;; Enhanced trade function
(define-public (trade (amount uint) (is-buy bool) (order-type (string-ascii 20)) (limit-price (optional uint)))
  (let ((player tx-sender)
        (balance (default-to u0 (map-get? player-balances player)))
        (current-price (unwrap! (get-bitcoin-price (var-get current-time)) ERR_INVALID_TIME))
        (fee (* amount current-price TRADING_FEE_RATE)))
    (asserts! (or (is-eq order-type "market") (is-eq order-type "limit")) ERR_INVALID_ORDER_TYPE)
    (if (is-eq order-type "market")
        (execute-market-order player amount is-buy balance current-price fee)
        (execute-limit-order player amount is-buy balance current-price fee limit-price))))

(define-private (execute-market-order (player principal) (amount uint) (is-buy bool) (balance uint) (current-price uint) (fee uint))
  (if is-buy
      (begin
        (asserts! (<= (+ (* amount current-price) fee) balance) ERR_INSUFFICIENT_BALANCE)
        (map-set player-balances player (- balance (+ (* amount current-price) fee)))
        (update-player-score player (to-int (* amount current-price)))
        (ok true))
      (begin
        (map-set player-balances player (+ balance (- (* amount current-price) fee)))
        (update-player-score player (to-int (* amount current-price)))
        (ok true))))

(define-private (execute-limit-order (player principal) (amount uint) (is-buy bool) (balance uint) (current-price uint) (fee uint) (limit-price (optional uint)))
  (let ((effective-price (default-to current-price limit-price)))
    (if is-buy
        (begin
          (asserts! (<= current-price effective-price) ERR_INVALID_ORDER_TYPE)
          (asserts! (<= (+ (* amount effective-price) fee) balance) ERR_INSUFFICIENT_BALANCE)
          (map-set player-balances player (- balance (+ (* amount effective-price) fee)))
          (update-player-score player (to-int (* amount effective-price)))
          (ok true))
        (begin
          (asserts! (>= current-price effective-price) ERR_INVALID_ORDER_TYPE)
          (map-set player-balances player (+ balance (- (* amount effective-price) fee)))
          (update-player-score player (to-int (* amount effective-price)))
          (ok true)))))

;; Updated function to update player score and maintain top players list
(define-public (update-player-score (player principal) (profit int))
  (let ((current-score (default-to u0 (map-get? player-scores player)))
        (time-bonus (- (var-get current-time) u0))
        (absolute-profit (if (< profit 0) (- 0 profit) profit))
        (new-score (+ current-score (to-uint absolute-profit) time-bonus)))
    (begin
      (map-set player-scores player new-score)
      (var-set top-players (add-to-top-players player new-score))
      (ok true))))

;; Helper function to add a player to the top players list
(define-private (add-to-top-players (player principal) (score uint))
  (let ((current-top (var-get top-players))
        (player-entry {player: player, score: score}))
    (if (< (len current-top) u10)
      (append current-top player-entry)
      (let ((min-top-score (get score (unwrap-panic (element-at current-top u9)))))
        (if (> score min-top-score)
          (let ((new-top (append (take u9 current-top) player-entry)))
            (sort-top new-top))
          current-top)))))

;; Helper function to sort top players (bubble sort implementation)
(define-private (sort-top (players (list 10 {player: principal, score: uint})))
  (fold sort-step players players))

(define-private (sort-step (index uint) (players (list 10 {player: principal, score: uint})))
  (let ((a (unwrap-panic (element-at players index)))
        (b (unwrap-panic (element-at players (+ index u1)))))
    (if (> (get score a) (get score b))
      (merge (take index players)
             (list b a)
             (drop (+ index u2) players))
      players)))

;; Function to get top players
(define-read-only (get-top-players)
  (ok (var-get top-players)))

;; Function to get "future" Bitcoin price prediction
(define-read-only (get-future-bitcoin-price (future-time uint))
  (let ((current-price (unwrap-panic (get-bitcoin-price (var-get current-time))))
        (time-difference (- future-time (var-get current-time)))
        (volatility (/ current-price u20))) ;; 5% volatility
    (ok (+ current-price (* (pow u2 (/ time-difference u31536000)) ;; Years into the future
                            (- (random-price volatility) (/ volatility u2)))))))

(define-private (random-price (range uint))
  (mod (pow u2 block-height) range))

;; Get player's current time position
(define-read-only (get-player-time-position (player principal))
  (ok (default-to u0 (map-get? player-time-positions player))))