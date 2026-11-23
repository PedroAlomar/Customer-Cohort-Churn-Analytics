# Customer Cohort & Churn Analytics

## 1. Project Overview

**Customer Cohort & Churn Analytics** is an end-to-end Business Intelligence project focused on customer retention, churn analysis, and customer segmentation in the telecommunications industry.

The project uses the IBM Telco Customer Churn dataset to analyze customer churn behavior and identify segments with different levels of customer retention.

The analysis combines **Python, SQL Server, and Power BI** to demonstrate a complete data analytics workflow, from data preparation and validation to dimensional modeling, analytical measures, interactive visualization, and business interpretation.

The main analytical areas include:

- Customer tenure
- Contract type
- Payment method
- Internet service
- Technical support
- Monthly charges
- Customer retention

The objective is to transform customer-level data into actionable business insights that can support customer retention strategies.

---

# 2. Business Objectives

The project was designed to answer the following business questions:

- What is the overall customer churn rate?
- What proportion of customers remain active?
- How does churn vary across customer tenure groups?
- Which contract types are associated with higher churn?
- Which payment methods present higher observed churn rates?
- Which combinations of internet service and technical support show higher churn?
- How does customer retention vary across tenure groups and contract types?
- What customer segments should be considered higher-risk from a retention perspective?

The analysis is descriptive and diagnostic. It identifies patterns and associations in the available customer data rather than attempting to establish causal relationships.

---

# 3. Dataset

## IBM Telco Customer Churn

The project uses the **IBM Telco Customer Churn** dataset.

The original dataset contains customer-level information related to:

- Customer demographics
- Account information
- Customer tenure
- Contract type
- Payment method
- Internet and subscribed services
- Monthly charges
- Total charges
- Customer churn status

Each row represents an individual customer.

The dataset contains approximately 7,000 customer records and provides a suitable basis for analyzing customer retention and churn patterns.

## Methodological Note

The dataset is a **cross-sectional snapshot** rather than a longitudinal record containing monthly observations for each customer.

Therefore, this project analyzes observed churn rates across tenure-based customer segments.

It does not attempt to:

- Reconstruct historical monthly retention curves.
- Forecast future monthly churn.
- Predict individual customer churn probabilities.
- Train a machine learning churn prediction model.

The term **tenure groups** or **tenure-based customer segments** is therefore used instead of treating the dataset as a true time-series cohort dataset.

---

# 4. Technologies and Tools

| Technology | Purpose |
|---|---|
| Python | Data exploration, cleaning, validation, feature engineering, and exploratory analysis |
| Pandas | Data manipulation and transformation |
| NumPy | Data validation and numerical operations |
| Plotly | Exploratory data visualization |
| SQL Server | Analytical data storage and dimensional modeling |
| SQL | Data loading, validation, transformation, and analytical queries |
| Power BI | Interactive reporting, KPI development, and business intelligence |

---

# 5. Project Architecture

The project follows an end-to-end analytical architecture:

```text
IBM Telco Churn Dataset
          │
          ▼
      Python / Pandas
          │
          ├── Data exploration
          ├── Data quality validation
          ├── Cleaning
          ├── Feature engineering
          └── Exploratory analysis
          │
          ▼
   Cleaned Customer Dataset
          │
          ▼
      SQL Server
          │
          ├── Staging Layer
          ├── Dimension Tables
          └── Fact Table
          │
          ▼
       Star Schema
          │
          ▼
       Power BI
          │
          ├── DAX Measures
          ├── KPI Cards
          ├── Analytical Charts
          ├── Heatmaps
          └── Interactive Filters
          │
          ▼
   Business Insights
```

---

# 6. Data Preparation with Python

Python was used as the first stage of the analytical workflow.

## 6.1 Dataset Exploration

The dataset was initially inspected to understand:

- Number of records and columns.
- Column names.
- Data types.
- Missing values.
- Empty strings.
- Duplicate records.
- Customer identifier uniqueness.

This initial exploration provided the basis for the subsequent data quality process.

## 6.2 Data Quality Validation

Several validation checks were performed, including:

- Missing value detection.
- Empty string identification.
- Duplicate customer identification.
- Validation of the `SeniorCitizen` field.
- Validation of customer tenure values.
- Validation of monthly charges.
- Validation of total charges.
- Validation of churn values.

The `TotalCharges` column required particular attention because some records contained empty values.

These values were converted to numeric format, resulting in null values where the original dataset contained empty strings.

The affected records were inspected rather than automatically replacing the missing values.

