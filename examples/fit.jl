using PropulsionBiology, Plots, LsqFit

init_databases()

motor = MotorDB["MN601S"]
bateria = BatteryDB["GNB HV 1700mAh 5S"]
propeller = PropellerDB["APC21x12WE"]
potencia = 600.0
tempo = 180.0
altdens = 1400
v_ar = range(0, 20, 21)

T = []
Q = []

for v in v_ar
    sim = run_propulsion_by_power(bateria, motor, propeller, potencia, v, altdens, tempo)
    push!(Q, sim[6])
    push!(T, sim[7])
end

function model_torque(x, p)
    p0, p1, p2, p3, p4 = p
    return p0 .+ p1.*x .+ p2.*x.^2 .+ p3.*x.^3 .+ p4.*x.^4
end

function model_traction(x, p)
    p0, p1, p2 = p
    return p0 .+ p1.*x .+ p2.*x.^2
end

fit_traction = curve_fit(model_traction, v_ar, T, [0.0, 0.0, 0.0])
T_fit = fit_traction.param
println(T_fit)
fit_torque = curve_fit(model_torque, v_ar, Q, [0.0, 0.0, 0.0, 0.0, 0.0])
Q_fit = fit_torque.param
println(Q_fit)


plot(v_ar, T, xlabel="Velocidade do ar [m/s]", ylabel="Tração [N]", label="Dados brutos")
plot!(v_ar, model(v_ar, T_fit), label="Fit", linestyle=:dash)
savefig("Fit Tração")
plot(v_ar, Q, xlabel="Velocidade do ar [m/s]", ylabel="Torque [N.m]", label="Dados brutos")
plot!(v_ar, model(v_ar, Q_fit), label="Fit", linestyle=:dash)
savefig("Fit Torque")
