# 📱 Kilele Mobile: Data Analytics & Board-Level Strategy

> **"The Second Place Problem: Five Corrections for the Board."**

## 📌 Project Overview
**Kilele Mobile** is a simulated Kenyan telecom operator (~11M subscribers). The Chief Commercial Officer (CCO) needed to present the true state of the business to the Board of Directors. She had five critical questions spanning subscriber growth, product profitability, agent liquidity, network capacity, and marketing ROI.

**My Role:** Lead Data Analyst. 
- 🗄️ Extracted raw data using **SQL**.
- 📊 Built finance-auditable **Excel** models.
- 📈 Designed a 6-page interactive **Power BI** Board Pack.
- ✍️ Wrote the executive findings to present to C-level stakeholders.

---

## 🔍 The Five Business Problems Solved

| # | Problem Area | The "Ghost" in the Data | The Correction | Key Tool |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Data Quality** | **The Ghost Subscribers:** 7.6% of "active" users were inflated by free 1 KES promo credits. | Corrected the active base from 33,235 down to the true **30,709**. | `SQL` / `Power BI` |
| **2** | **Product Analytics** | **The Usiku Cannibalization:** New night bundles ate daytime revenue. | Proved adopter revenue dropped **33%** (1,048 KES to 700 KES) despite higher data usage. | `DAX` / `Excel` |
| **3** | **Operations** | **The Coast Float Crisis:** 3.5M KES in failed KilelePay withdrawals. | Traced failures to a system cap (30K float vs. 95K nationally), exonerating agents. | `SQL` |
| **4** | **Network Planning** | **The Kisumu Crisis:** Regional average (86.9%) hid a localized meltdown. | Proved 100% of Kisumu's 24 towers ran at **99.5%** capacity, driving 30% silent churn. | `Power BI` |
| **5** | **Marketing ROI** | **The Campaign Illusion:** "8.5%" reactivation was pure statistical noise. | Used Standard Error math to prove the campaign had a **0.01%** true lift vs. holdout. | `Excel` |

---

## 🛠️ Technical Toolkit & Techniques

### 🗄️ 1. SQL (PostgreSQL) & Data Extraction
- **CTEs (Common Table Expressions):** Used to break down complex logic (like identifying 90-day usage windows) into readable, modular blocks.
- **Window Functions:** Utilized `ROW_NUMBER()` and `LAG()` to track customer behaviors over time.
- **Complex JOINs:** Joined data across 10+ tables (`subscribers`, `recharges`, `site_daily`, `campaign_targets`) using conditional `CASE WHEN` logic.

### 📈 2. Power BI (Executive Dashboarding)
- **DAX Measures:** Built complex measures using `CALCULATE`, `FILTER`, `TREATAS`, and `VAR` to compute dynamic metrics.
- **Star Schema Modeling:** Connected fact tables to a centralized `dim_date` table to ensure accurate time-intelligence.
- **UI/UX Design:** Built a 6-page report with a seamless custom navigation bar, dynamic titles, and "Bottom Line Up Front" (BLUF) captions.

### 📊 3. Excel (Finance & Audit)
- **Audit-Ready Formulas:** Used `INDEX/MATCH`, `XLOOKUP`, `SUMIFS`, and `COUNTIFS` so every summary number traces back to raw data without hardcoded values.
- **Statistical Testing:** Calculated the Standard Error of the difference between two proportions to prove campaign lift insignificance.

---

## 📸 Dashboard Preview

> *Click the image below to view the full Board Pack.*

![Kilele Mobile Dashboard Summary](01_PowerBI_Dashboard/Kilele_Dashboard_Screenshot_Summary.png)

---



---

<details>
<summary><b>🛠️ Click here to view the core SQL syntax used (Sample)</b></summary>

```sql
-- Example: Finding the 'Ghost Subscribers' (Episode 1)
WITH ActiveBase AS (
    SELECT 
        status, 
        last_revenue_event_on, 
        last_usage_on
    FROM kilele.subscribers
    WHERE status = 'active'
)
SELECT 
    COUNT(*) AS reported_active,
    COUNT(*) FILTER (WHERE last_revenue_event_on >= '2026-04-01') AS true_active
FROM ActiveBase;
