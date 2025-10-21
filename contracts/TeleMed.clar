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
(define-constant ERR-RECORD-EXISTS (err u108))
(define-constant ERR-ACCESS-DENIED (err u109))
(define-constant ERR-ACCESS-EXPIRED (err u110))
(define-constant ERR-INVALID-RECORD-TYPE (err u111))
(define-constant ERR-INVALID-EMERGENCY-TIER (err u301))
(define-constant ERR-NO-AVAILABLE-DOCTOR (err u302))
(define-constant ERR-REQUEST-EXPIRED (err u303))
(define-constant ERR-REQUEST-NOT-FOUND (err u304))
(define-constant ERR-NOT-REQUEST-PATIENT (err u305))
(define-constant ERR-ALREADY-ACCEPTED (err u306))
(define-constant ERR-NOT-MATCHED-DOCTOR (err u307))

(define-data-var platform-fee-percentage uint u5)
(define-data-var next-appointment-id uint u1)
(define-data-var next-record-id uint u1)

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

(define-map medical-records uint
  {
    patient: principal,
    record-type: (string-ascii 30),
    ipfs-hash: (string-ascii 60),
    created-at: uint,
    is-active: bool,
    description: (string-ascii 200)
  })

(define-map record-access-permissions {record-id: uint, doctor: principal}
  {
    granted-at: uint,
    expires-at: uint,
    granted-by: principal,
    access-type: (string-ascii 20)
  })

(define-map record-audit-trail {record-id: uint, event-id: uint}
  {
    actor: principal,
    action: (string-ascii 20),
    timestamp: uint,
    details: (optional (string-ascii 100))
  })

(define-map patient-record-counts principal uint)
(define-map record-event-counts uint uint)

(define-map emergency-queue
  { request-id: uint }
  {
    patient: principal,
    specialty-required: (string-ascii 50),
    emergency-tier: (string-ascii 10),
    cost-multiplier: uint,
    requested-at: uint,
    status: (string-ascii 20),
    matched-doctor: (optional principal)
  })

(define-map doctor-emergency-availability
  { doctor: principal }
  { available-for-emergency: bool })

(define-data-var emergency-request-counter uint u0)
(define-data-var emergency-acceptance-window uint u10)

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

