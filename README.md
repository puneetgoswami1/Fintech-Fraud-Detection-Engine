# Fintech Real-Time Fraud & Anomaly Detection

A transaction monitoring and rule-based anomaly pipeline built to flag payment velocity bursts, unusual ticket size deviations, and synthetic card takeover patterns.

## Overview
High-volume payment gateways require early intervention before chargebacks occur. This project combines windowed SQL feature engineering with a lightweight machine learning layer to score incoming transactions in real time.

## Project Structure
- `fraud_detection_pipeline.sql`: Production SQL CTEs calculating rolling 15-minute card velocity, historical ticket averages, and impossible travel detection.
- `fraud_engine.py`: Python script simulating 15k+ events and scoring fraud patterns using Random Forest with stratified sampling.
- `requirements.txt`: Python dependencies.

## Key Logic & Metrics
1. **Velocity Tracking:** Rolling transaction counts within short-time windows (`RANGE BETWEEN INTERVAL '15 MINUTE' PRECEDING AND CURRENT ROW`).
2. **Ticket Outliers:** Comparing current amount against a 30-transaction historical moving baseline.
3. **Threshold Actions:**
   - **Risk Score >= 70:** Immediate decline & alert trigger.
   - **Risk Score 40 - 69:** Step-up two-factor authentication challenge.
   - **Risk Score < 40:** Standard gateway approval.

## Performance
- **ROC-AUC Score:** ~0.91 on stratified holdout test sets.
- **Focus:** Minimizing customer checkout friction while catching rapid card-testing bursts.

## How to Run
```bash
# Clone the repository
git clone [https://github.com/puneetgoswami1/Fintech-Fraud-Detection-Engine.git](https://github.com/puneetgoswami1/Fintech-Fraud-Detection-Engine.git)
cd Fintech-Fraud-Detection-Engine

# Install requirements
pip install -r requirements.txt

# Run anomaly engine
python fraud_engine.py