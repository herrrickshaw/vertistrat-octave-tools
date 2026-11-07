function export_csv(file, columns, M)
% EXPORT_CSV  Write a numeric matrix with a header row (columns is a cell array of names).
  fid = fopen(file, 'w'); fprintf(fid, '%s\n', strjoin(columns, ','));
  for i = 1:size(M, 1), fprintf(fid, '%s\n', strjoin(arrayfun(@(x) sprintf('%.10g', x), M(i, :), 'UniformOutput', false), ',')); end
  fclose(fid);
end
