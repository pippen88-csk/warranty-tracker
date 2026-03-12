// ============================================================
// DATABASE TYPES
// ============================================================

export interface Customer {
  id: string;
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
  created_at: string;
  products?: Product[];
}

export interface Product {
  id: string;
  invoice_id: string;
  product_name: string;
  serial_number: string;
  warranty_expiry_date: string;
  created_at: string;
}

// ============================================================
// API TYPES
// ============================================================

export interface InvoicePayload {
  invoice_number: string;
  invoice_date: string;
  product_name: string;
  serial_number: string;
  customer_id: string;
  pdf_url: string;
}

// Supports multiple products per invoice (critical requirement)
export interface InvoicePayloadMulti {
  invoice_number: string;
  invoice_date: string;
  products: Array<{
    product_name: string;
    serial_number: string;
  }>;
  customer_id: string;
  pdf_url: string;
}

export interface UploadWebhookPayload {
  file_url: string;
  customer_id: string;
}

// ============================================================
// UI TYPES
// ============================================================

export type WarrantyStatus = "active" | "expired" | "expiring_soon";

export interface ProductWithWarranty extends Product {
  days_remaining: number;
  warranty_status: WarrantyStatus;
}

export interface InvoiceWithProducts extends Invoice {
  products: ProductWithWarranty[];
}

export interface UploadProgress {
  file: File;
  progress: number;
  status: "pending" | "uploading" | "processing" | "complete" | "error";
  error?: string;
}
