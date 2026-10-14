# SE3 Electricity Price Spike Prediction — Handoff

_Last updated: 2026-10-14_

## Project goal

Research question:

> **How well can we predict unusually high hourly electricity prices in SE3 one day ahead?**

The project has two separate ML/data-mining stages:

1. **Notebook 05 defines the target**: which observed hours count as contextual high-price anomalies.
2. **Notebook 06 predicts that target one day ahead** using only information that should have been available beforehand.

The key distinction is:

> **05 creates the facit. 06 tries to predict the facit.**

---

## Overall pipeline

```text
01 SE3 day-ahead prices
        +
02 historical weather forecasts
        +
03 SE3 day-ahead load forecasts
        ↓
04 master dataset
        ↓
05 anomaly detection
   → high_price_anomaly labels
        ↓
06 day-ahead classifier
```

---

# Data sources

## 01 — Svenska kraftnät: SE3 day-ahead prices

Purpose:
- keep bidding zone SE3
- use UTC timestamps
- restrict to project period
- create one price observation per hour

The source changes from hourly to 15-minute prices later in the period.

Rules used:
- before transition: valid hour requires 1 observation
- after transition: valid hour requires all 4 quarter-hours
- complete 15-minute data are averaged to hourly mean
- incomplete hours are left as missing, not interpolated

Known major gap:
- roughly 2025-09-30 22:00 UTC → 2025-10-08 21:00 UTC
- about 192 hours

Final price series:
- 18,816 project hours
- 459 missing/invalid price hours

Missing target-price hours:
- train: 92
- validation: 3
- test: 364

Negative prices were checked and kept because they are valid market observations.

Output:
`data/processed/se3_hourly_prices.csv`

---

## 02 — Open-Meteo / ECMWF weather forecasts

These are **historical forecasts**, not realized weather.

Used:
- Open-Meteo Previous Runs API
- ECMWF IFS 0.25° (`ecmwf_ifs025`)
- `previous_day2`, approximately a forecast generated ~48h before valid time

Locations:
- Stockholm
- Gothenburg
- Örebro

Variables:
- temperature at 2 m
- wind speed at 100 m

Reason:
- avoid leakage
- use information that could realistically have existed before the target hour
- wind at 100 m acts as a rough proxy for wind-power conditions

Final weather data:
- hourly
- UTC
- no missing values in the project period

Output:
`data/processed/se3_weather_forecasts.csv`

---

## 03 — ENTSO-E: SE3 day-ahead load forecast

Variable:
- `load_forecast_mw`

This is forecasted electricity load/demand, not realized consumption.

The data later changes to 15-minute resolution and is aggregated to hourly means when complete.

Confirmed real source gap:
- 24 hours around 2025-12-03 / 2025-12-04

Final:
- 18,816 hourly rows
- 24 missing load hours

API token is stored in `.env` as `ENTSOE_API_KEY` and should never be committed.

Output:
`data/processed/se3_load_forecast.csv`

---

# Time period and split

Master period:

```text
2024-03-08 00:00 UTC
→ 2026-04-30 23:00 UTC
```

Total:
- 18,816 hourly observations

Train:
```text
2024-03-08 → 2025-03-07
```
8760 hours

Validation:
```text
2025-03-08 → 2025-04-30
```
1296 hours

Test:
```text
2025-05-01 → 2026-04-30
```
8760 hours

Important limitation:
- validation is only about two months
- one year of training data may not fully represent later “normal” price behaviour

Technical alignment and lags use **UTC**.

Calendar features use Swedish local time:
`Europe/Stockholm`.

---

# 04 — Build master dataset

Known filename:
`04_build_master_dataset.ipynb`

Purpose:
- merge price + weather + load on timestamp
- keep one row per hour
- create price lags
- create calendar features
- add split column

Important lag features:
- `price_24h`
- `price_48h`
- `price_168h`

These were created while keeping the complete hourly time axis, so a shift of 24 means exactly 24 clock-hours earlier.

Calendar features:
- `hour`
- `weekday`
- `month`
- `is_weekend`

Cyclic sin/cos calendar encodings were tested and intentionally removed to keep the project easier to explain.

Output:
`data/processed/se3_master_dataset.csv`

Shape:
- 18,816 rows

---

# 05 — Anomaly detection

