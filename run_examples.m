% RUN_EXAMPLES  Worked examples for each tool. Run in Octave:  octave-cli run_examples.m
warning('off', 'all');   % hides Octave's fltk-toolkit notice
here = fileparts(mfilename('fullpath')); addpath(here); od = fullfile(here, 'out');
if ~exist(od, 'dir'), mkdir(od); end
fid = fopen(fullfile(od, 'examples.txt'), 'w'); P = @(varargin) fprintf(fid, varargin{:});

% 1. Biochar plant (placeholder inputs)
b = biochar_plant_economics();
P('BIOCHAR PLANT (placeholder inputs - replace with vendor quotes)\n');
P('  Feed %.0f tpd -> biochar %.0f t/yr, credits %.0f t CO2e/yr at full rate (%.2f credits per t feed)\n', ...
  b.inputs.feed_tpd, b.biochar_t(end), b.credits_t(end), b.credits_per_t_feed);
P('  NPV @%.0f%%: USD %.0f   IRR: %.1f%%   payback: %.1f yrs   break-even credit price: USD %.0f/t\n\n', ...
  100*b.inputs.discount_rate, b.npv, 100*b.irr, b.payback_years, b.breakeven_credit_price);
rg = struct('credit_price', [100 200], 'yield', [0.25 0.35], 'capex', [0.9e6 1.6e6], ...
            'feed_cost', [15 40], 'permanence', [0.7 0.9], 'opex_fixed', [100e3 250e3]);
tornado(@biochar_plant_economics, b.inputs, rg, 'npv', fullfile(od, 'biochar_npv_tornado.png'), 'Biochar plant NPV sensitivity (placeholder inputs)');

% 2. Project finance with debt
pf = project_finance(b.cashflow, 0.12, 'debt', 0.6*b.inputs.capex, 'debt_rate', 0.105, 'tenor', 7);
P('PROJECT FINANCE (same plant, 60%% debt at 10.5%%, 7 yrs)\n  Debt service USD %.0f/yr, minimum DSCR %.2f\n\n', pf.debt_service, pf.min_dscr);