(define-public (grant-consultation-access (appointment-id uint) (record-id uint))
  (let (
    (appointment-data (unwrap! (map-get? appointments appointment-id) ERR-NOT-FOUND))
    (record-data (unwrap! (map-get? medical-records record-id) ERR-NOT-FOUND))
    (access-blocks (* (get duration-hours appointment-data) u10))
  )
    (asserts! (is-eq tx-sender (get patient appointment-data)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get patient record-data) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (or (is-eq (get status appointment-data) "scheduled") 
                  (is-eq (get status appointment-data) "in-progress")) ERR-INVALID-STATUS)
    
    (map-set record-access-permissions {record-id: record-id, doctor: (get doctor appointment-data)} {
      granted-at: stacks-block-height,
      expires-at: (+ stacks-block-height access-blocks),
      granted-by: tx-sender,
      access-type: "consultation"
    })
    
    (log-record-event record-id tx-sender "consultation-access" 
      (some "Access granted for consultation"))
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

(define-private (log-record-event (record-id uint) (actor principal) (action (string-ascii 20)) (details (optional (string-ascii 100))))
  (let ((event-count (default-to u0 (map-get? record-event-counts record-id))))
    (map-set record-audit-trail {record-id: record-id, event-id: (+ event-count u1)} {
      actor: actor,
      action: action,
      timestamp: stacks-block-height,
      details: details
    })
    (map-set record-event-counts record-id (+ event-count u1))
    (+ event-count u1)))

(define-private (get-emergency-multiplier (tier (string-ascii 10)))
  (if (is-eq tier "standard")
    (ok u120)
    (if (is-eq tier "urgent")
      (ok u150)
      (if (is-eq tier "critical")
        (ok u200)
        ERR-INVALID-EMERGENCY-TIER
      )
    )
  )
)

(define-private (find-available-emergency-doctor (specialty (string-ascii 50)))
  (ok none)
)

(define-public (add-medical-record (record-type (string-ascii 30)) (ipfs-hash (string-ascii 60)) (description (string-ascii 200)))
  (let (
    (record-id (var-get next-record-id))
    (patient-data (unwrap! (map-get? patients tx-sender) ERR-NOT-FOUND))
  )
    (asserts! (get is-active patient-data) ERR-UNAUTHORIZED)
    (asserts! (> (len record-type) u0) ERR-INVALID-RECORD-TYPE)
    (asserts! (> (len ipfs-hash) u0) ERR-INVALID-AMOUNT)
    
    (map-set medical-records record-id {
      patient: tx-sender,
      record-type: record-type,
      ipfs-hash: ipfs-hash,
      created-at: stacks-block-height,
      is-active: true,
      description: description
    })
    
    (map-set patient-record-counts tx-sender 
      (+ (default-to u0 (map-get? patient-record-counts tx-sender)) u1))
    
    (log-record-event record-id tx-sender "created" (some "Record added to registry"))
    (var-set next-record-id (+ record-id u1))
    (ok record-id)))

(define-public (grant-record-access (record-id uint) (doctor principal) (duration-blocks uint) (access-type (string-ascii 20)))
  (let (
    (record-data (unwrap! (map-get? medical-records record-id) ERR-NOT-FOUND))
    (doctor-data (unwrap! (map-get? doctors doctor) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get patient record-data)) ERR-UNAUTHORIZED)
    (asserts! (get is-active doctor-data) ERR-UNAUTHORIZED)
    (asserts! (> duration-blocks u0) ERR-INVALID-AMOUNT)
    
    (map-set record-access-permissions {record-id: record-id, doctor: doctor} {
      granted-at: stacks-block-height,
      expires-at: (+ stacks-block-height duration-blocks),
      granted-by: tx-sender,
      access-type: access-type
    })
    
    (log-record-event record-id tx-sender "access-granted" 
      (some "Access granted to doctor"))
    (ok true)))

(define-public (revoke-record-access (record-id uint) (doctor principal))
  (let (
    (record-data (unwrap! (map-get? medical-records record-id) ERR-NOT-FOUND))
    (access-data (unwrap! (map-get? record-access-permissions {record-id: record-id, doctor: doctor}) ERR-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get patient record-data)) ERR-UNAUTHORIZED)
    
    (map-delete record-access-permissions {record-id: record-id, doctor: doctor})
    (log-record-event record-id tx-sender "access-revoked" 
      (some "Access revoked from doctor"))
    (ok true)))

(define-public (deactivate-record (record-id uint))
  (let ((record-data (unwrap! (map-get? medical-records record-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get patient record-data)) ERR-UNAUTHORIZED)
    
    (map-set medical-records record-id (merge record-data {is-active: false}))
    (log-record-event record-id tx-sender "deactivated" (some "Record marked inactive"))
    (ok true)))

(define-public (access-medical-record (record-id uint))
  (let (
    (record-data (unwrap! (map-get? medical-records record-id) ERR-NOT-FOUND))
    (access-data (map-get? record-access-permissions {record-id: record-id, doctor: tx-sender}))
  )
    (asserts! (get is-active record-data) ERR-UNAUTHORIZED)
    
    (if (is-eq tx-sender (get patient record-data))
      (begin
        (log-record-event record-id tx-sender "patient-accessed" (some "Patient viewed own record"))
        (ok (get ipfs-hash record-data)))
      (match access-data
        permission 
          (if (> (get expires-at permission) stacks-block-height)
            (begin
              (log-record-event record-id tx-sender "doctor-accessed" (some "Doctor viewed record during consultation"))
              (ok (get ipfs-hash record-data)))
            ERR-ACCESS-EXPIRED)
        ERR-ACCESS-DENIED))))

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee u20) ERR-INVALID-AMOUNT)
    (var-set platform-fee-percentage new-fee)
    (ok true)))

