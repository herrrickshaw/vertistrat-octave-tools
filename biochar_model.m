function r = biochar_model(s)
% BIOCHAR_MODEL  Detailed yearly model of a biochar carbon removal plant, run through project_model.
%
%   r = biochar_model()            placeholder inputs (every default is an assumption, not data)
%   r = biochar_model(s)           s overrides any field, including project_model fields such as
%                                  debt_share, interest, tenor, tax_rate, dep_rate, discount_rate.
%
%   Adds to the first-cut model: feed moisture, power use and self-generation, co-products (heat,
%   wood vinegar), credit issuance lag, price escalation, maintenance and insurance, decommissioning,
%   and construction time. Credits generated in year y are issued and paid in year y + lag
%   (credits that would fall after the last year are received in the last year).
%
%   Removal per tonne of biochar = carbon_fraction * permanence * 44/12 * (1 - project_emissions)
%                                  * (1 - buffer)      [t CO2e]
  d.feed_tpd_wet = 25;          % wet biomass delivered, tonnes per day
  d.moisture = 0.20;            % moisture share of delivered feed (wet basis)
  d.days = 330;                 % operating days a year
  d.yield_dry = 0.30;           % biochar tonnes per dry tonne of feed
  d.carbon_fraction = 0.75;     % organic carbon share of biochar
  d.permanence = 0.80;          % share of carbon counted as durable (set from the registry method)
  d.project_emissions = 0.10;   % share of gross removal lost to transport, energy, leakage
  d.buffer = 0.05;              % registry buffer / risk pool
  d.credit_price = 150;         % USD per t CO2e (placeholder)
  d.price_escalation = 0.0;     % annual change in credit price
  d.lag = 1;                    % years from generation to cash
  d.biochar_price = 0;          % USD per t biochar sold, 0 if given to farmers
  d.heat_revenue = 0;           % USD a year at full rate from surplus heat or syngas
  d.vinegar_t_per_t_feed = 0;   % wood vinegar (t per dry t feed), if collected
  d.vinegar_price = 0;          % USD per t
  d.feed_cost = 25;             % USD per wet t delivered
  d.power_kwh_per_t_feed = 60;  % electricity per wet t of feed
  d.power_price = 0.09;         % USD per kWh
  d.self_generation = 0;        % share of power need met from syngas
  d.labour = 90e3;              % USD a year
  d.other_fixed = 40e3;         % USD a year
  d.maintenance_share = 0.03;   % of capex, per year
  d.insurance_share = 0.005;    % of capex, per year
  d.mrv_cost_per_credit = 15;   % USD per credit: monitoring, verification, registry fees
  d.cost_escalation = 0.0;      % annual increase applied to all operating costs
  d.decommission_share = 0.05;  % of capex, paid in the last year
  d.capex = [0.6e6 0.6e6];      % USD by construction year (placeholder)
  d.capex_scale = 1;            % multiplier on capex, for sensitivity runs
  d.life = 15;                  % operating years
  d.ramp = [0.6 0.85];          % utilisation in the first operating years, then 1
  d.discount_rate = 0.12;
  d.compute_breakeven = true;   % set false inside Monte Carlo / tornado runs to save time
  d.debt_share = 0; d.interest = 0.105; d.tenor = 7; d.moratorium = 0; d.repayment = 'equal';
  d.tax_rate = 0.25168; d.dep_method = 'wdv'; d.dep_rate = 0.15; d.dep_life = 15; d.wc_share = 0;
  if nargin < 1, s = struct(); end
  f = fieldnames(s); for k = 1:numel(f), d.(f{k}) = s.(f{k}); end
  r = biochar_core(d);
  g = @(p) biochar_core(setfield(d, 'credit_price', p)).npv;
  r.breakeven_credit_price = NaN;
  if d.compute_breakeven
    try, r.breakeven_credit_price = fzero(g, [0 5000]); catch, end
  end
end

function r = biochar_core(d)
  n = d.life; y = 1:n;
  util = ones(1, n); m = min(numel(d.ramp), n); util(1:m) = d.ramp(1:m);
  wet = d.feed_tpd_wet * d.days * util;
  dry = wet * (1 - d.moisture);
  biochar = dry * d.yield_dry;
  per_t = d.carbon_fraction * d.permanence * 44/12 * (1 - d.project_emissions) * (1 - d.buffer);
  credits = biochar * per_t;
  % issuance timing: cash in year min(y + lag, n)
  pidx = min(y + d.lag, n); price = d.credit_price * (1 + d.price_escalation) .^ (y - 1);
  credit_rev = zeros(1, n);
  for k = 1:n, credit_rev(pidx(k)) = credit_rev(pidx(k)) + credits(k) * price(k); end
  revenue = credit_rev + biochar * d.biochar_price + d.heat_revenue * util ...
            + dry * d.vinegar_t_per_t_feed * d.vinegar_price;
  capex_v = d.capex * d.capex_scale; cap = sum(capex_v); esc = (1 + d.cost_escalation) .^ (y - 1);
  power = wet * d.power_kwh_per_t_feed * (1 - d.self_generation) * d.power_price;
  opex = (wet * d.feed_cost + power + d.labour + d.other_fixed ...
          + cap * (d.maintenance_share + d.insurance_share) + credits * d.mrv_cost_per_credit) .* esc;
  pm = struct('capex', capex_v, 'revenue', revenue, 'opex', opex, 'discount_rate', d.discount_rate, ...
              'salvage', -d.decommission_share * cap, 'debt_share', d.debt_share, 'interest', d.interest, ...
              'tenor', d.tenor, 'moratorium', d.moratorium, 'repayment', d.repayment, 'tax_rate', d.tax_rate, ...
              'dep_method', d.dep_method, 'dep_rate', d.dep_rate, 'dep_life', d.dep_life, 'wc_share', d.wc_share);
  r.model = project_model(pm);
  r.feed_wet_t = wet; r.feed_dry_t = dry; r.biochar_t = biochar; r.credits_t = credits;
  r.credits_per_t_biochar = per_t; r.revenue = revenue; r.opex = opex;
  r.npv = r.model.npv_post; r.irr = r.model.irr_post; r.payback_years = r.model.payback_years;
  r.min_dscr = r.model.min_dscr; r.inputs = d;
  r.cost_per_credit = sum(opex) / max(sum(credits), eps);   % undiscounted operating cost per credit
end