% 3. Gas demand (West Bengal FY2030 defaults)
g = gas_demand_scenario();
P('GAS DEMAND, WEST BENGAL FY2030 (mmscmd)   Low   Base   High\n');
P('  City gas                               %5.2f  %5.2f  %5.2f\n', g.city_gas);
P('  Anchor (fertiliser)                    %5.2f  %5.2f  %5.2f\n', g.anchor);
P('  Total                                  %5.2f  %5.2f  %5.2f\n\n', g.total);
h = figure('visible','off','position',[100 100 800 480]);
bar([g.cng; g.png; g.ci; g.anchor]', 'stacked'); set(gca,'xticklabel', g.labels);
legend({'CNG','Domestic PNG','Commercial & industrial','Fertiliser'}, 'location', 'northwest');
ylabel('mmscmd'); title('West Bengal gas demand, FY2030'); grid on;
save_figure(h, fullfile(od, 'wb_gas_demand.png'));

% 4. Feedstock land (pongamia example from the Ecopha email)
L = feedstock_land(100000, [3.5 5]);
P('FEEDSTOCK LAND: 100,000 t oil/yr at 3.5-5 t/ha -> %.0f-%.0f ha; full supply in year %d if planted over 3 years\n', ...
  min(L.hectares), max(L.hectares), L.year_full_supply);
h = figure('visible','off','position',[100 100 800 420]);
plot(L.year, 100*L.share_of_demand, '-o', 'linewidth', 2); ylim([0 110]); grid on;
xlabel('Year from first planting'); ylabel('% of demand met'); title('Plantation supply ramp (low-yield case)');
save_figure(h, fullfile(od, 'feedstock_ramp.png'));

% ------------------------------------------------------------------ v2 examples
P('\n=====  DETAILED MODELS  =====\n');
P('All biochar and plantation inputs below are PLACEHOLDERS, not data about any company.\n\n');

% 5. Detailed biochar plant with debt, tax and a moratorium
fin = struct('debt_share', 0.60, 'interest', 0.105, 'tenor', 8, 'moratorium', 1, 'repayment', 'equal');
B = biochar_model(fin);
m = B.model;
P('5. BIOCHAR PLANT, DETAILED (25 wet tpd at 20%% moisture, 60%% debt at 10.5%%, 8 yrs incl. 1 yr moratorium)\n');
P('   Credits at full rate: %.0f t CO2e/yr (%.2f per t biochar)\n', B.credits_t(end), B.credits_per_t_biochar);
P('   Project IRR: %.1f%% before tax, %.1f%% after tax   Equity IRR: %.1f%%\n', 100*m.irr_pre, 100*m.irr_post, 100*m.irr_equity);
P('   NPV after tax @%.0f%%: USD %.0f   Equity NPV: USD %.0f\n', 100*B.inputs.discount_rate, m.npv_post, m.npv_equity);
P('   DSCR minimum %.2f, average %.2f   LLCR %.2f   Debt USD %.0f\n', m.min_dscr, m.avg_dscr, m.llcr, m.debt);
P('   Operating cost per credit (undiscounted): USD %.0f   Break-even credit price: USD %.0f/t\n\n', B.cost_per_credit, B.breakeven_credit_price);
export_csv(fullfile(od, 'biochar_annual_table.csv'), m.columns, m.table);

% 6. Tornado on the detailed model
base = B.inputs; base.compute_breakeven = false;
rg = struct('credit_price', [100 200], 'yield_dry', [0.25 0.35], 'capex_scale', [0.7 1.4], 'feed_cost', [15 40], ...
            'permanence', [0.7 0.9], 'mrv_cost_per_credit', [8 25], 'lag', [0 2]);
T = tornado(@biochar_model, base, rg, 'npv', fullfile(od, 'biochar_detailed_tornado.png'), 'Detailed biochar plant: NPV sensitivity (placeholders)');
P('6. TORNADO, NPV swing by input (USD), largest first\n');
for k = numel(T.field):-1:1
  P('   %-22s %12.0f to %12.0f\n', T.field{k}, min(T.low(k), T.high(k)), max(T.low(k), T.high(k)));
end
P('\n');

% 7. Monte Carlo
dist = struct('credit_price', [90 150 220], 'yield_dry', [0.22 0.30 0.35], 'capex_scale', [0.8 1 1.5], ...
              'feed_cost', [15 25 40], 'permanence', [0.7 0.8 0.9]);
R = monte_carlo(@biochar_model, base, dist, 'npv', 1500, 11, fullfile(od, 'biochar_monte_carlo.png'), 'Biochar plant NPV (placeholder ranges)');
P('7. MONTE CARLO, %d draws, triangular ranges on price, yield, capex, feed cost, permanence\n', R.n);
P('   NPV mean USD %.0f   P10 %.0f   P50 %.0f   P90 %.0f   P(NPV>0) = %.0f%%\n', R.mean, R.p10, R.p50, R.p90, 100*R.prob_positive);
P('   Inputs are drawn independently; real price, yield and cost moves are correlated, so the true spread is wider.\n\n');

% 8. Gas demand projection with terminal loading
G = gas_projection();
P('8. WEST BENGAL GAS DEMAND PROJECTION (mmscmd) and 1.5 MMTPA terminal loading\n');
P('   Year   Low    Base   High   Terminal loading (Base)\n');
for yr = [2026 2028 2030 2035 2040]
  i = find(G.years == yr);
  P('   %d  %5.2f  %5.2f  %5.2f   %5.0f%%\n', yr, G.total(i, :), 100*G.terminal_utilisation(i, 2));
end
P('   Terminal capacity %.1f mmscmd; assumes the terminal can serve %.0f%% of regional demand.\n\n', G.terminal_capacity_mmscmd, 100*G.inputs.terminal_share(2));
h = figure('visible','off','position',[100 100 980 440]);
subplot(1, 2, 1); plot(G.years, G.total, 'linewidth', 2); grid on; xlabel('Year'); ylabel('mmscmd');
legend(G.labels, 'location', 'northwest'); title('Total demand');
subplot(1, 2, 2); plot(G.years, 100 * G.terminal_utilisation, 'linewidth', 2); grid on; xlabel('Year');
ylabel('% of terminal capacity'); title('Terminal loading'); legend(G.labels, 'location', 'northwest');
save_figure(h, fullfile(od, 'gas_projection.png'));

% 9. Plantation economics
PL = plantation_model();
P('9. PLANTATION FEEDSTOCK (100,000 t oil/yr; placeholder costs and price)\n');
P('   Land %.0f ha   first oil in year %d   full supply in year %d   peak funding USD %.1f million\n', PL.hectares, PL.first_oil_year, PL.year_full_supply, PL.peak_funding/1e6);
P('   Levelised cost of oil USD %.0f/t   Break-even oil yield %.2f t/ha   Break-even oil price USD %.0f/t\n', PL.levelised_cost_oil, PL.breakeven_oil_yield, PL.breakeven_oil_price);
P('   Yield  Hectares   Peak funding (USD m)   Levelised cost (USD/t)   NPV (USD m)\n');
for yv = [0.5 1 2 3.5 5]
  q = plantation_model(struct('oil_yield', yv));
  P('   %4.1f  %9.0f   %10.1f             %10.0f             %8.1f\n', yv, q.hectares, q.peak_funding/1e6, q.levelised_cost_oil, q.npv/1e6);
end
P('   Oil yield per hectare is the weakest input: the 3.5-5 t/ha used in public company material needs field validation.\n');
h = figure('visible','off','position',[100 100 800 420]);
plot(PL.year, cumsum(PL.cashflow) / 1e6, '-o', 'linewidth', 2); grid on; hold on; plot([1 PL.year(end)], [0 0], 'k-');
xlabel('Year from first planting'); ylabel('Cumulative cash flow, USD million'); title('Plantation: cumulative cash (placeholders)');
save_figure(h, fullfile(od, 'plantation_cash.png'));
fclose(fid); type(fullfile(od, 'examples.txt'));