Known filename:
`05_anomaly_detection.ipynb`

## Purpose

There is no external ground-truth label saying:

> “this hour was an unusually high price.”

Therefore 05 creates the target for the later classifier.

## Why contextual anomaly detection?

Price levels vary strongly by:
- month / season
- hour of day

A global fixed price cutoff would therefore be crude.

## Final accepted method

Train **12 separate Isolation Forests**, one per month.

Features:
- `price`
- `hour`

Parameters:
- `n_estimators=100`
- `contamination=0.01`
- `random_state=42`

Isolation Forest decides whether a point is anomalous.

Then the training-month median is only used to decide the direction:

```text
anomaly AND price > monthly training median
→ high_price_anomaly = 1
```

Important:
- Isolation Forest is the anomaly detector
- the median is only the high/low filter

Earlier approaches were tried and abandoned:
- one global Isolation Forest
- median/MAD scoring
- monthly IF variants that forced high anomalies every month
- training only on upper-half prices

We decided **not** to force every month to contain high-price anomalies.

## Training high-price anomaly counts

| Month | Count |
|---|---:|
| Jan | 8 |
| Feb | 6 |
| Mar | 8 |
| Apr | 6 |
| May | 8 |
| Jun | 6 |
| Jul | 0 |
| Aug | 0 |
| Sep | 8 |
| Oct | 8 |
| Nov | 8 |
| Dec | 8 |

July/August still contained IF anomalies, but only on the low-price side.

## Validation

The anomaly models are:
- trained only on train
- reused unchanged on validation
- evaluated using training-period monthly medians

Validation result:
- March 2025: 111 high-price anomalies across ~15 days
- April 2025: 8

March 2025 looked substantially different from training March, especially in the upper part of the price distribution.

Decision:
> Do not retune the anomaly detector just to make validation look nicer.

This is treated as a real limitation/distribution shift.

## Test anomaly results

Same fixed models, no retraining:

| Month | Valid obs. | High anomalies |
|---|---:|---:|
| 1 | 731 | 5 |
| 2 | 664 | 16 |
| 3 | 721 | 51 |
| 4 | 698 | 7 |
| 5 | 741 | 53 |
| 6 | 717 | 1 |
| 7 | 743 | 22 |
| 8 | 743 | 50 |
| 9 | 718 | 107 |
| 10 | 531 | 38 |
| 11 | 689 | 24 |
| 12 | 700 | 0 |

This reinforces the limitation that one training year may not fully capture later normal behaviour.

Output:
`data/processed/se3_anomaly_labels.csv`

Main target:
- `high_price_anomaly`

---

# 06 — Day-ahead prediction

Known filename:
`06_price_spike_prediction.ipynb`

## Purpose

Predict:

```text
high_price_anomaly
```

one day ahead.

The target comes from notebook 05.

## Planned predictors

Historical prices:
- `price_24h`
- `price_48h`
- `price_168h`

Forecasted system state:
- `load_forecast_mw`

Weather forecasts:
- `temp_stockholm`
- `wind_stockholm`
- `temp_gothenburg`
- `wind_gothenburg`
- `temp_orebro`
- `wind_orebro`

Calendar:
- `hour`
- `weekday`
- `month`
- `is_weekend`

### Must NOT be used

The actual target-hour `price`.

That would leak the answer.

---

# Current 06 status

An initial version was started.

It already:
- loads master data
- loads anomaly labels
- merges them
- selects features
- creates model dataset
- splits train / validation / test
- creates `X_train`, `y_train`, etc.

A Decision Tree baseline was about to be trained.

However, the group then realized that the logic of 06 was no longer clear to everyone.

## Recommendation

**Redo notebook 06 cleanly from scratch.**

Not because the old code is necessarily wrong, but because:
- every group member must understand it
- the exam may require live parameter changes
- the current 06 was built incrementally before the group had the whole conceptual picture

A simpler rebuilt notebook is safer.

---

# Missing-data issue found in 06

Missing values:

| Variable | Missing total |
|---|---:|
| `price_168h` | 616 |
| `price_48h` | 505 |
| `price_24h` | 482 |
| `high_price_anomaly` | 459 |
| `load_forecast_mw` | 24 |
| weather | 0 |
| calendar | 0 |

By split:

