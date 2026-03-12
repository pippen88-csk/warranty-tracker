import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";
import { addMonths, parseISO, format } from "date-fns";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { invoice_number, invoice_date, products, customer_id, pdf_url } = body;

    if (!invoice_number || !invoice_date || !customer_id) {
      return NextResponse.json({ error: "Missing required fields: invoice_number, invoice_date, customer_id" }, { status: 400 });
    }

    if (!products || !Array.isArray(products) || products.length === 0) {
      return NextResponse.json({ error: "products must be a non-empty array" }, { status: 400 });
    }

    for (const product of products) {
      if (!product.product_name) {
        return NextResponse.json({ error: "Each product must have a product_name" }, { status: 400 });
      }
    }

    const supabase = createAdminClient();

    const { data: customer, error: custError } = await supabase
      .from("customers").select("id").eq("id", customer_id).single();

    if (custError || !customer) {
      return NextResponse.json({ error: "Customer not found" }, { status: 404 });
    }

    const { data: invoice, error: invError } = await supabase
      .from("invoices")
      .insert({ customer_id, invoice_number, invoice_date, pdf_url: pdf_url || null, status: "parsed" })
      .select()
      .single();

    if (invError) {
      console.error("Invoice insert error:", invError);
      return NextResponse.json({ error: "Failed to create invoice" }, { status: 500 });
    }

    const parsedDate = parseISO(invoice_date);
    const productRows = products.map((p: { product_name: string; serial_number?: string }) => ({
      invoice_id: invoice.id,
      product_name: p.product_name,
      serial_number: p.serial_number || null,
      warranty_expiry_date: format(addMonths(parsedDate, 30), "yyyy-MM-dd"),
    }));

    const { data: insertedProducts, error: prodError } = await supabase
      .from("products").insert(productRows).select();

    if (prodError) {
      console.error("Product insert error:", prodError);
      await supabase.from("invoices").delete().eq("id", invoice.id);
      return NextResponse.json({ error: "Failed to create products" }, { status: 500 });
    }

    return NextResponse.json({
      message: "Invoice and products created successfully",
      invoice: { id: invoice.id, invoice_number, invoice_date, product_count: insertedProducts.length },
    }, { status: 201 });
  } catch (err: any) {
    console.error("API error:", err);
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}

export async function GET(req: NextRequest) {
  try {
    const customerId = new URL(req.url).searchParams.get("customer_id");
    if (!customerId) return NextResponse.json({ error: "customer_id is required" }, { status: 400 });

    const supabase = createAdminClient();
    const { data: invoices, error } = await supabase
      .from("invoices")
      .select("id, invoice_number, invoice_date, pdf_url, status, created_at, products (id, product_name, serial_number, warranty_expiry_date)")
      .eq("customer_id", customerId)
      .order("invoice_date", { ascending: false });

    if (error) return NextResponse.json({ error: error.message }, { status: 500 });
    return NextResponse.json({ invoices });
  } catch {
    return NextResponse.json({ error: "Internal server error" }, { status: 500 });
  }
}
