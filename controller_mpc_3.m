% BRIEF:
%   Controller function template. This function can be freely modified but
%   input and output dimension MUST NOT be changed.
% INPUT:
%   T: Measured system temperatures, dimension (3,1)
% OUTPUT:
%   p: Cooling power, dimension (2,1)
function p = controller_mpc_3(T)
% controller variables
persistent param yalmip_optimizer

% initialize controller, if not done already
if isempty(param)
    [param, yalmip_optimizer] = init();
end

% Estimate state and disturbance


%% Evaluate control action by solving MPC problem
[u_mpc,errorcode] = yalmip_optimizer(T - param.T_sp);
if (errorcode ~= 0)
      warning('MPC infeasible');
end
p = u_mpc + param.p_sp;
end

function [param, yalmip_optimizer] = init()
% initializes the controller on first call and returns parameters and
% Yalmip optimizer object

param = compute_controller_base_parameters; % get basic controller parameters

%% Optimization problem definition
% Params
N = 30;
nx = size(param.A,1);
nu = size(param.B,2);
% Declare Yalmip symbolic vars
U = sdpvar(repmat(nu,1,N-1), ones(1,N-1), 'full');
X = sdpvar(repmat(nx,1,N), ones(1,N), 'full');
% Objective definition
objective = 0;
constraints = [];
for k = 1:N-1
    % Add term to the objective
    objective = objective +  X{k}'*param.Q*X{k} + U{k}'*param.R*U{k};
    % Add dynamics equality constraints
    constraints = [constraints, X{k+1} == param.A * X{k} + param.B * U{k}];
    % Add state box constraint
    constraints = [constraints, param.Xcons(:,1) <= X{k+1} <= param.Xcons(:,2)];
    % Add input box constraint
    constraints = [constraints, param.Ucons(:,1) <= U{k} <= param.Ucons(:,2)];
end
% Get LQR polytopic invariant set
[A_x, b_x] = compute_X_LQR;
constraints = [constraints, A_x * X{N} <= b_x];
% Add terminal cost to the objective function
objective = objective + X{N}'*param.P*X{N};

% Define yalmip optimizer object
ops = sdpsettings('verbose',0,'solver','quadprog');
fprintf('JMPC_dummy = %f',value(objective));
% Here we leave X{1} as a parameter, 
yalmip_optimizer = optimizer(constraints,objective,ops,X{1},U{1});
end