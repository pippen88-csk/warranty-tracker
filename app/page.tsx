import Link from "next/link";
import { Shield, Upload, BarChart3, Clock, ArrowRight } from "lucide-react";

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-surface-50 via-white to-surface-50 dark:from-surface-950 dark:via-surface-900 dark:to-surface-950">
      <header className="px-6 py-4 flex items-center justify-between max-w-7xl mx-auto">
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 bg-brand-500 rounded-xl flex items-center justify-center">
            <Shield className="w-5 h-5 text-white" />
          </div>
          <span className="font-semibold text-lg">WarrantyTracker</span>
        </div>
        <div className="flex items-center gap-3">
          <Link href="/login" className="btn-secondary">Log In</Link>
          <Link href="/signup" className="btn-primary">Get Started</Link>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-6 pt-20 pb-32 text-center">
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-brand-50 dark:bg-brand-500/10 text-brand-600 dark:text-brand-400 text-xs font-medium mb-6">
          <Clock className="w-3.5 h-3.5" /> 30-month warranty tracking
        </div>
        <h1 className="text-5xl md:text-6xl font-bold tracking-tight leading-[1.1] max-w-3xl mx-auto">
          Upload invoices.<br /><span className="text-brand-500">Track warranties.</span>
        </h1>
        <p className="mt-6 text-lg text-surface-500 dark:text-surface-400 max-w-xl mx-auto leading-relaxed">
          Automatically parse product details from invoice PDFs and monitor warranty expiry dates from one clean dashboard.
        </p>
        <div className="mt-10 flex items-center justify-center gap-4">
          <Link href="/signup" className="btn-primary text-base px-8 py-3">Start Tracking <ArrowRight className="w-4 h-4" /></Link>
          <Link href="/login" className="btn-secondary text-base px-8 py-3">Log In</Link>
        </div>

        <div className="mt-24 grid md:grid-cols-3 gap-6 text-left">
          {[
            { icon: Upload, title: "PDF Upload", desc: "Drag & drop invoices. We extract product names, serial numbers, and dates automatically." },
            { icon: BarChart3, title: "Live Dashboard", desc: "See all your products, warranty statuses, and days remaining at a glance." },
            { icon: Clock, title: "Warranty Countdown", desc: "30-month warranty tracking with active, expiring, and expired status badges." },
          ].map((f) => (
            <div key={f.title} className="card p-6">
              <div className="w-10 h-10 rounded-xl bg-brand-50 dark:bg-brand-500/10 flex items-center justify-center mb-4">
                <f.icon className="w-5 h-5 text-brand-500" />
              </div>
              <h3 className="font-semibold text-base mb-2">{f.title}</h3>
              <p className="text-sm text-surface-500 dark:text-surface-400 leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}

