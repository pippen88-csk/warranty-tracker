import { redirect } from "next/navigation";
import { createServerSupabase } from "@/lib/supabase-server";
import { DashboardShell } from "@/components/layout/dashboard-shell";
import { FileUploader } from "@/components/dashboard/file-uploader";

export default async function UploadPage() {
  const supabase = createServerSupabase();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) redirect("/login");

  return (
    <DashboardShell title="Upload Invoices">
      <div className="max-w-2xl">
        <div className="mb-6">
          <h2 className="text-lg font-semibold">Upload Invoice PDFs</h2>
          <p className="text-sm text-surface-500 mt-1">
            Drop your invoices below. We&apos;ll parse them automatically and add products to your dashboard.
          </p>
        </div>
        <FileUploader />
      </div>
    </DashboardShell>
  );
}

