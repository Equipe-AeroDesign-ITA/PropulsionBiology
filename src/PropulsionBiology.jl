module PropulsionBiology

using COESA

include("Battery/BatteryModel.jl")
using .BatteryModel
export Battery, BatteryDB
export build_battery_DB, calculate_battery_runtime, calculate_battery_voltage_and_current   

include("Motor/MotorModel.jl")
using .MotorModel
export Motor, MotorDB
export build_motor_DB, calculate_motor_torque, calculate_motor_input, calculate_motor_efficiency

include("Propeller/PropellerModel.jl")
using .PropellerModel
export Propeller, PropellerDB
export build_propeller_DB, propeller_coeff_model, calculate_propeller_by_torque

include("PropulsionSimulation.jl")
using .Simulation
export run_propulsion_by_power, run_propulsion_by_input, check_constraints

export init_databases
function init_databases(; battery_data::String="Battery_data.xlsx", motor_data::String="Motor_data.xlsx", propeller_data::String="Propeller_data.xlsx")
    BatteryModel.build_battery_DB(battery_data)
    MotorModel.build_motor_DB(motor_data)
    PropellerModel.build_propeller_DB(propeller_data)
end

end