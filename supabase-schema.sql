-- ============================================================
-- DeryLoan — Supabase Database Schema
-- Run this in your Supabase SQL Editor:
-- https://supabase.com/dashboard/project/eiyexnuhqdscomilwpqg/sql
-- ============================================================

-- CLIENTS
CREATE TABLE IF NOT EXISTS dl_clients (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_no     TEXT UNIQUE NOT NULL,
  full_name     TEXT NOT NULL,
  client_type   TEXT DEFAULT 'Individual' CHECK (client_type IN ('Individual','Group','Company')),
  gender        TEXT,
  dob           DATE,
  district      TEXT,
  address       TEXT,
  phone         TEXT,
  national_id   TEXT,
  occupation    TEXT,
  status        TEXT DEFAULT 'Active' CHECK (status IN ('Active','Inactive','Blacklisted')),
  created_at    TIMESTAMPTZ DEFAULT now()
);

-- LOAN PRODUCTS
CREATE TABLE IF NOT EXISTS dl_loan_products (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                TEXT NOT NULL,
  interest_rate       NUMERIC NOT NULL,
  rate_type           TEXT DEFAULT 'Flat' CHECK (rate_type IN ('Flat','Declining')),
  min_amount          NUMERIC NOT NULL,
  max_amount          NUMERIC NOT NULL,
  max_tenor_months    INT NOT NULL,
  repayment_frequency TEXT DEFAULT 'Monthly',
  is_active           BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- LOANS
CREATE TABLE IF NOT EXISTS dl_loans (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_no             TEXT UNIQUE NOT NULL,
  client_id           uuid REFERENCES dl_clients(id) ON DELETE RESTRICT,
  product_id          uuid REFERENCES dl_loan_products(id),
  principal           NUMERIC NOT NULL,
  interest_rate       NUMERIC NOT NULL,
  tenor_months        INT NOT NULL,
  disbursed_at        DATE,
  maturity_date       DATE,
  outstanding_balance NUMERIC,
  status              TEXT DEFAULT 'Pending' CHECK (status IN ('Pending','Active','Closed','Written Off')),
  officer             TEXT,
  created_at          TIMESTAMPTZ DEFAULT now()
);

-- REPAYMENTS
CREATE TABLE IF NOT EXISTS dl_repayments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id         uuid REFERENCES dl_loans(id) ON DELETE RESTRICT,
  amount          NUMERIC NOT NULL,
  principal_paid  NUMERIC DEFAULT 0,
  interest_paid   NUMERIC DEFAULT 0,
  method          TEXT DEFAULT 'CASH' CHECK (method IN ('CASH','MTN_MOMO','AIRTEL_MONEY','BANK')),
  reference       TEXT,
  paid_at         DATE DEFAULT CURRENT_DATE,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- SAVINGS
CREATE TABLE IF NOT EXISTS dl_savings (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  account_no   TEXT UNIQUE NOT NULL,
  client_id    uuid REFERENCES dl_clients(id) ON DELETE RESTRICT,
  account_type TEXT DEFAULT 'Voluntary' CHECK (account_type IN ('Voluntary','Compulsory','Fixed Deposit')),
  balance      NUMERIC DEFAULT 0,
  status       TEXT DEFAULT 'Active',
  created_at   TIMESTAMPTZ DEFAULT now()
);

-- COLLATERALS
CREATE TABLE IF NOT EXISTS dl_collaterals (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id          uuid REFERENCES dl_loans(id) ON DELETE CASCADE,
  collateral_type  TEXT,
  description      TEXT,
  estimated_value  NUMERIC,
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- ── RLS POLICIES ──────────────────────────────────────────────────────────────
ALTER TABLE dl_clients       ENABLE ROW LEVEL SECURITY;
ALTER TABLE dl_loan_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE dl_loans         ENABLE ROW LEVEL SECURITY;
ALTER TABLE dl_repayments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE dl_savings       ENABLE ROW LEVEL SECURITY;
ALTER TABLE dl_collaterals   ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='allow_all_clients')     THEN CREATE POLICY allow_all_clients     ON dl_clients       FOR ALL USING (true) WITH CHECK (true); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='allow_all_products')    THEN CREATE POLICY allow_all_products    ON dl_loan_products FOR ALL USING (true) WITH CHECK (true); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='allow_all_loans')       THEN CREATE POLICY allow_all_loans       ON dl_loans         FOR ALL USING (true) WITH CHECK (true); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='allow_all_repayments')  THEN CREATE POLICY allow_all_repayments  ON dl_repayments    FOR ALL USING (true) WITH CHECK (true); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='allow_all_savings')     THEN CREATE POLICY allow_all_savings     ON dl_savings       FOR ALL USING (true) WITH CHECK (true); END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname='allow_all_collaterals') THEN CREATE POLICY allow_all_collaterals ON dl_collaterals   FOR ALL USING (true) WITH CHECK (true); END IF;
END $$;

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
INSERT INTO dl_loan_products (name, interest_rate, rate_type, min_amount, max_amount, max_tenor_months, repayment_frequency)
VALUES
  ('Business Loan',   18, 'Flat',      500000,   50000000, 24, 'Monthly'),
  ('Agriculture Loan',15, 'Declining', 200000,   20000000, 12, 'Monthly'),
  ('Emergency Loan',   3, 'Flat',      100000,    5000000,  3, 'Weekly')
ON CONFLICT DO NOTHING;

INSERT INTO dl_clients (client_no, full_name, client_type, gender, district, phone, occupation, status)
VALUES
  ('CL-001','Amina Nakato',          'Individual','Female','Kyenjojo','+256772002326','Trader','Active'),
  ('CL-002','Robert Mugisha',        'Individual','Male',  'Kampala', '+256701234567','Farmer','Active'),
  ('CL-003','Grace Atuhaire',        'Individual','Female','Mbarara', '+256753456789','Teacher','Active'),
  ('CL-004','Patrick Ssemwogerere', 'Individual','Male',  'Gulu',    '+256784567890','Driver','Active'),
  ('CL-005','Esther Akello',         'Individual','Female','Wakiso',  '+256775678901','Business','Active'),
  ('CL-006','Kyenjojo Traders Group','Group',     NULL,    'Kyenjojo','+256706789012','Trade Group','Active'),
  ('CL-007','David Opolot',          'Individual','Male',  'Gulu',    '+256796789012','Farmer','Active')
ON CONFLICT DO NOTHING;
