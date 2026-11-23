# 1. Imports
from pathlib import Path

import pandas as pd
import plotly.express as px


DATA_FILE = "telco_customer_churn.csv"
TENURE_GROUPS = ["0-12 meses", "13-24 meses", "25-48 meses", "49-72 meses"]
CONTRACT_ORDER = ["Month-to-month", "One year", "Two year"]
CHURN_ORDER = ["No", "Yes"]
SERVICE_COLUMNS = [
    "PhoneService",
    "MultipleLines",
    "InternetService",
    "OnlineSecurity",
    "OnlineBackup",
    "DeviceProtection",
    "TechSupport",
    "StreamingTV",
    "StreamingMovies",
]
REQUIRED_COLUMNS = [
    "customerID",
    "tenure",
    "Churn",
    "Contract",
    "PaymentMethod",
    "InternetService",
    "TechSupport",
    "MonthlyCharges",
    "TotalCharges",
    *SERVICE_COLUMNS,
]
RATE_COLUMNS = ["Churn Rate", "Retention Rate"]


def summarize_by(data, group_columns):
    if isinstance(group_columns, str):
        group_columns = [group_columns]

    summary = (
        data.groupby(group_columns, observed=True, dropna=False)
        .agg(
            Customers=("Churn_Flag", "size"),
            Churned_Customers=("Churn_Flag", "sum"),
        )
        .reset_index()
        .rename(columns={"Churned_Customers": "Churned Customers"})
    )
    summary["Churn Rate"] = summary["Churned Customers"] / summary["Customers"]
    summary["Retention Rate"] = 1 - summary["Churn Rate"]
    return summary


def summarize_segment(data):
    customers = len(data)
    churned_customers = int(data["Churn_Flag"].sum())
    churn_rate = churned_customers / customers if customers else float("nan")
    return pd.DataFrame(
        [
            {
                "Customers": customers,
                "Churned Customers": churned_customers,
                "Churn Rate": churn_rate,
                "Retention Rate": 1 - churn_rate,
            }
        ]
    )


def format_rate_table(table):
    formatted = table.copy()
    for column in RATE_COLUMNS:
        if column in formatted.columns:
            formatted[column] = formatted[column].map(
                lambda rate: f"{rate:.1%}" if pd.notna(rate) else "N/A"
            )
    return formatted


def create_churn_rate_chart(summary, group_column, title, x_title):
    figure = px.bar(
        summary,
        x=group_column,
        y="Churn Rate",
        text="Churn Rate",
        hover_data={
            "Customers": True,
            "Churned Customers": True,
            "Churn Rate": ":.1%",
            "Retention Rate": ":.1%",
        },
        title=title,
        labels={
            group_column: x_title,
            "Churn Rate": "Observed churn rate",
        },
    )
    figure.update_traces(
        texttemplate="%{text:.1%}",
        textposition="outside",
        cliponaxis=False,
    )
    figure.update_yaxes(
        title="Observed churn rate",
        tickformat=".0%",
        range=[0, 1.08],
    )
    figure.update_layout(template="plotly_white")
    return figure


