# Vamos manter a logica de funcionamento com inputs

using PropulsionBiology, Plots

# Alteração: define os caminhos absolutos das planilhas usando o diretório deste arquivo
init_databases(
    battery_data = joinpath(@__DIR__, "Battery_data.xlsx"),
    motor_data   = joinpath(@__DIR__, "Motor_data.xlsx"),
    propeller_data = joinpath(@__DIR__, "Propeller_data_apc.xlsx")
)

# Definição dos conjuntos de propulsão a comparar
propulsion_sets = [
    (nome="MN601 21x12WE 5S", bateria=BatteryDB["GNB HV 1700mAh 5S"], motor=MotorDB["MN601S"], helice=PropellerDB["APC21x12WE"]),
    (nome="MN601 27X12E 4S", bateria=BatteryDB["Tatto 2300mAh 4S"], motor=MotorDB["MN601S"], helice=PropellerDB["APC27x13E"]),
]

potencia = 600.0 # W
tempo = 180.0    # voo
altdens = 1000.0  # m
v_ar = range(0, 20, 21)

# Inicializa dicionários para armazenar resultados de cada métrica para cada conjunto
results = Dict{String,Dict{Symbol,Vector{Float64}}}()
for cfg in propulsion_sets
    results[cfg.nome] = Dict(
        :traction => Float64[],
        :voltage  => Float64[],
        :current  => Float64[],
        :rpm      => Float64[],
        :motor_torque => Float64[],
        :power => Float64[],
        :motor_input => Float64[],
    )
end

# Loop para cada configuração e simulação
for cfg in propulsion_sets
    println("===================================")
    println("Iniciando análise para: ", cfg.nome)
    println("===================================")
    for v in v_ar
        sim = run_propulsion_by_power(cfg.bateria, cfg.motor, cfg.helice, potencia, v, altdens, tempo)
        push!(results[cfg.nome][:motor_input], sim[1])
        push!(results[cfg.nome][:current], sim[2])
        push!(results[cfg.nome][:voltage], sim[3])
        push!(results[cfg.nome][:power], sim[4])
        push!(results[cfg.nome][:rpm], sim[5])
        push!(results[cfg.nome][:motor_torque], sim[6])
        push!(results[cfg.nome][:traction], sim[7])
        print("Velocidade do ar [m/s]: ", v)
        println(sim[8])
    end
end

# Cria os gráficos comparativos: para cada métrica, adiciona uma curva por conjunto

# Plot de Tração
p1 = plot(title="Curva de Tração", xlabel="Velocidade do ar [m/s]", ylabel="Tração [N]",
          xlims=(0,20), ylims=(0,50), xticks=0:5:30, yticks=0:5:50, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p1, v_ar, results[cfg.nome][:traction], label=cfg.nome)
end

# Plot de Corrente
p2 = plot(title="Corrente vs Velocidade", xlabel="Velocidade do ar [m/s]", ylabel="Corrente [A]",
          xlims=(0,20), ylims=(0,50), xticks=0:5:30, yticks=0:5:100, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p2, v_ar, results[cfg.nome][:current], label=cfg.nome)
end

# Plot de Tensão
p3 = plot(title="Tensão vs Velocidade", xlabel="Velocidade do ar [m/s]", ylabel="Tensão [V]",
          xlims=(0,20), ylims=(0,30), xticks=0:5:30, yticks=0:5:50, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p3, v_ar, results[cfg.nome][:voltage], label=cfg.nome)
end

# Plot de Potência
p4 = plot(title="Potência vs Velocidade", xlabel="Velocidade do ar [m/s]", ylabel="Potência [W]",
          xlims=(0,20), ylims=(0,750), xticks=0:5:30, yticks=0:100:2000, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p4, v_ar, results[cfg.nome][:power], label=cfg.nome)
end

# Plot da Manete
p5 = plot(title="Manete vs Velocidade", xlabel="Velocidade do ar [m/s]", ylabel="Manete",
          xlims=(0,20), ylims=(0,1.0), xticks=0:5:30, yticks=0:0.1:1.0, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p5, v_ar, results[cfg.nome][:motor_input], label=cfg.nome)
end

# Plot de RPM
p6 = plot(title="RPM vs Velocidade", xlabel="Velocidade do ar [m/s]", ylabel="RPM",
          xlims=(0,20), ylims=(0,6000), xticks=0:5:30, yticks=0:500:6000, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p6, v_ar, results[cfg.nome][:rpm], label=cfg.nome)
end

# Plot do Torque do Motor
p7 = plot(title="Torque do Motor vs Velocidade", xlabel="Velocidade do ar [m/s]", ylabel="Torque [Nm]",
          xlims=(0,25), ylims=(0,2.0), xticks=0:5:30, yticks=0:0.25:4.0, minorgrid=:true)
for cfg in propulsion_sets
    plot!(p7, v_ar, results[cfg.nome][:motor_torque], label=cfg.nome)
end

# Layout com os plots
layout = @layout [a; b c d; e f g]
graph = plot(p1, p2, p3, p4, p5, p6, p7, layout=layout, size=(800,800))
display(graph)
#savefig(bateria.name*(" ")*motor.name*(" ")*helice.name)