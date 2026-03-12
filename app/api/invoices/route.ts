import { NextRequest, NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase-admin";
import { addMonths, format, parseISO } from "date-fns";

const WARRANTY_MONTHS = 30;

/**
 * POST /api/invoices
 *
 * Accepts parsed invoice data from Make.com webhook.
 * Supports both single-product and multi-product payloads.
 *
 * Single product payload:
 * { invoice_number, invoice_date, product_name, serial_number, customer_id, pdf_url }
 *
 * Multi product payload:
 * { invoice_number, invoice_date, products: [{ product_name, serial_number }], customer_id, pdf_url }
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    // Validate required fields
    const { invoice_number, invoice_date, customer_id, pdf_url } = body;
    if (!invoice_number || !invoice_date || !customer_id) {
      return NextResponse.json(
        { error: "Missing required fields: invoice_number, invoice_date, customer_id" },
        { status: 400 }
      );
    }

    // Normalize products array (handle single or multi product)
    let products: Array<{ product_name: string; serial_number: string }> = [];

    if (body.products && Array.isArray(body.products)) {
      products = body.products;
    } else if (body.product_name && body.serial_number) {
      products = [{ product_name: body.product_name, serial_number: body.serial_number }];
    }

    if (products.length === 0) {
      return NextResponse.json(
        { error: "At least one product with product_name and serial_number is required" },
        { status: 400 }
      );
    }

    const supabase = createAdminClient();

    // Insert invoice
    const { data: invoice, error: invError } = await supabase
      .from("invoices")
      .insert({
        customer_id,
        invoice_number,
        invoice_date,
        pdf_url: pdf_url || null,
      })
      .select()
      .single();

    if (invError) {
      console.error("Invoice insert error:", invError);
      return NextResponse.json({ error: "Failed to create invoice" }, { status: 500 });
    }

    // Calculate warranty expiry
    const warrantyExpiry = format(
      addMonths(parseISO(invoice_date), WARRANTY_MONTHS),
      "yyyy-MM-dd"
    );

    // Insert all products
    const productRows = products.map((p) => ({
      invoice_id: invoice.id,
      product_name: p.product_name,
      serial_number: p.serial_number,
      warranty_expiry_date: warrantyExpiry,
    }));

    const { data: insertedProducts, error: prodError } = await supabase
      .from("products")
      .insert(productRows)
      .select();

    if (prodError) {
      console.error("Product insert error:", prodError);
      return NextResponse.json({ error: "Failed to create products" }, { status: 500 });
    }

    return NextResponse.json({
      success: true,
      invoice: invoice,
      products: insertedProducts,
      warranty_expiry: warrantyExpiry,
    });
  } catch (err: any) {
    console.error("API error:", err);
    return NextResponse.json({ error: err.message || "Internal server error" }, { status: 500 });
  }
}

