# 📱 Kilele Mobile: Turning Data into Board-Level Strategy

## 📌 Project Overview
Kilele Mobile is Kenya's second-largest telecom operator. The Chief Commercial Officer (CCO) needed to present the state of the business to the Board of Directors. She had five critical questions across subscriber growth, product profitability, agent liquidity, network capacity, and marketing ROI.

**My Role:** Lead Data Analyst. I was responsible for extracting the data using SQL, auditing the logic in Excel for Finance, building the interactive Power BI board pack, and writing the executive findings.

## 🔍 The Five Business Problems Solved
1. **The Ghost Subscribers:** Discovered that 7.6% of "active" subscribers were inflated by free 1 KES promo credits. Corrected the board number from 33,235 to 30,709.
2. **The Usiku Cannibalization:** Proved that the new night-time data bundles were eating daytime revenue, causing a 33% drop in adopter revenue.
3. **The Coast Float Crisis:** Traced 3.5M KES in failed withdrawals to a structural system cap (agents limited to 30K float), exonerating the agent network.
4. **The Kisumu Network Crisis:** Exposed how the regional average (86.9%) hid a localized crisis where 24/24 towers in Kisumu were running at 99.5% capacity, driving 30% silent churn.
5. **The Campaign Illusion:** Exposed that the "8.5% reactivation" win-back campaign had a true statistical lift of 0.01% (pure noise) by comparing it to the holdout group.

## 🛠️ Tools & Techniques Used
*   **SQL (PostgreSQL):** Extracted, cleaned, and aggregated data using CTEs, Window Functions, and complex JOINs.
*   **Power BI:** Built a 6-page interactive dashboard using DAX measures, star-schema modeling, dynamic titles, and executive UI/UX design.
*   **Excel:** Built a finance-auditable workbook using PivotTables, `SUMIFS`, `COUNTIFS`, `XLOOKUP`, and statistical significance testing (Standard Error).

## 🚀 The Final Deliverable
The final output is a **one-page Power BI summary** that the CCO can click through during the board meeting, backed by a live Excel workbook and SQL scripts for the Finance team to audit.

## 📸 Dashboard Preview
*(Insert your screenshot here using: `![Summary Page](01_PowerBI_Dashboard/Kilele_Dashboard_Screenshot_Summary.png)`)*

## 📂 How to navigate this repository
*   `01_PowerBI_Dashboard`: Contains the `.pbix` file and screenshots.
*   `02_Excel_Audits`: Contains the finance-ready workbook.
*   `03_SQL_Code`: Contains the raw SQL queries used for data extraction.
*   `04_Executive_Summary`: Contains the final email sent to the CCO.
