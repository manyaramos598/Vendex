(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_VENDOR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_RATING (err u102))
(define-constant ERR_ALREADY_REVIEWED (err u103))
(define-constant ERR_VENDOR_EXISTS (err u104))
(define-constant ERR_NFT_NOT_FOUND (err u105))
(define-constant ERR_ALREADY_SUBSCRIBED (err u106))
(define-constant ERR_NOT_SUBSCRIBED (err u107))
(define-constant ERR_INSUFFICIENT_POINTS (err u108))
(define-constant ERR_INVALID_TIER (err u109))
(define-constant ERR_INVALID_REWARD (err u110))
(define-constant ERR_PRODUCT_NOT_FOUND (err u111))
(define-constant ERR_INSUFFICIENT_INVENTORY (err u112))
(define-constant ERR_INVALID_PRICE (err u113))
(define-constant ERR_INVALID_QUANTITY (err u114))
(define-constant ERR_PRODUCT_INACTIVE (err u115))

(define-non-fungible-token vendor-nft uint)

(define-data-var next-vendor-id uint u1)
(define-data-var next-review-id uint u1)
(define-data-var next-subscription-id uint u1)
(define-data-var next-reward-id uint u1)
(define-data-var next-product-id uint u1)

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

(define-map subscriptions
  { subscription-id: uint }
  {
    subscriber: principal,
    vendor-id: uint,
    tier: uint,
    loyalty-points: uint,
    subscription-date: uint,
    is-active: bool
  }
)

(define-map user-subscriptions
  { subscriber: principal, vendor-id: uint }
  { subscription-id: uint }
)

(define-map loyalty-points
  { user: principal }
  { total-points: uint }
)

(define-map vendor-rewards
  { reward-id: uint }
  {
    vendor-id: uint,
    reward-name: (string-ascii 50),
    points-required: uint,
    max-redemptions: uint,
    current-redemptions: uint,
    tier-required: uint,
    is-active: bool,
    created-at: uint
  }
)

(define-map reward-redemptions
  { redemption-id: uint }
  {
    user: principal,
    reward-id: uint,
    redeemed-at: uint
  }
)

(define-map products
  { product-id: uint }
  {
    vendor-id: uint,
    name: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    price: uint,
    inventory: uint,
    is-active: bool,
    created-at: uint,
    views: uint,
    tags: (string-ascii 200)
  }
)

(define-map vendor-products
  { vendor-id: uint, product-id: uint }
  { is-listed: bool }
)

(define-map product-analytics
  { product-id: uint }
  {
    total-views: uint,
    weekly-views: uint,
    last-view-block: uint,
    popularity-score: uint
  }
)

(define-map product-categories
  { category: (string-ascii 50) }
  { product-count: uint }
)

(define-public (award-loyalty-points (user principal) (points uint))
  (let
    (
      (current-points (default-to u0 (get total-points (map-get? loyalty-points { user: user }))))
      (new-total (+ current-points points))
    )
    (map-set loyalty-points
      { user: user }
      { total-points: new-total }
    )
    (ok new-total)
  )
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
      (let
        (
          (points-result (award-loyalty-points tx-sender u10))
        )
        (ok review-id)
      )
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

(define-public (subscribe-to-vendor (vendor-id uint) (tier uint))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
      (subscription-id (var-get next-subscription-id))
      (existing-subscription (map-get? user-subscriptions { subscriber: tx-sender, vendor-id: vendor-id }))
    )
    (asserts! (and (>= tier u1) (<= tier u3)) ERR_INVALID_TIER)
    (asserts! (is-none existing-subscription) ERR_ALREADY_SUBSCRIBED)
    (asserts! (get is-active vendor) ERR_VENDOR_NOT_FOUND)
    (asserts! (not (is-eq tx-sender (get owner vendor))) ERR_NOT_AUTHORIZED)
    
    (map-set subscriptions
      { subscription-id: subscription-id }
      {
        subscriber: tx-sender,
        vendor-id: vendor-id,
        tier: tier,
        loyalty-points: u0,
        subscription-date: stacks-block-height,
        is-active: true
      }
    )
    (map-set user-subscriptions
      { subscriber: tx-sender, vendor-id: vendor-id }
      { subscription-id: subscription-id }
    )
    (var-set next-subscription-id (+ subscription-id u1))
    (let
      (
        (points-result (award-loyalty-points tx-sender u5))
      )
      (ok subscription-id)
    )
  )
)

