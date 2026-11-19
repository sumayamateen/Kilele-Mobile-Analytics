📱 Kilele Mobile: Data Analytics & Board-Level Strategy
📌 Project Overview
Kilele Mobile is Kenya's second-largest telecom operator (~11M subscribers). The Chief Commercial Officer (CCO) needed to present the true state of the business to the Board of Directors. She had five critical questions spanning subscriber growth, product profitability, agent liquidity, network capacity, and marketing ROI.

My Role: Lead Data Analyst. I extracted raw data using SQL, built finance-auditable Excel models, designed a 6-page interactive Power BI Board Pack, and wrote the executive findings to present to C-level stakeholders.

🔍 The Five Business Problems Solved
The Ghost Subscribers (Data Quality): Discovered that 7.6% of "active" subscribers were artificially inflated by free 1 KES promo credits. I built a logic to exclude these ghosts and corrected the board's active base from 33,235 down to the true 30,709.

The Usiku Cannibalization (Product Analytics): The new night-time data bundles were eating daytime revenue. By comparing "Adopters" vs "Non-Adopters," I proved that adopter revenue dropped by 33% (from 1,048 KES to 700 KES) despite data usage going up.

The Coast Float Crisis (Operations/Liquidity): Traced 3.5M KES in failed KilelePay withdrawals to a structural system cap (Coast agents were limited to 30K float limits vs. 95K nationally). This proved the failures were a system issue, exonerating the agent network.

The Kisumu Network Crisis (Network Planning): Exposed how the Nyanza regional average (86.9%) hid a localized crisis. 100% of the 24 live towers in Kisumu were running at 99.5% capacity, driving a 30% silent churn rate.

The Campaign Illusion (Marketing ROI): Exposed that the "8.5% reactivation" win-back campaign had a true statistical lift of 0.01% (pure noise). I used Standard Error calculations to prove the campaign had zero real effect compared to the holdout group.

🛠️ Technical Toolkit & Techniques
1. SQL (PostgreSQL) & Data Extraction
CTEs (Common Table Expressions): Used to break down complex logic (like identifying 90-day usage windows and isolating targeted campaigns) into readable, modular blocks.

Window Functions: Utilized ROW_NUMBER() and LAG() to track customer behaviors over time (e.g., identifying the first purchase of a night bundle).

Complex JOINs & Aggregations: Joined data across 10+ tables (subscribers, recharges, kilelepay_transactions, site_daily, campaign_targets) using LEFT JOIN, INNER JOIN, and conditional CASE WHEN logic.

2. Power BI (Executive Dashboarding)
DAX (Data Analysis Expressions): Built complex measures using CALCULATE, FILTER, TREATAS, and VAR to compute dynamic metrics (e.g., Active Base, Revenue Drop, Statistical Lift).

Star Schema Modeling: Designed a clean data model, connecting fact tables to a centralized dim_date table to ensure accurate time-intelligence.

Executive UI/UX Design: Built a 6-page report with a seamless custom navigation bar, dynamic titles, conditional formatting (red flags for gaps), and "Bottom Line Up Front" (BLUF) captions for the Board.

3. Excel (Finance & Audit)
Audit-Ready Formulas: Used INDEX/MATCH, XLOOKUP, SUMIFS, and COUNTIFS to create a live workbook where every summary number traces back to a raw data sheet without hardcoded values.

Statistical Testing: Calculated the Standard Error of the difference between two proportions to prove that a campaign's lift was statistically insignificant.

PivotTables: Built clean, dynamic PivotTables to aggregate millions of rows of transaction data into board-ready summaries.

🚀 The Final Deliverable
The Power BI Board Pack: A 6-page interactive summary that the CCO can click through during the board meeting. (Note: Since the data source is a local simulation, the .pbix file is provided in this repo. A PDF export of the dashboard is also available for easy viewing).

The Excel Audit Pack: A multi-sheet workbook designed for the Finance team. Every formula is live, and every number on the Summary tab links directly to a working sheet.

The SQL Pack: The raw queries used to build the extracts.

📸 Dashboard Preview
(Recruiters: Click the image below to view the full dashboard PDF)

https://01_powerbi_dashboard/Kilele_Dashboard_Screenshot_Summary.png

📂 Repository Structure
01_PowerBI_Dashboard/: The .pbix file, screenshots, and PDF export.

02_Excel_Audits/: The final finance-ready audit workbook (.xlsx).

03_SQL_Code/: The raw PostgreSQL queries for all five findings.

04_Executive_Summary/: The final written findings and C-level email.