## 6.3 Feature Engineering

Two analytical fields were created during the preparation process.

### Churn_Flag

The original `Churn` field contains categorical values:

- `Yes`
- `No`

A numerical/Boolean analytical field was created:

```text
Yes → 1 / TRUE
No  → 0 / FALSE
```

This field was later used in SQL Server and Power BI to calculate churn-related KPIs.

### Tenure_Group

Customer tenure was grouped into four analytical segments:

| Tenure Group | Range |
|---|---:|
| 0-12 meses | 0–12 months |
| 13-24 meses | 13–24 months |
| 25-48 meses | 25–48 months |
| 49-72 meses | 49–72 months |

These groups were used throughout the SQL and Power BI analysis.

## 6.4 Exploratory Analysis

Python was also used to examine churn across several variables, including:

- Tenure groups
- Contract types
- Payment methods
- Internet services
- Technical support
- Other subscribed services
- Monthly charges

Plotly was used to create exploratory visualizations and evaluate the distribution of churn across different customer segments.

---

# 7. SQL Server Data Model

After the Python preparation stage, the cleaned dataset was loaded into SQL Server.

The analytical database is named:

```text
CustomerChurnDW
```

The database uses a **Star Schema** designed for analytical reporting.

## 7.1 Staging Layer

The staging table is:

```text
dbo.StgCustomerChurn
```

This table stores the prepared source data before it is loaded into the dimensional model.

The staging layer also allows data validation to be performed before inserting records into the analytical fact and dimension tables.

---

# 8. Dimensional Model

The analytical model consists of one fact table and four dimensions.

## Fact Table

```text
dbo.FactCustomerChurn
```

The fact table contains one record per customer.

Important fields include:

- `CustomerChurnKey`
- `customerID`
- `TenureKey`
- `ContractKey`
- `PaymentKey`
- `ServiceKey`
- `TenureMonths`
- `MonthlyCharges`
- `TotalCharges`
- `Churn_Flag`

The `customerID` field is unique within the fact table.

## Dimension Tables

### DimTenure

```text
dbo.DimTenure
```

Contains the four tenure groups and their analytical sort order.

Important fields:

- `TenureKey`
- `TenureGroup`
- `GroupSortOrder`

### DimContract

```text
dbo.DimContract
```

Contains the available contract types:

- Month-to-month
- One year
- Two year

Important fields:

- `ContractKey`
- `ContractName`
- `SortOrder`

### DimPayment

```text
dbo.DimPayment
```

Contains the available payment methods.

Important fields:

- `PaymentKey`
- `PaymentMethod`

### DimService

```text
dbo.DimService
```

Contains the customer's service profile.

The dimension includes:

- `PhoneService`
- `MultipleLines`
- `InternetService`
- `OnlineSecurity`
- `OnlineBackup`
- `DeviceProtection`
- `TechSupport`
- `StreamingTV`
- `StreamingMovies`

This design allows service combinations to be analyzed without creating a separate dimension for every individual service attribute.

---

# 9. Star Schema Relationships

The Power BI model follows the same dimensional structure created in SQL Server.

The relationships are:

```text
DimTenure[TenureKey]
        │
        │ 1 : *
        ▼
FactCustomerChurn[TenureKey]


DimContract[ContractKey]
        │
        │ 1 : *
        ▼
FactCustomerChurn[ContractKey]


DimPayment[PaymentKey]
        │
        │ 1 : *
        ▼
FactCustomerChurn[PaymentKey]


DimService[ServiceKey]
        │
        │ 1 : *
        ▼
FactCustomerChurn[ServiceKey]
```

The relationships use a single-direction filter from the dimensions to the fact table.

---

# 10. Power BI Analytical Model

Power BI was connected to the SQL Server dimensional model using the **Import** storage mode.

This approach was selected because the dataset is relatively small and the project does not require real-time data.

The model provides the foundation for the interactive dashboard and DAX calculations.

---

# 11. DAX Measures

The main analytical measures created in Power BI are:

## Total Customers

```dax
Total Customers =
COUNTROWS(FactCustomerChurn)
```

Counts the total number of customer records within the current filter context.

## Churned Customers

```dax
Churned Customers =
CALCULATE(
    [Total Customers],
    FactCustomerChurn[Churn_Flag] = TRUE()
)
```

Calculates the number of customers who churned.

## Retained Customers

```dax
Retained Customers =
CALCULATE(
    [Total Customers],
    FactCustomerChurn[Churn_Flag] = FALSE()
)
```

