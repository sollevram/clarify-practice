;; Define the map to store user sessions
(define-map user-sessions 
  principal 
  {
    practice-count: uint,
    total-duration: uint,
    ratings: (list 100 uint)
  }
)

;; Store the ID of the last practice session
(define-data-var last-session-id uint u0)

;; Event: Emit when a user practices
(define-data-var practice-session-increment 
  {
    user: principal,
    session-id: uint,
    new-count: uint
  }
  {
    user: tx-sender,
    session-id: u0,
    new-count: u0
  }
)

;; Event: Emit when a user's practice session is reset
(define-data-var practice-session-reset 
  {
    user: principal
  }
  {
    user: tx-sender
  }
)

;; Public function to start a new practice session
(define-private (start-practice-session-impl (duration uint) (rating uint))
  (begin
    (let 
        ((current-id (+ (var-get last-session-id) u1)))
      
      ;; Add the session metadata for the user
      (map-set user-sessions tx-sender
        {
          practice-count: u1,
          total-duration: duration,
          ratings: (list rating)
        }
      )
      
      ;; Update the session ID for the next session
      (var-set last-session-id current-id)
      
      ;; Update practice session increment event data
      (var-set practice-session-increment
        {
          user: tx-sender,
          session-id: current-id,
          new-count: u1
        }
      )
      
      (ok "Practice session started successfully.")
    )
  )
)

(define-public (start-practice-session (duration uint) (rating uint))
  (begin
    (asserts! (< duration u10000) (err "Duration must be less than 10000"))
    (asserts! (< rating u10) (err "Rating must be between 0 and 9"))
    (start-practice-session-impl duration rating)))

;; Public function to increment the practice session count and add the duration
(define-private (increment-practice-session-impl (duration uint) (rating uint))
  (let ((current-session (map-get? user-sessions tx-sender)))
    (if (is-none current-session)
      (err "No practice session found. Please start a practice session first.")
      (let ((session-data (unwrap! current-session (err "Failed to unwrap session data"))))
        (let ((current-ratings (get ratings session-data)))
          (if (>= (len current-ratings) u100)
            (err "Maximum ratings limit reached")
            (let ((new-ratings (unwrap! (as-max-len? (append current-ratings rating) u100) (err "Failed to update ratings"))))
              ;; Update the practice session count
              (map-set user-sessions tx-sender
                {
                  practice-count: (+ (get practice-count session-data) u1),
                  total-duration: (+ (get total-duration session-data) duration),
                  ratings: new-ratings
                }
              )
              
              ;; Update practice session increment event data
              (var-set practice-session-increment
                {
                  user: tx-sender,
                  session-id: (var-get last-session-id),
                  new-count: (+ (get practice-count session-data) u1)
                }
              )
              
              (ok "Practice session incremented successfully.")
            )
          )
        )
      )
    )
  )
)

(define-public (increment-practice-session (duration uint) (rating uint))
  (begin
    (asserts! (< duration u10000) (err "Duration must be less than 10000"))
    (asserts! (< rating u10) (err "Rating must be between 0 and 9"))
    (increment-practice-session-impl duration rating)))

;; Private function to get the current user's practice session details
(define-private (get-practice-session-details-impl)
  (let ((current-session (map-get? user-sessions tx-sender)))
    (if (is-none current-session)
      (err "No practice session found. Please start a practice session first.")
      (ok (unwrap! current-session (err "Failed to unwrap session data")))
    )
  )
)

;; Public function to get the current user's practice session details
(define-public (get-practice-session-details)
  (get-practice-session-details-impl))

;; Private function to reset the user's practice session count and data
(define-private (reset-practice-sessions-impl)
  (let ((current-session (map-get? user-sessions tx-sender)))
    (if (is-none current-session)
      (err "No practice session data to reset.")
      (begin
        ;; Reset the user's practice session data
        (map-delete user-sessions tx-sender)
        
        ;; Update reset event data
        (var-set practice-session-reset
          {
            user: tx-sender
          }
        )
        
        (ok "Practice sessions reset successfully.")
      )
    )
  )
)

;; Public function to reset the user's practice session count and data
(define-public (reset-practice-sessions)
  (reset-practice-sessions-impl))