def main():
    # 2. Load Dataset
    dataset_path = Path(__file__).resolve().parent / DATA_FILE
    if not dataset_path.is_file():
        raise FileNotFoundError(f"Dataset not found: {dataset_path}")

    df = pd.read_csv(dataset_path)
    missing_columns = sorted(set(REQUIRED_COLUMNS) - set(df.columns))
    if missing_columns:
        raise ValueError(f"Required dataset columns are missing: {missing_columns}")

    # 3. Data Understanding
    print("=== Data Understanding ===")
    print("Each row represents one customer and their current services and churn status.")
    print(f"Dataset shape: {df.shape[0]} customers x {df.shape[1]} columns")
    print("\nData types:")
    print(df.dtypes.to_string())

    # 4. Data Quality & Cleaning
    print("\n=== Data Quality & Cleaning ===")
    print(f"Fully duplicated rows: {df.duplicated().sum()}")
    duplicate_customer_ids = df["customerID"].duplicated(keep=False)
    print(f"Rows with duplicated customerID: {duplicate_customer_ids.sum()}")
    if duplicate_customer_ids.any():
        print("Duplicate customer records are retained and should be reviewed:")
        print(
            df.loc[duplicate_customer_ids, ["customerID", "Churn", "tenure"]]
            .sort_values("customerID")
            .to_string(index=False)
        )

    raw_total_charges = df["TotalCharges"].astype("string").str.strip()
    empty_total_charges = (
        raw_total_charges.isna() | raw_total_charges.eq("").fillna(False)
    )
    numeric_total_charges = pd.to_numeric(
        raw_total_charges.replace("", pd.NA),
        errors="coerce",
    )
    invalid_total_charges = numeric_total_charges.isna() & ~empty_total_charges
    df["TotalCharges"] = numeric_total_charges

    print(f"Blank TotalCharges records retained as null: {empty_total_charges.sum()}")
    print(f"Nonblank, nonnumeric TotalCharges values: {invalid_total_charges.sum()}")
    if empty_total_charges.any():
        blank_charge_records = df.loc[empty_total_charges]
        print(
            "Blank TotalCharges by tenure:\n"
            f"{blank_charge_records['tenure'].value_counts(dropna=False).to_string()}"
        )
        print(
            "Churn status of blank TotalCharges records:\n"
            f"{blank_charge_records['Churn'].value_counts(dropna=False).to_string()}"
        )
    print("\nNull values after cleaning:")
    print(df.isna().sum().to_string())

    # 5. Feature Engineering
    print("\n=== Feature Engineering ===")
    invalid_churn_values = sorted(set(df["Churn"].dropna()) - set(CHURN_ORDER))
    if df["Churn"].isna().any() or invalid_churn_values:
        raise ValueError(f"Unexpected or missing Churn values: {invalid_churn_values}")
    df["Churn_Flag"] = df["Churn"].map({"No": 0, "Yes": 1}).astype("int8")

    df["tenure"] = pd.to_numeric(df["tenure"], errors="coerce")
    if df["tenure"].isna().any() or not df["tenure"].between(0, 72).all():
        raise ValueError("Tenure must contain valid values from 0 to 72 months.")
    df["MonthlyCharges"] = pd.to_numeric(df["MonthlyCharges"], errors="coerce")
    if df["MonthlyCharges"].isna().any():
        raise ValueError("MonthlyCharges contains missing or nonnumeric values.")

    df["Tenure_Group"] = pd.cut(
        df["tenure"],
        bins=[0, 12, 24, 48, 72],
        labels=TENURE_GROUPS,
        include_lowest=True,
        ordered=True,
    )
    df["Contract"] = pd.Categorical(
        df["Contract"],
        categories=CONTRACT_ORDER,
        ordered=True,
    )
    df["Churn"] = pd.Categorical(
        df["Churn"],
        categories=CHURN_ORDER,
        ordered=True,
    )
    if df["Tenure_Group"].isna().any() or df["Contract"].isna().any():
        raise ValueError("Some customers could not be assigned to a tenure group or contract.")

    # 6. Baseline Churn
    print("\n=== Baseline Churn ===")
    total_customers = len(df)
    churned_customers = int(df["Churn_Flag"].sum())
    baseline_churn_rate = churned_customers / total_customers
    baseline_retention_rate = 1 - baseline_churn_rate
    baseline_summary = pd.DataFrame(
        [
            {
                "Customers": total_customers,
                "Churned Customers": churned_customers,
                "Churn Rate": baseline_churn_rate,
                "Retention Rate": baseline_retention_rate,
            }
        ]
    )
    print(format_rate_table(baseline_summary).to_string(index=False))

    baseline_chart_data = pd.DataFrame(
        {
            "Customer outcome": ["Retained", "Churned"],
            "Customers": [
                total_customers - churned_customers,
                churned_customers,
            ],
        }
    )
    fig_baseline = px.pie(
        baseline_chart_data,
        names="Customer outcome",
        values="Customers",
        hole=0.48,
        title="Baseline Customer Churn (Observed)",
        color="Customer outcome",
        color_discrete_map={"Retained": "#2E8B57", "Churned": "#C0392B"},
        labels={"Customers": "Customers"},
    )
    fig_baseline.update_traces(textinfo="label+percent")
    fig_baseline.update_layout(template="plotly_white")
    fig_baseline.show()

    # 7. Tenure & Contract Analysis
    print("\n=== Tenure & Contract Analysis ===")
    tenure_summary = summarize_by(df, "Tenure_Group")
    print("\nTenure cohorts:")
    print(format_rate_table(tenure_summary).to_string(index=False))
    create_churn_rate_chart(
        tenure_summary,
        "Tenure_Group",
        "Observed Churn Rate by Tenure Cohort",
        "Tenure cohort",
    ).show()

    contract_summary = summarize_by(df, "Contract")
    print("\nContract types:")
    print(format_rate_table(contract_summary).to_string(index=False))
    create_churn_rate_chart(
        contract_summary,
        "Contract",
        "Observed Churn Rate by Contract Type",
        "Contract type",
    ).show()

    # 8. Payment Method Analysis
    print("\n=== Payment Method Analysis ===")
    payment_summary = summarize_by(df, "PaymentMethod").sort_values(
        "Churn Rate",
        ascending=False,
    )
    print(format_rate_table(payment_summary).to_string(index=False))
    create_churn_rate_chart(
        payment_summary,
        "PaymentMethod",
        "Observed Churn Rate by Payment Method",
        "Payment method",
    ).show()

    # 9. Service Analysis
    print("\n=== Service Analysis ===")
    services_long = df.melt(
        id_vars="Churn_Flag",
        value_vars=SERVICE_COLUMNS,
        var_name="Service",
        value_name="Service Status",
    )
    service_summary = summarize_by(
        services_long,
        ["Service", "Service Status"],
    )
    print(format_rate_table(service_summary).to_string(index=False))
    fig_services = px.bar(
        service_summary,
        x="Service",
        y="Churn Rate",
        color="Service Status",
        barmode="group",
        hover_data={
            "Customers": True,
            "Churned Customers": True,
            "Churn Rate": ":.1%",
            "Retention Rate": ":.1%",
        },
        title="Observed Churn Rate by Service and Subscription Status",
        labels={
            "Service": "Service",
            "Service Status": "Subscription status",
            "Churn Rate": "Observed churn rate",
        },
    )
    fig_services.update_yaxes(
        title="Observed churn rate",
        tickformat=".0%",
        range=[0, 1.08],
    )
    fig_services.update_layout(template="plotly_white")
    fig_services.show()

    # 10. Monthly Charges Analysis
    print("\n=== Monthly Charges Analysis ===")
    monthly_charges_summary = (
        df.groupby("Churn", observed=True)
        .agg(
            Customers=("MonthlyCharges", "size"),
            Mean_Monthly_Charges=("MonthlyCharges", "mean"),
            Median_Monthly_Charges=("MonthlyCharges", "median"),
        )
        .reset_index()
        .rename(
            columns={
                "Customers": "Customer Count",
                "Mean_Monthly_Charges": "Mean Monthly Charges",
                "Median_Monthly_Charges": "Median Monthly Charges",
            }
        )
    )
    print(monthly_charges_summary.to_string(index=False, float_format=lambda x: f"{x:,.2f}"))

    fig_monthly_charges = px.box(
        df,
        x="Churn",
        y="MonthlyCharges",
        color="Churn",
        points="outliers",
        category_orders={"Churn": CHURN_ORDER},
        title="Monthly Charges by Churn Status",
        labels={
            "Churn": "Churned customer",
            "MonthlyCharges": "Monthly charges (dataset units)",
        },
    )
    fig_monthly_charges.update_layout(template="plotly_white")
    fig_monthly_charges.show()

    # 11. High-Risk Segment Analysis
    print("\n=== High-Risk Segment Analysis ===")
    high_risk_mask = (
        df["InternetService"].eq("Fiber optic")
        & df["TechSupport"].eq("No")
    )
    high_risk_customers = df.loc[high_risk_mask]
    high_risk_summary = summarize_segment(high_risk_customers)
    print("InternetService = Fiber optic and TechSupport = No:")
    print(format_rate_table(high_risk_summary).to_string(index=False))

    internet_support_summary = summarize_by(
        df,
        ["InternetService", "TechSupport"],
    )
    target_segment = internet_support_summary.loc[
        internet_support_summary["InternetService"].eq("Fiber optic")
        & internet_support_summary["TechSupport"].eq("No")
    ]
    if target_segment.empty:
        highest_service_segment = None
        print("The target segment is not present; its churn rate cannot be compared.")
    else:
        highest_service_segment = internet_support_summary.sort_values(
            "Churn Rate",
            ascending=False,
        ).iloc[0]
        target_rate = target_segment["Churn Rate"].iloc[0]
        highest_rate = highest_service_segment["Churn Rate"]
        top_segment_count = internet_support_summary["Churn Rate"].eq(highest_rate).sum()
        if target_rate == highest_rate and top_segment_count > 1:
            comparison = "The target segment is tied for the highest observed churn rate."
        elif target_rate == highest_rate:
            comparison = "The target segment has the highest observed churn rate."
        else:
            comparison = "The target segment does not have the highest observed churn rate."
        print(
            f"{comparison} Highest InternetService + TechSupport segment: "
            f"{highest_service_segment['InternetService']} / "
            f"{highest_service_segment['TechSupport']} "
            f"({highest_rate:.1%}; {int(highest_service_segment['Customers'])} customers)."
        )

    high_risk_chart_data = pd.DataFrame(
        {
            "Observed outcome rate": ["Churn rate", "Retention rate"],
            "Rate": [
                high_risk_summary["Churn Rate"].iloc[0],
                high_risk_summary["Retention Rate"].iloc[0],
            ],
        }
    )
    fig_high_risk = px.bar(
        high_risk_chart_data,
        x="Observed outcome rate",
        y="Rate",
        color="Observed outcome rate",
        text="Rate",
        title="High-Risk Segment: Fiber Optic + No Tech Support",
        labels={
            "Observed outcome rate": "Observed outcome",
            "Rate": "Observed customer rate",
        },
        color_discrete_map={
            "Churn rate": "#C0392B",
            "Retention rate": "#2E8B57",
        },
    )
    fig_high_risk.update_traces(
        texttemplate="%{text:.1%}",
        textposition="outside",
        cliponaxis=False,
    )
    fig_high_risk.update_yaxes(
        title="Observed customer rate",
        tickformat=".0%",
        range=[0, 1.08],
    )
    fig_high_risk.update_layout(template="plotly_white")

    # 12. Cohort Retention Matrix
    print("\n=== Cohort Retention Matrix ===")
    cohort_contract_summary = summarize_by(df, ["Tenure_Group", "Contract"])
    retention_matrix = (
        cohort_contract_summary.pivot(
            index="Tenure_Group",
            columns="Contract",
            values="Retention Rate",
        )
        .reindex(index=TENURE_GROUPS, columns=CONTRACT_ORDER)
    )
    churn_matrix = (
        cohort_contract_summary.pivot(
            index="Tenure_Group",
            columns="Contract",
            values="Churn Rate",
        )
        .reindex(index=TENURE_GROUPS, columns=CONTRACT_ORDER)
    )
    retention_matrix.index.name = "Tenure_Group"
    retention_matrix.columns.name = "Contract"
    churn_matrix.index.name = "Tenure_Group"
    churn_matrix.columns.name = "Contract"

    print("Retention rate matrix:")
    print(
        retention_matrix.apply(
            lambda column: column.map(
                lambda rate: f"{rate:.1%}" if pd.notna(rate) else "N/A"
            )
        ).to_string()
    )
    print("Churn rate matrix (validation metric):")
    print(
        churn_matrix.apply(
            lambda column: column.map(
                lambda rate: f"{rate:.1%}" if pd.notna(rate) else "N/A"
            )
        ).to_string()
    )

    fig_retention_matrix = px.imshow(
        retention_matrix,
        text_auto=".1%",
        aspect="auto",
        color_continuous_scale="RdYlGn",
        zmin=0,
        zmax=1,
        title="Observed Retention Rate by Tenure Cohort and Contract",
        labels={
            "x": "Contract type",
            "y": "Tenure cohort",
            "color": "Retention rate",
        },
    )
    fig_retention_matrix.update_xaxes(side="top")
    fig_retention_matrix.update_layout(
        template="plotly_white",
        coloraxis_colorbar_tickformat=".0%",
    )
    fig_retention_matrix.show()

    # 13. Final Results
    print("\n=== Final Results ===")
    print(
        f"Baseline observed churn: {baseline_churn_rate:.1%}; "
        f"retention: {baseline_retention_rate:.1%} "
        f"({churned_customers} churned of {total_customers} customers)."
    )
    print(
        f"High-risk segment size: {len(high_risk_customers)}; "
        f"observed churn: {high_risk_summary['Churn Rate'].iloc[0]:.1%}; "
        f"observed retention: {high_risk_summary['Retention Rate'].iloc[0]:.1%}."
    )
    print(
        "\nMethodology: churn rates describe observed outcomes in this dataset, "
        "not predictive probabilities. The snapshot has no acquisition dates or "
        "customer-period history, so the retention matrix compares current tenure "
        "cohorts and contract types; it is not a longitudinal cohort-retention curve."
    )
    print(
        f"TotalCharges remains numeric with {df['TotalCharges'].isna().sum()} null values; "
        "no values were imputed."
    )
    fig_high_risk.show()


if __name__ == "__main__":
    main()
