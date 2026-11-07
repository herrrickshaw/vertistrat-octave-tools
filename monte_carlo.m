function R = monte_carlo(model, base, dists, metric, n, seed, outfile, ttl)
% MONTE_CARLO  Propagate uncertain inputs through any model that takes and returns a struct.
%   dists: struct, each field [min mode max] (triangular) or [lo hi] (uniform) for that input.
%   Returns samples, the metric for each draw, mean, P10/P50/P90, and the probability metric > 0.
%   Draws are independent. Real inputs are often correlated (price and yield, cost and capex),
%   which widens the spread; treat results as a first screen, not a forecast.
  if nargin < 5, n = 2000; end
  if nargin < 6, seed = 1; end
  try, rng(seed); catch, rand('twister', seed); end
  f = fieldnames(dists); k = numel(f); u = rand(n, k); X = zeros(n, k);
  for j = 1:k
    v = dists.(f{j});
    if numel(v) == 3, X(:, j) = tri_inv(u(:, j), v(1), v(2), v(3));
    else, X(:, j) = v(1) + u(:, j) * (v(2) - v(1)); end
  end
  y = zeros(n, 1);
  for i = 1:n
    s = base; for j = 1:k, s.(f{j}) = X(i, j); end
    y(i) = model(s).(metric);
  end
  ys = sort(y(~isnan(y)));
  pc = @(q) ys(max(1, min(numel(ys), round(q * numel(ys)))));
  R = struct('fields', {f}, 'samples', X, 'values', y, 'mean', mean(ys), ...
             'p10', pc(0.10), 'p50', pc(0.50), 'p90', pc(0.90), ...
             'prob_positive', mean(ys > 0), 'n', n, 'seed', seed);
  if nargin >= 7 && ~isempty(outfile)
    h = figure('visible', 'off', 'position', [100 100 860 480]);
    hist(ys, 40); hold on; yl = ylim; plot([0 0], yl, 'k-', 'linewidth', 1.5);
    xlabel(strrep(metric, '_', ' ')); ylabel('Draws');
    title({ttl, sprintf('P(>0) = %.0f%%   P10 %.3g   P50 %.3g   P90 %.3g', 100*R.prob_positive, R.p10, R.p50, R.p90)});
    grid on; save_figure(h, outfile);
  end
end

function x = tri_inv(u, a, c, b)
  Fc = (c - a) / (b - a); x = zeros(size(u)); lo = u < Fc;
  x(lo) = a + sqrt(u(lo) * (b - a) * (c - a));
  x(~lo) = b - sqrt((1 - u(~lo)) * (b - a) * (b - c));
end