Calculates the number of retained customers.

## Churn Rate

```dax
Churn Rate % =
DIVIDE(
    [Churned Customers],
    [Total Customers],
    0
)
```

Measures the proportion of customers who churned.

## Retention Rate

```dax
Retention Rate % =
DIVIDE(
    [Retained Customers],
    [Total Customers],
    0
)
```

Measures the proportion of customers who remained active.

## Average Monthly Charges

```dax
Average Monthly Charges =
AVERAGE(FactCustomerChurn[MonthlyCharges])
```

Calculates the average monthly charge within the current filter context.

## Average Tenure

```dax
Average Tenure =
AVERAGE(FactCustomerChurn[TenureMonths])
```

Calculates the average customer tenure.

Additional display-only measures were created for the KPI cards where necessary to control the visual presentation of integer values.

---

# 12. Power BI Dashboard

The final dashboard is designed as an interactive customer churn and retention analysis report.

## KPI Cards

The dashboard contains four primary KPI cards:

- Total Customers
- Churn Rate
- Retention Rate
- Churned Customers

These provide an immediate overview of the customer base and its observed retention performance.

---

# 13. Churn by Tenure

A clustered column chart was created using:

**Axis**

```text
DimTenure[TenureGroup]
```

**Value**

```text
[Churn Rate %]
```

The visualization compares observed churn rates across the four tenure-based customer segments.

This allows the business to identify whether churn is concentrated among newer or more established customers.

---

# 14. Churn by Contract

A clustered column chart compares churn rates across contract types.

The visualization uses:

```text
DimContract[ContractName]
```

and:

```text
[Churn Rate %]
```

The analysis allows the business to identify differences in observed churn between month-to-month, one-year, and two-year contracts.

---

# 15. Churn by Payment Method

A clustered column chart analyzes churn rates according to payment method.

The visualization uses:

```text
DimPayment[PaymentMethod]
```

and:

```text
[Churn Rate %]
```

This analysis helps identify payment segments associated with higher observed churn.

The results should be interpreted as associations rather than evidence that the payment method itself causes customer churn.

---

# 16. Service Risk Analysis

A matrix visualization was created to analyze churn rates according to the combination of:

**Rows**

```text
DimService[InternetService]
```

**Columns**

```text
DimService[TechSupport]
```

**Values**

```text
[Churn Rate %]
```

Conditional formatting is used to create a heatmap effect.

Higher churn rates are represented as higher-risk segments, while lower churn rates represent comparatively lower observed churn.

This analysis is particularly useful for evaluating combinations such as:

- Fiber optic + no technical support
- Fiber optic + technical support
- DSL + no technical support
- DSL + technical support

The analysis identifies segments with different observed churn levels without assuming a causal relationship between the service configuration and churn.

---

# 17. Retention Rate by Tenure and Contract

A retention matrix was created to examine the interaction between customer tenure and contract type.

**Rows**

```text
DimTenure[TenureGroup]
```

**Columns**

```text
DimContract[ContractName]
```

**Values**

```text
[Retention Rate %]
```

Conditional formatting provides a heatmap representation of retention levels.

This allows the analysis to identify combinations of tenure and contract type associated with higher or lower observed retention.

---

# 18. Interactive Filters

The dashboard includes interactive slicers for:

- Contract
- Payment Method
- Internet Service

These filters allow users to dynamically segment the analysis and observe how churn and retention metrics change across different customer groups.

Because the dashboard is based on a dimensional model, filters propagate through the corresponding dimension-to-fact relationships.

---

# 19. Key Business Insights

The final dashboard highlights several important patterns in the customer base.

## Customer Tenure

The analysis shows that churn is substantially higher among customers in the earliest tenure group.

As customer tenure increases, the observed churn rate decreases.

This indicates that **early customer lifecycle stages represent an important retention opportunity**.

## Contract Type

Month-to-month customers show considerably higher observed churn than customers with longer-term contracts.

Longer contractual commitments are associated with stronger observed retention.

This suggests that contract structure should be considered when designing customer retention strategies.

## Payment Method

Payment methods show noticeable differences in observed churn rates.

The segment using **electronic check** presents a substantially higher churn rate than the automatic payment methods analyzed.

This should be treated as a customer segment association rather than direct evidence that the payment method causes churn.

## Internet Service and Technical Support

The service analysis shows meaningful differences in churn depending on the combination of internet service and technical support.

The heatmap allows high-churn service combinations to be identified and investigated further.

## Retention by Tenure and Contract