| Variable | Train | Validation | Test |
|---|---:|---:|---:|
| price_24h | 116 | 3 | 363 |
| price_48h | 140 | 3 | 362 |
| price_168h | 260 | 3 | 353 |
| load_forecast_mw | 0 | 0 | 24 |
| high_price_anomaly | 92 | 3 | 364 |

With simple complete-case `dropna()`:

| Split | Rows left | Anomalies |
|---|---:|---:|
| Train | 8240 | 73 |
| Validation | 1284 | 119 |
| Test | 7792 | 337 |

Current defensible approach:
- do not interpolate missing target prices
- do not invent values across the long price gap
- `dropna()` is acceptable if clearly documented
- lost rows should be mentioned as a limitation

This can be revisited when rebuilding 06.

---

# Recommended clean 06 structure

## A. Explain the goal

Markdown cell:

> Predict whether each target hour will have `high_price_anomaly = 1` using only information available before that hour.

## B. Load and merge

Load:
- master dataset
- anomaly labels

Merge on timestamp.

## C. Define predictors and target

Make it explicit that current actual `price` is excluded.

## D. Missing data

Choose one clear policy and print:
- rows removed
- remaining train / validation / test size
- anomaly count in each split

Simplest policy:
- drop rows with missing target or required predictors

## E. Baseline

Include a trivial reference model, e.g.:
- always predict “no anomaly”

This demonstrates why accuracy alone is misleading.

## F. Main classifier

Recommended first model:
- **Decision Tree**

Reasons:
- simple
- course-appropriate
- easy to explain
- easy to tune live
- easy to inspect

Random Forest can be added later only if useful.

## G. Validation

Use validation to choose:
- tree depth
- minimum leaf size
- perhaps class weighting / probability threshold

Do not touch test for tuning.

## H. Final test

Metrics:
- precision
- recall
- F1
- confusion matrix
- precision–recall curve

Accuracy should not be the main metric because the positive class is rare.

## I. Interpret

Look at:
- feature importance
- false positives
- false negatives
- possible month effects

Then answer the original research question.

---

# Leakage / “one day ahead” issue to check

Before rebuilding 06, explicitly define:

> Are we predicting each hour exactly 24 hours before that hour?

If yes, every predictor must genuinely be available at that cutoff.

Check:
- historical price availability
- ENTSO-E forecast publication timing
- weather forecast run timing

The `previous_day2` weather choice was intentionally conservative.

This should be verified conceptually before finalizing 06.

---

# Preliminary presentation storyline

Current slides are built around:

1. Title
2. Research Question & Motivation
3. Data Collection & Tabular Schema
4. Initial / Processed Data plots
5. Data Quality & Preprocessing
6. Anomaly Detection Methodology
7. Initial Experimental Results
8. Discussion & Remaining Tasks

Current research question:

> How well can we predict unusually high hourly electricity prices in SE3 one day ahead?

Suggested simple definition:

> A price that stands out as unusually high compared with prices from the same month, taking the hour of day into account.

Current anomaly-method storyline:
- no ground-truth label exists
- price varies by season and hour
- 12 monthly Isolation Forests
- anomalies above training-month median become high-price anomalies
- models are trained only on train and reused unchanged on validation/test

Current remaining tasks:
- rebuild/finish the day-ahead prediction model
- decide how to handle missing lagged-price features
- tune classifier on validation
- evaluate on test with precision/recall/F1
- optionally test sensitivity to `contamination`

The contamination sensitivity check is lower priority than getting 06 correct.

---

# Important decisions to preserve

1. UTC for technical alignment and price lags.
2. Swedish local time for calendar features.
3. Do not interpolate missing target prices.
4. Keep the complete hourly timeline before creating lags.
5. Use historical forecasts, not realized future weather.
6. Do not use target-hour actual price in 06.
7. Do not retrain anomaly models on validation/test.
8. Do not change anomaly settings because validation/test looks surprising.
9. Do not force a high anomaly in every month.
10. Do not tune the classifier on the final test set.

---

# Recommended next step

**Start notebook 06 again from the top.**

Before writing classifier code, make sure all three group members can explain:

1. what the target is,
2. how 05 created it,
3. which information 06 is allowed to use,
4. what “one day ahead” means,
5. why train / validation / test have different roles.

Then rebuild the notebook slowly and keep only code that everyone understands.
