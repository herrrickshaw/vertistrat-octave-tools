% TEST_TOOLS  Checks against hand calculations. Run:  octave-cli test_tools.m
addpath(fileparts(mfilename('fullpath'))); tol = 1e-6;
% project_finance: -100 then 60, 60 -> IRR 13.07%, payback 1.67
r = project_finance([-100 60 60], 0.10);
assert(abs(r.npv - (-100 + 60/1.1 + 60/1.21)) < tol); assert(abs(r.irr - 0.130662) < 1e-5);
assert(abs(r.payback_years - (1 + 40/60)) < tol);
r = project_finance([-100 -5 -5], 0.1); assert(isnan(r.irr) && isnan(r.payback_years));
r = project_finance([-100 30 30 30], 0.1, 'debt', 60, 'debt_rate', 0.1, 'tenor', 3);
assert(abs(r.debt_service - 60*0.1/(1-1.1^-3)) < tol); assert(abs(r.min_dscr - 30/r.debt_service) < tol);
% gas_demand_scenario reproduces the email's table (rounded to 0.1)
g = gas_demand_scenario();
assert(isequal(round(10*g.city_gas)/10, [0.7 1.9 4.1])); assert(isequal(round(10*g.total)/10, [3.1 4.6 6.8]));
% feedstock_land: 100,000 / 5 = 20,000 ha; / 3.5 = 28,571 ha
L = feedstock_land(100000, [3.5 5]); assert(abs(L.hectares(2) - 20000) < tol); assert(round(L.hectares(1)) == 28571);
assert(abs(L.share_of_demand(end) - 1) < 1e-9);
% biochar: removal formula by hand at full utilisation
b = biochar_plant_economics(struct('ramp', []));
exp_c = 20*330*0.30*0.75*0.80*44/12*0.90*0.95; assert(abs(b.credits_t(1) - exp_c) < 1e-6);
z = biochar_plant_economics(struct('ramp', [], 'credit_price', b.breakeven_credit_price));
assert(abs(z.npv) < 1);   % NPV is ~0 at the break-even price
% tornado: sorted by swing, base matches
T = tornado(@biochar_plant_economics, b.inputs, struct('capex',[1e6 2e6],'yield',[0.2 0.4]), 'npv');
assert(abs(T.base - b.npv) < tol); assert(abs(T.high(end)-T.low(end)) >= abs(T.high(1)-T.low(1)));
disp('All tests passed');

% ---------------------------------------------------------------- v2 tools
tol = 1e-9;
% irr_calc / payback_years
assert(abs(irr_calc([-100 60 60]) - 0.130662) < 1e-5); assert(isnan(irr_calc([-100 -5]))); assert(isnan(irr_calc([10 20])));
assert(abs(payback_years([-100 60 60]) - (1 + 40/60)) < tol); assert(isnan(payback_years([-100 10 10])));

