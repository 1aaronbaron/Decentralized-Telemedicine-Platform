;; TeleMed - Decentralized Telemedicine Platform

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-APPOINTMENT-EXPIRED (err u106))
(define-constant ERR-INVALID-RATING (err u107))

(define-data-var platform-fee-percentage uint u5)
(define-data-var next-appointment-id uint u1)

(define-map doctors principal 
  {
    name: (string-ascii 50),
    specialty: (string-ascii 30),
    hourly-rate: uint,
    total-consultations: uint,
    average-rating: uint,
    is-active: bool
  })

(define-map patients principal 
  {
    name: (string-ascii 50),
    total-appointments: uint,
    is-active: bool
  })

(define-map appointments uint 
  {
    patient: principal,
    doctor: principal,
    scheduled-time: uint,
    duration-hours: uint,
    total-cost: uint,
    status: (string-ascii 20),
    consultation-notes: (optional (string-ascii 500)),
    patient-rating: (optional uint)
  })

(define-map doctor-earnings principal uint)
(define-map patient-payments principal uint)
(define-map appointment-payments uint uint)

(define-public (register-doctor (name (string-ascii 50)) (specialty (string-ascii 30)) (hourly-rate uint))
  (begin
    (asserts! (is-none (map-get? doctors tx-sender)) ERR-ALREADY-EXISTS)
    (asserts! (> hourly-rate u0) ERR-INVALID-AMOUNT)
    (map-set doctors tx-sender {
      name: name,
      specialty: specialty,
      hourly-rate: hourly-rate,
      total-consultations: u0,
      average-rating: u0,
      is-active: true
    })
    (ok true)))

(define-public (register-patient (name (string-ascii 50)))
  (begin
    (asserts! (is-none (map-get? patients tx-sender)) ERR-ALREADY-EXISTS)
    (map-set patients tx-sender {
      name: name,
      total-appointments: u0,
      is-active: true
    })
    (ok true)))

(define-public (update-doctor-status (is-active bool))
  (let ((doctor-data (unwrap! (map-get? doctors tx-sender) ERR-NOT-FOUND)))
    (map-set doctors tx-sender (merge doctor-data {is-active: is-active}))
    (ok true)))

(define-public (update-hourly-rate (new-rate uint))
  (let ((doctor-data (unwrap! (map-get? doctors tx-sender) ERR-NOT-FOUND)))
    (asserts! (> new-rate u0) ERR-INVALID-AMOUNT)
    (map-set doctors tx-sender (merge doctor-data {hourly-rate: new-rate}))
    (ok true)))

(define-public (schedule-appointment (doctor principal) (scheduled-time uint) (duration-hours uint))
  (let (
    (appointment-id (var-get next-appointment-id))
    (doctor-data (unwrap! (map-get? doctors doctor) ERR-NOT-FOUND))
    (patient-data (unwrap! (map-get? patients tx-sender) ERR-NOT-FOUND))
    (total-cost (* (get hourly-rate doctor-data) duration-hours))
  )
    (asserts! (get is-active doctor-data) ERR-UNAUTHORIZED)
    (asserts! (get is-active patient-data) ERR-UNAUTHORIZED)
    (asserts! (> scheduled-time stacks-block-height) ERR-INVALID-STATUS)
    (asserts! (> duration-hours u0) ERR-INVALID-AMOUNT)
    
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    (map-set appointments appointment-id {
      patient: tx-sender,
      doctor: doctor,
      scheduled-time: scheduled-time,
      duration-hours: duration-hours,
      total-cost: total-cost,
      status: "scheduled",
      consultation-notes: none,
      patient-rating: none
    })
    
    (map-set appointment-payments appointment-id total-cost)
    (map-set patients tx-sender (merge patient-data {total-appointments: (+ (get total-appointments patient-data) u1)}))
    (var-set next-appointment-id (+ appointment-id u1))
    (ok appointment-id)))

(define-public (cancel-appointment (appointment-id uint))
  (let (
    (appointment-data (unwrap! (map-get? appointments appointment-id) ERR-NOT-FOUND))
    (refund-amount (get total-cost appointment-data))
  )
    (asserts! (is-eq tx-sender (get patient appointment-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status appointment-data) "scheduled") ERR-INVALID-STATUS)
    (asserts! (> (get scheduled-time appointment-data) stacks-block-height) ERR-APPOINTMENT-EXPIRED)
    
    (map-set appointments appointment-id (merge appointment-data {status: "cancelled"}))
    (try! (as-contract (stx-transfer? refund-amount tx-sender (get patient appointment-data))))
    (ok true)))

