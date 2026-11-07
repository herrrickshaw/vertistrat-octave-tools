function r = project_finance(cf, rate, varargin)
% PROJECT_FINANCE  NPV, IRR, payback and DSCR for a yearly cash-flow series.
%   r = project_finance(cf, rate)  cf(1) is year 0 (usually negative capex).
%   r = project_finance(cf, rate, 'debt', D, 'debt_rate', i, 'tenor', n)
%       adds an annuity loan of D drawn in year 0 and reports DSCR by year.
%   Works in MATLAB and GNU Octave. Units are whatever cf is in.
  p = inputParser; p.addParameter('debt', 0); p.addParameter('debt_rate', 0.10); p.addParameter('tenor', 7);
  p.parse(varargin{:}); o = p.Results;
  cf = cf(:)'; t = 0:numel(cf)-1;
  npvf = @(k) sum(cf ./ (1+k).^t);
  r.npv = npvf(rate);
  r.irr = NaN;
  if any(cf < 0) && any(cf > 0)
    try, r.irr = fzero(npvf, [-0.99 10]); catch, r.irr = NaN; end
  end
  cum = cumsum(cf); k = find(cum >= 0 & t > 0, 1);
  if isempty(k), r.payback_years = NaN;
  else, r.payback_years = t(k-1) + (-cum(k-1)) / cf(k); end
  r.dscr = []; r.min_dscr = NaN; r.debt_service = 0;
  if o.debt > 0
    i = o.debt_rate; n = o.tenor;
    r.debt_service = o.debt * i / (1 - (1+i)^-n);
    ops = cf(2:min(end, n+1));
    r.dscr = ops / r.debt_service; r.min_dscr = min(r.dscr);
  end
end