% project_model, tax: capex 100, WDV 50%, revenue 60, 60, tax 25%
% dep 50 then 25; taxable 10 then 35; tax 2.5 then 8.75
m = project_model(struct('capex', 100, 'revenue', [60 60], 'opex', 0, 'tax_rate', 0.25, 'dep_method', 'wdv', 'dep_rate', 0.5));
assert(max(abs(m.cf_post - [-100 57.5 51.25])) < tol);
assert(abs(m.irr_pre - irr_calc([-100 60 60])) < 1e-9);
% loss carry-forward: capex 100, SLM 2 yrs (dep 50, 50), revenue 10 then 100 -> loss 40, then taxable 50-40 = 10 -> tax 2.5
m = project_model(struct('capex', 100, 'revenue', [10 100], 'opex', 0, 'tax_rate', 0.25, 'dep_method', 'slm', 'dep_life', 2));
assert(max(abs(m.table(:, 10)' - [0 0 2.5])) < tol);
% debt, equal principal: D = 60, 10%, 3 yrs -> principal 20; interest 6, 4, 2; service 26, 24, 22
m = project_model(struct('capex', 100, 'revenue', [50 50 50], 'opex', 0, 'tax_rate', 0, 'debt_share', 0.6, 'interest', 0.10, 'tenor', 3));
assert(max(abs(m.table(2:4, 8)' - [20 20 20])) < tol); assert(max(abs(m.table(2:4, 7)' - [6 4 2])) < tol);
assert(abs(m.table(end, 9)) < tol);                              % loan fully repaid
assert(abs(m.min_dscr - 50/26) < tol); assert(abs(m.cf_equity(1) + 40) < tol);
% annuity: constant service, principal sums to D
m = project_model(struct('capex', 100, 'revenue', [50 50 50 50], 'opex', 0, 'tax_rate', 0, 'debt_share', 0.5, ...
    'interest', 0.10, 'tenor', 4, 'repayment', 'annuity'));
sv = m.table(2:5, 7) + m.table(2:5, 8); assert(max(abs(sv - sv(1))) < 1e-9); assert(abs(sum(m.table(:, 8)) - 50) < 1e-9);
% moratorium: interest only in year 1, principal 30 + 30 afterwards
m = project_model(struct('capex', 100, 'revenue', [50 50 50], 'opex', 0, 'tax_rate', 0, 'debt_share', 0.6, ...
    'interest', 0.10, 'tenor', 3, 'moratorium', 1));
assert(max(abs(m.table(2:4, 8)' - [0 30 30])) < tol);
% working capital builds up then releases; nets to zero
m = project_model(struct('capex', 100, 'revenue', [100 100], 'opex', 0, 'tax_rate', 0, 'wc_share', 0.1));
assert(abs(sum(m.table(:, 12))) < tol); assert(abs(m.table(2, 12) + 10) < tol);
% LLCR with zero tax: PV(CFADS over tenor at interest) / debt
m = project_model(struct('capex', 100, 'revenue', [50 50 50], 'opex', 0, 'tax_rate', 0, 'debt_share', 0.6, 'interest', 0.10, 'tenor', 3));
assert(abs(m.llcr - sum(50 ./ 1.1.^(1:3)) / 60) < 1e-9);

% biochar_model collapses to the first-cut model when every extra is switched off
z = struct('moisture', 0, 'feed_tpd_wet', 20, 'lag', 0, 'labour', 150e3, 'other_fixed', 0, 'maintenance_share', 0, ...
           'insurance_share', 0, 'power_kwh_per_t_feed', 0, 'decommission_share', 0, 'tax_rate', 0, 'capex', 1.2e6);
a = biochar_model(z); b0 = biochar_plant_economics();
assert(abs(a.npv - b0.npv) < 1e-4); assert(max(abs(a.credits_t - b0.credits_t)) < 1e-9);
assert(abs(a.breakeven_credit_price - b0.breakeven_credit_price) < 1e-4);
% moisture: wet 25 t/day at 20% moisture = 20 dry t/day
w = biochar_model(struct('feed_tpd_wet', 25, 'moisture', 0.2)); assert(abs(w.feed_dry_t(end) - 20*330) < 1e-9);
% lag shifts cash: with lag 2 the last two years of credits are received in the final year
l = biochar_model(struct('lag', 2, 'tax_rate', 0)); assert(abs(sum(l.revenue) - sum(l.credits_t) * 150) < 1e-6);
% break-even price gives NPV ~ 0
z.credit_price = a.breakeven_credit_price; q = biochar_model(z); assert(abs(q.npv) < 1);
% and with every extra switched on, the full model's own break-even price also gives NPV ~ 0
full = biochar_model(); q2 = biochar_model(struct('credit_price', full.breakeven_credit_price)); assert(abs(q2.npv) < 1);
% capex_scale doubles capex
c2 = biochar_model(struct('capex_scale', 2)); assert(abs(sum(c2.model.table(:, 2)) - 2 * sum(biochar_model().inputs.capex)) < 1e-6);

% gas_projection: hits gas_demand_scenario at the target year, starts at today's values, linear midpoint
g = gas_projection(); gs = gas_demand_scenario(); i30 = find(g.years == 2030);
assert(max(abs(g.total(i30, :) - gs.total)) < 1e-9); assert(max(abs(g.city_gas(i30, :) - gs.city_gas)) < 1e-9);
assert(abs(g.cng(1, 2) - 249 * 1330 / 1e6) < 1e-9);
gl = gas_projection(struct('shape', 'linear', 'cng_stations_target', [600 600 600], 'scmd_per_station_target', 1330));
assert(abs(gl.cng(find(gl.years == 2028), 1) - (249 + 0.5 * 351) * 1330 / 1e6) < 1e-9);
assert(all(diff(g.city_gas(1:i30, 2)) >= -1e-12));                         % no decline up to the target year
assert(abs(g.city_gas(end, 2) - g.city_gas(i30, 2) * 1.05^10) < 1e-9);     % growth applied once, not twice
assert(abs(g.terminal_capacity_mmscmd - 5.4) < 1e-9);

% unit_convert
assert(abs(unit_convert(1.5, 'mmtpa_lng', 'mmscmd') - 5.4) < 1e-9);
assert(abs(unit_convert(unit_convert(2, 'mmscmd', 'mmtpa_lng'), 'mmtpa_lng', 'mmscmd') - 2) < 1e-9);
assert(abs(unit_convert(1, 'tbiochar', 'tco2') - 0.75 * 44/12) < 1e-9); assert(abs(unit_convert(12, 'tc', 'tco2') - 44) < 1e-9);
try, unit_convert(1, 'mmscmd', 'furlongs'); assert(false); catch e, assert(~isempty(strfind(e.message, 'no conversion'))); end

% plantation_model
p = plantation_model(); assert(abs(p.hectares - 100000 / 3.5) < 1e-6);
assert(abs(plantation_model(struct('oil_yield', p.breakeven_oil_yield)).npv) < 1);
assert(abs(p.breakeven_oil_price - p.levelised_cost_oil) < 1e-3 * p.levelised_cost_oil);   % meal price is 0 by default
assert(p.first_oil_year == 4); assert(abs(max(p.oil_t) - 100000) < 1e-6);
assert(p.peak_funding > 0);

% monte_carlo: triangular mean, ordering, reproducibility
R = monte_carlo(@(s) struct('v', s.x), struct('x', 0), struct('x', [0 1 4]), 'v', 20000, 3);
assert(abs(R.mean - 5/3) < 0.05); assert(R.p10 < R.p50 && R.p50 < R.p90); assert(R.prob_positive > 0.999);
R2 = monte_carlo(@(s) struct('v', s.x), struct('x', 0), struct('x', [0 1 4]), 'v', 20000, 3); assert(R.mean == R2.mean);
U = monte_carlo(@(s) struct('v', s.x), struct('x', 0), struct('x', [-1 1]), 'v', 20000, 4); assert(abs(U.prob_positive - 0.5) < 0.02);

% export_csv round trip
f = [tempname() '.csv']; export_csv(f, {'a','b'}, [1 2.5; 3 4]); t = fileread(f); delete(f);
assert(strcmp(t, sprintf('a,b\n1,2.5\n3,4\n')));
% rounding residue after repayment must not create a phantom debt service (regression: DSCR average was 8e15)
m = project_model(struct('capex', 1e6, 'revenue', 3e5*ones(1,10), 'opex', 0, 'tax_rate', 0, 'debt_share', 0.6, ...
    'interest', 0.105, 'tenor', 7));
assert(all(m.table(9:end, 7) == 0) && all(m.table(9:end, 8) == 0));      % operating years 8-10: no interest, no principal
assert(all(m.table(9:end, 9) == 0)); assert(m.avg_dscr < 100 && m.min_dscr > 0);
assert(abs(sum(m.table(:, 8)) - 6e5) < 1e-6);                             % principal repaid in full
b = biochar_model(struct('debt_share', 0.6, 'tenor', 8, 'moratorium', 1)); assert(abs(b.model.avg_dscr) < 1e3);
disp('All v2 tests passed');
