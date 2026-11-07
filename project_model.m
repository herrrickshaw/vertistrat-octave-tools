function r = project_model(s)
% PROJECT_MODEL  Yearly project finance model: tax, depreciation, debt, working capital, returns.
%
%   r = project_model(s)   s is a struct. Required: revenue and opex (1 x n, one value per
%   operating year). Everything else has a default (see the list below and docs/METHODS.md).
%
%   Timeline: capex may be a vector spread over construction years starting at t = 0.
%   Operations run for numel(revenue) years straight after construction.
%
%   Returns project IRR before and after tax (unlevered), equity IRR (levered), NPVs,
%   payback, DSCR by year, minimum and average DSCR, LLCR, and an annual table
%   (r.table with column names in r.columns).
%
%   Simplifications: no interest during construction, debt drawn pro rata to capex,
%   tax losses carried forward without expiry (Indian business losses expire after 8 years), tax
%   depreciation only (no book/tax split), no GST, fees, reserve accounts or inflation unless the
%   inputs are escalated by the caller. See docs/METHODS.md.
  d.capex = 1e6;               % currency units, scalar or vector by construction year
  d.revenue = []; d.opex = [];
  d.tax_rate = 0.25168;        % 22% + 10% surcharge + 4% cess = 25.168%; a placeholder: verify the regime and eligibility under the current Act
  d.dep_method = 'wdv';        % 'wdv' (written-down value) or 'slm' (straight line)
  d.dep_rate = 0.15;           % WDV rate; 15% is the general plant & machinery rate (check asset class)
  d.dep_life = 15;             % SLM life in years
  d.debt_share = 0;            % share of capex funded by debt
  d.interest = 0.105;          % annual interest rate on debt
  d.tenor = 7;                 % loan life in operating years, including moratorium
  d.moratorium = 0;            % interest-only operating years at the start
  d.repayment = 'equal';       % 'equal' principal or 'annuity'
  d.discount_rate = 0.12;      % for project NPV
  d.equity_rate = [];          % for equity NPV; empty = discount_rate
  d.wc_share = 0;              % working capital held, as a share of revenue
  d.salvage = 0;               % cash received at the end of the last year
  if nargin < 1, s = struct(); end
  f = fieldnames(s); for k = 1:numel(f), d.(f{k}) = s.(f{k}); end
  if isempty(d.revenue) || isempty(d.opex), error('project_model: revenue and opex are required'); end
  if numel(d.opex) == 1, d.opex = d.opex * ones(size(d.revenue)); end
  if isempty(d.equity_rate), d.equity_rate = d.discount_rate; end
  capex = d.capex(:)'; c = numel(capex); n = numel(d.revenue); T = c + n; ops = c+1:T;
  z = zeros(1, T);
  cap = z; cap(1:c) = capex; rev = z; rev(ops) = d.revenue(:)'; opx = z; opx(ops) = d.opex(:)';
  ebitda = rev - opx;
  % working capital: build-up is an outflow, released in the final year
  wcl = d.wc_share * rev; wc = -diff([0 wcl]); wc(T) = wc(T) + wcl(T);
  sal = z; sal(T) = d.salvage;
  % tax depreciation on total capex, from the first operating year
  dep = z; base = sum(capex);
  if strcmpi(d.dep_method, 'wdv')
    book = base; for y = ops, dep(y) = book * d.dep_rate; book = book - dep(y); end
  else
    L = min(d.dep_life, n); dep(c+1:c+L) = base / d.dep_life;
  end
  % debt: drawn pro rata to capex, repaid over tenor operating years after any moratorium
  D = d.debt_share * base; draw = d.debt_share * cap; tol_d = 1e-9 * max(D, 1);   % rounding residue is not debt
  int = z; prin = z; bal_end = z; bal = D; m = d.tenor - d.moratorium;
  for k = 1:n
    y = c + k; int(y) = bal * d.interest;
    if k > d.moratorium && k <= d.tenor && bal > tol_d
      if strcmpi(d.repayment, 'annuity')
        pay = D * d.interest / (1 - (1 + d.interest)^-m); prin(y) = pay - int(y);
      else
        prin(y) = D / m;
      end
      prin(y) = min(prin(y), bal);
    end
    bal = bal - prin(y); if bal < tol_d, bal = 0; end
    bal_end(y) = bal;
  end
  ds = int + prin;
  tax_u = loss_cf_tax(ebitda - dep, d.tax_rate);         % unlevered (for project IRR)
  tax_l = loss_cf_tax(ebitda - dep - int, d.tax_rate);   % levered (for equity)
  cf_pre  = -cap + ebitda + wc + sal;
  cf_post = cf_pre - tax_u;
  cfads   = ebitda - tax_l + wc;
  cf_eq   = -(cap - draw) + cfads - ds + sal;
  ds(ds < tol_d) = 0;
  dscr = NaN(1, T); j = ds > 0; dscr(j) = cfads(j) ./ ds(j);
  t = 0:T-1;
  r.irr_pre = irr_calc(cf_pre); r.irr_post = irr_calc(cf_post); r.irr_equity = irr_calc(cf_eq);
  r.npv_post = sum(cf_post ./ (1 + d.discount_rate).^t);
  r.npv_equity = sum(cf_eq ./ (1 + d.equity_rate).^t);
  r.payback_years = payback_years(cf_post);
  r.min_dscr = min(dscr(j)); r.avg_dscr = mean(dscr(j));
  if isempty(r.min_dscr), r.min_dscr = NaN; r.avg_dscr = NaN; end
  r.llcr = NaN;
  if D > 0
    ly = c+1:min(c + d.tenor, T); tt = 1:numel(ly);
    r.llcr = sum(cfads(ly) ./ (1 + d.interest).^tt) / D;
  end
  r.debt = D; r.cf_pre = cf_pre; r.cf_post = cf_post; r.cf_equity = cf_eq; r.dscr = dscr;
  r.columns = {'year','capex','revenue','opex','ebitda','depreciation','interest','principal', ...
               'debt_balance','tax_unlevered','tax_levered','working_capital_cf','cfads', ...
               'dscr','project_cf_post_tax','equity_cf'};
  r.table = [t' cap' rev' opx' ebitda' dep' int' prin' bal_end' tax_u' tax_l' wc' cfads' dscr' cf_post' cf_eq'];
  r.inputs = d;
end

function tax = loss_cf_tax(taxable, rate)
% Tax with losses carried forward (no expiry, no carry-back).
  tax = zeros(size(taxable)); pool = 0;
  for y = 1:numel(taxable)
    x = taxable(y) - pool;
    if x > 0, tax(y) = x * rate; pool = 0; else, pool = -x; end
  end
end