(define-public (unsubscribe-from-vendor (vendor-id uint))
  (let
    (
      (subscription-lookup (unwrap! (map-get? user-subscriptions { subscriber: tx-sender, vendor-id: vendor-id }) ERR_NOT_SUBSCRIBED))
      (subscription-id (get subscription-id subscription-lookup))
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) ERR_NOT_SUBSCRIBED))
    )
    (asserts! (get is-active subscription) ERR_NOT_SUBSCRIBED)
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { is-active: false })
    )
    (ok true)
  )
)

(define-public (upgrade-subscription-tier (vendor-id uint) (new-tier uint))
  (let
    (
      (subscription-lookup (unwrap! (map-get? user-subscriptions { subscriber: tx-sender, vendor-id: vendor-id }) ERR_NOT_SUBSCRIBED))
      (subscription-id (get subscription-id subscription-lookup))
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) ERR_NOT_SUBSCRIBED))
      (current-tier (get tier subscription))
    )
    (asserts! (and (>= new-tier u1) (<= new-tier u3)) ERR_INVALID_TIER)
    (asserts! (> new-tier current-tier) ERR_INVALID_TIER)
    (asserts! (get is-active subscription) ERR_NOT_SUBSCRIBED)
    
    (map-set subscriptions
      { subscription-id: subscription-id }
      (merge subscription { tier: new-tier })
    )
    (let
      (
        (points-result (award-loyalty-points tx-sender (* (- new-tier current-tier) u3)))
      )
      (ok true)
    )
  )
)

(define-public (deduct-loyalty-points (user principal) (points uint))
  (let
    (
      (current-points (default-to u0 (get total-points (map-get? loyalty-points { user: user }))))
    )
    (asserts! (>= current-points points) ERR_INSUFFICIENT_POINTS)
    (map-set loyalty-points
      { user: user }
      { total-points: (- current-points points) }
    )
    (ok (- current-points points))
  )
)

(define-public (create-vendor-reward (vendor-id uint) (reward-name (string-ascii 50)) (points-required uint) (max-redemptions uint) (tier-required uint))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
      (reward-id (var-get next-reward-id))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (and (>= tier-required u1) (<= tier-required u3)) ERR_INVALID_TIER)
    (asserts! (> points-required u0) ERR_INVALID_REWARD)
    (asserts! (> max-redemptions u0) ERR_INVALID_REWARD)
    
    (map-set vendor-rewards
      { reward-id: reward-id }
      {
        vendor-id: vendor-id,
        reward-name: reward-name,
        points-required: points-required,
        max-redemptions: max-redemptions,
        current-redemptions: u0,
        tier-required: tier-required,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    (var-set next-reward-id (+ reward-id u1))
    (ok reward-id)
  )
)

(define-public (redeem-reward (reward-id uint))
  (let
    (
      (reward (unwrap! (map-get? vendor-rewards { reward-id: reward-id }) ERR_INVALID_REWARD))
      (vendor-id (get vendor-id reward))
      (subscription-lookup (unwrap! (map-get? user-subscriptions { subscriber: tx-sender, vendor-id: vendor-id }) ERR_NOT_SUBSCRIBED))
      (subscription-id (get subscription-id subscription-lookup))
      (subscription (unwrap! (map-get? subscriptions { subscription-id: subscription-id }) ERR_NOT_SUBSCRIBED))
      (user-points (default-to u0 (get total-points (map-get? loyalty-points { user: tx-sender }))))
      (redemption-id (var-get next-reward-id))
    )
    (asserts! (get is-active reward) ERR_INVALID_REWARD)
    (asserts! (get is-active subscription) ERR_NOT_SUBSCRIBED)
    (asserts! (>= (get tier subscription) (get tier-required reward)) ERR_INVALID_TIER)
    (asserts! (>= user-points (get points-required reward)) ERR_INSUFFICIENT_POINTS)
    (asserts! (< (get current-redemptions reward) (get max-redemptions reward)) ERR_INVALID_REWARD)
    
    (map-set reward-redemptions
      { redemption-id: redemption-id }
      {
        user: tx-sender,
        reward-id: reward-id,
        redeemed-at: stacks-block-height
      }
    )
    (map-set vendor-rewards
      { reward-id: reward-id }
      (merge reward { current-redemptions: (+ (get current-redemptions reward) u1) })
    )
    (try! (deduct-loyalty-points tx-sender (get points-required reward)))
    (ok true)
  )
)

