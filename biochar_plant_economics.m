function r = biochar_plant_economics(s)
% BIOCHAR_PLANT_ECONOMICS  Output, carbon removal credits and returns for a pyrolysis plant.
%   r = biochar_plant_economics()      uses PLACEHOLDER defaults (replace with real quotes)
%   r = biochar_plant_economics(s)     s is a struct overriding any field below.
% Removal (t CO2e/yr) = biochar t * carbon fraction * permanence * 44/12 * (1 - project emissions share).
% Every default is an assumption for illustration, not data about any company.
  d.feed_tpd          = 20;     % dry biomass input, tonnes per day
  d.days              = 330;    % operating days per year
  d.yield             = 0.30;   % biochar per tonne of dry feed
  d.carbon_fraction   = 0.75;   % organic carbon in biochar
  d.permanence        = 0.80;   % share of carbon counted as durable
  d.project_emissions = 0.10;   % share of gross removal lost to transport, energy etc.
  d.buffer            = 0.05;   % registry buffer / risk pool
  d.credit_price      = 150;    % USD per t CO2e (placeholder)
  d.biochar_price     = 0;      % USD per t biochar sold, 0 if given to farmers
  d.feed_cost         = 25;     % USD per t dry feed delivered (placeholder)
  d.opex_fixed        = 150e3;  % USD per year (placeholder)
  d.mrv_cost_per_t    = 15;     % USD per credit for monitoring, verification, registry (placeholder)
  d.capex             = 1.2e6;  % USD (placeholder)
  d.life              = 15;     % years
  d.ramp              = [0.6 0.85];  % utilisation in first years, then 1
  d.discount_rate     = 0.12;
  if nargin < 1, s = struct(); end
  f = fieldnames(s); for k = 1:numel(f), d.(f{k}) = s.(f{k}); end
  util = ones(1, d.life); util(1:min(end, numel(d.ramp))) = d.ramp(1:min(end, d.life));
  feed = d.feed_tpd * d.days * util;
  biochar = feed * d.yield;
  gross = biochar * d.carbon_fraction * d.permanence * 44/12;
  credits = gross * (1 - d.project_emissions) * (1 - d.buffer);
  revenue = credits * d.credit_price + biochar * d.biochar_price;
  opex = feed * d.feed_cost + d.opex_fixed + credits * d.mrv_cost_per_t;
  cf = [-d.capex, revenue - opex];
  fin = project_finance(cf, d.discount_rate);
  r = struct('inputs', d, 'feed_t', feed, 'biochar_t', biochar, 'credits_t', credits, ...
             'revenue', revenue, 'opex', opex, 'cashflow', cf, 'npv', fin.npv, 'irr', fin.irr, ...
             'payback_years', fin.payback_years, ...
             'credits_per_t_feed', credits(end) / feed(end), ...
             'breakeven_credit_price', NaN);
  g = @(p) project_finance([-d.capex, credits*p + biochar*d.biochar_price - opex], d.discount_rate).npv;
  try, r.breakeven_credit_price = fzero(g, [0 5000]); catch, end
end