The retention matrix demonstrates that retention varies according to both customer tenure and contract type.

Longer-tenure and longer-term contract segments generally show stronger observed retention.

---

# 20. Business Recommendations

Based on the observed patterns, the following actions could be considered:

### 1. Focus on early-tenure customers

Develop stronger onboarding and early-lifecycle engagement programs for customers during their first year.

Potential actions include:

- Proactive customer support.
- Onboarding communications.
- Service follow-ups.
- Early satisfaction monitoring.

### 2. Encourage longer-term contracts

Evaluate incentives that encourage customers to move from month-to-month contracts toward longer-term agreements.

Potential strategies could include:

- Contract renewal incentives.
- Discounts for longer commitments.
- Bundled service offers.
- Loyalty benefits.

### 3. Investigate high-churn payment segments

Customers using higher-churn payment methods could be investigated to understand whether there are operational, behavioral, or customer-experience differences associated with those payment methods.

### 4. Review high-risk service combinations

High-churn combinations identified in the service heatmap should be investigated further.

Technical support availability, service quality, pricing, and customer experience could be examined before implementing retention interventions.

### 5. Prioritize retention based on customer segment

Rather than applying the same retention strategy to the entire customer base, the company could prioritize segments based on their observed churn and retention characteristics.

---

# 21. Limitations

Several limitations should be considered when interpreting the results.

### Cross-sectional dataset

The dataset represents a customer snapshot rather than a complete longitudinal history.

Therefore, the analysis describes observed churn patterns rather than customer retention trajectories over time.

### No causal inference

A higher churn rate within a segment does not demonstrate that the corresponding characteristic causes churn.

For example, observing higher churn among customers with a particular payment method does not mean that payment method is necessarily the cause.

### No predictive modeling

The project does not include a machine learning model to predict future individual customer churn.

The analysis is focused on descriptive and diagnostic Business Intelligence.

### No future churn forecast

The dataset does not provide sufficient monthly historical information to construct a reliable forecast of future monthly churn.

---

# 22. Project Outcome

The project demonstrates an end-to-end Business Intelligence workflow:

```text
Data Source
     ↓
Python
     ↓
Data Cleaning & Validation
     ↓
Feature Engineering
     ↓
SQL Server
     ↓
Star Schema
     ↓
Power BI
     ↓
DAX Measures
     ↓
Interactive Dashboard
     ↓
Business Insights
```

The final result is an interactive dashboard that allows users to explore customer churn and retention across multiple customer segments.

The project demonstrates practical skills in:

- Data cleaning
- Exploratory data analysis
- Python
- Pandas
- SQL
- SQL Server
- Dimensional modeling
- Star schema design
- DAX
- Power BI
- Data visualization
- Customer segmentation
- Business analysis
- Data-driven recommendations

---

# 23. Repository Structure

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

The repository structure may evolve as the project is maintained.

---

# 24. Project Status

**Completed**

- [x] Dataset selection and exploration
- [x] Data cleaning and validation in Python
- [x] Feature engineering
- [x] Exploratory churn analysis
- [x] Clean dataset export
- [x] SQL Server environment configuration
- [x] SQL Server connection setup
- [x] Dimensional data modeling
- [x] Star schema implementation
- [x] Data loading and validation
- [x] Power BI data model
- [x] DAX measures
- [x] KPI development
- [x] Churn analysis dashboard
- [x] Retention analysis
- [x] Interactive filters
- [x] Heatmap visualizations
- [x] Business insights
- [x] Retention recommendations
- [x] Technical documentation

---

# 25. Expected Deliverables

The completed project provides:

- Cleaned and validated customer dataset.
- Python data preparation and analysis script.
- SQL Server analytical database.
- Dimensional Star Schema.
- SQL analytical queries.
- Power BI data model.
- DAX analytical measures.
- Interactive customer churn dashboard.
- Customer retention analysis.
- Business insights and recommendations.
- Technical project documentation.

---

# 26. Conclusion

**Customer Cohort & Churn Analytics** demonstrates how customer-level data can be transformed into actionable business information through an end-to-end Business Intelligence workflow.

The combination of Python for data preparation and exploration, SQL Server for structured analytical modeling, and Power BI for interactive reporting provides a complete analytical solution.

The final dashboard enables stakeholders to identify customer segments with different churn and retention patterns, with particular attention to customer tenure, contract type, payment method, and service configuration.

The project focuses on understanding **what happened and which customer segments behave differently**, providing a foundation for future retention initiatives and more advanced analytical projects.