(define-read-only (get-subscription (subscription-id uint))
  (map-get? subscriptions { subscription-id: subscription-id })
)

(define-read-only (get-user-subscription (subscriber principal) (vendor-id uint))
  (match (map-get? user-subscriptions { subscriber: subscriber, vendor-id: vendor-id })
    lookup (map-get? subscriptions { subscription-id: (get subscription-id lookup) })
    none
  )
)

(define-read-only (get-user-loyalty-points (user principal))
  (default-to u0 (get total-points (map-get? loyalty-points { user: user })))
)

(define-read-only (get-vendor-reward (reward-id uint))
  (map-get? vendor-rewards { reward-id: reward-id })
)

(define-read-only (is-subscribed (user principal) (vendor-id uint))
  (match (get-user-subscription user vendor-id)
    subscription (get is-active subscription)
    false
  )
)

(define-read-only (get-subscription-tier (user principal) (vendor-id uint))
  (match (get-user-subscription user vendor-id)
    subscription 
    (if (get is-active subscription)
      (some (get tier subscription))
      none
    )
    none
  )
)

(define-read-only (can-redeem-reward (user principal) (reward-id uint))
  (match (map-get? vendor-rewards { reward-id: reward-id })
    reward 
    (let
      (
        (vendor-id (get vendor-id reward))
        (user-points (get-user-loyalty-points user))
        (user-tier (get-subscription-tier user vendor-id))
      )
      (and
        (get is-active reward)
        (>= user-points (get points-required reward))
        (< (get current-redemptions reward) (get max-redemptions reward))
        (match user-tier
          tier (>= tier (get tier-required reward))
          false
        )
      )
    )
    false
  )
)

(define-public (create-product (vendor-id uint) (name (string-ascii 100)) (description (string-ascii 500)) (category (string-ascii 50)) (price uint) (inventory uint) (tags (string-ascii 200)))
  (let
    (
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
      (product-id (var-get next-product-id))
      (current-category-count (default-to u0 (get product-count (map-get? product-categories { category: category }))))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active vendor) ERR_VENDOR_NOT_FOUND)
    (asserts! (> price u0) ERR_INVALID_PRICE)
    (asserts! (>= inventory u0) ERR_INVALID_QUANTITY)
    
    (map-set products
      { product-id: product-id }
      {
        vendor-id: vendor-id,
        name: name,
        description: description,
        category: category,
        price: price,
        inventory: inventory,
        is-active: true,
        created-at: stacks-block-height,
        views: u0,
        tags: tags
      }
    )
    (map-set vendor-products
      { vendor-id: vendor-id, product-id: product-id }
      { is-listed: true }
    )
    (map-set product-analytics
      { product-id: product-id }
      {
        total-views: u0,
        weekly-views: u0,
        last-view-block: stacks-block-height,
        popularity-score: u0
      }
    )
    (map-set product-categories
      { category: category }
      { product-count: (+ current-category-count u1) }
    )
    (var-set next-product-id (+ product-id u1))
    (ok product-id)
  )
)

(define-public (update-product (product-id uint) (name (string-ascii 100)) (description (string-ascii 500)) (category (string-ascii 50)) (price uint) (tags (string-ascii 200)))
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (vendor-id (get vendor-id product))
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
      (old-category (get category product))
      (old-category-count (default-to u1 (get product-count (map-get? product-categories { category: old-category }))))
      (new-category-count (default-to u0 (get product-count (map-get? product-categories { category: category }))))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active product) ERR_PRODUCT_INACTIVE)
    (asserts! (> price u0) ERR_INVALID_PRICE)
    
    (map-set products
      { product-id: product-id }
      (merge product {
        name: name,
        description: description,
        category: category,
        price: price,
        tags: tags
      })
    )
    (if (not (is-eq old-category category))
      (begin
        (map-set product-categories
          { category: old-category }
          { product-count: (- old-category-count u1) }
        )
        (map-set product-categories
          { category: category }
          { product-count: (+ new-category-count u1) }
        )
      )
      true
    )
    (ok true)
  )
)

