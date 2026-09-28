ALTER TABLE data_mart.fact_order
    ADD COLUMN order_approved_at TIMESTAMP,
    ADD COLUMN order_delivered_carrier_date TIMESTAMP;