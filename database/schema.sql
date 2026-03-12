-- ============================================================
-- WARRANTY TRACKER — SUPABASE DATABASE SCHEMA
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- CUSTOMERS (linked to Supabase Auth)
CREATE TABLE public.customers (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  email       TEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- INVOICES
CREATE TABLE public.invoices (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id     UUID NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  invoice_number  TEXT NOT NULL,
  invoice_date    DATE NOT NULL,
  pdf_url         TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoices_customer ON public.invoices(customer_id);
CREATE INDEX idx_invoices_number   ON public.invoices(invoice_number);

-- PRODUCTS (each invoice can have multiple products/serials)
CREATE TABLE public.products (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  invoice_id            UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  product_name          TEXT NOT NULL,
  serial_number         TEXT NOT NULL,
  warranty_expiry_date  DATE NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_products_invoice ON public.products(invoice_id);
CREATE INDEX idx_products_serial  ON public.products(serial_number);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products  ENABLE ROW LEVEL SECURITY;

-- Customers
CREATE POLICY "Users view own profile"   ON public.customers FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.customers FOR UPDATE USING (auth.uid() = id);

-- Invoices
CREATE POLICY "Users view own invoices"   ON public.invoices FOR SELECT USING (customer_id = auth.uid());
CREATE POLICY "Users insert own invoices" ON public.invoices FOR INSERT WITH CHECK (customer_id = auth.uid());

-- Products (via invoice ownership)
CREATE POLICY "Users view own products" ON public.products FOR SELECT
  USING (invoice_id IN (SELECT id FROM public.invoices WHERE customer_id = auth.uid()));

-- Service-role bypass for API/Make.com writes
CREATE POLICY "Service write invoices" ON public.invoices FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

CREATE POLICY "Service write products" ON public.products FOR ALL
  USING (auth.jwt() ->> 'role' = 'service_role');

-- ============================================================
-- STORAGE BUCKET
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('invoices', 'invoices', false)
ON CONFLICT DO NOTHING;

CREATE POLICY "Authenticated users upload PDFs"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'invoices' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users view own PDFs"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'invoices' AND (storage.foldername(name))[1] = auth.uid()::text);

-- ============================================================
-- HELPER FUNCTION: auto-create customer profile on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.customers (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

