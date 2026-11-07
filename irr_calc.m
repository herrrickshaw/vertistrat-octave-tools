function k = irr_calc(cf)
% IRR_CALC  Internal rate of return of a yearly cash-flow series (cf(1) is year 0).
%   Returns NaN when the series has no sign change or no root in -95%..300%.
%   Scans for the first sign change, then refines with fzero, so it is robust
%   to series where fzero alone would fail to bracket a root.
  cf = cf(:)'; t = 0:numel(cf)-1; k = NaN;
  if ~(any(cf < 0) && any(cf > 0)), return; end
  f = @(x) sum(cf ./ (1+x).^t);
  g = -0.95:0.005:3; v = arrayfun(f, g);
  j = find(sign(v(1:end-1)) ~= sign(v(2:end)), 1);
  if isempty(j), return; end
  k = fzero(f, [g(j) g(j+1)]);
end
