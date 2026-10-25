"""
Real-time fraud scoring and pattern classifier.
Evaluates synthetic transaction stream against velocity and amount threshold features.
"""

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, roc_auc_score


def generate_mock_stream(records: int = 15000) -> pd.DataFrame:
    """Generates synthetic banking logs with realistic anomaly distributions."""
    np.random.seed(42)
    user_ids = np.random.randint(100, 1500, size=records)
    amounts = np.round(np.random.exponential(scale=45.0, size=records) + 5.0, 2)
    velocity_15m = np.random.poisson(lam=0.9, size=records)
    is_foreign_ip = np.random.choice([0, 1], p=[0.96, 0.04], size=records)

    # Injected fraud triggers: sudden high velocity + high ticket spend
    fraud_weights = (
        0.02
        + 0.40 * (velocity_15m >= 4)
        + 0.30 * (amounts > 250)
        + 0.25 * (is_foreign_ip == 1)
    )
    is_fraud = (np.random.rand(records) < np.clip(fraud_weights, 0.0, 0.90)).astype(int)

    return pd.DataFrame({
        "user_id": user_ids,
        "amount": amounts,
        "velocity_15m": velocity_15m,
        "is_foreign_ip": is_foreign_ip,
        "is_fraud": is_fraud
    })


def run_pipeline():
    print("Ingesting transaction stream...")
    data = generate_mock_stream(15000)
    print(f"Total Transactions: {len(data):,} | Baseline Anomaly Rate: {data['is_fraud'].mean()*100:.2f}%\n")

    features = ["amount", "velocity_15m", "is_foreign_ip"]
    X = data[features]
    y = data["is_fraud"]

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )

    clf = RandomForestClassifier(n_estimators=100, max_depth=5, random_state=42)
    clf.fit(X_train, y_train)

    preds = clf.predict(X_test)
    probs = clf.predict_proba(X_test)[:, 1]

    print("Model Evaluation:")
    print(classification_report(y_test, preds, target_names=["Legit", "Fraud"]))
    print(f"ROC-AUC Score: {roc_auc_score(y_test, probs):.4f}")


if __name__ == "__main__":
    run_pipeline()