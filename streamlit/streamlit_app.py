"""Sales dashboard + "Ask the data" (Cortex Analyst) on GOLD. Runs in Streamlit in Snowflake."""
import json

import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Sales dashboard", layout="wide")
session = get_active_session()
DB = session.get_current_database().strip('"')
FCT = f"{DB}.GOLD.FCT_SALES"
NARRATIVE = f"{DB}.GOLD.DAILY_SALES_NARRATIVE"
SEMANTIC_VIEW = f"{DB}.GOLD.SALES_SV"


@st.cache_data(ttl=600)
def query(sql: str, params: tuple = ()):
    return session.sql(sql, params=list(params)).to_pandas()


st.title("Sales dashboard")
tab_dash, tab_ask = st.tabs(["Dashboard", "Ask the data"])

# --- Dashboard ---------------------------------------------------------------------
with tab_dash:
    bounds = query(f"select min(order_date) lo, max(order_date) hi from {FCT}")
    lo, hi = bounds.iloc[0]["LO"], bounds.iloc[0]["HI"]
    channels_all = query(f"select distinct channel from {FCT} order by 1")["CHANNEL"].tolist()
    statuses_all = query(f"select distinct status from {FCT} order by 1")["STATUS"].tolist()

    with st.sidebar:
        st.header("Filters")
        date_range = st.date_input("Order date", (lo, hi), min_value=lo, max_value=hi)
        channels = st.multiselect("Channel", channels_all, default=channels_all)
        statuses = st.multiselect("Status", statuses_all, default=["completed"])

    if len(date_range) != 2 or not channels or not statuses:
        st.info("Pick a date range, at least one channel and one status.")
        st.stop()

    start, end = date_range
    where = (
        f"order_date between ? and ? "
        f"and channel in ({', '.join('?' * len(channels))}) "
        f"and status in ({', '.join('?' * len(statuses))})"
    )
    params = (str(start), str(end), *channels, *statuses)

    kpi = query(
        f"""select count(*) orders, sum(net_amount) net, sum(margin_amount) margin
            from {FCT} where {where}""",
        params,
    ).iloc[0]
    orders, net, margin = int(kpi["ORDERS"]), float(kpi["NET"] or 0), float(kpi["MARGIN"] or 0)
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Orders", f"{orders:,}")
    c2.metric("Net revenue (AUD)", f"{net:,.0f}")
    c3.metric("Margin %", f"{(margin / net * 100) if net else 0:.1f}%")
    c4.metric("Avg order value", f"{(net / orders) if orders else 0:,.2f}")

    def by(dim: str, measure: str = "sum(net_amount)"):
        return query(
            f"select {dim} as k, {measure} as v from {FCT} where {where} group by 1 order by 1", params
        ).set_index("K")

    left, right = st.columns(2)
    left.subheader("Net revenue by day")
    left.line_chart(by("order_date"))
    right.subheader("Net revenue by hour")
    right.line_chart(by("order_hour"))

    a, b, c = st.columns(3)
    a.subheader("By category")
    a.bar_chart(by("category"))
    b.subheader("Orders by channel")
    b.bar_chart(by("channel", "count(*)"))
    c.subheader("By customer tier")
    c.bar_chart(by("customer_tier"))

    st.subheader("Top 10 products")
    st.dataframe(
        query(
            f"""select product_name, brand, category, sum(quantity) units, sum(net_amount) net_revenue
                from {FCT} where {where} group by all order by net_revenue desc limit 10""",
            params,
        ),
        use_container_width=True,
    )

    # Step 9: AI-written daily summary (table may not exist yet).
    try:
        notes = query(f"select order_date, summary from {NARRATIVE} order by order_date desc")
        st.subheader("Daily summary (Cortex AI)")
        for _, row in notes.iterrows():
            with st.expander(str(row["ORDER_DATE"])):
                st.write(row["SUMMARY"])
    except Exception:
        pass

    fresh = query(f"select count(*) n, max(event_ts) latest from {FCT}").iloc[0]
    st.caption(f"{int(fresh['N']):,} transactions in gold · latest event {fresh['LATEST']}")

# --- Ask the data (Cortex Analyst) ------------------------------------------------------
with tab_ask:
    try:
        import _snowflake  # warehouse runtime only (see snowflake.yml runtime_name)
    except ModuleNotFoundError:
        st.error("Cortex Analyst chat needs the warehouse runtime (`runtime_name: SYSTEM$WAREHOUSE_RUNTIME`).")
        st.stop()

    st.caption(f"Questions are answered by Cortex Analyst using `{SEMANTIC_VIEW}`.")
    if "messages" not in st.session_state:
        st.session_state.messages = []

    def is_read_only(sql: str) -> bool:
        body = "\n".join(l for l in sql.splitlines() if not l.strip().startswith("--")).strip().rstrip(";")
        return body.lower().startswith(("select", "with")) and ";" not in body

    def render(content, key):
        for i, item in enumerate(content):
            if item["type"] == "text":
                st.markdown(item["text"])
            elif item["type"] == "sql":
                stmt = item["statement"]
                with st.expander("SQL", expanded=False):
                    st.code(stmt, language="sql")
                # The app runs with its owner's role: only run a single read-only query.
                if not is_read_only(stmt):
                    st.warning("Generated SQL is not a single SELECT; not executed.")
                    continue
                df = query(stmt)  # cached: reruns don't re-execute history
                st.dataframe(df, use_container_width=True)
                if df.shape[1] == 2 and df.shape[0] > 1:
                    st.bar_chart(df.set_index(df.columns[0]))
            elif item["type"] == "suggestions":
                for j, s in enumerate(item["suggestions"]):
                    if st.button(s, key=f"sug-{key}-{i}-{j}"):
                        st.session_state.pending = s

    for n, m in enumerate(st.session_state.messages):
        with st.chat_message("user" if m["role"] == "user" else "assistant"):
            render(m["content"], n)

    question = st.chat_input("e.g. What was net revenue by channel?") or st.session_state.pop("pending", None)
    if question:
        st.session_state.messages.append({"role": "user", "content": [{"type": "text", "text": question}]})
        resp = _snowflake.send_snow_api_request(
            "POST", "/api/v2/cortex/analyst/message", {}, {},
            {"messages": st.session_state.messages, "semantic_view": SEMANTIC_VIEW},
            None, 50000,
        )
        body = json.loads(resp["content"])
        if resp["status"] >= 400:
            st.error(body)
            st.session_state.messages.pop()
        else:
            st.session_state.messages.append(body["message"])
        st.rerun()
