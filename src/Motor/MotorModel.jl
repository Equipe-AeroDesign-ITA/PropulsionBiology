module MotorModel

using XLSX

export Motor, MotorDB
export build_motor_DB, motor_restrictions

struct Motor
    name::String
    kv::Float64            # Constante KV do motor
    kq::Float64        # Constante KQ do motor, se não fornecida é igual ao KV.
    resistance::Float64    # Resistência interna (Ohms)
    no_load_current::Float64 # Corrente sem carga (A)
    current_peak::Float64  # Corrente máxima de pico (A)
    max_power::Float64      # Potência máxima (W)
    mass::Float64          # Peso do motor (kg)
end

# Banco de dados de materiais
MotorDB = Dict{String,Motor}()

# Função que controi o banco de dados de baterias
function build_motor_DB(motor_database_name::String)
    if !isfile(motor_database_name)
        motor_database_name = (@__DIR__) * "/Motor_data.xlsx" # Planilha padrão
    end

    # Obtem os nomes das paginas da planilha no arquivo
    data = XLSX.readtable(motor_database_name, "Sheet1").data

    for (name, KV, KQ, R, Io, Imax, Pmax, m, observation, acquired) in zip(data...)
        MotorDB[name] = Motor(name, KV, KQ, R, Io, Imax, Pmax, m)
    end
end

end
