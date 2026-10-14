# SE3 Price Spike Prediction

Data Mining I project investigating whether unusually high electricity prices in Sweden's SE3 electricity price area can be predicted one day in advance.

## Project idea

The project consists of two main steps:

1. Use anomaly detection to define unusually high electricity prices.
2. Predict these high-price anomalies one day ahead using historical prices, weather forecasts, load forecasts and calendar information.

## Data sources

- Svenska kraftnät — SE3 day-ahead electricity prices
- ENTSO-E — SE3 day-ahead load forecasts
- Open-Meteo / ECMWF IFS — historical weather forecasts

The final dataset contains hourly observations from:

**2024-03-08 to 2026-04-30**

## Notebook structure

- `01` — Process SE3 electricity prices
- `02` — Fetch/process weather forecasts
- `03` — Fetch/process ENTSO-E load forecasts
- `04_build_master_dataset.ipynb` — Merge data and create features
- `05_anomaly_detection.ipynb` — Create contextual high-price anomaly labels
- `06_price_spike_prediction.ipynb` — Predict high-price anomalies one day ahead

## Setup

Clone the repository and run:

```bash
chmod +x setup.sh
./setup.sh