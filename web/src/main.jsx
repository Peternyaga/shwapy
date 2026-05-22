import React, { useMemo, useState } from 'react';
import ReactDOM from 'react-dom/client';
import {
  AlertCircle,
  CheckCircle2,
  Eye,
  FileImage,
  FileText,
  Loader2,
  LogIn,
  LogOut,
  ReceiptText,
  Send,
  ShieldCheck,
  Upload,
  WalletCards,
} from 'lucide-react';
import './styles.css';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ||'http://192.168.100.224' ||'http://localhost';

const emptyPaymentAccount = {
  type: 'till',
  paybill_no: '',
  account_no: '',
  till_no: '',
  merchant_name: '',
};

function App() {
  const [token, setToken] = useState(() => localStorage.getItem('shwapy_token') || '');
  const [authMode, setAuthMode] = useState('login');
  const [authForm, setAuthForm] = useState({
    name: 'Test User',
    email: 'test@example.com',
    phone_number: '0759265709',
    password: 'password123',
    password_confirmation: 'password123',
  });
  const [extractMode, setExtractMode] = useState('image');
  const [textContent, setTextContent] = useState('');
  const [file, setFile] = useState(null);
  const [phoneHint, setPhoneHint] = useState('');
  const [extraction, setExtraction] = useState(null);
  const [checkoutForm, setCheckoutForm] = useState({
    payment_account: emptyPaymentAccount,
    amount: '',
    phone_number: '0759265709',
    extraction_confidence: null,
  });
  const [status, setStatus] = useState({ kind: 'idle', message: '' });
  const [busy, setBusy] = useState('');
  const [checkoutResult, setCheckoutResult] = useState(null);

  const isAuthed = token.trim() !== '';
  const canExtract = isAuthed && (extractMode === 'text' ? textContent.trim() : file);
  const accountType = checkoutForm.payment_account.type;

  const missingFields = useMemo(() => extraction?.missing_fields || [], [extraction]);

  async function api(path, options = {}) {
    const response = await fetch(`${API_BASE_URL}${path}`, {
      ...options,
      headers: {
        Accept: 'application/json',
        ...(options.body instanceof FormData ? {} : { 'Content-Type': 'application/json' }),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(options.headers || {}),
      },
    });

    const payload = await response.json().catch(() => ({}));

    if (!response.ok) {
      const message = payload?.error?.message || payload?.message || 'Request failed.';
      throw new Error(message);
    }

    return payload;
  }

  async function handleAuth(event) {
    event.preventDefault();
    setBusy('auth');
    setStatus({ kind: 'idle', message: '' });

    try {
      const path = authMode === 'login' ? '/api/auth/login' : '/api/auth/register';
      const body = authMode === 'login'
        ? { email: authForm.email, password: authForm.password }
        : authForm;
      const payload = await api(path, {
        method: 'POST',
        body: JSON.stringify(body),
        headers: {},
      });
      const nextToken = payload.data.token;
      setToken(nextToken);
      localStorage.setItem('shwapy_token', nextToken);
      setStatus({ kind: 'success', message: authMode === 'login' ? 'Signed in.' : 'Account created.' });
    } catch (error) {
      setStatus({ kind: 'error', message: error.message });
    } finally {
      setBusy('');
    }
  }

  async function handleExtraction(event) {
    event.preventDefault();
    setBusy('extract');
    setStatus({ kind: 'idle', message: '' });
    setCheckoutResult(null);

    try {
      const formData = new FormData();
      formData.append('type', extractMode);

      if (extractMode === 'text') {
        formData.append('content', textContent);
      } else {
        formData.append('content', file);
      }

      if (phoneHint.trim()) {
        formData.append('phone_number', phoneHint.trim());
      }

      const payload = await api('/api/extractions/payment', {
        method: 'POST',
        body: formData,
      });

      const data = payload.data;
      setExtraction(data);
      setCheckoutForm({
        payment_account: {
          type: data.payment_account.type === 'paybill' ? 'paybill' : 'till',
          paybill_no: data.payment_account.paybill_no || '',
          account_no: data.payment_account.account_no || '',
          till_no: data.payment_account.till_no || '',
          merchant_name: data.payment_account.merchant_name || '',
        },
        amount: data.amount ?? '',
        phone_number: data.phone_number || phoneHint || authForm.phone_number,
        extraction_confidence: data.confidence,
      });
      setStatus({ kind: 'success', message: 'Extraction completed. Review before checkout.' });
    } catch (error) {
      setStatus({ kind: 'error', message: error.message });
    } finally {
      setBusy('');
    }
  }

  async function handleCheckout(event) {
    event.preventDefault();
    setBusy('checkout');
    setCheckoutResult(null);
    setStatus({ kind: 'idle', message: '' });

    try {
      const account = checkoutForm.payment_account;
      const paymentAccount = {
        type: account.type,
        merchant_name: account.merchant_name || null,
      };

      if (account.type === 'paybill') {
        paymentAccount.paybill_no = account.paybill_no;
        paymentAccount.account_no = account.account_no;
      } else {
        paymentAccount.till_no = account.till_no;
      }

      const payload = await api('/api/payments/checkout', {
        method: 'POST',
        body: JSON.stringify({
          payment_account: paymentAccount,
          amount: Number(checkoutForm.amount),
          phone_number: checkoutForm.phone_number,
          extraction_confidence: checkoutForm.extraction_confidence,
          raw_extraction: extraction,
        }),
      });

      setCheckoutResult(payload.data);
      setStatus({ kind: 'success', message: 'STK push requested.' });
    } catch (error) {
      setStatus({ kind: 'error', message: error.message });
    } finally {
      setBusy('');
    }
  }

  async function logout() {
    if (token) {
      try {
        await api('/api/auth/logout', { method: 'POST', body: JSON.stringify({}) });
      } catch {
        // The local token is cleared either way.
      }
    }

    setToken('');
    localStorage.removeItem('shwapy_token');
    setStatus({ kind: 'idle', message: '' });
  }

  function updateAccount(field, value) {
    setCheckoutForm((current) => ({
      ...current,
      payment_account: {
        ...current.payment_account,
        [field]: value,
      },
    }));
  }

  return (
    <main className="app-shell">
      <section className="topbar">
        <div>
          <p className="eyebrow">Shwapy</p>
          <h1>Payment extraction console</h1>
        </div>
        <div className="token-state">
          <ShieldCheck size={18} />
          <span>{isAuthed ? 'API session active' : 'Sign in required'}</span>
          {isAuthed && (
            <button className="icon-button" type="button" onClick={logout} aria-label="Log out" title="Log out">
              <LogOut size={18} />
            </button>
          )}
        </div>
      </section>

      {status.message && (
        <StatusBanner kind={status.kind} message={status.message} />
      )}

      <section className="workspace">
        <aside className="panel auth-panel">
          <div className="panel-heading">
            <LogIn size={20} />
            <h2>Access</h2>
          </div>

          {!isAuthed ? (
            <form onSubmit={handleAuth} className="stack">
              <Segmented
                value={authMode}
                options={[
                  { value: 'login', label: 'Login' },
                  { value: 'register', label: 'Register' },
                ]}
                onChange={setAuthMode}
              />

              {authMode === 'register' && (
                <>
                  <Field label="Name" value={authForm.name} onChange={(value) => setAuthForm({ ...authForm, name: value })} />
                  <Field label="Phone" value={authForm.phone_number} onChange={(value) => setAuthForm({ ...authForm, phone_number: value })} />
                </>
              )}
              <Field label="Email" value={authForm.email} onChange={(value) => setAuthForm({ ...authForm, email: value })} />
              <Field label="Password" type="password" value={authForm.password} onChange={(value) => setAuthForm({ ...authForm, password: value })} />
              {authMode === 'register' && (
                <Field label="Confirm password" type="password" value={authForm.password_confirmation} onChange={(value) => setAuthForm({ ...authForm, password_confirmation: value })} />
              )}
              <button className="primary-button" type="submit" disabled={busy === 'auth'}>
                {busy === 'auth' ? <Loader2 className="spin" size={18} /> : <LogIn size={18} />}
                {authMode === 'login' ? 'Sign in' : 'Create account'}
              </button>
            </form>
          ) : (
            <div className="signed-in">
              <CheckCircle2 size={28} />
              <div>
                <strong>Ready</strong>
                <span>Upload or paste payment details.</span>
              </div>
            </div>
          )}
        </aside>

        <section className="panel extraction-panel">
          <div className="panel-heading">
            <ReceiptText size={20} />
            <h2>Extract</h2>
          </div>

          <form onSubmit={handleExtraction} className="stack">
            <Segmented
              value={extractMode}
              options={[
                { value: 'image', label: 'Image' },
                { value: 'pdf', label: 'PDF' },
                { value: 'text', label: 'Text' },
              ]}
              onChange={setExtractMode}
            />

            {extractMode === 'text' ? (
              <label className="field">
                <span>Payment text</span>
                <textarea
                  value={textContent}
                  onChange={(event) => setTextContent(event.target.value)}
                  placeholder="Pay KES 1500 to till 123456"
                  rows={8}
                />
              </label>
            ) : (
              <label className="dropzone">
                <input
                  type="file"
                  accept={extractMode === 'image' ? 'image/jpeg,image/png,image/webp' : 'application/pdf'}
                  onChange={(event) => setFile(event.target.files?.[0] || null)}
                />
                {extractMode === 'image' ? <FileImage size={28} /> : <FileText size={28} />}
                <strong>{file ? file.name : `Choose ${extractMode.toUpperCase()}`}</strong>
                <span>{file ? `${Math.round(file.size / 1024)} KB` : 'Small receipts, signs, screenshots, or one to two page PDFs'}</span>
              </label>
            )}

            <Field label="Phone hint" value={phoneHint} onChange={setPhoneHint} placeholder="0759265709" />
            <button className="primary-button" type="submit" disabled={!canExtract || busy === 'extract'}>
              {busy === 'extract' ? <Loader2 className="spin" size={18} /> : <Upload size={18} />}
              Extract details
            </button>
          </form>
        </section>

        <section className="panel review-panel">
          <div className="panel-heading">
            <Eye size={20} />
            <h2>Review</h2>
          </div>

          {extraction ? (
            <form onSubmit={handleCheckout} className="stack">
              <div className="result-strip">
                <Metric label="Confidence" value={`${Math.round((extraction.confidence || 0) * 100)}%`} />
                <Metric label="Currency" value={extraction.currency || 'KES'} />
                <Metric label="Missing" value={missingFields.length || 'None'} />
              </div>

              {missingFields.length > 0 && (
                <div className="inline-alert">
                  <AlertCircle size={18} />
                  <span>{missingFields.join(', ')}</span>
                </div>
              )}

              <Segmented
                value={accountType}
                options={[
                  { value: 'till', label: 'Till' },
                  { value: 'paybill', label: 'Paybill' },
                ]}
                onChange={(value) => updateAccount('type', value)}
              />

              {accountType === 'paybill' ? (
                <div className="two-col">
                  <Field label="Paybill" value={checkoutForm.payment_account.paybill_no} onChange={(value) => updateAccount('paybill_no', value)} />
                  <Field label="Account" value={checkoutForm.payment_account.account_no} onChange={(value) => updateAccount('account_no', value)} />
                </div>
              ) : (
                <Field label="Till number" value={checkoutForm.payment_account.till_no} onChange={(value) => updateAccount('till_no', value)} />
              )}

              <Field label="Merchant" value={checkoutForm.payment_account.merchant_name} onChange={(value) => updateAccount('merchant_name', value)} />
              <div className="two-col">
                <Field label="Amount" type="number" min="1" value={checkoutForm.amount} onChange={(value) => setCheckoutForm({ ...checkoutForm, amount: value })} />
                <Field label="Phone" value={checkoutForm.phone_number} onChange={(value) => setCheckoutForm({ ...checkoutForm, phone_number: value })} />
              </div>

              <button className="pay-button" type="submit" disabled={busy === 'checkout'}>
                {busy === 'checkout' ? <Loader2 className="spin" size={18} /> : <Send size={18} />}
                Send STK push
              </button>
            </form>
          ) : (
            <div className="empty-state">
              <WalletCards size={36} />
              <strong>No extraction yet</strong>
              <span>Results appear here for review before checkout.</span>
            </div>
          )}
        </section>
      </section>

      {checkoutResult && (
        <section className="checkout-result">
          <CheckCircle2 size={22} />
          <div>
            <strong>{checkoutResult.message}</strong>
            <span>Transaction #{checkoutResult.transaction_id} · {checkoutResult.status}</span>
          </div>
        </section>
      )}
    </main>
  );
}

function StatusBanner({ kind, message }) {
  const Icon = kind === 'error' ? AlertCircle : CheckCircle2;
  return (
    <div className={`status-banner ${kind}`}>
      <Icon size={18} />
      <span>{message}</span>
    </div>
  );
}

function Segmented({ value, options, onChange }) {
  return (
    <div className="segmented">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          className={value === option.value ? 'active' : ''}
          onClick={() => onChange(option.value)}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

function Field({ label, value, onChange, type = 'text', placeholder = '', min }) {
  return (
    <label className="field">
      <span>{label}</span>
      <input
        type={type}
        min={min}
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}

function Metric({ label, value }) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
