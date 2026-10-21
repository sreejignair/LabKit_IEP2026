% compare_rtl.m  -  Experiment 6
% Reads the RTL output, rescales it, and reports the comparison.
%
% Expects rtl_out.txt: one signed decimal accumulator value per line, N_PTS lines.
% Your testbench should write this with $fdisplay.

clear; clc;
load('../data/ref_matlab.mat');

acc    = load('../data/rtl_out.txt');
golden = load('../data/golden_acc.txt');
s      = fileread('../data/scales.txt');
lsb    = sscanf(s(strfind(s,'lsb')+3:end), '%f', 1);

fprintf('--- bit-exact check against the golden model ---\n');
nbad = sum(acc(:) ~= golden(:));
if nbad == 0
    fprintf('PASS: all %d points bit-exact\n', numel(acc));
else
    fprintf('FAIL: %d of %d points differ\n', nbad, numel(acc));
    k = find(acc(:) ~= golden(:), 5);
    for i = 1:numel(k)
        fprintf('   point %d: rtl %d, golden %d\n', k(i)-1, acc(k(i)), golden(k(i)));
    end
end

y_rtl = acc(:) * lsb;
err   = y_rtl - y_ref(:);
pk    = max(abs(y_ref));
fprintf('\n--- numerical comparison against the double-precision reference ---\n');
fprintf('NRMSE      : %.2f dB\n', 20*log10(sqrt(mean(err.^2))/pk));
fprintf('peak error : %.3e  (%.2f dB below peak)\n', max(abs(err)), ...
        20*log10(max(abs(err))/pk));

figure;
subplot(2,1,1);
plot(zs*1e3, y_ref/pk, 'k-', 'LineWidth', 1.4); hold on;
plot(zs*1e3, y_rtl/pk, 'r--', 'LineWidth', 1.0);
ylabel('normalised'); legend('MATLAB reference','RTL','Location','best');
title('Experiment 6 - beamformed line');
subplot(2,1,2);
plot(zs*1e3, err/pk, 'r-'); xlabel('depth (mm)'); ylabel('error');
