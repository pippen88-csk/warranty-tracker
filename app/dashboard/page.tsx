import { createServerSupabase } from "@/lib/supabase-server";
import { redirect } from "next/navigation";
import { Sidebar } from "@/components/dashboard/sidebar";
import { Header } from "@/components/dashboard/header";
import { DashboardStats } from "@/components/dashboard/stats";
import { InvoiceTable } from "@/components/dashboard/invoice-table";
import type { InvoiceGroup, ProductWithWarranty } from "@/lib/types";
import { differenceInDays, parseISO } from "date-fns";

export const dynamic = "force-dynamic";

export default async function DashboardPage() {
  const supabase = createServerSupabase();
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) redirect("/login");

  const { data: customer } = await supabase.from("customers").select("*").eq("auth_id", session.user.id).single();
  if (!customer) redirect("/login");

  const { data: invoices } = await supabase
    .from("invoices")
    .select("id, invoice_number, invoice_date, pdf_url, customer_id, products (id, product_name, serial_number, warranty_expiry_date, created_at)")
    .eq("customer_id", customer.id)
    .order("invoice_date", { ascending: false });

  const invoiceGroups: InvoiceGroup[] = (invoices || []).map((inv: any) => {
    const products: ProductWithWarranty[] = (inv.products || []).map((p: any) => {
      const daysRemaining = differenceInDays(parseISO(p.warranty_expiry_date), new Date());
      return {
        ...p,
        invoice_id: inv.id,
        days_remaining: daysRemaining,
        warranty_status: daysRemaining > 90 ? "active" : daysRemaining > 0 ? "expiring_soon" : "expired",
      };
    });
    return { invoice_id: inv.id, invoice_number: inv.invoice_number, invoice_date: inv.invoice_date, pdf_url: inv.pdf_url, products };
  });

  const allProducts = invoiceGroups.flatMap((g) => g.products);
  const stats = {
    totalInvoices: invoiceGroups.length,
    totalProducts: allProducts.length,
    activeWarranties: allProducts.filter((p) => p.warranty_status === "active").length,
    expiringSoon: allProducts.filter((p) => p.warranty_status === "expiring_soon").length,
    expired: allProducts.filter((p) => p.warranty_status === "expired").length,
  };

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Header customerName={customer.name} />
        <main className="flex-1 p-6 lg:p-8 space-y-6">
          <div>
            <h2 className="text-2xl font-bold tracking-tight">Warranty Dashboard</h2>
            <p className="text-muted-foreground mt-1">Track all your product warranties in one place.</p>
          </div>
          <DashboardStats {...stats} />
          <InvoiceTable invoiceGroups={invoiceGroups} />
        </main>
      </div>
    </div>
  );
}
