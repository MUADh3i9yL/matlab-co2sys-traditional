function [data,headers,nice_headers]=CO2SYS(parameter_1,parameter_2, ...
                                            parameter_1_type,parameter_2_type, ...
                                            salinity, ...
                                            temperature_in,temperature_out, ...
                                            pressure_in,pressure_out, ...
                                            silicate,phosphate,ammonia,sulphide, ...
                                            pH_scale_in, ...
                                            which_k1_k2_constants,which_kso4_constant,which_kf_constant, which_boron, ...
                                            varargin)

    % Declare global variables
    global pH_scale_in_GLOBAL which_k1_k2_constants_GLOBAL which_kso4_constant_GLOBAL which_kf_constant_GLOBAL which_boron_GLOBAL
    global salinity_GLOBAL sqrt_salinity_GLOBAL temperature_in_GLOBAL temperature_out_GLOBAL pressure_in_GLOBAL pressure_out_GLOBAL;
    global FugFac VPFac peng_correction_GLOBAL number_of_points gas_constant_GLOBAL;
    global K0 K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL CAL selected_GLOBAL;
    
    % Added by JM Epitalon
    % For computing derivative with respect to Ks, one has to call CO2sys with a perturbed K
    % Requested perturbation is passed through the following global variables
    global k_perturbation_GLOBAL    % Id of perturbed K
    global Perturb  % perturbation
    
    % Input conditioning
    
    % set default for optional input argument
    global p_opt
    p_opt = 0;
    % parse optional input argument
    for i = 1:2:length(varargin)-1
        if strcmpi(varargin{i}, 'co2_press')
            p_opt = varargin{i+1};
        end
    end
    
    % Determine lengths of input vectors
    veclengths=[length(parameter_1) length(parameter_2) length(parameter_1_type)...
                length(parameter_2_type) length(salinity) length(temperature_in)...
                length(temperature_out) length(pressure_in) length(pressure_out)...
                length(silicate) length(phosphate) length(ammonia) length(sulphide)...
                length(pH_scale_in) length(which_k1_k2_constants) length(which_kso4_constant)...
	            length(which_kf_constant) length(which_boron)];
    
    if length(unique(veclengths))>2
	    disp(' '); disp('*** INPUT ERROR: Input vectors must all be of same length, or of length 1. ***'); disp(' '); return
    end
    
    % Find the longest column vector:
    number_of_points = max(veclengths);
    
    % Populate column vectors
    parameter_1(1:number_of_points,1)          = parameter_1(:)          ;
    parameter_2(1:number_of_points,1)          = parameter_2(:)          ;
    parameter_1_type(1:number_of_points,1)      = parameter_1_type(:)      ;
    parameter_2_type(1:number_of_points,1)      = parameter_2_type(:)      ;
    salinity(1:number_of_points,1)           = salinity(:)           ;
    temperature_in(1:number_of_points,1)        = temperature_in(:)        ;
    temperature_out(1:number_of_points,1)       = temperature_out(:)       ;
    pressure_in(1:number_of_points,1)        = pressure_in(:)        ;
    pressure_out(1:number_of_points,1)       = pressure_out(:)       ;
    silicate(1:number_of_points,1)            = silicate(:)            ;
    phosphate(1:number_of_points,1)           = phosphate(:)           ;
    ammonia(1:number_of_points,1)           = ammonia(:)           ;
    sulphide(1:number_of_points,1)           = sulphide(:)           ;
    pH_scale_in(1:number_of_points,1)     = pH_scale_in(:)     ;
    which_k1_k2_constants(1:number_of_points,1) = which_k1_k2_constants(:) ;
    which_kso4_constant(1:number_of_points,1)  = which_kso4_constant(:)  ;
    which_kf_constant(1:number_of_points,1)    = which_kf_constant(:)    ;
    which_boron(1:number_of_points,1)         = which_boron(:)         ;
    
    % Assign input to the 'historical' variable names.
    pH_scale_in_GLOBAL      = pH_scale_in;
    which_k1_k2_constants_GLOBAL      = which_k1_k2_constants;
    which_kso4_constant_GLOBAL    = which_kso4_constant;
    which_kf_constant_GLOBAL      = which_kf_constant;
    which_boron_GLOBAL      = which_boron;
    temperature_in_GLOBAL       = temperature_in;
    temperature_out_GLOBAL       = temperature_out;
    pressure_in_GLOBAL       = pressure_in;
    pressure_out_GLOBAL       = pressure_out;
    salinity_GLOBAL          = salinity;
    sqrt_salinity_GLOBAL       = sqrt(salinity);
    phosphate_GLOBAL           = phosphate;
    silicate_GLOBAL          = silicate;
    ammonia_GLOBAL         = ammonia;
    sulphide_GLOBAL         = sulphide;
    
    gas_constant_GLOBAL = 83.14462618; % ml bar-1 K-1 mol-1,
    
    % Generate empty vectors for...
    TA   = nan(number_of_points,1); % Talk
    TC   = nan(number_of_points,1); % DIC
    PH   = nan(number_of_points,1); % pH
    PC   = nan(number_of_points,1); % pCO2
    FC   = nan(number_of_points,1); % fCO2
    HCO3 = nan(number_of_points,1); % [HCO3]
    CO3  = nan(number_of_points,1); % [CO3]
    CO2  = nan(number_of_points,1); % [CO2*]
    
    % Assign values to empty vectors.
    selected_GLOBAL=(parameter_1_type==1 & parameter_1~=-999);   TA(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_1_type==2 & parameter_1~=-999);   TC(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_1_type==3 & parameter_1~=-999);   PH(selected_GLOBAL)=parameter_1(selected_GLOBAL);
    selected_GLOBAL=(parameter_1_type==4 & parameter_1~=-999);   PC(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from microatm. to atm.
    selected_GLOBAL=(parameter_1_type==5 & parameter_1~=-999);   FC(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from microatm. to atm.
    selected_GLOBAL=(parameter_1_type==6 & parameter_1~=-999); HCO3(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_1_type==7 & parameter_1~=-999);  CO3(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_1_type==8 & parameter_1~=-999);  CO2(selected_GLOBAL)=parameter_1(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_2_type==1 & parameter_2~=-999);   TA(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_2_type==2 & parameter_2~=-999);   TC(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_2_type==3 & parameter_2~=-999);   PH(selected_GLOBAL)=parameter_2(selected_GLOBAL);
    selected_GLOBAL=(parameter_2_type==4 & parameter_2~=-999);   PC(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from microatm. to atm.
    selected_GLOBAL=(parameter_2_type==5 & parameter_2~=-999);   FC(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from microatm. to atm.
    selected_GLOBAL=(parameter_2_type==6 & parameter_2~=-999); HCO3(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_2_type==7 & parameter_2~=-999);  CO3(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    selected_GLOBAL=(parameter_2_type==8 & parameter_2~=-999);  CO2(selected_GLOBAL)=parameter_2(selected_GLOBAL)/1e6; % Convert from micromol/kg to mol/kg
    
    % Generate the columns holding Si, Phos, Amm, H2S and salinity_GLOBAL.
    % Pure Water case:
    selected_GLOBAL=(which_k1_k2_constants_GLOBAL==8);
    salinity_GLOBAL(selected_GLOBAL) = 0;
    % GEOSECS and Pure Water:
    selected_GLOBAL=(which_k1_k2_constants_GLOBAL==8 | which_k1_k2_constants_GLOBAL==6);  
    phosphate_GLOBAL(selected_GLOBAL)  = 0;
    silicate_GLOBAL(selected_GLOBAL) = 0;
    ammonia_GLOBAL(selected_GLOBAL)  = 0;
    sulphide_GLOBAL(selected_GLOBAL)  = 0;
    % All other cases
    selected_GLOBAL=~selected_GLOBAL;                         
    phosphate_GLOBAL(selected_GLOBAL)   = phosphate_GLOBAL(selected_GLOBAL)./1e6;
    silicate_GLOBAL(selected_GLOBAL)  = silicate_GLOBAL(selected_GLOBAL)./1e6;
    ammonia_GLOBAL(selected_GLOBAL) = ammonia_GLOBAL(selected_GLOBAL)./1e6;
    sulphide_GLOBAL(selected_GLOBAL) = sulphide_GLOBAL(selected_GLOBAL)./1e6;
    
    % The vector 'peng_correction_GLOBAL' is used to modify the value of TA, for those
    % cases where which_k1_k2_constants_GLOBAL==7, since PAlk(Peng) = PAlk(Dickson) + phosphate_GLOBAL.
    % Thus, peng_correction_GLOBAL is 0 for all cases where which_k1_k2_constants_GLOBAL is not 7
    peng_correction_GLOBAL=zeros(number_of_points,1); selected_GLOBAL=which_k1_k2_constants_GLOBAL==7; peng_correction_GLOBAL(selected_GLOBAL)=phosphate_GLOBAL(selected_GLOBAL);
    
    % Calculate the constants for all samples at input conditions
    % The constants calculated for each sample will be on the appropriate pH scale!
    calculate_equilibrium_constants(temperature_in_GLOBAL,pressure_in_GLOBAL);
    
    % Added by JM Epitalon
    % For computing derivative with respect to Ks, one has to perturb the value of one K
    % Requested perturbation is passed through global variables k_perturbation_GLOBAL and Perturb
    if (~ isempty(k_perturbation_GLOBAL))
        switch k_perturbation_GLOBAL
            case {'K0'}
                K0 = K0 + Perturb;
            case {'K1'}
                K1 = K1 + Perturb;
            case {'K2'}
                K2 = K2 + Perturb;
            case {'KB'}
                KB = KB + Perturb;
            case {'KW'}
                KW = KW + Perturb;
            case {'BOR'}
                boron_concentration_GLOBAL = boron_concentration_GLOBAL + Perturb;
        end
    end
    
    
    % Make sure fCO2 is available for each sample that has pCO2 or CO2.
    selected_GLOBAL = (~isnan(PC) & (parameter_1_type==4 | parameter_2_type==4));  FC(selected_GLOBAL) = PC(selected_GLOBAL).*FugFac(selected_GLOBAL);
    selected_GLOBAL = (~isnan(CO2) & (parameter_1_type==8 | parameter_2_type==8)); FC(selected_GLOBAL) = CO2(selected_GLOBAL)./K0(selected_GLOBAL);
    
    % Generate vectors for results, and copy the raw input values into them
    TAc    = TA;
    TCc    = TC;
    PHic   = PH;
    PCic   = PC;
    FCic   = FC;
    HCO3ic = HCO3;
    CO3ic  = CO3;
    CO2ic  = CO2;
    
    % Generate vector describing the combination of input parameters
    % So, the valid ones are:
    % 12,13,15,16,17,18,23,25,26,27,28,35,36,37,38,56,57,67,68,78
    combination = 10*min(parameter_1_type,parameter_2_type) + max(parameter_1_type,parameter_2_type);
    
    % Calculate missing values for AT,CT,PH,FC,HCO3,CO3,CO2:
    % pCO2 will be calculated later on, routines work with fCO2.
    selected_GLOBAL=combination==12; % input TA, TC
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TAc) & ~isnan(TCc) & selected_GLOBAL);
        PHic(selected_GLOBAL)                = CalculatepHfromTATC(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),TCc(selected_GLOBAL));
        selected_GLOBAL=(~isnan(PHic) & selected_GLOBAL);
        if any(selected_GLOBAL)
           FCic(selected_GLOBAL)              = CalculatefCO2fromTCpH(TCc(selected_GLOBAL), PHic(selected_GLOBAL));
           [CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL)] = CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        end
    end
    selected_GLOBAL=combination==13; % input TA, pH
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TAc) & ~isnan(PHic) & selected_GLOBAL);
        TCc(selected_GLOBAL)                 = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
        FCic(selected_GLOBAL)                = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        [CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL)]   = CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==14 | combination==15 | combination==18; % input TA, (pCO2 or fCO2 or CO2)
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TAc) & ~isnan(FCic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                = CalculatepHfromTAfCO2(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),FCic(selected_GLOBAL));
        selected_GLOBAL=(~isnan(PHic) & selected_GLOBAL);
        if any(selected_GLOBAL)
           TCc(selected_GLOBAL)              = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
           [CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL)]= CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        end
    end
    selected_GLOBAL=combination==16; % input TA, HCO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TAc) & ~isnan(HCO3ic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                = CalculatepHfromTAHCO3(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),HCO3ic(selected_GLOBAL));  % added Peng correction // MPH
        selected_GLOBAL=(~isnan(PHic) & selected_GLOBAL);
        if any(selected_GLOBAL)
           TCc(selected_GLOBAL)              = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
           FCic(selected_GLOBAL)             = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)); 
           CO3ic(selected_GLOBAL)            = CalculateCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        end
    end
    selected_GLOBAL=combination==17; % input TA, CO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TAc) & ~isnan(CO3ic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                 = CalculatepHfromTACO3(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),CO3ic(selected_GLOBAL));  % added Peng correction // MPH
        selected_GLOBAL=(~isnan(PHic) & selected_GLOBAL);
        if any(selected_GLOBAL)
           TCc(selected_GLOBAL)               = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
           FCic(selected_GLOBAL)              = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)); 
           HCO3ic(selected_GLOBAL)            = CalculateHCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        end
    end
    selected_GLOBAL=combination==23; % input TC, pH
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TCc) & ~isnan(PHic) & selected_GLOBAL);
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        FCic(selected_GLOBAL)                 = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        [CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL)]    = CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL), PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==24 | combination==25 | combination==28;  % input TC, (pCO2 or fCO2 or CO2)
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TCc) & ~isnan(FCic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                 = CalculatepHfromTCfCO2(TCc(selected_GLOBAL),FCic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        [CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL)]    = CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==26; % input TC, HCO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TCc) & ~isnan(HCO3ic) & selected_GLOBAL);
        [PHic(selected_GLOBAL),FCic(selected_GLOBAL)]       = CalculatepHfCO2fromTCHCO3(TCc(selected_GLOBAL),HCO3ic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        CO3ic(selected_GLOBAL)                = CalculateCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==27; % input TC, CO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(TCc) & ~isnan(CO3ic) & selected_GLOBAL);
        [PHic(selected_GLOBAL),FCic(selected_GLOBAL)]       = CalculatepHfCO2fromTCCO3(TCc(selected_GLOBAL),CO3ic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        HCO3ic(selected_GLOBAL)               = CalculateHCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==34 | combination==35 | combination==38; % input pH, (pCO2 or fCO2 or CO2)
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(PHic) & ~isnan(FCic) & selected_GLOBAL);
        TCc(selected_GLOBAL)                  = CalculateTCfrompHfCO2(PHic(selected_GLOBAL),FCic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        [CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL)]    = CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==36; % input pH, HCO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(PHic) & ~isnan(HCO3ic) & selected_GLOBAL);
        TAc(selected_GLOBAL)                  = CalculateTAfrompHHCO3(PHic(selected_GLOBAL),HCO3ic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        TCc(selected_GLOBAL)                  = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
        FCic(selected_GLOBAL)                 = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        CO3ic(selected_GLOBAL)                = CalculateCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==37; % input pH, CO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(PHic) & ~isnan(CO3ic) & selected_GLOBAL);
        TAc(selected_GLOBAL)                  = CalculateTAfrompHCO3(PHic(selected_GLOBAL),CO3ic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        TCc(selected_GLOBAL)                  = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
        FCic(selected_GLOBAL)                 = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        HCO3ic(selected_GLOBAL)               = CalculateHCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==46 | combination==56 | combination==68; % input (pCO2 or fCO2 or CO2), HCO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(FCic) & ~isnan(HCO3ic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                 = CalculatepHfromfCO2HCO3(FCic(selected_GLOBAL),HCO3ic(selected_GLOBAL));
        TCc(selected_GLOBAL)                  = CalculateTCfrompHfCO2(PHic(selected_GLOBAL),FCic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        CO3ic(selected_GLOBAL)                = CalculateCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==47 | combination==57 | combination==78; % input (pCO2 or fCO2 or CO2), CO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(FCic) & ~isnan(CO3ic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                 = CalculatepHfromfCO2CO3(FCic(selected_GLOBAL),CO3ic(selected_GLOBAL));
        TCc(selected_GLOBAL)                  = CalculateTCfrompHfCO2 (PHic(selected_GLOBAL),FCic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        HCO3ic(selected_GLOBAL)               = CalculateHCO3fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    selected_GLOBAL=combination==67; % input HCO3, CO3
    if any(selected_GLOBAL)
    selected_GLOBAL=(~isnan(HCO3ic) & ~isnan(CO3ic) & selected_GLOBAL);
        PHic(selected_GLOBAL)                 = CalculatepHfromCO3HCO3(CO3ic(selected_GLOBAL),HCO3ic(selected_GLOBAL));
        TAc(selected_GLOBAL)                  = CalculateTAfrompHCO3(PHic(selected_GLOBAL),CO3ic(selected_GLOBAL)) + peng_correction_GLOBAL(selected_GLOBAL);
        TCc(selected_GLOBAL)                  = CalculateTCfromTApH(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL),PHic(selected_GLOBAL));
        FCic(selected_GLOBAL)                 = CalculatefCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
        %CO2ic(selected_GLOBAL)                = CalculateCO2fromTCpH(TCc(selected_GLOBAL),PHic(selected_GLOBAL));
    end
    
    % By now, an fCO2 value is available for each sample.
    % Generate the associated pCO2 value:
    selected_GLOBAL = (isnan(PCic) & (parameter_1_type~=4 | parameter_2_type~=4)); PCic(selected_GLOBAL)  = FCic(selected_GLOBAL)./FugFac(selected_GLOBAL);
    % Generate the associated CO2 value:
    selected_GLOBAL = (isnan(CO2ic) & (parameter_1_type~=8 | parameter_2_type~=8)); CO2ic(selected_GLOBAL) = FCic(selected_GLOBAL).*K0(selected_GLOBAL);
    
    % Calculate Other Params At Input Conditions:
    BAlkinp    = nan(number_of_points,1); % Generate empty vectors
    [OHinp,PAlkinp,SiAlkinp,AmmAlkinp,HSAlkinp,Hfreeinp,HSO4inp,HFinp,...
        Revelleinp,OmegaCainp,OmegaArinp,xCO2dryinp] = deal(BAlkinp);
    selected_GLOBAL=(~isnan(PHic)); % if PHic = NaN, pH calculation was not performed or did not converge
    [BAlkinp(selected_GLOBAL),OHinp(selected_GLOBAL), PAlkinp(selected_GLOBAL),SiAlkinp(selected_GLOBAL),AmmAlkinp(selected_GLOBAL),...
        HSAlkinp(selected_GLOBAL), Hfreeinp(selected_GLOBAL),HSO4inp(selected_GLOBAL),HFinp(selected_GLOBAL)] = CalculateAlkParts(PHic(selected_GLOBAL));
    PAlkinp(selected_GLOBAL)                = PAlkinp(selected_GLOBAL)+peng_correction_GLOBAL(selected_GLOBAL);
    Revelleinp(selected_GLOBAL)             = RevelleFactor(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL), TCc(selected_GLOBAL));
    [OmegaCainp(selected_GLOBAL),OmegaArinp(selected_GLOBAL)] = CaSolubility(salinity_GLOBAL(selected_GLOBAL), temperature_in_GLOBAL(selected_GLOBAL), pressure_in_GLOBAL(selected_GLOBAL), TCc(selected_GLOBAL), PHic(selected_GLOBAL));
    xCO2dryinp(~isnan(PCic),1) = PCic(~isnan(PCic),1)./VPFac(~isnan(PCic),1); % ' this assumes pTot = 1 atm
    SIRinp = HCO3ic./(Hfreeinp.*1e6);
    
    % % Just for reference, convert pH at input conditions to the other scales
    pHicT = nan(number_of_points,1);
    pHicS = nan(number_of_points,1);
    pHicF = nan(number_of_points,1);
    pHicN = nan(number_of_points,1);
    [pHicT(selected_GLOBAL),pHicS(selected_GLOBAL),pHicF(selected_GLOBAL),pHicN(selected_GLOBAL)]=FindpHOnAllScales(PHic(selected_GLOBAL));
    
    % Merge the Ks at input into an array. Ks at output will be glued to this later.
    KIVEC=[K0 K1 K2 -log10(K1) -log10(K2) KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S];
    
    % Calculate the constants for all samples at output conditions
    calculate_equilibrium_constants(temperature_out_GLOBAL,pressure_out_GLOBAL);
    
    % Added by JM Epitalon
    % For computing derivative with respect to Ks, one has to perturb the value of one K
    % Requested perturbation is passed through global variables k_perturbation_GLOBAL and Perturb
    if (~ isempty(k_perturbation_GLOBAL))
        switch k_perturbation_GLOBAL
            case {'K0'}
                K0 = K0 + Perturb;
            case {'K1'}
                K1 = K1 + Perturb;
            case {'K2'}
                K2 = K2 + Perturb;
            case {'KB'}
                KB = KB + Perturb;
            case {'KW'}
                KW = KW + Perturb;
            case {'BOR'}
                boron_concentration_GLOBAL = boron_concentration_GLOBAL + Perturb;
        end
    end                  

    % For output conditions, using conservative TA and TC, calculate pH, fCO2
    % and pCO2, HCO3, CO3, and CO2
    selected_GLOBAL=(~isnan(TAc) & ~isnan(TCc)); % i.e., do for all samples that have TA and TC values
    PHoc=nan(number_of_points,1);
    [CO3oc,HCO3oc,FCoc] = deal(PHoc);
    PHoc(selected_GLOBAL) = CalculatepHfromTATC(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL), TCc(selected_GLOBAL)); % pH is returned on the scale requested in "pHscale" (see 'constants'...)
        FCoc(selected_GLOBAL) = CalculatefCO2fromTCpH(TCc(selected_GLOBAL), PHoc(selected_GLOBAL));
        [CO3oc(selected_GLOBAL),HCO3oc(selected_GLOBAL)] = CalculateCO3HCO3fromTCpH(TCc(selected_GLOBAL),PHoc(selected_GLOBAL));
    
    % Generate the associated pCO2 value:
    PCoc  = FCoc./FugFac;
    % Generate the associated CO2 value:
    CO2oc = FCoc.*K0;
    
    % Calculate Other Params At Output Conditions:
    BAlkout    = nan(number_of_points,1); % Generate empty vectors
    [OHout,PAlkout,SiAlkout,AmmAlkout,HSAlkout,Hfreeout,HSO4out,HFout,...
        Revelleout,OmegaCaout,OmegaArout,xCO2dryout] = deal(BAlkout);
    selected_GLOBAL=(~isnan(PHoc)); % if PHoc = NaN, pH calculation was not performed or did not converge
    [BAlkout(selected_GLOBAL),OHout(selected_GLOBAL),PAlkout(selected_GLOBAL),SiAlkout(selected_GLOBAL),AmmAlkout(selected_GLOBAL),...
        HSAlkout(selected_GLOBAL), Hfreeout(selected_GLOBAL),HSO4out(selected_GLOBAL),HFout(selected_GLOBAL)] = CalculateAlkParts(PHoc(selected_GLOBAL));
    PAlkout(selected_GLOBAL)                 = PAlkout(selected_GLOBAL)+peng_correction_GLOBAL(selected_GLOBAL);
    Revelleout(selected_GLOBAL)              = RevelleFactor(TAc(selected_GLOBAL)-peng_correction_GLOBAL(selected_GLOBAL), TCc(selected_GLOBAL));
    [OmegaCaout(selected_GLOBAL),OmegaArout(selected_GLOBAL)] = CaSolubility(salinity_GLOBAL(selected_GLOBAL), temperature_out_GLOBAL(selected_GLOBAL), pressure_out_GLOBAL(selected_GLOBAL), TCc(selected_GLOBAL), PHoc(selected_GLOBAL));
    xCO2dryout(~isnan(PCoc),1)    = PCoc(~isnan(PCoc))./VPFac(~isnan(PCoc)); % ' this assumes pTot = 1 atm
    SIRout = HCO3oc./(Hfreeout.*1e6);
    
    % Just for reference, convert pH at output conditions to the other scales
    pHocT = nan(number_of_points,1);
    pHocS = nan(number_of_points,1);
    pHocF = nan(number_of_points,1);
    pHocN = nan(number_of_points,1);
    [pHocT(selected_GLOBAL),pHocS(selected_GLOBAL),pHocF(selected_GLOBAL),pHocN(selected_GLOBAL)]=FindpHOnAllScales(PHoc(selected_GLOBAL));
    
    KOVEC=[K0 K1 K2 -log10(K1) -log10(K2) KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S];
    TVEC =[boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL];
    
    % Saving data in array, 99 columns, as many rows as samples input
    data=[TAc*1e6         TCc*1e6        PHic           PCic*1e6        FCic*1e6...
          HCO3ic*1e6      CO3ic*1e6      CO2ic*1e6      BAlkinp*1e6     OHinp*1e6...
          PAlkinp*1e6     SiAlkinp*1e6   AmmAlkinp*1e6  HSAlkinp*1e6    Hfreeinp*1e6... %%% Multiplied Hfreeinp *1e6, svh20100827
          Revelleinp      OmegaCainp     OmegaArinp     xCO2dryinp*1e6  SIRinp...
          PHoc            PCoc*1e6       FCoc*1e6       HCO3oc*1e6      CO3oc*1e6...
          CO2oc*1e6       BAlkout*1e6    OHout*1e6      PAlkout*1e6     SiAlkout*1e6...
          AmmAlkout*1e6   HSAlkout*1e6   Hfreeout*1e6   Revelleout      OmegaCaout... %%% Multiplied Hfreeout *1e6, svh20100827
          OmegaArout      xCO2dryout*1e6 SIRout         pHicT           pHicS...
          pHicF           pHicN          pHocT          pHocS           pHocF...
          pHocN           temperature_in         temperature_out        pressure_in          pressure_out...
          parameter_1_type        parameter_2_type       which_k1_k2_constants  which_kso4_constant    which_kf_constant...
          which_boron           pH_scale_in      salinity            phosphate             silicate...
          ammonia             sulphide            KIVEC          KOVEC           TVEC*1e6];
    data(isnan(data))=-999;
    
    headers={'TAlk';'TCO2';'pHin';'pCO2in';'fCO2in';'HCO3in';'CO3in';...
        'CO2in';'BAlkin';'OHin';'PAlkin';'SiAlkin';'AmmAlkin';'HSAlkin';...
        'Hfreein';'RFin';'OmegaCAin';'OmegaARin';'xCO2in';'SIRin';'pHout';...
        'pCO2out';'fCO2out';'HCO3out';'CO3out';'CO2out';'BAlkout';'OHout';...
        'PAlkout';'SiAlkout';'AmmAlkout';'HSAlkout';'Hfreeout';'RFout';'OmegaCAout';...
        'OmegaARout';'xCO2out';'SIRout';'pHinTOTAL';'pHinSWS';'pHinFREE';'pHinNBS';...
        'pHoutTOTAL';'pHoutSWS';'pHoutFREE';'pHoutNBS';'TEMPIN';'TEMPOUT';...
        'PRESIN';'PRESOUT';'PAR1TYPE';'PAR2TYPE';'K1K2CONSTANTS';'KSO4CONSTANT';... KSO4CONSTANTS => KSO4CONSTANT // MPH
        'KFCONSTANT';'BORON';'pHSCALEIN';'SAL';'PO4';'SI';'NH4';'H2S';'K0input';...
        'K1input';'K2input';'pK1input';'pK2input';'KWinput';'KBinput';'KFinput';...
        'KSinput';'KP1input';'KP2input';'KP3input';'KSiinput';'KNH4input';...
        'KH2Sinput';'K0output';'K1output';'K2output';'pK1output';'pK2output';...
        'KWoutput';'KBoutput';'KFoutput';'KSoutput';'KP1output';'KP2output';...
        'KP3output';'KSioutput';'KNH4output';'KH2Soutput';'boron_concentration_GLOBAL';'fluorine_concentration_GLOBAL';'sulphate_concentration_GLOBAL';...
        'phosphate_GLOBAL';'silicate_GLOBAL';'ammonia_GLOBAL';'sulphide_GLOBAL'};
    
    nice_headers={...
        '01 - TAlk             (umol/kgSW) ';
        '02 - TCO2             (umol/kgSW) ';
        '03 - pHin             ()          ';
        '04 - pCO2in           (uatm)      ';
        '05 - fCO2in           (uatm)      ';
        '06 - HCO3in           (umol/kgSW) ';
        '07 - CO3in            (umol/kgSW) ';
        '08 - CO2in            (umol/kgSW) ';
        '09 - BAlkin           (umol/kgSW) ';
        '10 - OHin             (umol/kgSW) ';
        '11 - PAlkin           (umol/kgSW) ';
        '12 - SiAlkin          (umol/kgSW) ';
        '13 - AmmAlkin         (umol/kgSW) ';
        '14 - HSAlkin          (umol/kgSW) ';
        '15 - Hfreein          (umol/kgSW) ';
        '16 - RevelleFactorin  ()          ';
        '17 - OmegaCain        ()          ';
        '18 - OmegaArin        ()          ';
        '19 - xCO2in           (ppm)       ';
        '20 - SIRin            ()          ';
        '21 - pHout            ()          ';
        '22 - pCO2out          (uatm)      ';
        '23 - fCO2out          (uatm)      ';
        '24 - HCO3out          (umol/kgSW) ';
        '25 - CO3out           (umol/kgSW) ';
        '26 - CO2out           (umol/kgSW) ';
        '27 - BAlkout          (umol/kgSW) ';
        '28 - OHout            (umol/kgSW) ';
        '29 - PAlkout          (umol/kgSW) ';
        '30 - SiAlkout         (umol/kgSW) ';
        '31 - AmmAlkout        (umol/kgSW) ';
        '32 - HSAlkout         (umol/kgSW) ';
        '33 - Hfreeout         (umol/kgSW) ';
        '34 - RevelleFactorout ()          ';
        '35 - OmegaCaout       ()          ';
        '36 - OmegaArout       ()          ';
        '37 - xCO2out          (ppm)       ';
        '38 - SIRout           ()          ';
        '39 - pHin (Total)     ()          ';
        '40 - pHin (SWS)       ()          ';
        '41 - pHin (Free)      ()          ';
        '42 - pHin (NBS )      ()          ';
        '43 - pHout(Total)     ()          ';
        '44 - pHout(SWS)       ()          ';
        '45 - pHout(Free)      ()          ';
        '46 - pHout(NBS )      ()          ';
        '47 - TEMPIN           (Deg C)     ';    
        '48 - TEMPOUT          (Deg C)     ';
        '49 - PRESIN           (dbar)      ';
        '50 - PRESOUT          (dbar)      ';
        '51 - PAR1TYPE         ()          ';
        '52 - PAR2TYPE         ()          ';
        '53 - K1K2CONSTANTS    ()          ';
        '54 - KSO4CONSTANT     ()          ';
        '55 - KFCONSTANT       ()          ';
        '56 - BORON            ()          ';
        '57 - pHSCALEIN        ()          ';
        '58 - SAL              (umol/kgSW) ';
        '59 - PO4              (umol/kgSW) ';
        '60 - SI               (umol/kgSW) ';
        '61	- NH4	           (umol/kgSW) ';
        '62	- H2S	           (umol/kgSW) ';
        '63 - K0input          ()          ';
        '64 - K1input          ()          ';
        '65 - K2input          ()          ';
        '66 - pK1input         ()          ';
        '67 - pK2input         ()          ';
        '68 - KWinput          ()          ';
        '69 - KBinput          ()          ';
        '70 - KFinput          ()          ';
        '71 - KSinput          ()          ';
        '72 - KP1input         ()          ';
        '73 - KP2input         ()          ';
        '74 - KP3input         ()          ';
        '75 - KSiinput         ()          ';
        '76 - KNH4input        ()          ';
        '77 - KH2Sinput        ()          ';  
        '78 - K0output         ()          ';
        '79 - K1output         ()          ';
        '80 - K2output         ()          ';
        '81 - pK1output        ()          ';
        '82 - pK2output        ()          ';
        '83 - KWoutput         ()          ';
        '84 - KBoutput         ()          ';
        '85 - KFoutput         ()          ';
        '86 - KSoutput         ()          ';
        '87 - KP1output        ()          ';
        '88 - KP2output        ()          ';
        '89 - KP3output        ()          ';
        '90 - KSioutput        ()          ';
        '91 - KNH4output       ()          ';
        '92 - KH2Soutput       ()          ';
        '93 - boron_concentration_GLOBAL               (umol/kgSW) ';
        '94 - fluorine_concentration_GLOBAL               (umol/kgSW) ';
        '95 - sulphate_concentration_GLOBAL               (umol/kgSW) ';
        '96 - phosphate_GLOBAL               (umol/kgSW) ';
        '97 - silicate_GLOBAL              (umol/kgSW) ';
        '98 - ammonia_GLOBAL             (umol/kgSW) ';
        '99 - sulphide_GLOBAL             (umol/kgSW) '};
    
    clear global selected_GLOBAL K2 KP3 pressure_in_GLOBAL salinity_GLOBAL sulphate_concentration_GLOBAL VPFac number_of_points 
    clear global FugFac KB KS pressure_out_GLOBAL T silicate_GLOBAL BORON which_k1_k2_constants_GLOBAL pH_scale_in_GLOBAL 
    clear global K KF KSi KNH4 KH2S peng_correction_GLOBAL boron_concentration_GLOBAL temperature_in_GLOBAL which_kso4_constant_GLOBAL which_kf_constant_GLOBAL which_boron_GLOBAL sqrt_salinity_GLOBAL 
    clear global K0 KP1 KW gas_constant_GLOBAL fluorine_concentration_GLOBAL temperature_out_GLOBAL fH 
    clear global K1 KP2 Pbar phosphate_GLOBAL temp_k_GLOBAL log_temp_k_GLOBAL
	
end 

function varargout=CalculatepHfromTATC(TAi, TCi)
    global K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL;
    % ' SUB CalculatepHfromTATC, version 04.01, 10-13-96, written by Ernie Lewis
    % ' with modifications from Denis Pierrot.
    % ' Inputs: TA, TC, K(), T()
    % ' Output: pH
    %
    % ' This calculates pH from TA and TC using K1 and K2 by Newton's method.
    % ' It tries to solve for the pH at which Residual = 0.
    % ' The starting guess is determined by the method introduced by Munhoven
    % ' (2013).
    %
    % ' Made this to accept vectors. It will continue iterating until all
    % ' values in the vector are "abs(deltapH) < pHTol". SVH2007
    % ' However, once a given abs(deltapH) is less than pHTol, that pH value
    % ' will be locked in. This avoids erroneous contributions to results from
    % ' other lines of input. JDS2020
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    vl          = sum(selected_GLOBAL);  % VectorLength
    % Find initital pH guess using method of Munhoven (2013)
    pHGuess         = CalculatepHfromTATCMunhoven(TAi, TCi);
    ln10            = log(10);
    pH              = pHGuess;
    pHTol           = 0.0001;  % tolerance for iterations end
    deltapH(1:vl,1) = pHTol+1;
    loopc=0;
    nF=(abs(deltapH) > pHTol);
    while any(nF)
        H         = 10.^(-pH);
        Denom     = (H.*H + K1F.*H + K1F.*K2F);
        CAlk      = TCi.*K1F.*(H + 2.*K2F)./Denom;
        BAlk      = TBF.*KBF./(KBF + H);
        OH        = KWF./H;
        PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
        PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
        PAlk      = TPF.*PhosTop./PhosBot;
        SiAlk     = TSiF.*KSiF./(KSiF + H);
        AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
        HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
        [~,~,pHfree,~] = FindpHOnAllScales(pH); % this converts pH to pHfree no matter the scale
        Hfree     = 10.^-pHfree; % this converts pHfree to Hfree
        HSO4      = TSF./(1 + KSF./Hfree); % since KS is on the free scale
        HF        = TFF./(1 + KFF./Hfree); % since KF is on the free scale
        Residual  = TAi - CAlk - BAlk - OH - PAlk - SiAlk  - AmmAlk - HSAlk + Hfree + HSO4 + HF;
        % find Slope dTA/dpH;
        % (this is not exact, but keeps all important terms);
        Slope     = ln10.*(TCi.*K1F.*H.*(H.*H + K1F.*K2F + 4.*H.*K2F)./Denom./Denom + BAlk.*H./(KBF + H) + OH + H);
        deltapH   = Residual./Slope; %' this is Newton's method
        % ' to keep the jump from being too big:
        while any(abs(deltapH) > 1)
            FF=abs(deltapH)>1; deltapH(FF)=deltapH(FF)./2;
        end
        pH(nF) = pH(nF) + deltapH(nF);
        nF     = abs(deltapH) > pHTol;
        loopc=loopc+1;
     
        if loopc>10000
            Fr=find(abs(deltapH) > pHTol);
            pH(Fr)=NaN;  disp(['pH value did not converge for data on row(s): ' num2str((Fr)')]);
            deltapH=pHTol*0.9;
        end
    end
    varargout{1}=pH;
end

function varargout=CalculatefCO2fromTCpH(TCx, pHx)
    global K0 K1 K2 selected_GLOBAL
    % ' SUB CalculatefCO2fromTCpH, version 02.02, 12-13-96, written by Ernie Lewis.
    % ' Inputs: TC, pH, K0, K1, K2
    % ' Output: fCO2
    % ' This calculates fCO2 from TC and pH, using K0, K1, and K2.
    H            = 10.^(-pHx);
    fCO2x        = TCx.*H.*H./(H.*H + K1(selected_GLOBAL).*H + K1(selected_GLOBAL).*K2(selected_GLOBAL))./K0(selected_GLOBAL);
    varargout{1} = fCO2x;
    end % end nested function
    
    function varargout=CalculateTCfromTApH(TAx, pHx)
    global K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    % ' SUB CalculateTCfromTApH, version 02.03, 10-10-97, written by Ernie Lewis.
    % ' Inputs: TA, pH, K(), T()
    % ' Output: TC
    % ' This calculates TC from TA and pH.
    H         = 10.^(-pHx);
    BAlk      = TBF.*KBF./(KBF + H);
    OH        = KWF./H;
    PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
    PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
    PAlk      = TPF.*PhosTop./PhosBot;
    SiAlk     = TSiF.*KSiF./(KSiF + H);
    AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
    HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
    [~,~,pHfree,~] = FindpHOnAllScales(pHx); % this converts pH to pHfree no matter the scale
    Hfree     = 10.^-pHfree; % this converts pHfree to Hfree
    HSO4      = TSF./(1 + KSF./Hfree); %' since KS is on the free scale
    HF        = TFF./(1 + KFF./Hfree); %' since KF is on the free scale
    CAlk      = TAx - BAlk - OH - PAlk - SiAlk - AmmAlk - HSAlk + Hfree + HSO4 + HF;
    TCxtemp   = CAlk.*(H.*H + K1F.*H + K1F.*K2F)./(K1F.*(H + 2.*K2F));
    varargout{1} = TCxtemp;
end % end nested function

function varargout=CalculatepHfromTAfCO2(TAi, fCO2i)
    global K0 K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    % ' SUB CalculatepHfromTAfCO2, version 04.01, 10-13-97, written by Ernie
    % ' Lewis with modifications from Denis Pierrot.
    % ' Inputs: TA, fCO2, K0, K(), T()
    % ' Output: pH
    % ' This calculates pH from TA and fCO2 using K1 and K2 by Newton's method.
    % ' It tries to solve for the pH at which Residual = 0.
    % ' The starting guess is determined by the method introduced by Munhoven
    % ' (2013) and extended by Humphreys et al. (2021).
    %
    % ' This will continue iterating until all values in the vector are
    % ' "abs(deltapH) < pHTol"
    % ' However, once a given abs(deltapH) is less than pHTol, that pH value
    % ' will be locked in. This avoids erroneous contributions to results from
    % ' other lines of input.
    K0F=K0(selected_GLOBAL);     K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    vl         = sum(selected_GLOBAL); % vectorlength
    % Find initital pH guess using method of Munhoven (2013)
    CO2i       = fCO2i.*K0F; % Convert fCO2 to CO2
    pHGuess    = CalculatepHfromTACO2Munhoven(TAi, CO2i);
    ln10       = log(10);
    pH         = pHGuess;
    pHTol      = 0.0001; % tolerance
    deltapH = pHTol+pH;
    loopc=0;
    nF=(abs(deltapH) > pHTol);
    while any(nF)
        H         = 10.^(-pH);
        HCO3      = K0F.*K1F.*fCO2i./H;
        CO3       = K0F.*K1F.*K2F.*fCO2i./(H.*H);
        CAlk      = HCO3 + 2.*CO3;
        BAlk      = TBF.*KBF./(KBF + H);
        OH        = KWF./H;
        PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
        PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
        PAlk      = TPF.*PhosTop./PhosBot;
        SiAlk     = TSiF.*KSiF./(KSiF + H);
        AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
        HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
        [~,~,pHfree,~] = FindpHOnAllScales(pH); % this converts pH to pHfree no matter the scale
        Hfree     = 10.^-pHfree; % this converts pHfree to Hfree
        HSO4      = TSF./(1 + KSF./Hfree); %' since KS is on the free scale
        HF        = TFF./(1 + KFF./Hfree);% ' since KF is on the free scale
        Residual  = TAi - CAlk - BAlk - OH - PAlk - SiAlk - AmmAlk - HSAlk + Hfree + HSO4 + HF;
        % '               find Slope dTA/dpH
        % '               (this is not exact, but keeps all important terms):
        Slope     = ln10.*(HCO3 + 4.*CO3 + BAlk.*H./(KBF + H) + OH + H);
        deltapH   = Residual./Slope; %' this is Newton's method
        % ' to keep the jump from being too big:
        while any(abs(deltapH) > 1)
            FF=abs(deltapH)>1; deltapH(FF)=deltapH(FF)./2;
        end
        pH(nF) = pH(nF) + deltapH(nF);
        nF     = abs(deltapH) > pHTol;
        loopc=loopc+1;
     
        if loopc>10000
            Fr=find(abs(deltapH) > pHTol);
            pH(Fr)=NaN;  disp(['pH value did not converge for data on row(s): ' num2str((Fr)')]);
            deltapH=pHTol*0.9;
        end
    end
    varargout{1}=pH;
end

function varargout=CalculateTAfromTCpH(TCi, pHi)
    global K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    % ' SUB CalculateTAfromTCpH, version 02.02, 10-10-97, written by Ernie Lewis.
    % ' Inputs: TC, pH, K(), T()
    % ' Output: TA
    % ' This calculates TA from TC and pH.
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    H         = 10.^(-pHi);
    CAlk      = TCi.*K1F.*(H + 2.*K2F)./(H.*H + K1F.*H + K1F.*K2F);
    BAlk      = TBF.*KBF./(KBF + H);
    OH        = KWF./H;
    PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
    PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
    PAlk      = TPF.*PhosTop./PhosBot;
    SiAlk     = TSiF.*KSiF./(KSiF + H);
    AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
    HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
    [~,~,pHfree,~] = FindpHOnAllScales(pHi); % this converts pH to pHfree no matter the scale
    Hfree = 10.^-pHfree; % this converts pHfree to Hfree
    HSO4      = TSF./(1 + KSF./Hfree);% ' since KS is on the free scale
    HF        = TFF./(1 + KFF./Hfree);% ' since KF is on the free scale
    TActemp    = CAlk + BAlk + OH + PAlk + SiAlk + AmmAlk + HSAlk - Hfree - HSO4 - HF;
    varargout{1}=TActemp;
end

function varargout=CalculatepHfromTCfCO2(TCi, fCO2i)
    global K0 K1 K2 selected_GLOBAL;
    % ' SUB CalculatepHfromTCfCO2, version 02.02, 11-12-96, written by Ernie Lewis.
    % ' Inputs: TC, fCO2, K0, K1, K2
    % ' Output: pH
    % ' This calculates pH from TC and fCO2 using K0, K1, and K2 by solving the
    % '       quadratic in H: fCO2.*K0 = TC.*H.*H./(K1.*H + H.*H + K1.*K2).
    % ' if there is not a real root, then pH is returned as missingn.
    RR = K0(selected_GLOBAL).*fCO2i./TCi;
    %       if RR >= 1
    %          varargout{1}= missingn;
    %          disp('nein!');return;
    %       end
    % check after sub to see if pH = missingn.
    Discr = (K1(selected_GLOBAL).*RR).*(K1(selected_GLOBAL).*RR) + 4.*(1 - RR).*(K1(selected_GLOBAL).*K2(selected_GLOBAL).*RR);
    H     = 0.5.*(K1(selected_GLOBAL).*RR + sqrt(Discr))./(1 - RR);
    %       if (H <= 0)
    %           pHctemp = missingn;
    %       else
    pHctemp = log(H)./log(0.1);
    %       end
    varargout{1}=pHctemp;
end

function varargout=CalculateTCfrompHfCO2(pHi, fCO2i)
    global K0 K1 K2 selected_GLOBAL;
    % ' SUB CalculateTCfrompHfCO2, version 01.02, 12-13-96, written by Ernie Lewis.
    % ' Inputs: pH, fCO2, K0, K1, K2
    % ' Output: TC
    % ' This calculates TC from pH and fCO2, using K0, K1, and K2.
    H       = 10.^(-pHi);
    TCctemp = K0(selected_GLOBAL).*fCO2i.*(H.*H + K1(selected_GLOBAL).*H + K1(selected_GLOBAL).*K2(selected_GLOBAL))./(H.*H);
    varargout{1}=TCctemp;
end

function varargout=CalculateTAfrompHHCO3(pHi, HCO3i)
    global K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    % ' SUB CalculateTAfrompHCO3, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: pH, HCO3, K(), T()
    % ' Output: TA
    % ' This calculates TA from pH and HCO3.
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    H         = 10.^(-pHi);
    CAlk      = HCO3i.*(2.*K2F./H + 1);
    BAlk      = TBF.*KBF./(KBF + H);
    OH        = KWF./H;
    PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
    PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
    PAlk      = TPF.*PhosTop./PhosBot;
    SiAlk     = TSiF.*KSiF./(KSiF + H);
    AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
    HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
    [~,~,pHfree,~] = FindpHOnAllScales(pHi); % this converts pH to pHfree no matter the scale
    Hfree = 10.^-pHfree; % this converts pHfree to Hfree
    HSO4      = TSF./(1 + KSF./Hfree);% ' since KS is on the free scale
    HF        = TFF./(1 + KFF./Hfree);% ' since KF is on the free scale
    TActemp     = CAlk + BAlk + OH + PAlk + SiAlk + AmmAlk + HSAlk - Hfree - HSO4 - HF;
    varargout{1}=TActemp;
end

function varargout=CalculatepHfromTAHCO3(TAi, HCO3i)
    global K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    % ' SUB CalculatepHfromTAHCO3, version 01.0, 8-18, added by J. Sharp with
    % ' modifications from Denis Pierrot.
    % ' Inputs: TA, CO3, K0, K(), T()
    % ' Output: pH
    %
    % ' This calculates pH from TA and CO3 using K1 and K2 by Newton's method.
    % ' It tries to solve for the pH at which Residual = 0.
    % ' The starting guess is determined by the method introduced by Munhoven
    % ' (2013) and extended by Humphreys et al. (2021).
    %
    % ' This will continue iterating until all values in the vector are
    % ' "abs(deltapH) < pHTol"
    % ' However, once a given abs(deltapH) is less than pHTol, that pH value
    % ' will be locked in. This avoids erroneous contributions to results from
    % ' other lines of input.
    K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    vl         = sum(selected_GLOBAL); % vectorlength
    % Find initital pH guess using method of Munhoven (2013)
    pHGuess    = CalculatepHfromTAHCO3Munhoven(TAi, HCO3i);
    ln10       = log(10);
    pH         = pHGuess;
    pHTol      = 0.0001; % tolerance
    deltapH    = pHTol+pH;
    loopc=0;
    nF=(abs(deltapH) > pHTol);
    while any(nF)
        H         = 10.^(-pH);
        CAlk      = HCO3i.*(H+2.*K2F)./H;
        BAlk      = TBF.*KBF./(KBF + H);
        OH        = KWF./H;
        PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
        PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
        PAlk      = TPF.*PhosTop./PhosBot;
        SiAlk     = TSiF.*KSiF./(KSiF + H);
        AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
        HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
        [~,~,pHfree,~] = FindpHOnAllScales(pH); % this converts pH to pHfree no matter the scale
        Hfree = 10.^-pHfree; % this converts pHfree to Hfree
        HSO4      = TSF./(1 + KSF./Hfree); %' since KS is on the free scale
        HF        = TFF./(1 + KFF./Hfree);% ' since KF is on the free scale
        Residual  = TAi - CAlk - BAlk - OH - PAlk - SiAlk - AmmAlk - HSAlk + Hfree + HSO4 + HF;
        % '               find Slope dTA/dpH
        % '               (this is not exact, but keeps all important terms):
        Slope = ln10 .* (2 .* HCO3i .* K2F ./ H + BAlk .* H ./ (KBF + H) + OH + H);
        deltapH   = Residual./Slope; %' this is Newton's method
        % ' to keep the jump from being too big:
        while any(abs(deltapH) > 1)
            FF=abs(deltapH)>1; deltapH(FF)=deltapH(FF)./2;
        end
        pH(nF) = pH(nF) + deltapH(nF);
        nF     = abs(deltapH) > pHTol;
        loopc=loopc+1;
     
        if loopc>10000
            Fr=find(abs(deltapH) > pHTol);
            pH(Fr)=NaN;  disp(['pH value did not converge for data on row(s): ' num2str((Fr)')]);
            deltapH=pHTol*0.9;
        end
    end
    varargout{1}=pH;
end

function varargout=CalculatepHfromTCHCO3(TCi, HCO3i)
    global K1 K2 selected_GLOBAL;
    % ' SUB CalculatepHfromTCHCO3, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: TC, HCO3, K0, K1, K2
    % ' Output: pH
    % ' This calculates pH from TC and HCO3 using K1 and K2 by solving the
    % '       quadratic in H: TC = HCO3i.*(H./K1 + 1 + K2./H).
    % '       Therefore:      0  = H.*H./K1 + (1-TC/HCO3i).*H + K2.
    % ' if there is not a real root, then pH is returned as missingn.
    RR = TCi./HCO3i;
    %       if RR >= 1
    %          varargout{1}= missingn;
    %          disp('nein!');return;
    %       end
    % check after sub to see if pH = missingn.
    Discr = ((1-RR).*(1-RR) - 4.*(1./(K1(selected_GLOBAL))).*(K2(selected_GLOBAL)));
    H     = 0.5.*((-(1-RR)) - sqrt(Discr))./(1./(K1(selected_GLOBAL))); % Subtraction
    %       if (H <= 0)
    %           pHctemp = missingn;
    %       else
    pHctemp = log(H)./log(0.1);
    %       end
    varargout{1}=pHctemp;
end

function varargout=CalculatepHfromfCO2HCO3(fCO2i, HCO3i)
    global K0 K1 selected_GLOBAL;
    % ' SUB CalculatepHfromfCO2HCO3, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: fCO2, HCO3, K0, K1, K2
    % ' Output: pH
    % ' This calculates pH from fCO2 and HCO3, using K0, K1, and K2.
    H            = (fCO2i.*K0(selected_GLOBAL).*K1(selected_GLOBAL))./HCO3i;  % removed incorrect (selected_GLOBAL) index from HCO3i // MPH
    pHx          = -log10(H);
    varargout{1} = pHx;
    end % end nested function
    
    function varargout=CalculatepHfCO2fromTCHCO3(TCx, HCO3x)
    % Outputs pH fCO2, in that order
    % SUB CalculatepHfCO2fromTCHCO3, version 01.0, 3-19, added by J. Sharp
    % Inputs: pHScale%, which_k1_k2_constants_GLOBAL%, which_kso4_constant_GLOBAL%, TC, HCO3, salinity_GLOBAL, K(), T(), TempC, Pdbar
    % Outputs: pH, fCO2
    % This calculates pH and fCO2 from TC and HCO3 at output conditions.
    pHx   = CalculatepHfromTCHCO3(TCx, HCO3x); % pH is returned on the scale requested in "pHscale" (see 'constants'...)
    fCO2x = CalculatefCO2fromTCpH(TCx, pHx);
    varargout{1} = pHx;
    varargout{2} = fCO2x;
    end


function varargout=CalculateTAfrompHCO3(pHi, CO3i)
    global K1 K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    % ' SUB CalculateTAfrompHCO3, version 01.0, 8-18, added by J. Sharp
    % ' Inputs: pH, CO3, K(), T()
    % ' Output: TA
    % ' This calculates TA from pH and CO3.
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    H         = 10.^(-pHi);
    CAlk      = CO3i.*(H./K2F + 2);
    BAlk      = TBF.*KBF./(KBF + H);
    OH        = KWF./H;
    PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
    PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
    PAlk      = TPF.*PhosTop./PhosBot;
    SiAlk     = TSiF.*KSiF./(KSiF + H);
    AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
    HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
    [~,~,pHfree,~] = FindpHOnAllScales(pHi); % this converts pH to pHfree no matter the scale
    Hfree = 10.^-pHfree; % this converts pHfree to Hfree
    HSO4      = TSF./(1 + KSF./Hfree);% ' since KS is on the free scale
    HF        = TFF./(1 + KFF./Hfree);% ' since KF is on the free scale
    TActemp     = CAlk + BAlk + OH + PAlk + SiAlk + AmmAlk + HSAlk - Hfree - HSO4 - HF;
    varargout{1}=TActemp;
end

function varargout=CalculatepHfromTACO3(TAi, CO3i)
    global K2 KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL
    % ' SUB CalculatepHfromTACO3, version 01.0, 8-18, added by J. Sharp with
    % ' modifications from Denis Pierrot.
    % ' Inputs: TA, CO3, K0, K(), T()
    % ' Output: pH
    %
    % ' This calculates pH from TA and CO3 using K1 and K2 by Newton's method.
    % ' It tries to solve for the pH at which Residual = 0.
    % ' The starting guess is determined by the method introduced by Munhoven
    % ' (2013) and extended by Humphreys et al. (2021).
    %
    % ' This will continue iterating until all values in the vector are
    % ' "abs(deltapH) < pHTol"
    % ' However, once a given abs(deltapH) is less than pHTol, that pH value
    % ' will be locked in. This avoids erroneous contributions to results from
    % ' other lines of input.
    K2F=K2(selected_GLOBAL);     KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    vl         = sum(selected_GLOBAL); % vectorlength
    % Find initital pH guess using method of Munhoven (2013)
    pHGuess    = CalculatepHfromTACO3Munhoven(TAi, CO3i);
    ln10       = log(10);
    pH         = pHGuess;
    pHTol      = 0.0001; % tolerance
    deltapH    = pHTol+pH;
    loopc=0;
    nF=(abs(deltapH) > pHTol);
    while any(nF)
        H         = 10.^(-pH);
        CAlk      = CO3i.*(H+2.*K2F)./K2F;
        BAlk      = TBF.*KBF./(KBF + H);
        OH        = KWF./H;
        PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
        PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
        PAlk      = TPF.*PhosTop./PhosBot;
        SiAlk     = TSiF.*KSiF./(KSiF + H);
        AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
        HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
        [~,~,pHfree,~] = FindpHOnAllScales(pH); % this converts pH to pHfree no matter the scale
        Hfree = 10.^-pHfree; % this converts pHfree to Hfree
        HSO4      = TSF./(1 + KSF./Hfree); %' since KS is on the free scale
        HF        = TFF./(1 + KFF./Hfree);% ' since KF is on the free scale
        Residual  = TAi - CAlk - BAlk - OH - PAlk - SiAlk - AmmAlk - HSAlk + Hfree + HSO4 + HF;
        % '               find Slope dTA/dpH
        % '               (this is not exact, but keeps all important terms):
        Slope = ln10 .* (-CO3i .* H ./ K2F + BAlk .* H ./ (KBF + H) + OH + H);
        deltapH   = Residual./Slope; %' this is Newton's method
        % ' to keep the jump from being too big:
        while any(abs(deltapH) > 1)
            FF=abs(deltapH)>1; deltapH(FF)=deltapH(FF)./2;
        end
        pH(nF) = pH(nF) + deltapH(nF);
        nF     = abs(deltapH) > pHTol;
        loopc=loopc+1;
     
        if loopc>10000 
            Fr=find(abs(deltapH) > pHTol);
            pH(Fr)=NaN;  disp(['pH value did not converge for data on row(s): ' num2str((Fr)')]);
            deltapH=pHTol*0.9;
        end
    end
    varargout{1}=pH;
end

function varargout=CalculatepHfromTCCO3(TCi, CO3i)
    global K1 K2 selected_GLOBAL;
    % ' SUB CalculatepHfromTCCO3, version 01.0, 8-18, added by J. Sharp
    % ' Inputs: TC, CO3, K0, K1, K2
    % ' Output: pH
    % ' This calculates pH from TC and CO3 using K1 and K2 by solving the
    % '       quadratic in H: TC = CO3i.*(H.*H/(K1.*K2) + H./K2 + 1).
    % '       Therefore:      0  = H.*H/(K1.*K2) + H./K2 + (1-TC./CO3i).
    % ' if there is not a real root, then pH is returned as missingn.
    RR = TCi./CO3i;
    %       if RR >= 1
    %          varargout{1}= missingn;
    %          disp('nein!');return;
    %       end
    % check after sub to see if pH = missingn.
    Discr = ((1./K2(selected_GLOBAL)).*(1./K2(selected_GLOBAL)) - 4.*(1./(K1(selected_GLOBAL).*K2(selected_GLOBAL))).*(1-RR));
    H     = 0.5.*((-1./K2(selected_GLOBAL)) + sqrt(Discr))./(1./(K1(selected_GLOBAL).*K2(selected_GLOBAL))); % Addition
    %       if (H <= 0)
    %           pHctemp = missingn;
    %       else
    pHctemp = log(H)./log(0.1);
    %       end
    varargout{1}=pHctemp;
end

function varargout=CalculatepHfromfCO2CO3(fCO2i, CO3i)
    global K0 K1 K2 selected_GLOBAL;
    % ' SUB CalculatepHfromfCO2CO3, version 01.0, 8-18, added by J. Sharp
    % ' Inputs: fCO2, CO3, K0, K1, K2
    % ' Output: pH
    % ' This calculates pH from fCO2 and CO3, using K0, K1, and K2.
    H            = sqrt((fCO2i.*K0(selected_GLOBAL).*K1(selected_GLOBAL).*K2(selected_GLOBAL))./CO3i);    % removed incorrect (selected_GLOBAL) index from CO3i // MPH
    pHx          = -log10(H);
    varargout{1} = pHx;
end

function varargout=CalculatepHfCO2fromTCCO3(TCx, CO3x)
    % Outputs pH fCO2, in that order
    % SUB CalculatepHfCO2fromTCCO3, version 01.0, 8-18, added by J. Sharp
    % Inputs: pHScale%, which_k1_k2_constants_GLOBAL%, which_kso4_constant_GLOBAL%, TC, CO3, salinity_GLOBAL, K(), T(), TempC, Pdbar
    % Outputs: pH, fCO2
    % This calculates pH and fCO2 from TC and CO3 at output conditions.
    pHx   = CalculatepHfromTCCO3(TCx, CO3x); % pH is returned on the scale requested in "pHscale" (see 'constants'...)
    fCO2x = CalculatefCO2fromTCpH(TCx, pHx);
    varargout{1} = pHx;
    varargout{2} = fCO2x;
end

function varargout=CalculatepHfromCO3HCO3(CO3x, HCO3x)
    global K2 selected_GLOBAL
    % ' SUB CalculatepHfromCO3HCO3, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: CO3, HCO3, K2
    % ' Output: pH
    % ' This calculates fCO2 from TC and pH, using K2.
    H            = HCO3x.*K2(selected_GLOBAL)./CO3x;
    pHx          = -log10(H);
    varargout{1} = pHx;
end

function varargout=CalculateCO3HCO3fromTCpH(TCx, pHx)
    global K1 K2 selected_GLOBAL
    % ' SUB CalculateCO3HCO3CO2fromTCpH, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: TC, pH, K1, K2
    % ' Output: CO3, HCO3, CO2
    % ' This calculates CO3, HCO3, and CO2 from TC and pH, using K1, and K2.
    H            = 10.^(-pHx);
    CO3x         = TCx.*K1(selected_GLOBAL).*K2(selected_GLOBAL)./(K1(selected_GLOBAL).*H + H.*H + K1(selected_GLOBAL).*K2(selected_GLOBAL));
    HCO3x        = TCx.*K1(selected_GLOBAL).*H./(K1(selected_GLOBAL).*H + H.*H + K1(selected_GLOBAL).*K2(selected_GLOBAL));
    varargout{1} = CO3x;
    varargout{2} = HCO3x;
end

function varargout=CalculateCO3fromTCpH(TCx, pHx)
    global K1 K2 selected_GLOBAL
    % ' SUB CalculateCO3CO2fromTCpH, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: TC, pH, K1, K2
    % ' Output: CO3, CO2
    % ' This calculates CO3 and CO2 from TC and pH, using K1, and K2.
    H            = 10.^(-pHx);
    CO3x         = TCx.*K1(selected_GLOBAL).*K2(selected_GLOBAL)./(K1(selected_GLOBAL).*H + H.*H + K1(selected_GLOBAL).*K2(selected_GLOBAL));
    varargout{1} = CO3x;
end

function varargout=CalculateHCO3fromTCpH(TCx, pHx)
    global K1 K2 selected_GLOBAL
    % ' SUB CalculateHCO3CO2fromTCpH, version 01.0, 3-19, added by J. Sharp
    % ' Inputs: TC, pH, K1, K2
    % ' Output: HCO3, CO2
    % ' This calculates HCO3 and CO2 from TC and pH, using K1, and K2.
    H            = 10.^(-pHx);
    HCO3x        = TCx.*K1(selected_GLOBAL).*H./(K1(selected_GLOBAL).*H + H.*H + K1(selected_GLOBAL).*K2(selected_GLOBAL));
    varargout{1} = HCO3x;
end


function varargout=CalculatepHfromTATCMunhoven(TAi, TCi)
    global K1 K2 KB boron_concentration_GLOBAL selected_GLOBAL;
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    g0 = K1F.*K2F.*KBF.*(1-(2.*TCi+TBF)./TAi);
    g1 = K1F.*(KBF.*(1-TBF./TAi-TCi./TAi)+K2F.*(1-2.*TCi./TAi));
    g2 = KBF.*(1-TBF./TAi)+K1F.*(1-TCi./TAi);
    % Determine g21min
    g21min = g2.^2-3.*g1;
    g21min_positive = g21min > 0;
    sq21 = nan(size(TAi,1),1);
    sq21(g21min_positive) = sqrt(g21min(g21min_positive));
    sq21(~g21min_positive) = 0;
    % Determine Hmin
    Hmin = nan(size(TAi,1),1);
    g2_positive = g2 >=0;
    Hmin(~g2_positive) = (-g2(~g2_positive) + sq21(~g2_positive))./3;
    Hmin(g2_positive) = -g1(g2_positive)./(g2(g2_positive) + sq21(g2_positive));
    % Calculate initial pH
    pHGuess = nan(size(TAi,1),1);
    idx = TAi <= 0;
    pHGuess(idx) = -log10(1e-3);
    idx = TAi > 0 & TAi < 2.*TCi + TBF;
    pHGuess(idx & g21min_positive) = ...
        -log10(Hmin(idx & g21min_positive) + ...
        sqrt(-(Hmin(idx & g21min_positive).^3 + g2(idx & g21min_positive).*Hmin(idx & g21min_positive).^2 + ...
        g1(idx & g21min_positive).*Hmin(idx & g21min_positive) + ...
        g0(idx & g21min_positive))./sq21(idx & g21min_positive)));
    pHGuess(idx & ~g21min_positive) = -log10(1e-7);
    idx = TAi >= 2.*TCi + TBF;
    pHGuess(idx) = -log10(1e-10);
    varargout{1}=pHGuess;
end

function varargout=CalculatepHfromTACO2Munhoven(TAi, CO2x)
    global K1 K2 KB boron_concentration_GLOBAL selected_GLOBAL;
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    g0 = -2.*K1F.*K2F.*KBF.*CO2x./TAi;
    g1 = -K1F.*(2.*K2F.*CO2x+KBF.*CO2x)./TAi;
    g2 = KBF-(TBF.*KBF+K1F.*CO2x)./TAi;
    % Determine Hmin
    g21min = g2.^2-3.*g1;
    g21min_positive = g21min > 0;
    sq21 = nan(size(TAi,1),1);
    sq21(g21min_positive) = sqrt(g21min(g21min_positive));
    sq21(~g21min_positive) = 0;
    Hmin = nan(size(TAi,1),1);
    g2_positive = g2 >=0;
    Hmin(~g2_positive) = (-g2(~g2_positive) + sq21(~g2_positive))./3;
    Hmin(g2_positive) = -g1(g2_positive)./(g2(g2_positive) + sq21(g2_positive));
    % Calculate initial pH
    pHGuess = nan(size(TAi,1),1);
    idx = TAi <= 0;
    pHGuess(idx) = -log10(1e-3);
    idx = TAi > 0;
    pHGuess(idx & g21min_positive) = ...
        -log10(Hmin(idx & g21min_positive) + ...
        sqrt(-(Hmin(idx & g21min_positive).^3 + g2(idx & g21min_positive).*Hmin(idx & g21min_positive).^2 + ...
        g1(idx & g21min_positive).*Hmin(idx & g21min_positive)+...
        g0(idx & g21min_positive))./sq21(idx & g21min_positive)));
    pHGuess(idx & ~g21min_positive) = -log10(1e-7);
    varargout{1}=pHGuess;
end

function varargout=CalculatepHfromTAHCO3Munhoven(TAi, HCO3x)
    global K1 K2 KB boron_concentration_GLOBAL selected_GLOBAL;
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    g0 = 2.*K2F.*KBF.*HCO3x;
    g1 = KBF.*(HCO3x+TBF-TAi)+2.*K2F.*HCO3x;
    g2 = HCO3x-TAi;
    % Calculate initial pH
    pHGuess = nan(size(TAi,1),1);
    idx = TAi <= HCO3x;
    pHGuess(idx) = -log10(1e-3);
    idx = TAi > HCO3x;
    pHGuess(idx) = ...
        -log10((-g1(idx)-sqrt(g1(idx).^2-4.*g0(idx).*g2(idx)))./(2.*g2(idx)));
    varargout{1}=pHGuess;
end

function varargout=CalculatepHfromTACO3Munhoven(TAi, CO3x)
    global K1 K2 KB boron_concentration_GLOBAL selected_GLOBAL;
    K1F=K1(selected_GLOBAL);     K2F=K2(selected_GLOBAL);     TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    g0 = K2F.*KBF.*(2.*CO3x+TBF-TAi);
    g1 = KBF.*CO3x+K2F.*(2.*CO3x-TAi);
    g2 = CO3x;
    % Calculate initial pH
    pHGuess = nan(size(TAi,1),1);
    idx = TAi <= 2.*CO3x+TBF;
    pHGuess(idx) = -log10(1e-3);
    idx = TAi > 2.*CO3x+TBF;
    pHGuess(idx) = ...
        -log10((-g1(idx)+sqrt(g1(idx).^2-4.*g0(idx).*g2(idx)))./(2.*g2(idx)));
    varargout{1}=pHGuess;
end

function varargout=RevelleFactor(TAi, TCi)
    % global which_k1_k2_constants_GLOBAL;
    % ' SUB RevelleFactor, version 01.03, 01-07-97, written by Ernie Lewis.
    % ' Inputs: which_k1_k2_constants_GLOBAL%, TA, TC, K0, K(), T()
    % ' Outputs: Revelle
    % ' This calculates the Revelle factor (dfCO2/dTC)|TA/(fCO2/TC).
    % ' It only makes sense to talk about it at pTot = 1 atm, but it is computed
    % '       here at the given K(), which may be at pressure <> 1 atm. Care must
    % '       thus be used to see if there is any validity to the number computed.
    TC0 = TCi;
    dTC = 0.00000001;% ' 0.01 umol/kg-SW (lower than prior versions of CO2SYS)
    % ' Find fCO2 at TA, TC + dTC
    TCi = TC0 + dTC;
    pHc= CalculatepHfromTATC(TAi, TCi);
    fCO2c= CalculatefCO2fromTCpH(TCi, pHc);
    fCO2plus = fCO2c;
    % ' Find fCO2 at TA, TC - dTC
    TCi = TC0 - dTC;
    pHc= CalculatepHfromTATC(TAi, TCi);
    fCO2c= CalculatefCO2fromTCpH(TCi, pHc);
    fCO2minus = fCO2c;
    % CalculateRevelleFactor:
    Revelle = (fCO2plus - fCO2minus)./dTC./((fCO2plus + fCO2minus)./TC0); % Corrected error pointed out by MP Humphreys (https://pyco2sys.readthedocs.io/en/latest/validate/)
    varargout{1}=Revelle;
end


function varargout=CalculateAlkParts(pH)
    global KW KB KF KS KP1 KP2 KP3 KSi KNH4 KH2S;
    global boron_concentration_GLOBAL fluorine_concentration_GLOBAL sulphate_concentration_GLOBAL phosphate_GLOBAL silicate_GLOBAL ammonia_GLOBAL sulphide_GLOBAL selected_GLOBAL;
    % ' SUB CalculateAlkParts, version 01.03, 10-10-97, written by Ernie Lewis.
    % ' Inputs: pH, TC, K(), T()
    % ' Outputs: BAlk, OH, PAlk, SiAlk, Hfree, HSO4, HF
    % ' This calculates the various contributions to the alkalinity.
    % ' Though it is coded for H on the total pH scale, for the pH values occuring
    % ' in seawater (pH > 6) it will be equally valid on any pH scale (H terms
    % ' negligible) as long as the K Constants are on that scale.
    
    KWF =KW(selected_GLOBAL);
    KP1F=KP1(selected_GLOBAL);   KP2F=KP2(selected_GLOBAL);   KP3F=KP3(selected_GLOBAL);   TPF=phosphate_GLOBAL(selected_GLOBAL);
    TSiF=silicate_GLOBAL(selected_GLOBAL);   KSiF=KSi(selected_GLOBAL);   TNH4F=ammonia_GLOBAL(selected_GLOBAL); KNH4F=KNH4(selected_GLOBAL);
    TH2SF=sulphide_GLOBAL(selected_GLOBAL); KH2SF=KH2S(selected_GLOBAL); TBF =boron_concentration_GLOBAL(selected_GLOBAL);    KBF=KB(selected_GLOBAL);
    TSF =sulphate_concentration_GLOBAL(selected_GLOBAL);    KSF =KS(selected_GLOBAL);    TFF =fluorine_concentration_GLOBAL(selected_GLOBAL);    KFF=KF(selected_GLOBAL);
    
    H         = 10.^(-pH);
    BAlk      = TBF.*KBF./(KBF + H);
    OH        = KWF./H;
    PhosTop   = KP1F.*KP2F.*H + 2.*KP1F.*KP2F.*KP3F - H.*H.*H;
    PhosBot   = H.*H.*H + KP1F.*H.*H + KP1F.*KP2F.*H + KP1F.*KP2F.*KP3F;
    PAlk      = TPF.*PhosTop./PhosBot;
    SiAlk     = TSiF.*KSiF./(KSiF + H);
    AmmAlk    = TNH4F.*KNH4F./(KNH4F + H);
    HSAlk     = TH2SF.*KH2SF./(KH2SF + H);
    [~,~,pHfree,~] = FindpHOnAllScales(pH); % this converts pH to pHfree no matter the scale
    Hfree = 10.^-pHfree; % this converts pHfree to Hfree
    HSO4      = TSF./(1 + KSF./Hfree); %' since KS is on the free scale
    HF        = TFF./(1 + KFF./Hfree); %' since KF is on the free scale
    
    varargout{1} = BAlk;  varargout{2} = OH; varargout{3} = PAlk;
    varargout{4} = SiAlk; varargout{5} = AmmAlk; varargout{6} = HSAlk;
    varargout{7} = Hfree; varargout{8} = HSO4; varargout{9} = HF;
end


function varargout=CaSolubility(salinity_GLOBAL, TempC, Pdbar, TC, pH)
    global K1 K2 temp_k_GLOBAL log_temp_k_GLOBAL sqrt_salinity_GLOBAL Pbar which_k1_k2_constants_GLOBAL CAL selected_GLOBAL
    global k_perturbation_GLOBAL    % Id of perturbed K
    global Perturb gas_constant_GLOBAL % perturbation
    % '***********************************************************************
    % ' SUB CaSolubility, version 01.05, 05-23-97, written by Ernie Lewis.
    % ' Inputs: which_k1_k2_constants_GLOBAL%, salinity_GLOBAL, temperature_in_GLOBAL, pressure_in_GLOBAL, TCi, pHi, K1, K2
    % ' Outputs: OmegaCa, OmegaAr
    % ' This calculates omega, the solubility ratio, for calcite and aragonite.
    % ' This is defined by: Omega = [CO3--]*[Ca++]./Ksp,
    % '       where Ksp is the solubility product (either KCa or KAr).
    % '***********************************************************************
    % ' These are from:
    % ' Mucci, Alphonso, The solubility of calcite and aragonite in seawater
    % '       at various salinities, temperatures, and one atmosphere total
    % '       pressure, American Journal of Science 283:781-799, 1983.
    % ' Ingle, S. E., Solubility of calcite in the ocean,
    % '       Marine Chemistry 3:301-319, 1975,
    % ' Millero, Frank, The thermodynamics of the carbonate system in seawater,
    % '       Geochemica et Cosmochemica Acta 43:1651-1661, 1979.
    % ' Ingle et al, The solubility of calcite in seawater at atmospheric pressure
    % '       and 35%o salinity, Marine Chemistry 1:295-307, 1973.
    % ' Berner, R. A., The solubility of calcite and aragonite in seawater in
    % '       atmospheric pressure and 34.5%o salinity, American Journal of
    % '       Science 276:713-730, 1976.
    % ' Takahashi et al, in GEOSECS Pacific Expedition, v. 3, 1982.
    % ' Culberson, C. H. and Pytkowicz, R. M., Effect of pressure on carbonic acid,
    % '       boric acid, and the pHi of seawater, Limnology and Oceanography
    % '       13:403-417, 1968.
    % '***********************************************************************
    Ca=CAL(selected_GLOBAL);
    Ar=nan(sum(selected_GLOBAL),1);
    KCa=nan(sum(selected_GLOBAL),1);
    KAr=nan(sum(selected_GLOBAL),1);
    TempKx=temp_k_GLOBAL(selected_GLOBAL);
    logTempKx=log_temp_k_GLOBAL(selected_GLOBAL);
    sqrSalx=sqrt_salinity_GLOBAL(selected_GLOBAL);
    Pbarx=Pbar(selected_GLOBAL);
    RR = (gas_constant_GLOBAL.*temp_k_GLOBAL);
    RTx = RR(selected_GLOBAL);
    FF=(which_k1_k2_constants_GLOBAL(selected_GLOBAL)~=6 & which_k1_k2_constants_GLOBAL(selected_GLOBAL)~=7);
    if any(FF)
    % (below here, selected_GLOBAL isn't used, since almost always all rows match the above criterium,
    %  in all other cases the rows will be overwritten later on).
        % CalciteSolubility:
        % '       Mucci, Alphonso, Amer. J. of Science 283:781-799, 1983.
        logKCa = -171.9065 - 0.077993.*TempKx(FF) + 2839.319./TempKx(FF);
        logKCa = logKCa + 71.595.*logTempKx(FF)./log(10);
        logKCa = logKCa + (-0.77712 + 0.0028426.*TempKx(FF) + 178.34./TempKx(FF)).*sqrSalx(FF);
        logKCa = logKCa - 0.07711.*salinity_GLOBAL(FF) + 0.0041249.*sqrSalx(FF).*salinity_GLOBAL(FF);
        % '       sd fit = .01 (for salinity_GLOBAL part, not part independent of salinity_GLOBAL)
        KCa(FF) = 10.^(logKCa);% ' this is in (mol/kg-SW)^2
        % AragoniteSolubility:
        % '       Mucci, Alphonso, Amer. J. of Science 283:781-799, 1983.
        logKAr = -171.945 - 0.077993.*TempKx(FF) + 2903.293./TempKx(FF);
        logKAr = logKAr + 71.595.*logTempKx(FF)./log(10);
        logKAr = logKAr + (-0.068393 + 0.0017276.*TempKx(FF) + 88.135./TempKx(FF)).*sqrSalx(FF);
        logKAr = logKAr - 0.10018.*salinity_GLOBAL(FF) + 0.0059415.*sqrSalx(FF).*salinity_GLOBAL(FF);
        % '       sd fit = .009 (for salinity_GLOBAL part, not part independent of salinity_GLOBAL)
        KAr(FF)    = 10.^(logKAr);% ' this is in (mol/kg-SW)^2
        % PressureCorrectionForCalcite:
        % '       Ingle, Marine Chemistry 3:301-319, 1975
        % '       same as in Millero, GCA 43:1651-1661, 1979, but Millero, GCA 1995
        % '       has typos (-.5304, -.3692, and 10^3 for Kappa factor)
        deltaVKCa = -48.76 + 0.5304.*TempC(FF);
        KappaKCa  = (-11.76 + 0.3692.*TempC(FF))./1000;
        lnKCafac  = (-deltaVKCa + 0.5.*KappaKCa.*Pbarx(FF)).*Pbarx(FF)./RTx(FF);
        KCa(FF)       = KCa(FF).*exp(lnKCafac);
        % PressureCorrectionForAragonite:
        % '       Millero, Geochemica et Cosmochemica Acta 43:1651-1661, 1979,
        % '       same as Millero, GCA 1995 except for typos (-.5304, -.3692,
        % '       and 10^3 for Kappa factor)
        deltaVKAr = deltaVKCa + 2.8;
        KappaKAr  = KappaKCa;
        lnKArfac  = (-deltaVKAr + 0.5.*KappaKAr.*Pbarx(FF)).*Pbarx(FF)./RTx(FF);
        KAr(FF)       = KAr(FF).*exp(lnKArfac);
    end
    FF=(which_k1_k2_constants_GLOBAL(selected_GLOBAL)==6 | which_k1_k2_constants_GLOBAL(selected_GLOBAL)==7);
    if any(FF)
        % *** CalculateKCaforGEOSECS:
        % Ingle et al, Marine Chemistry 1:295-307, 1973 is referenced in
        % (quoted in Takahashi et al, GEOSECS Pacific Expedition v. 3, 1982
        % but the fit is actually from Ingle, Marine Chemistry 3:301-319, 1975)
        KCa(FF) = 0.0000001.*(-34.452 - 39.866.*salinity_GLOBAL(FF).^(1./3) +...
            110.21.*log(salinity_GLOBAL(FF))./log(10) - 0.0000075752.*TempKx(FF).^2);
        % this is in (mol/kg-SW)^2
        %
        % *** CalculateKArforGEOSECS:
        % Berner, R. A., American Journal of Science 276:713-730, 1976:
        % (quoted in Takahashi et al, GEOSECS Pacific Expedition v. 3, 1982)
        KAr(FF) = 1.45.*KCa(FF);% ' this is in (mol/kg-SW)^2
        % Berner (p. 722) states that he uses 1.48.
        % It appears that 1.45 was used in the GEOSECS calculations
        %
        % *** CalculatePressureEffectsOnKCaKArGEOSECS:
        % Culberson and Pytkowicz, Limnology and Oceanography 13:403-417, 1968
        % (quoted in Takahashi et al, GEOSECS Pacific Expedition v. 3, 1982
        % but their paper is not even on this topic).
        % The fits appears to be new in the GEOSECS report.
        % I can't find them anywhere else.
        KCa(FF) = KCa(FF).*exp((36   - 0.2 .*TempC(FF)).*Pbarx(FF)./RTx(FF));
        KAr(FF) = KAr(FF).*exp((33.3 - 0.22.*TempC(FF)).*Pbarx(FF)./RTx(FF));
    end
    % Added by JM Epitalon
    % For computing derivative with respect to KCa or KAr, one has to perturb the value of one K
    % Requested perturbation is passed through global variables k_perturbation_GLOBAL and Perturb
    if (~ isempty(k_perturbation_GLOBAL))
        switch k_perturbation_GLOBAL
            case {'KSPA'}   % solubility Product for Aragonite
                KAr = KAr + Perturb;
            case {'KSPC'}   % for Calcite
                KCa = KCa + Perturb;
            case {'CAL'}   % for calcium concentration
                Ca  = Ca  + Perturb;
        end
    end
    
    % CalculateOmegasHere:
    H = 10.^(-pH);
    CO3 = TC.*K1(selected_GLOBAL).*K2(selected_GLOBAL)./(K1(selected_GLOBAL).*H + H.*H + K1(selected_GLOBAL).*K2(selected_GLOBAL));
    varargout{1} = CO3.*Ca./KCa; % OmegaCa, dimensionless
    varargout{2} = CO3.*Ca./KAr; % OmegaAr, dimensionless
end
    
function varargout=FindpHOnAllScales(pH)
    global pH_scale_in_GLOBAL sulphate_concentration_GLOBAL KS fluorine_concentration_GLOBAL KF fH selected_GLOBAL ntps;
    % ' SUB FindpHOnAllScales, version 01.02, 01-08-97, written by Ernie Lewis.
    % ' Inputs: pHScale%, pH, K(), T(), fH
    % ' Outputs: pHNBS, pHfree, pHTot, pHSWS
    % ' This takes the pH on the given scale and finds the pH on all scales.
    %  sulphate_concentration_GLOBAL = T(3); fluorine_concentration_GLOBAL = T(2);
    %  KS = K(6); KF = K(5);% 'these are at the given T, S, P
    TSx=sulphate_concentration_GLOBAL(selected_GLOBAL); KSx=KS(selected_GLOBAL); TFx=fluorine_concentration_GLOBAL(selected_GLOBAL); KFx=KF(selected_GLOBAL);fHx=fH(selected_GLOBAL);
    FREEtoTOT = (1 + TSx./KSx); % ' pH scale conversion factor
    SWStoTOT  = (1 + TSx./KSx)./(1 + TSx./KSx + TFx./KFx);% ' pH scale conversion factor
    factor=nan(sum(selected_GLOBAL),1);
    nF=pH_scale_in_GLOBAL(selected_GLOBAL)==1;  %'"pHtot"
    factor(nF) = 0;
    nF=pH_scale_in_GLOBAL(selected_GLOBAL)==2; % '"pHsws"
    factor(nF) = -log(SWStoTOT(nF))./log(0.1);
    nF=pH_scale_in_GLOBAL(selected_GLOBAL)==3; % '"pHfree"
    factor(nF) = -log(FREEtoTOT(nF))./log(0.1);
    nF=pH_scale_in_GLOBAL(selected_GLOBAL)==4;  %'"pHNBS"
    factor(nF) = -log(SWStoTOT(nF))./log(0.1) + log(fHx(nF))./log(0.1);
    pHtot  = pH    - factor;    % ' pH comes into this sub on the given scale
    pHNBS  = pHtot - log(SWStoTOT) ./log(0.1) + log(fHx)./log(0.1);
    pHfree = pHtot - log(FREEtoTOT)./log(0.1);
    pHsws  = pHtot - log(SWStoTOT) ./log(0.1);
    varargout{1}=pHtot;
    varargout{2}=pHsws;
    varargout{3}=pHfree;
    varargout{4}=pHNBS;
end
