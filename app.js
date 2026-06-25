// DeryLoan — Supabase API Layer
// All CRUD operations for clients, loans, repayments, savings

const SUPABASE_URL  = "https://eiyexnuhqdscomilwpqg.supabase.co";
const SUPABASE_ANON = "sb_publishable_S1u_aPqq2USyJcKpeisOlQ_TMzbHxtX";

const HDR = {
  "apikey":        SUPABASE_ANON,
  "Authorization": `Bearer ${SUPABASE_ANON}`,
  "Content-Type":  "application/json",
  "Prefer":        "return=representation"
};

// ── Generic REST helpers ──────────────────────────────────────────────────────
async function sbGet(table, params = "") {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}${params}`, { headers: HDR });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function sbPost(table, body) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST", headers: HDR, body: JSON.stringify(body)
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function sbPatch(table, id, body) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?id=eq.${id}`, {
    method: "PATCH", headers: HDR, body: JSON.stringify(body)
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

async function sbDelete(table, id) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}?id=eq.${id}`, {
    method: "DELETE", headers: HDR
  });
  if (!res.ok) throw new Error(await res.text());
}

// ── Clients ───────────────────────────────────────────────────────────────────
const Clients = {
  list:   ()         => sbGet("dl_clients", "?order=created_at.desc"),
  get:    (id)       => sbGet("dl_clients", `?id=eq.${id}`),
  create: (data)     => sbPost("dl_clients", data),
  update: (id, data) => sbPatch("dl_clients", id, data),
};

// ── Loan Products ─────────────────────────────────────────────────────────────
const LoanProducts = {
  list:   ()         => sbGet("dl_loan_products", "?is_active=eq.true&order=name"),
  create: (data)     => sbPost("dl_loan_products", data),
  update: (id, data) => sbPatch("dl_loan_products", id, data),
};

// ── Loans ─────────────────────────────────────────────────────────────────────
const Loans = {
  list:   ()         => sbGet("dl_loans", "?order=created_at.desc&select=*,dl_clients(full_name,client_no),dl_loan_products(name,rate_type)"),
  get:    (id)       => sbGet("dl_loans", `?id=eq.${id}&select=*,dl_clients(*),dl_loan_products(*)`),
  create: (data)     => sbPost("dl_loans", data),
  update: (id, data) => sbPatch("dl_loans", id, data),
  byClient: (cid)    => sbGet("dl_loans", `?client_id=eq.${cid}&order=created_at.desc`),
};

// ── Repayments ────────────────────────────────────────────────────────────────
const Repayments = {
  list:    ()          => sbGet("dl_repayments", "?order=paid_at.desc&limit=50"),
  byLoan:  (lid)       => sbGet("dl_repayments", `?loan_id=eq.${lid}&order=paid_at.desc`),
  create:  (data)      => sbPost("dl_repayments", data),
};

// ── Savings ───────────────────────────────────────────────────────────────────
const Savings = {
  list:   ()         => sbGet("dl_savings", "?order=created_at.desc&select=*,dl_clients(full_name)"),
  create: (data)     => sbPost("dl_savings", data),
  update: (id, data) => sbPatch("dl_savings", id, data),
};

// ── Dashboard Stats ───────────────────────────────────────────────────────────
async function getDashboardStats() {
  const [clients, loans, repayments, savings] = await Promise.all([
    sbGet("dl_clients", "?select=id,status"),
    sbGet("dl_loans",   "?select=id,status,outstanding_balance,principal"),
    sbGet("dl_repayments", `?paid_at=gte.${new Date().toISOString().slice(0,7)}-01&select=amount`),
    sbGet("dl_savings", "?select=balance"),
  ]);

  const activeLoans     = loans.filter(l => l.status === "Active");
  const portfolioOLB    = activeLoans.reduce((s, l) => s + (l.outstanding_balance || 0), 0);
  const collected       = repayments.reduce((s, r) => s + (r.amount || 0), 0);
  const totalSavings    = savings.reduce((s, sv) => s + (sv.balance || 0), 0);
  const inArrears       = loans.filter(l => l.status === "Active" && l.outstanding_balance > 0).length;

  return {
    totalClients:  clients.length,
    activeLoans:   activeLoans.length,
    portfolioOLB,
    collected,
    totalSavings,
    inArrears,
  };
}

// ── Next ID generators ────────────────────────────────────────────────────────
async function nextClientNo() {
  const all = await sbGet("dl_clients", "?select=client_no&order=created_at.desc&limit=1");
  if (!all.length) return "CL-001";
  const last = parseInt(all[0].client_no.split("-")[1] || "0");
  return `CL-${String(last + 1).padStart(3, "0")}`;
}

async function nextLoanNo() {
  const all = await sbGet("dl_loans", "?select=loan_no&order=created_at.desc&limit=1");
  const year = new Date().getFullYear();
  if (!all.length) return `DL-${year}-001`;
  const parts = all[0].loan_no.split("-");
  const seq   = parseInt(parts[2] || "0") + 1;
  return `DL-${year}-${String(seq).padStart(3, "0")}`;
}

// ── Utility ───────────────────────────────────────────────────────────────────
function formatUGX(n) {
  n = parseFloat(n) || 0;
  if (n >= 1e9) return `UGX ${(n/1e9).toFixed(1).replace(/\.0$/,"")}B`;
  if (n >= 1e6) return `UGX ${(n/1e6).toFixed(1).replace(/\.0$/,"")}M`;
  if (n >= 1e3) return `UGX ${(n/1e3).toFixed(0)}K`;
  return `UGX ${n.toLocaleString()}`;
}