(define-public (start-consultation (appointment-id uint))
  (let ((appointment-data (unwrap! (map-get? appointments appointment-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get doctor appointment-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status appointment-data) "scheduled") ERR-INVALID-STATUS)
    (asserts! (<= (get scheduled-time appointment-data) stacks-block-height) ERR-INVALID-STATUS)
    
    (map-set appointments appointment-id (merge appointment-data {status: "in-progress"}))
    (ok true)))

(define-public (complete-consultation (appointment-id uint) (notes (string-ascii 500)))
  (let (
    (appointment-data (unwrap! (map-get? appointments appointment-id) ERR-NOT-FOUND))
    (doctor-data (unwrap! (map-get? doctors (get doctor appointment-data)) ERR-NOT-FOUND))
    (payment-amount (get total-cost appointment-data))
    (platform-fee (/ (* payment-amount (var-get platform-fee-percentage)) u100))
    (doctor-payment (- payment-amount platform-fee))
  )
    (asserts! (is-eq tx-sender (get doctor appointment-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status appointment-data) "in-progress") ERR-INVALID-STATUS)
    
    (map-set appointments appointment-id (merge appointment-data {
      status: "completed",
      consultation-notes: (some notes)
    }))
    
    (map-set doctors (get doctor appointment-data) 
      (merge doctor-data {total-consultations: (+ (get total-consultations doctor-data) u1)}))
    
    (map-set doctor-earnings (get doctor appointment-data) 
      (+ (default-to u0 (map-get? doctor-earnings (get doctor appointment-data))) doctor-payment))
    
    (try! (as-contract (stx-transfer? doctor-payment tx-sender (get doctor appointment-data))))
    (ok true)))

(define-public (rate-consultation (appointment-id uint) (rating uint))
  (let (
    (appointment-data (unwrap! (map-get? appointments appointment-id) ERR-NOT-FOUND))
    (doctor-data (unwrap! (map-get? doctors (get doctor appointment-data)) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get patient appointment-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status appointment-data) "completed") ERR-INVALID-STATUS)
    (asserts! (is-none (get patient-rating appointment-data)) ERR-ALREADY-EXISTS)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    
    (let (
      (total-consultations (get total-consultations doctor-data))
      (current-average (get average-rating doctor-data))
      (new-average (if (is-eq total-consultations u1)
                     rating
                     (/ (+ (* current-average (- total-consultations u1)) rating) total-consultations)))
    )
      (map-set appointments appointment-id (merge appointment-data {patient-rating: (some rating)}))
      (map-set doctors (get doctor appointment-data) (merge doctor-data {average-rating: new-average}))
      (ok true))))

(define-public (withdraw-earnings)
  (let (
    (doctor-data (unwrap! (map-get? doctors tx-sender) ERR-NOT-FOUND))
    (earnings (default-to u0 (map-get? doctor-earnings tx-sender)))
  )
    (asserts! (> earnings u0) ERR-INSUFFICIENT-FUNDS)
    (map-delete doctor-earnings tx-sender)
    (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
    (ok earnings)))

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee u20) ERR-INVALID-AMOUNT)
    (var-set platform-fee-percentage new-fee)
    (ok true)))

(define-read-only (get-doctor (doctor-address principal))
  (map-get? doctors doctor-address))

(define-read-only (get-patient (patient-address principal))
  (map-get? patients patient-address))

(define-read-only (get-appointment (appointment-id uint))
  (map-get? appointments appointment-id))

(define-read-only (get-doctor-earnings (doctor-address principal))
  (default-to u0 (map-get? doctor-earnings doctor-address)))

(define-read-only (get-platform-fee)
  (var-get platform-fee-percentage))

(define-read-only (get-next-appointment-id)
  (var-get next-appointment-id))

(define-read-only (get-doctor-rating (doctor-address principal))
  (match (map-get? doctors doctor-address)
    doctor-data (some (get average-rating doctor-data))
    none))

(define-read-only (get-appointment-cost (doctor-address principal) (duration-hours uint))
  (match (map-get? doctors doctor-address)
    doctor-data (some (* (get hourly-rate doctor-data) duration-hours))
    none))

(define-read-only (is-appointment-active (appointment-id uint))
  (match (map-get? appointments appointment-id)
    appointment-data (or (is-eq (get status appointment-data) "scheduled") 
                         (is-eq (get status appointment-data) "in-progress"))
    false))

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender)))
