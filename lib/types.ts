export interface Customer {
  id: string;
  auth_id: string;
  name: string;
  email: string;
  created_at: string;
}

export interface Invoice {
  id: string;
  customer_id: string;
  invoice_number: string;
  invoice_date: string;
  pdf_url: string | null;
  status: "pending" | "parsing" | "parsed" | "failed";
  created_at: string;
}

export interface Product {
  id: string;
  invoice_id: string;
  product_name: string;
  serial_number: string | null;
  warranty_expiry_date: string;
  created_at: string;
}

export interface ProductWithWarranty extends Product {
  days_remaining: number;
  warranty_status: "active" | "expiring_soon" | "expired";
}

export interface InvoiceGroup {
  invoice_id: string;
  invoice_number: string;
  invoice_date: string;
  pdf_url: string | null;
  products: ProductWithWarranty[];
}
