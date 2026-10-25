-- Fintech Transaction Monitoring & Anomaly Extraction Pipeline
-- Analyzes transaction velocity, unusual ticket size deviations, and location jumps.

WITH transaction_features AS (
    SELECT 
        transaction_id,
        user_id,
        card_id,
        transaction_amount,
        merchant_category,
        terminal_city,
        transaction_timestamp,

        -- 1. Velocity Check: Count transactions on this card in the last 15 minutes
        COUNT(transaction_id) OVER (
            PARTITION BY card_id 
            ORDER BY transaction_timestamp 
            RANGE BETWEEN INTERVAL '15 MINUTE' PRECEDING AND CURRENT ROW
        ) AS tx_count_last_15m,

        -- 2. Baseline Spend: User's historical average amount over the last 30 transactions
        AVG(transaction_amount) OVER (
            PARTITION BY user_id 
            ORDER BY transaction_timestamp
            ROWS BETWEEN 30 PRECEDING AND 1 PRECEDING
        ) AS user_avg_amount_last_30tx,

        -- 3. Prior Transaction Location & Time for impossible travel check
        LAG(terminal_city, 1) OVER (
            PARTITION BY card_id 
            ORDER BY transaction_timestamp
        ) AS last_terminal_city,

        LAG(transaction_timestamp, 1) OVER (
            PARTITION BY card_id 
            ORDER BY transaction_timestamp
        ) AS last_tx_timestamp
    FROM raw_payments_stream
    WHERE status = 'SUCCESS'
),

risk_scored_events AS (
    SELECT 
        transaction_id,
        user_id,
        card_id,
        transaction_amount,
        tx_count_last_15m,
        terminal_city,

        -- Rule 1: High frequency burst (>4 tx in 15 mins)
        CASE WHEN tx_count_last_15m >= 4 THEN 1 ELSE 0 END AS flag_velocity_burst,

        -- Rule 2: Sudden ticket size jump (>3.5x regular ticket average)
        CASE 
            WHEN transaction_amount > (3.5 * COALESCE(user_avg_amount_last_30tx, transaction_amount)) 
            THEN 1 ELSE 0 
        END AS flag_amount_outlier,

        -- Rule 3: City mismatch within 10 minutes (impossible travel)
        CASE 
            WHEN last_terminal_city IS NOT NULL 
                 AND last_terminal_city <> terminal_city
                 AND EXTRACT(EPOCH FROM (transaction_timestamp - last_tx_timestamp)) < 600
            THEN 1 ELSE 0 
        END AS flag_location_jump
    FROM transaction_features
)

SELECT 
    transaction_id,
    user_id,
    card_id,
    transaction_amount,
    tx_count_last_15m,
    flag_velocity_burst,
    flag_amount_outlier,
    flag_location_jump,
    -- Weighted risk rating
    (flag_velocity_burst * 40 + flag_amount_outlier * 35 + flag_location_jump * 25) AS risk_score,
    CASE 
        WHEN (flag_velocity_burst * 40 + flag_amount_outlier * 35 + flag_location_jump * 25) >= 70 THEN 'BLOCK_AND_ALERT'
        WHEN (flag_velocity_burst * 40 + flag_amount_outlier * 35 + flag_location_jump * 25) >= 40 THEN 'REQUIRE_2FA'
        ELSE 'APPROVE'
    END AS gateway_action
FROM risk_scored_events;