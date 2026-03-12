import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import { Sidebar } from "@/components/dashboard/sidebar";
import { Header } from "@/components/dashboard/header";
import { UploadPageClient } from "./client";

export default async function UploadPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  const { data: customer } = await supabase.from("customers").select("*").eq("auth_id", user.id).single();
  if (!customer) redirect("/login");

  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <div className="flex-1 flex flex-col">
        <Header customerName={customer.name} />
        <main className="flex-1 p-6 lg:p-8">
          <UploadPageClient customerId={customer.id} />
        </main>
      </div>
    </div>
  );
}
