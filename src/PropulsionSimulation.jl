module Simulation

using COESA, NLsolve

export run_propulsion_by_input, run_propulsion_by_power, check_constraints

# Função para calcular os estados baseados nas equações de equilíbrio
function run_propulsion_by_input(batt, motor, prop, Π, v_ar, altdens, time)
    ρ = COESA.density(COESA.atmosphere(altdens))  # Densidade do ar na altitude
    V_bat = batt.voltage  # Tensão nominal da bateria
    r = batt.resistance   # Resistência interna da bateria
    R = motor.resistance  # Resistência do motor
    Io = motor.no_load_current  # Corrente sem carga
    KV = motor.kv         # Constante de velocidade do motor [RPM/V]
    KT = 1 / ((π / 30) * motor.kq)  # Constante de torque do motor [N.m/A]
    Ωo = (π / 30) * KV * (V_bat - (r + R) * Io)  # Velocidade angular do motor sem carga [rad/s]
    if abs(Ωo) < 1e-6
        error("Ωo muito pequeno, impossibilitando o cálculo de B.")
    end
    B = KT * Io / Ωo     # Coeficiente de viscosidade
    D = prop.diameter # Diâmetro da hélice [m]

    # Resolver o equilíbrio elétrico
    I(RPM) = (Π * V_bat - RPM / KV) / (Π * r + R)  # Corrente elétrica do motor em função da manete e da RPM

    # Resolver o equilíbrio dinâmico
    Qmotor(RPM) = KT * (I(RPM))
    Qvisc(RPM) = B * (π/30) * RPM
    J(RPM) = v_ar / (D*(RPM/60))  # Razão de avanço
    Qprop(RPM) = ρ*(RPM/60)^2*D^5*(prop.Cq(J(RPM), RPM))

    # Achando a solução da equação
    function f!(F, x)
        rpm = x[1]
        tm = Qmotor(rpm)
        tv = Qvisc(rpm)
        tp = Qprop(rpm)[1]
        if !isfinite(tm) || !isfinite(tv) || !isfinite(tp)
            F[1] = 1e10  # valor de penalidade para forçar convergência
        else
            F[1] = tm - tv - tp
        end
    end
    sol = nlsolve(f!, [3000.0], method=:newton, iterations=10000)
    # Se a manete fornecida nao fizer o motor girar a pelo menos 1000 RPM, passa para o próximo valor de manete
    # Dados interpolados da APC são entre RPM's de 1000 e 6000. ⚠️⚠️⚠️ NÃO MEXA NA 2º condição⚠️⚠️⚠️ => FAZ O SOLVER DIVERGIR EM MANETES BAIXAS.
    if !converged(sol)
        #println("❌ Erro: `nlsolve` não convergiu. Ajuste os parâmetros iniciais ou use outro método. FUMO GRANDE")
        return Π, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN  # Retorna valores inválidos para indicar falha [faz o loop passar para a próxima manete]
    end
    RPM = sol.zero[1]
    if RPM < 1000.0
        return Π, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN
    end
    
    J = J(RPM) # Razão de avanço 
    Qmotor_val = Qmotor(RPM) # Torque do motor
    I_val = I(RPM) # Corrente do motor

    # Calculando as medições feitas pelo wattímetro
    V = V_bat - r*I_val
    P = V * I_val

    # Calculando o empuxo produzido pela hélice
    T = ρ*(RPM/60)^2*D^4*(prop.Ct(J, RPM)[1])

    valid, msg = check_constraints(batt, motor, prop, I_val, RPM, Qmotor_val, time, altdens)
    mass = batt.mass + motor.mass + prop.mass
    return Π, I_val, V, P, RPM, Qmotor_val, T, valid, msg, mass
end

"""
    check_constraints(batt, motor, prop, I, RPM, Qmotor, time, altdens)

Verifica se a simulação não ultrapassou alguma restrição dos componentes.
"""

function check_constraints(batt, motor, prop, I, RPM, Qmotor, t, altdens)
    messages = []
    valid = true
    # Bateria precisa ter a capacidade mínima requisitada
    if t > batt.capacity * 3.6 / abs(I)
        valid = false 
        push!(messages, "⚠️A bateria atingiu o tempo mínimo de operação!")
    end
    # Corrente não pode ultrapassar o máximo da bateria
    if abs(I) > batt.max_current
        valid = false 
        push!(messages, "⚠️A bateria atingiu sua corrente limite de operação!")
    end
    # Corrente não pode ultrapassar o máximo do motor
    if abs(I) > motor.current_peak
        valid = false 
        push!(messages, "⚠️O motor atingiu sua corrente limite de operação!")
    end
    # Potência fornecida ao eixo do motor não pode ultrapassar do limite do motor.
    if abs(Qmotor) * (abs(RPM) * π / 30) > abs(motor.max_power)
        valid = false 
        push!(messages, "⚠️O motor atingiu sua potência limite de operação!")
    end
    # Número de Mach na ponta da hélice não pode se aproximar de MACH.8
    if (abs(RPM) * π / 30 * prop.diameter / 2) * 0.8 > COESA.speed_of_sound(COESA.atmosphere(altdens))
        valid = false 
        push!(messages, "⚠️Hélice atingiu a sua RPM máxima!")
    end
    return valid, messages
end

"""
    run_propulsion_by_power(batt, motor, prop, max_power, v_ar, altdens, time)

Executa a simulação buscando atingir a potência `max_power` ajustando `Π`.
"""
function run_propulsion_by_power(batt, motor, prop, max_power, v_ar, altdens, time)
    Π = 0.0
    I = 0.0
    V = 0.0
    P = 0.0
    V = 0.0
    RPM = 0.0
    Qm = 0.0
    T = 0.0

    while Π < 1.0
        Π, I, V, P, RPM, Qm, T, valid, msg, mass = run_propulsion_by_input(batt, motor, prop, Π, v_ar, altdens, time)
        if valid == false
            msg = join(msg)
            return Π, I, V, P, RPM, Qm, T, msg
        end

        if P > max_power || abs(P-max_power) < 1.0 # Condição para 'chegada' na potência.
            msg = "✅ Potência alvo atingida! Simulação finalizada."
            return Π, I, V, P, RPM, Qm, T, msg
        end

        Π += 0.0001
    end
    msg = "⚠️ Manete chegou ao máximo sem atingir a potência desejada."
    return Π, I, V, P, RPM, Qm, T, msg, mass
end

end  # Fim do módulo