(define-public (update-inventory (product-id uint) (new-inventory uint))
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (vendor-id (get vendor-id product))
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active product) ERR_PRODUCT_INACTIVE)
    (asserts! (>= new-inventory u0) ERR_INVALID_QUANTITY)
    
    (map-set products
      { product-id: product-id }
      (merge product { inventory: new-inventory })
    )
    (ok true)
  )
)

(define-public (deactivate-product (product-id uint))
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (vendor-id (get vendor-id product))
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active product) ERR_PRODUCT_INACTIVE)
    
    (map-set products
      { product-id: product-id }
      (merge product { is-active: false })
    )
    (map-set vendor-products
      { vendor-id: vendor-id, product-id: product-id }
      { is-listed: false }
    )
    (ok true)
  )
)

(define-public (reactivate-product (product-id uint))
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (vendor-id (get vendor-id product))
      (vendor (unwrap! (map-get? vendors { vendor-id: vendor-id }) ERR_VENDOR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get owner vendor)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get is-active product)) ERR_PRODUCT_INACTIVE)
    
    (map-set products
      { product-id: product-id }
      (merge product { is-active: true })
    )
    (map-set vendor-products
      { vendor-id: vendor-id, product-id: product-id }
      { is-listed: true }
    )
    (ok true)
  )
)

(define-public (view-product (product-id uint))
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (analytics (unwrap! (map-get? product-analytics { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (current-views (get views product))
      (total-views (get total-views analytics))
      (weekly-views (get weekly-views analytics))
      (blocks-since-last (- stacks-block-height (get last-view-block analytics)))
      (new-weekly-views (if (> blocks-since-last u1008) u1 (+ weekly-views u1)))
      (popularity-score (+ (* new-weekly-views u10) (/ (+ total-views u1) u100)))
    )
    (asserts! (get is-active product) ERR_PRODUCT_INACTIVE)
    
    (map-set products
      { product-id: product-id }
      (merge product { views: (+ current-views u1) })
    )
    (map-set product-analytics
      { product-id: product-id }
      {
        total-views: (+ total-views u1),
        weekly-views: new-weekly-views,
        last-view-block: stacks-block-height,
        popularity-score: popularity-score
      }
    )
    (ok product)
  )
)

(define-public (reserve-inventory (product-id uint) (quantity uint))
  (let
    (
      (product (unwrap! (map-get? products { product-id: product-id }) ERR_PRODUCT_NOT_FOUND))
      (current-inventory (get inventory product))
    )
    (asserts! (get is-active product) ERR_PRODUCT_INACTIVE)
    (asserts! (> quantity u0) ERR_INVALID_QUANTITY)
    (asserts! (>= current-inventory quantity) ERR_INSUFFICIENT_INVENTORY)
    
    (map-set products
      { product-id: product-id }
      (merge product { inventory: (- current-inventory quantity) })
    )
    (ok (- current-inventory quantity))
  )
)

(define-read-only (get-product (product-id uint))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-product-analytics (product-id uint))
  (map-get? product-analytics { product-id: product-id })
)

(define-read-only (is-vendor-product (vendor-id uint) (product-id uint))
  (is-some (map-get? vendor-products { vendor-id: vendor-id, product-id: product-id }))
)

(define-read-only (get-category-count (category (string-ascii 50)))
  (default-to u0 (get product-count (map-get? product-categories { category: category })))
)

(define-read-only (is-product-available (product-id uint) (quantity uint))
  (match (map-get? products { product-id: product-id })
    product 
    (and
      (get is-active product)
      (>= (get inventory product) quantity)
      (> quantity u0)
    )
    false
  )
)

(define-read-only (get-product-popularity (product-id uint))
  (match (map-get? product-analytics { product-id: product-id })
    analytics (some (get popularity-score analytics))
    none
  )
)

(define-read-only (calculate-product-value (product-id uint))
  (match (map-get? products { product-id: product-id })
    product 
    (let
      (
        (price (get price product))
        (inventory (get inventory product))
        (views (get views product))
        (analytics (map-get? product-analytics { product-id: product-id }))
        (popularity (match analytics
          some-analytics (get popularity-score some-analytics)
          u0
        ))
      )
      (some (+ (* price inventory) (* views u5) (* popularity u2)))
    )
    none
  )
)

(define-read-only (get-next-product-id)
  (var-get next-product-id)
)


