import { addMonths, differenceInDays, format, parseISO } from "date-fns";
import type { WarrantyStatus, Product, ProductWithWarranty } from "@/lib/types";

const WARRANTY_MONTHS = 30;
const EXPIRING_SOON_DAYS = 90;

/**
 * Calculate warranty expiry from invoice date.
 * warranty_expiry = invoice_date + 30 months
 */
export function calculateWarrantyExpiry(invoiceDate: string): Date {
  return addMonths(parseISO(invoiceDate), WARRANTY_MONTHS);
}

/**
 * Calculate days remaining until warranty expires.
 */
export function getDaysRemaining(warrantyExpiryDate: string): number {
  const expiry = parseISO(warrantyExpiryDate);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return differenceInDays(expiry, today);
}

/**
 * Determine warranty status based on days remaining.
 */
export function getWarrantyStatus(daysRemaining: number): WarrantyStatus {
  if (daysRemaining <= 0) return "expired";
  if (daysRemaining <= EXPIRING_SOON_DAYS) return "expiring_soon";
  return "active";
}

/**
 * Enrich a product with computed warranty fields.
 */
export function enrichProduct(product: Product): ProductWithWarranty {
  const days_remaining = getDaysRemaining(product.warranty_expiry_date);
  return {
    ...product,
    days_remaining,
    warranty_status: getWarrantyStatus(days_remaining),
  };
}

/**
 * Format date for display.
 */
export function formatDate(dateStr: string): string {
  return format(parseISO(dateStr), "dd MMM yyyy");
}

/**
 * Format days remaining as human-readable string.
 */
export function formatDaysRemaining(days: number): string {
  if (days <= 0) return "Expired";
  if (days === 1) return "1 Day Left";
  return `${days} Days Left`;
}

