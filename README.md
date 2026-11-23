# Customer Cohort & Churn Analytics

**A Business Intelligence project focused on customer retention, churn analysis, and customer segmentation in the telecommunications industry.**

## Project Overview

This project analyzes customer churn behavior using the IBM Telco Customer Churn dataset.

The main objective is to identify customer segments with different churn rates, explore the factors associated with customer cancellations, and generate insights that can support customer retention strategies.

The analysis focuses on customer tenure, contract types, payment methods, internet services, technical support, and monthly charges.

## Business Objectives

- Measure the overall customer churn and retention rates.
- Analyze churn behavior across customer tenure groups.
- Compare churn rates by contract type and payment method.
- Identify service combinations associated with higher churn rates.
- Examine the relationship between monthly charges and customer churn.
- Build a customer retention matrix based on tenure groups and contract types.
- Present findings through an interactive Business Intelligence dashboard.

## Dataset

**IBM Telco Customer Churn**

The dataset contains customer-level information from a telecommunications company, including:

- Customer demographics.
- Account information and tenure.
- Contract and payment details.
- Subscribed services.
- Monthly and total charges.
- Customer churn status.

Each row represents an individual customer.

**Methodological note:** The dataset is a cross-sectional snapshot rather than a historical record of monthly customer activity. Therefore, this project analyzes observed churn rates across tenure-based customer segments. It does not attempt to reconstruct historical retention curves or predict individual customer churn probabilities.

## Technologies & Tools

| Technology | Purpose |
|---|---|
| Python | Data exploration, cleaning, and preparation |
| Pandas & NumPy | Data manipulation and validation |
| Plotly | Exploratory data visualization |
| SQL Server | Data storage and dimensional modeling |
| SQL | Data transformation and analytical queries |
| Power BI | Interactive dashboards and business intelligence |

## Project Workflow

The project follows an end-to-end Business Intelligence workflow:

### 1. Data Preparation — Python

- Dataset exploration and structural analysis.
- Missing values and duplicate identification.
- Data type validation and correction.
- Data quality checks.
- Feature engineering, including `Churn_Flag` and `Tenure_Group`.
- Exploratory churn analysis and visualization.
- Export of the cleaned dataset.

### 2. Data Modeling — SQL Server

- Creation of a dedicated analytical database.
- Staging table implementation.
- Dimensional modeling using a Star Schema.
- Fact and dimension table development.
- Data loading and integrity validation.
- SQL queries for analytical reporting.

### 3. Business Intelligence — Power BI

- Connection to the SQL Server data model.
- Development of analytical measures and KPIs.
- Interactive customer churn dashboard.
- Customer segmentation and retention analysis.
- Business insights and strategic recommendations.

## Key Analytical Areas

The analysis covers the following dimensions:

| Area | Analysis |
|---|---|
| Customer Tenure | Churn across tenure-based customer groups |
| Contract Type | Comparison of month-to-month, one-year, and two-year contracts |
| Payment Method | Churn distribution by payment method |
| Internet Services | Churn by internet service type |
| Technical Support | Analysis of InternetService and TechSupport combinations |
| Monthly Charges | Comparison of charges across churn groups |
| Customer Retention | Retention matrix by tenure group and contract type |

## Repository Structure

```text
Customer-Cohort-Churn-Analytics/
│
├── README.md
├── PROJECT_DOCUMENTATION.md
│
├── data/
│   └── telco_customer_churn_clean.csv
│
├── python/
│   └── churn_analysis.py
│
├── sql/
│   └── basededatos.sql
│
└── powerbi/
    └── churn_dashboard.pbix
```

*Repository structure may evolve as development progresses.*

## Project Status

<ins>In Progress</ins>

- [x] Dataset selection and exploration
- [x] Data cleaning and validation in Python
- [x] Feature engineering
- [x] Exploratory churn analysis
- [x] Clean dataset export
- [x] SQL Server environment configuration
- [x] SQL Server connection setup
- [ ] Dimensional data modeling
- [ ] Data loading and SQL validation
- [ ] Power BI dashboard development
- [ ] Final business insights and recommendations

## Expected Deliverables

- Cleaned and validated customer dataset.
- Python data preparation and analysis scripts.
- SQL Server dimensional data model.
- Interactive Power BI dashboard.
- Customer churn analysis report.
- Data-driven customer retention recommendations.

## Documentation

For a more detailed explanation of the methodology, data preparation, technical implementation, and project development, see [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md).

---

**Author:** Pedro Alomar  
**Field:** Business Intelligence & Data Analytics
