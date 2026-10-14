# SE3 Price Spike Prediction

Data Mining I project investigating whether unusually high electricity prices in SE3 can be predicted one day in advance.

## Project idea

First we use anomaly detection to define unusually high prices, then we try to predict those anomalies one day ahead using previous prices, load forecasts, weather forecasts and calendar information.

## Data sources

- Svenska kraftnät: SE3 day-ahead prices
- ENTSO-E: day-ahead load forecasts
- Open-Meteo / ECMWF IFS: weather forecasts

Period: 2024-03-08 to 2026-04-30

## Notebook structure

- `01`: Process price data
- `02`: Process weather forecasts
- `03`: Process ENTSO-E load forecasts
- `04_build_master_dataset.ipynb`: Merge data and create features
- `05_anomaly_detection.ipynb`: Create anomaly labels
- `06_price_spike_prediction.ipynb`: Predict anomalies one day ahead

## Setup
chmod +x setup.sh
./setup.sh