(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_VENDOR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_RATING (err u102))
(define-constant ERR_ALREADY_REVIEWED (err u103))
(define-constant ERR_VENDOR_EXISTS (err u104))
(define-constant ERR_NFT_NOT_FOUND (err u105))

(define-non-fungible-token vendor-nft uint)

(define-data-var next-vendor-id uint u1)
(define-data-var next-review-id uint u1)

(define-map vendors
  { vendor-id: uint }
  {
    owner: principal,
    name: (string-ascii 50),
    category: (string-ascii 30),
    total-reviews: uint,
    average-rating: uint,
    total-rating-points: uint,
    created-at: uint,
    is-active: bool
  }
)

(define-map reviews
  { review-id: uint }
  {
    vendor-id: uint,
    reviewer: principal,
    rating: uint,
    comment: (string-ascii 200),
    created-at: uint
  }
)

(define-map vendor-reviews
  { vendor-id: uint, reviewer: principal }
  { review-id: uint }
)

(define-map vendor-owner-lookup
  { owner: principal }
  { vendor-id: uint }
)

(define-public (register-vendor (name (string-ascii 50)) (category (string-ascii 30)))
  (let
    (
      (vendor-id (var-get next-vendor-id))
      (existing-vendor (map-get? vendor-owner-lookup { owner: tx-sender }))
    )
    (asserts! (is-none existing-vendor) ERR_VENDOR_EXISTS)
    (try! (nft-mint? vendor-nft vendor-id tx-sender))
    (map-set vendors
      { vendor-id: vendor-id }
      {
        owner: tx-sender,
        name: name,
        category: category,
        total-reviews: u0,
        average-rating: u0,
        total-rating-points: u0,
        created-at: stacks-block-height,
        is-active: true
      }
    )
    (map-set vendor-owner-lookup
      { owner: tx-sender }
      { vendor-id: vendor-id }
    )
    (var-set next-vendor-id (+ vendor-id u1))
    (ok vendor-id)
  )
)

(define-public (submit-review (vendor-id uint) (rating uint) (comment (string-ascii 200)))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
      (review-id (var-get next-review-id))
      (existing-review (map-get? vendor-reviews { vendor-id: vendor-id, reviewer: tx-sender }))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (asserts! (is-none existing-review) ERR_ALREADY_REVIEWED)
    (asserts! (get is-active vendor) ERR_VENDOR_NOT_FOUND)
    (asserts! (not (is-eq tx-sender (get owner vendor))) ERR_NOT_AUTHORIZED)
    
    (let
      (
        (new-total-reviews (+ (get total-reviews vendor) u1))
        (new-total-rating-points (+ (get total-rating-points vendor) rating))
        (new-average-rating (/ new-total-rating-points new-total-reviews))
      )
      (map-set reviews
        { review-id: review-id }
        {
          vendor-id: vendor-id,
          reviewer: tx-sender,
          rating: rating,
          comment: comment,
          created-at: stacks-block-height
        }
      )
      (map-set vendor-reviews
        { vendor-id: vendor-id, reviewer: tx-sender }
        { review-id: review-id }
      )
      (map-set vendors
        { vendor-id: vendor-id }
        (merge vendor {
          total-reviews: new-total-reviews,
          average-rating: new-average-rating,
          total-rating-points: new-total-rating-points
        })
      )
      (var-set next-review-id (+ review-id u1))
      (ok review-id)
    )
  )
)

(define-public (update-vendor-info (vendor-id uint) (name (string-ascii 50)) (category (string-ascii 30)))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active vendor) ERR_VENDOR_NOT_FOUND)
    (map-set vendors
      { vendor-id: vendor-id }
      (merge vendor { name: name, category: category })
    )
    (ok true)
  )
)

(define-public (deactivate-vendor (vendor-id uint))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (map-set vendors
      { vendor-id: vendor-id }
      (merge vendor { is-active: false })
    )
    (ok true)
  )
)

(define-public (transfer-vendor-nft (vendor-id uint) (recipient principal))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? vendor-nft vendor-id tx-sender recipient))
    (map-delete vendor-owner-lookup { owner: tx-sender })
    (map-set vendor-owner-lookup
      { owner: recipient }
      { vendor-id: vendor-id }
    )
    (map-set vendors
      { vendor-id: vendor-id }
      (merge vendor { owner: recipient })
    )
    (ok true)
  )
)

(define-read-only (get-vendor (vendor-id uint))
  (map-get? vendors { vendor-id: vendor-id })
)

(define-read-only (get-review (review-id uint))
  (map-get? reviews { review-id: review-id })
)

(define-read-only (get-vendor-by-owner (owner principal))
  (match (map-get? vendor-owner-lookup { owner: owner })
    lookup (map-get? vendors { vendor-id: (get vendor-id lookup) })
    none
  )
)

(define-read-only (has-reviewed (vendor-id uint) (reviewer principal))
  (is-some (map-get? vendor-reviews { vendor-id: vendor-id, reviewer: reviewer }))
)

(define-read-only (get-vendor-nft-owner (vendor-id uint))
  (nft-get-owner? vendor-nft vendor-id)
)

(define-read-only (get-next-vendor-id)
  (var-get next-vendor-id)
)

(define-read-only (get-next-review-id)
  (var-get next-review-id)
)

(define-read-only (get-vendor-reputation-score (vendor-id uint))
  (match (map-get? vendors { vendor-id: vendor-id })
    vendor 
    (let
      (
        (avg-rating (get average-rating vendor))
        (total-reviews (get total-reviews vendor))
        (reputation-multiplier (if (>= total-reviews u10) u100 (* total-reviews u10)))
      )
      (some (* avg-rating reputation-multiplier))
    )
    none
  )
)