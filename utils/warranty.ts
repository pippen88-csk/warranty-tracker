import { addMonths, differenceInDays, format, parseISO } from "date-fns";

const WARRANTY_MONTHS = 30;

export function calculateWarrantyExpiry(invoiceDate: string | Date): Date {
  const date = typeof invoiceDate === "string" ? parseISO(invoiceDate) : invoiceDate;
  return addMonths(date, WARRANTY_MONTHS);
}

export function getDaysRemaining(warrantyExpiryDate: string | Date): number {
  const expiry = typeof warrantyExpiryDate === "string" ? parseISO(warrantyExpiryDate) : warrantyExpiryDate;
  return differenceInDays(expiry, new Date());
}

export function getWarrantyStatus(daysRemaining: number): "active" | "expiring_soon" | "expired" {
  if (daysRemaining > 90) return "active";
  if (daysRemaining > 0) return "expiring_soon";
  return "expired";
}

export function formatDate(date: string | Date): string {
  const d = typeof date === "string" ? parseISO(date) : date;
  return format(d, "MMM d, yyyy");
}
