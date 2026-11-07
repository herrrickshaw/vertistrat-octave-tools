function r = feedstock_land(demand_t, yield_t_per_ha, varargin)
% FEEDSTOCK_LAND  Land needed for a plantation feedstock and the planting schedule to reach it.
%   r = feedstock_land(100000, [3.5 5])   tonnes of oil (or biomass) a year at a yield range.
%   Options: 'maturity_years' (6), 'ramp' yield fraction by tree age starting at year 1
%   (default: 0 until year 4, then 0.25 0.5 0.75 1), 'plant_years' (3) to spread planting.
  p = inputParser; p.addParameter('maturity_years', 6); p.addParameter('ramp', []); p.addParameter('plant_years', 3);
  p.parse(varargin{:}); o = p.Results;
  ramp = o.ramp; if isempty(ramp), ramp = [0 0 0 0.25 0.5 0.75 1]; end
  r.hectares = demand_t ./ yield_t_per_ha;
  ha = max(r.hectares);                       % plan for the low-yield case
  horizon = numel(ramp) + o.plant_years + 2;
  planted = zeros(1, horizon); planted(1:o.plant_years) = ha / o.plant_years;
  supply = zeros(1, horizon);
  for y = 1:horizon
    for c = 1:o.plant_years
      age = y - c + 1;
      if age >= 1, supply(y) = supply(y) + planted(c) * min(yield_t_per_ha) * ramp(min(age, end)); end
    end
  end
  r.year = 1:horizon; r.planted_ha = planted; r.supply_t = supply;
  r.share_of_demand = supply / demand_t;
  k = find(r.share_of_demand >= 0.999, 1); if isempty(k), k = NaN; end
  r.year_full_supply = k;
end
