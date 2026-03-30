%% === GA-Based Optimal DVR Placement for IEEE 13-Node Feeder ===
clc; clear; close all;

%% === System Setup ===
n_buses = 24;
n_dvr   = 1;     % number of DVRs

% Map internal index -> actual IEEE bus number
bus_map = [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23];

% Load B-coefficients (from realvalue.m using IEEE 13-bus line/load data)
[bij, bi0, b00] = newloss_sanepa();   % Units: kW-based model

%% === GA Parameters ===
pop_size        = 30;
num_generations = 50;
mutation_rate   = 0.10;
crossover_rate  = 0.80;

% Decision-variable bounds
P_bounds_MW = [0.1, 2.0];        % each DVR rating in MW
L_bounds    = [2, n_buses];      % bus indices (exclude slack/index 1)

%% === Initialize Population ===
chrom_len  = 2 * n_dvr;          % [P1..Pn | L1..Ln]
population = zeros(pop_size, chrom_len);

for i = 1:pop_size
    % Powers
    for j = 1:n_dvr
        population(i, j) = rand() * (P_bounds_MW(2) - P_bounds_MW(1)) + P_bounds_MW(1);
    end
    % Locations
    for j = 1:n_dvr
        population(i, n_dvr + j) = randi([L_bounds(1), L_bounds(2)]);
    end
end

%% === Fitness Function (loss in kW) ===
fitness_fn = @(chrom) compute_loss_kW(chrom, bij, bi0, b00, n_buses);

best_fitness_log = zeros(1, num_generations);

%% === GA Main Loop ===
for gen = 1:num_generations
    fitness = zeros(pop_size, 1);
    for i = 1:pop_size
        fitness(i) = fitness_fn(population(i, :));
    end
    [best_fitness_log(gen), ~] = min(fitness);

    new_pop = zeros(size(population));
    for i = 1:2:pop_size
        p1 = population(tournament_select(population, fitness), :);
        p2 = population(tournament_select(population, fitness), :);

        if rand < crossover_rate
            [c1, c2] = single_point_crossover(p1, p2);
        else
            c1 = p1; c2 = p2;
        end

        c1 = mutate(c1, P_bounds_MW, L_bounds, mutation_rate, n_dvr);
        c2 = mutate(c2, P_bounds_MW, L_bounds, mutation_rate, n_dvr);

        new_pop(i, :) = c1;
        if i + 1 <= pop_size
            new_pop(i+1, :) = c2;
        end
    end

    population = new_pop;
end

%% === Output Best Result ===
fitness = zeros(pop_size, 1);
for i = 1:pop_size
    fitness(i) = fitness_fn(population(i, :));
end

[best_loss_kW, best_idx] = min(fitness);
best = population(best_idx, :);

fprintf('\n=== Optimal DVR Placement for Sanepa Feeder ===\n');
for i = 1:n_dvr
    bus_idx = round(best(n_dvr + i));
    fprintf('DVR-%d: Power = %.3f MW at Bus-%d\n', i, best(i), bus_map(bus_idx));
end
fprintf('Minimum Power Loss: %.4f kW (%.6f MW)\n', best_loss_kW, best_loss_kW/1000);

%% === Plot Fitness Convergence ===
figure;
plot(1:num_generations, best_fitness_log, 'b-o','LineWidth',1.5);
xlabel('Generation');
ylabel('Best Power Loss (kW)');
title('GA Convergence for DVR Placement - IEEE 13-Node');
grid on;

%% === Function Definitions ===
function loss_kW = compute_loss_kW(chrom, bij, bi0, b00, nbus)
    n_dvr = numel(chrom)/2;
    P_MW  = chrom(1:n_dvr);
    locs  = round(chrom(n_dvr+1:end));

    if any(locs < 2) || any(locs > nbus) || numel(unique(locs)) < n_dvr
        loss_kW = inf;
        return;
    end

    P_bus_kW = zeros(1, nbus);
    for k = 1:n_dvr
        P_bus_kW(locs(k)) = P_bus_kW(locs(k)) + P_MW(k) * 1000; % MW->kW
    end

    loss_kW = P_bus_kW * bij * P_bus_kW' + (bi0(:).') * P_bus_kW.' + b00;
end

function idx = tournament_select(pop, fitness)
    cand = randperm(size(pop, 1), 3);
    [~, b] = min(fitness(cand));
    idx = cand(b);
end

function [c1, c2] = single_point_crossover(p1, p2)
    pt = randi(length(p1) - 1);
    c1 = [p1(1:pt), p2(pt+1:end)];
    c2 = [p2(1:pt), p1(pt+1:end)];
end

function mutated = mutate(chrom, P_bounds_MW, L_bounds, rate, n_dvr)
    mutated = chrom;
    for i = 1:length(chrom)
        if rand < rate
            if i <= n_dvr
                mutated(i) = rand() * (P_bounds_MW(2) - P_bounds_MW(1)) + P_bounds_MW(1);
            else
                mutated(i) = randi([L_bounds(1), L_bounds(2)]);
            end
        end
    end
end
