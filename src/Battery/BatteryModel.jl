module BatteryModel

using XLSX

export Battery, BatteryDB
export build_battery_DB

# Estrutura da Bateria
struct Battery
    name::String            # Nome da bateria
    capacity::Float64       # Capacidade total (mAh)
    type::String            # Tipo da bateria: "LiFe" ou "LiPo"
    cells::Int              # Número de células em série
    resistance::Float64 # Resistência interna (Ohms)
    voltage::Float64     # Tensão total da bateria [V] [Inicia sem nada e carrega com o tipo]
    max_current::Float64 # Máxima corrente que a bateria é capaz de suportar [A]
    mass::Float64         # Peso da bateria (kg)
end

# Banco de dados de materiais
BatteryDB = Dict{String,Battery}()

# Função que controi o banco de dados de baterias
function build_battery_DB(battery_database_name::String)
    if !isfile(battery_database_name)
        battery_database_name = (@__DIR__) * "/Battery_data.xlsx" # Planilha padrão
    end

    # Obtem os nomes das paginas da planilha no arquivo
    data = XLSX.readtable(battery_database_name, "Sheet1").data

    for (name, type, cells, capacity, C, resistance, mass, observation, acqured) in zip(data...)
        voltages = VOLTAGE_CELL[type]
        # Calculando 90% do intervalo de voltagem máximo
        cell_voltage = voltages[:empty] + 0.9*(voltages[:full] - voltages[:empty]) 
        # Multiplicando pelo número de células
        total_voltage = cells*cell_voltage
        max_current = (total_voltage - voltages.empty*1.05*cells)/resistance # Corrente máxima de operação para que a tensão fique quase no mínimo
        BatteryDB[name] = Battery(name, capacity, type, cells, resistance, total_voltage, max_current, mass)
    end
end

# Tensão por célula em diferentes tipos de bateria
const VOLTAGE_CELL = Dict(
    "LiPO" => (nominal=3.7, full=4.2, empty=3.0),
    "LiPOHV" => (nominal=3.8, full=4.35, empty=3.0),
    "LiFe" => (nominal=3.3, full=3.65, empty=2.8)
)

end
