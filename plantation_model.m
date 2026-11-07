function r = plantation_model(s)
% PLANTATION_MODEL  Cost, cash flow and levelised cost of oil for a tree-crop feedstock plantation.
%
%   r = plantation_model()    placeholder inputs for a pongamia-type oil crop (replace with field data).
%   r = plantation_model(s)   s overrides any field.
%
%   Land is planted in equal blocks over plant_years. Each block follows the yield ramp by tree age.
%   Costs: establishment per ha (spread over the first years), annual upkeep, harvest cost per tonne
%   of seed, land lease or opportunity cost, crushing cost per tonne of oil. Revenue: oil at oil_price
%   and meal at meal_price (0 by default). Reports NPV, levelised cost of oil (PV costs / PV oil, net of meal
%   credit if meal_credit is true) and the cash gap before the first oil.
  d.demand_oil_t = 100000;          % oil needed at full supply, tonnes a year
  d.oil_yield = 3.5;                % t oil per ha at maturity (company modelling, needs field validation)
  d.extraction = 0.30;              % t oil per t seed
  d.meal_per_t_oil = 2.0;           % t seed meal per t oil (defatted cake mass balance, assumption)
  d.ramp = [0 0 0 0.25 0.5 0.75 1]; % yield fraction by tree age, year 1 first
  d.plant_years = 3;
  d.horizon = 25;
  d.establishment = 1500;           % USD per ha (placeholder)
  d.est_years = 2;                  % establishment cost spread over this many years
  d.upkeep = 180;                   % USD per ha per year after establishment
  d.lease = 60;                     % USD per ha per year
  d.harvest_cost = 35;              % USD per t seed
  d.crush_cost = 45;                % USD per t oil
  d.oil_price = 900;                % USD per t oil (placeholder)
  d.meal_price = 0;                 % USD per t meal; 0 until feed safety and a buyer are proven
  d.meal_credit = true;
  d.discount_rate = 0.12;
  if nargin < 1, s = struct(); end
  f = fieldnames(s); for k = 1:numel(f), d.(f{k}) = s.(f{k}); end
  r = plantation_core(d);
  g = @(y) plantation_core(setfield(d, 'oil_yield', y)).npv;
  r.breakeven_oil_yield = NaN;
  try, r.breakeven_oil_yield = fzero(g, [0.05 20]); catch, end
  r.breakeven_oil_price = NaN;
  h = @(p) plantation_core(setfield(d, 'oil_price', p)).npv;
  try, r.breakeven_oil_price = fzero(h, [1 20000]); catch, end
end

function r = plantation_core(d)
  H = d.horizon; ha = d.demand_oil_t / d.oil_yield;
  blocks = zeros(1, H); blocks(1:d.plant_years) = ha / d.plant_years;
  oil = zeros(1, H); cap = zeros(1, H); upk = zeros(1, H); lea = zeros(1, H);
  for c = 1:d.plant_years
    for y = c:H
      age = y - c + 1;
      oil(y) = oil(y) + blocks(c) * d.oil_yield * d.ramp(min(age, numel(d.ramp)));
      lea(y) = lea(y) + blocks(c) * d.lease;
      if age <= d.est_years, cap(y) = cap(y) + blocks(c) * d.establishment / d.est_years;
      else, upk(y) = upk(y) + blocks(c) * d.upkeep; end
    end
  end
  seed = oil / d.extraction; meal = oil * d.meal_per_t_oil;
  harvest = seed * d.harvest_cost; crush = oil * d.crush_cost;
  cost = cap + upk + lea + harvest + crush;
  rev = oil * d.oil_price + meal * d.meal_price;
  cf = rev - cost; t = 1:H; df = (1 + d.discount_rate) .^ -(t - 1);
  r.hectares = ha; r.year = t; r.oil_t = oil; r.seed_t = seed; r.meal_t = meal;
  r.capex = cap; r.upkeep = upk; r.lease = lea; r.cost = cost; r.revenue = rev; r.cashflow = cf;
  r.npv = sum(cf .* df); r.irr = irr_calc(cf);
  r.peak_funding = -min(cumsum(cf));
  net_cost = sum(cost .* df); if d.meal_credit, net_cost = net_cost - sum(meal * d.meal_price .* df); end
  r.levelised_cost_oil = net_cost / sum(oil .* df);
  k = find(oil >= d.demand_oil_t * 0.999, 1); r.year_full_supply = ifelse_nan(k);
  r.first_oil_year = ifelse_nan(find(oil > 0, 1));
  r.inputs = d;
end

function v = ifelse_nan(k), if isempty(k), v = NaN; else, v = k; end, end
