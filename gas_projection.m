function r = gas_projection(s)
% GAS_PROJECTION  Year-by-year gas demand and import-terminal loading for a region, low/base/high.
%
%   r = gas_projection()      defaults reproduce the West Bengal view in the Haldia email at target_year.
%   r = gas_projection(s)     s overrides any field. Vector fields are [low base high].
%
%   Each driver moves from its value in start_year to its value in target_year along a smooth
%   S-curve (smoothstep). After target_year each segment's demand grows at post_growth a year. City gas = CNG + domestic PNG +
%   commercial/industrial; anchor loads switch on at their own start years.
%   Terminal loading = demand_share_to_terminal * total / terminal capacity (mmscmd).
  d.start_year = 2026; d.target_year = 2030; d.end_year = 2040;
  d.shape = 'scurve';                               % 'scurve' or 'linear'
  d.cng_stations_now = 249;      d.cng_stations_target = [471 645 819];
  d.scmd_per_station_now = 1330; d.scmd_per_station_target = [1330 2400 3109];
  d.png_conn_now = 170000;       d.png_conn_target = [427000 427000 0.20*1.46e7];
  d.scm_per_conn_now = 0.073;    d.scm_per_conn_target = [0.073 0.23 0.23];
  d.ci_now = 0.02;               d.ci_target = [0.03 0.23 0.88];       % mmscmd
  d.anchor_mmscmd = [2.4 2.7 2.7]; d.anchor_start_year = 2026;       % existing load, already running
  d.post_growth = [0.03 0.05 0.08];                 % yearly growth after target_year
  d.terminal_mmtpa = 1.5; d.terminal_start_year = 2028;
  d.terminal_share = [0.5 0.5 0.5];                 % share of demand the terminal could serve (assumption)
  d.ramp_years = 3;                                 % years for the terminal to reach full loading allowance
  if nargin < 1, s = struct(); end
  f = fieldnames(s); for k = 1:numel(f), d.(f{k}) = s.(f{k}); end
  yrs = d.start_year:d.end_year; ny = numel(yrs);
  u = min(max((yrs - d.start_year) / (d.target_year - d.start_year), 0), 1);
  if strcmpi(d.shape, 'scurve'), u = u.^2 .* (3 - 2*u); end
  after = max(yrs - d.target_year, 0);
  mk = @(a, b) deal_path(a, b, u);
  gr = d.post_growth(:)'; if numel(gr) == 1, gr = [gr gr gr]; end
  gf = (1 + gr) .^ after(:);          % growth factor by year and case, applied once per segment
  r.years = yrs; r.labels = {'Low','Base','High'};
  stn = mk(d.cng_stations_now, d.cng_stations_target);
  sps = mk(d.scmd_per_station_now, d.scmd_per_station_target);
  conn = mk(d.png_conn_now, d.png_conn_target);
  spc = mk(d.scm_per_conn_now, d.scm_per_conn_target);
  r.cng = (stn .* sps) / 1e6 .* gf;
  r.png = (conn .* spc) / 1e6 .* gf;
  r.ci = mk(d.ci_now, d.ci_target) .* gf;
  r.city_gas = r.cng + r.png + r.ci;
  on = double(yrs >= d.anchor_start_year)';
  r.anchor = on * d.anchor_mmscmd(:)';
  r.total = r.city_gas + r.anchor;
  % terminal loading
  cap = unit_convert(d.terminal_mmtpa, 'mmtpa_lng', 'mmscmd');
  ramp = min(max((yrs - d.terminal_start_year + 1) / d.ramp_years, 0), 1)';
  r.terminal_capacity_mmscmd = cap;
  r.terminal_demand = r.total .* (ramp * d.terminal_share(:)');
  r.terminal_utilisation = r.terminal_demand / cap;
  r.inputs = d;
end

function P = deal_path(a, b, u)
% rows = years, columns = [low base high]
  b = b(:)'; if numel(b) == 1, b = [b b b]; end
  P = a + (u(:) * (b - a));
end
