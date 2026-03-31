% Parameters file
clc;
clear all;

%% Sample times
Ts_PWM = 5e-6;           
Ts_Control = 50e-6;      % Control systems sample Ts_Control = 1/F_Switching.
Ts_Power = Ts_PWM;       % Default value  Ts_PWM  = Ts_Control/10
 
%% Grid parameters
Fnom = 50;               % Nominal system frequency (Hz)
Vnom_grid =230e3;        % nominal voltage (L-L rms)
Psc_grid = 500e6;        % Short-circuit level (VA)


%% STATCOM parameters

% DC link:
Pnom_dc_3L = 50e6;                            % Nominal DC link Power (VA)
Vnom_dc_3L = 380e3;                           % Nominal DC link voltage (V)
H_3L = 1/Fnom*2;                             % DC link stored energy constant(s) = 2 cycles
Clink_3L = Pnom_dc_3L*H_3L*2 /Vnom_dc_3L^2;  %  DC link capacitor (F)
Vc_Initial_3L = Vnom_dc_3L/2;                %  capacitor initial voltage (V)

% Transformer:
Pnom_3L = Pnom_dc_3L;         % Transformer nominal power (VA)
Vnom_prim_3L = Vnom_grid;     % Nominal primary voltage (V)
m_nom_3L = 0.8;               % Nominal modulation index for 3-Level converter
Vnom_sec_3L = 0.5*Vnom_dc_3L/sqrt(2)*sqrt(3)*m_nom_3L;  % Nominal secondary voltage (V)
Lxfo_3L = 0.10;               % Total Leakage inductance (pu)
Rxfo_3L = 0.10/30;            % Total winding resistance (pu)
Rm_3L = 500;                  % Magnetization resistance (pu)
Lm_3L = 500;                  % Magnetization inductance (pu)

% Filter:
Qnom_Filter1=0.05*Pnom_dc_3L; % Nominal reactive power (VA)  5 % of the nomial DC power
Fn_Filter1=33*Fnom;           % Tuning frequency (Hz)        is the switching frequency  
Q_Filter1=10;                  % Quality factor               higher Q, sharper the filter

%  Control Parameters
Fc_3L=33*Fnom;                % PWM carrier frequency (Hz)
Freq_Filter=1000;             % Measurement filters natural frequency (Hz)


Lact = 0.15*(((Vnom_sec_3L/1000)*1e3)^2/(Pnom_3L))/314.159

Qnom_Filter11=0.05*Pnom_dc_3L;
Q_Filter11=5;  

% VDC controller 
Kp_VDCreg_3L= 3;              % Proportional gain
Ki_VDCreg_3L= 300;            % Integral gain
LimitU_VDCreg_3L= 1.5;        % Output (Idref) Upper limit (pu)
LimitL_VDCreg_3L= -1.5;       % Output (Idref) Lower limit (pu)

% Current controller
Rff_3L= Rxfo_3L;              % Feedforward R
Lff_3L= Lxfo_3L;              % Feedforward L
Kp_Ireg_3L= 0.2/2;            % Proportional gain
Ki_Ireg_3L= 15;                % Integral gain
LimitU_Ireg_3L= 1.5;          % Output (Vdq_conv) Upper limit (pu)
LimitL_Ireg_3L= -1.5;         % Output (Vdq_conv) Lower limit (pu)

