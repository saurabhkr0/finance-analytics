import streamlit as st
import pandas as pd
from datetime import timedelta

st.set_page_config(
    page_title="Finance Analytics Dashboard",
    page_icon=":bar_chart:",
    layout="wide",
)

st.title("Finance Analytics Dashboard")

conn = st.connection("snowflake")


@st.cache_data(ttl=timedelta(minutes=10))
def load_kpis():
    return conn.query("""
        SELECT
            (SELECT COUNT(*) FROM FINANCE_DEMO.RAW.TRANSACTIONS) AS total_transactions,
            (SELECT COUNT(*) FROM FINANCE_DEMO.RAW.CUSTOMERS) AS total_customers,
            (SELECT COUNT(*) FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS) AS total_alerts,
            (SELECT SUM(AMOUNT) FROM FINANCE_DEMO.RAW.TRANSACTIONS WHERE AMOUNT > 0) AS total_volume
    """)


@st.cache_data(ttl=timedelta(minutes=10))
def load_transaction_trends():
    return conn.query("""
        SELECT
            DATE_TRUNC('MONTH', TRANSACTION_DATE) AS month,
            COUNT(*) AS transaction_count,
            SUM(CASE WHEN AMOUNT > 0 THEN AMOUNT ELSE 0 END) AS total_amount
        FROM FINANCE_DEMO.RAW.TRANSACTIONS
        GROUP BY 1
        ORDER BY 1
    """)


@st.cache_data(ttl=timedelta(minutes=10))
def load_alert_breakdown():
    return conn.query("""
        SELECT
            ALERT_TYPE,
            SEVERITY,
            STATUS,
            COUNT(*) AS alert_count
        FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
        GROUP BY 1, 2, 3
        ORDER BY alert_count DESC
    """)


@st.cache_data(ttl=timedelta(minutes=10))
def load_customer_risk():
    return conn.query("""
        SELECT
            c.RISK_RATING,
            c.CLIENT_SEGMENT,
            COUNT(DISTINCT c.CUSTOMER_ID) AS customer_count,
            COALESCE(SUM(a.alert_count), 0) AS total_alerts
        FROM FINANCE_DEMO.RAW.CUSTOMERS c
        LEFT JOIN (
            SELECT CUSTOMER_ID, COUNT(*) AS alert_count
            FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
            GROUP BY CUSTOMER_ID
        ) a ON c.CUSTOMER_ID = a.CUSTOMER_ID
        GROUP BY 1, 2
        ORDER BY total_alerts DESC
    """)


@st.cache_data(ttl=timedelta(minutes=10))
def load_alert_trend():
    return conn.query("""
        SELECT
            DATE_TRUNC('MONTH', ALERT_DATE) AS month,
            SEVERITY,
            COUNT(*) AS alert_count
        FROM FINANCE_DEMO.RAW.COMPLIANCE_ALERTS
        GROUP BY 1, 2
        ORDER BY 1
    """)


# --- Sidebar Filters ---
with st.sidebar:
    st.header("Filters")
    alert_data_raw = load_alert_breakdown()
    all_severities = sorted(alert_data_raw["SEVERITY"].unique().tolist())
    selected_severities = st.multiselect(
        "Alert Severity", all_severities, default=all_severities
    )
    all_segments = sorted(load_customer_risk()["CLIENT_SEGMENT"].unique().tolist())
    selected_segments = st.multiselect(
        "Client Segment", all_segments, default=all_segments
    )

# --- KPI Row ---
kpis = load_kpis()

with st.container(horizontal=True):
    st.metric(
        "Total Transactions",
        f"{int(kpis['TOTAL_TRANSACTIONS'].iloc[0]):,}",
        border=True,
    )
    st.metric(
        "Total Customers",
        f"{int(kpis['TOTAL_CUSTOMERS'].iloc[0]):,}",
        border=True,
    )
    st.metric(
        "Compliance Alerts",
        f"{int(kpis['TOTAL_ALERTS'].iloc[0]):,}",
        border=True,
    )
    st.metric(
        "Transaction Volume",
        f"${kpis['TOTAL_VOLUME'].iloc[0]:,.0f}",
        border=True,
    )

