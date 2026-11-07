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