(define-public (request-emergency-consultation (specialty (string-ascii 50)) (tier (string-ascii 10)))
  (let
    (
      (request-id (+ (var-get emergency-request-counter) u1))
      (multiplier-result (get-emergency-multiplier tier))
      (current-block stacks-block-height)
    )
    (asserts! (is-ok multiplier-result) multiplier-result)
    (let
      (
        (cost-multiplier (unwrap-panic multiplier-result))
      )
      (map-set emergency-queue
        { request-id: request-id }
        {
          patient: tx-sender,
          specialty-required: specialty,
          emergency-tier: tier,
          cost-multiplier: cost-multiplier,
          requested-at: current-block,
          status: "pending",
          matched-doctor: none
        }
      )
      (var-set emergency-request-counter request-id)
      (ok request-id)
    )
  )
)

(define-public (accept-emergency-request (request-id uint))
  (let
    (
      (request (unwrap! (map-get? emergency-queue { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
      (current-block stacks-block-height)
      (requested-at (get requested-at request))
      (acceptance-window (var-get emergency-acceptance-window))
    )
    (asserts! (is-eq (get status request) "pending") ERR-ALREADY-ACCEPTED)
    (asserts! (<= current-block (+ requested-at acceptance-window)) ERR-REQUEST-EXPIRED)
    (map-set emergency-queue
      { request-id: request-id }
      (merge request {
        status: "accepted",
        matched-doctor: (some tx-sender)
      })
    )
    (ok true)
  )
)

(define-public (reject-emergency-request (request-id uint))
  (let
    (
      (request (unwrap! (map-get? emergency-queue { request-id: request-id }) ERR-REQUEST-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get patient request)) ERR-NOT-REQUEST-PATIENT)
    (asserts! (is-eq (get status request) "pending") ERR-ALREADY-ACCEPTED)
    (map-set emergency-queue
      { request-id: request-id }
      (merge request { status: "rejected" })
    )
    (ok true)
  )
)

(define-public (toggle-emergency-availability (available bool))
  (begin
    (map-set doctor-emergency-availability
      { doctor: tx-sender }
      { available-for-emergency: available }
    )
    (ok true)
  )
)

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

(define-read-only (get-medical-record (record-id uint))
  (map-get? medical-records record-id))

(define-read-only (get-record-access-permission (record-id uint) (doctor principal))
  (map-get? record-access-permissions {record-id: record-id, doctor: doctor}))

(define-read-only (get-patient-record-count (patient principal))
  (default-to u0 (map-get? patient-record-counts patient)))

(define-read-only (get-next-record-id)
  (var-get next-record-id))

(define-read-only (has-active-record-access (record-id uint) (doctor principal))
  (match (map-get? record-access-permissions {record-id: record-id, doctor: doctor})
    access-data (> (get expires-at access-data) stacks-block-height)
    false))

(define-read-only (get-record-audit-event (record-id uint) (event-id uint))
  (map-get? record-audit-trail {record-id: record-id, event-id: event-id}))

(define-read-only (get-record-event-count (record-id uint))
  (default-to u0 (map-get? record-event-counts record-id)))

(define-read-only (is-record-owner (record-id uint) (user principal))
  (match (map-get? medical-records record-id)
    record-data (is-eq (get patient record-data) user)
    false))

(define-read-only (get-emergency-request (request-id uint))
  (map-get? emergency-queue { request-id: request-id })
)

(define-read-only (get-doctor-emergency-status (doctor principal))
  (default-to
    { available-for-emergency: false }
    (map-get? doctor-emergency-availability { doctor: doctor })
  )
)

(define-read-only (get-emergency-request-counter)
  (var-get emergency-request-counter)
)

(define-read-only (is-request-expired (request-id uint))
  (match (map-get? emergency-queue { request-id: request-id })
    request
      (let
        (
          (current-block stacks-block-height)
          (requested-at (get requested-at request))
          (acceptance-window (var-get emergency-acceptance-window))
        )
        (> current-block (+ requested-at acceptance-window))
      )
    false
  )
)