# --- Transaction Volume Trends ---
st.subheader("Transaction Volume Trends")

txn_trends = load_transaction_trends()
txn_trends["MONTH"] = pd.to_datetime(txn_trends["MONTH"])

col1, col2 = st.columns(2)

with col1:
    with st.container(border=True):
        st.markdown("**Monthly Transaction Count**")
        st.bar_chart(
            txn_trends,
            x="MONTH",
            y="TRANSACTION_COUNT",
            x_label="Month",
            y_label="Transactions",
        )

with col2:
    with st.container(border=True):
        st.markdown("**Monthly Transaction Amount**")
        st.line_chart(
            txn_trends,
            x="MONTH",
            y="TOTAL_AMOUNT",
            x_label="Month",
            y_label="Amount ($)",
        )

# --- Compliance Alert Breakdown ---
st.subheader("Compliance Alert Breakdown")

alert_data = alert_data_raw[alert_data_raw["SEVERITY"].isin(selected_severities)]

col3, col4 = st.columns(2)

with col3:
    with st.container(border=True):
        st.markdown("**Alerts by Type**")
        by_type = alert_data.groupby("ALERT_TYPE", as_index=False)["ALERT_COUNT"].sum()
        by_type = by_type.sort_values("ALERT_COUNT", ascending=False)
        st.bar_chart(by_type, x="ALERT_TYPE", y="ALERT_COUNT", horizontal=True)

with col4:
    with st.container(border=True):
        st.markdown("**Alerts by Severity**")
        by_severity = (
            alert_data.groupby("SEVERITY", as_index=False)["ALERT_COUNT"].sum()
        )
        st.bar_chart(by_severity, x="SEVERITY", y="ALERT_COUNT")

with st.container(border=True):
    st.markdown("**Alert Status Distribution**")
    by_status = alert_data.groupby("STATUS", as_index=False)["ALERT_COUNT"].sum()
    by_status = by_status.sort_values("ALERT_COUNT", ascending=False)
    st.bar_chart(by_status, x="STATUS", y="ALERT_COUNT")

# --- Alert Trend Over Time ---
st.subheader("Alert Trend Over Time")

alert_trend = load_alert_trend()
alert_trend = alert_trend[alert_trend["SEVERITY"].isin(selected_severities)]
alert_trend["MONTH"] = pd.to_datetime(alert_trend["MONTH"])

with st.container(border=True):
    pivot_alerts = alert_trend.pivot_table(
        index="MONTH", columns="SEVERITY", values="ALERT_COUNT", fill_value=0
    ).reset_index()
    severity_cols = [c for c in pivot_alerts.columns if c != "MONTH"]
    if severity_cols:
        st.line_chart(pivot_alerts, x="MONTH", y=severity_cols)

# --- Customer Risk Distribution ---
st.subheader("Customer Risk Distribution")

risk_data = load_customer_risk()
risk_data = risk_data[risk_data["CLIENT_SEGMENT"].isin(selected_segments)]

col5, col6 = st.columns(2)

with col5:
    with st.container(border=True):
        st.markdown("**Customers by Risk Rating**")
        by_risk = risk_data.groupby("RISK_RATING", as_index=False)[
            "CUSTOMER_COUNT"
        ].sum()
        st.bar_chart(by_risk, x="RISK_RATING", y="CUSTOMER_COUNT")

with col6:
    with st.container(border=True):
        st.markdown("**Customers by Segment**")
        by_segment = risk_data.groupby("CLIENT_SEGMENT", as_index=False)[
            "CUSTOMER_COUNT"
        ].sum()
        st.bar_chart(by_segment, x="CLIENT_SEGMENT", y="CUSTOMER_COUNT")

with st.container(border=True):
    st.markdown("**Alerts per Segment & Risk Rating**")
    pivot_risk = risk_data.pivot_table(
        index="CLIENT_SEGMENT",
        columns="RISK_RATING",
        values="TOTAL_ALERTS",
        fill_value=0,
        aggfunc="sum",
    ).reset_index()
    risk_cols = [c for c in pivot_risk.columns if c != "CLIENT_SEGMENT"]
    st.bar_chart(pivot_risk, x="CLIENT_SEGMENT", y=risk_cols)
