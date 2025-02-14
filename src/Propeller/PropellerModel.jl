module PropellerModel

using XLSX, NLsolve, DataFrames, LsqFit

export Propeller, PropellerDB
export build_propeller_DB, propeller_coeff_model, calculate_propeller_by_torque

struct Propeller{F1, F2}
    name::String
    diameter::Float64  # Diâmetro da hélice (m)
    mass::Float64     # Peso da hélice (kg)
    Ct::F1 # Dados para modelagem do ct
    Cq::F2 # Dados para a modelagem do cq
end

# Banco de dados de materiais
PropellerDB = Dict{String,Propeller}()

# Função que controi o banco de dados de baterias
function build_propeller_DB(propeller_database_name::String)
    if !isfile(propeller_database_name)
        propeller_database_name = (@__DIR__) * "/Propeller_data.xlsx" # Planilha padrão
    end

    # Obtem os nomes das paginas da planilha no arquivo
    xlsx_file = XLSX.readxlsx(propeller_database_name)
    sheet_names = XLSX.sheetnames(xlsx_file)

    for sheet in sheet_names
        data = DataFrame(XLSX.readtable(propeller_database_name, sheet))
        RPM = Float64.(data.RPM)
        J = Float64.(data.J)
        Ct = Float64.(data.CT)
        Cp = Float64.(data.CP)
        Cq = Cp./(2pi)
        x = hcat(J, RPM)'
        fit_ct = curve_fit(propeller_coeff_model, x, Ct, zeros(21))
        ct(J, RPM) = propeller_coeff_model([J, RPM], fit_ct.param) 
        fit_cq = curve_fit(propeller_coeff_model, x, Cq, zeros(21))
        cq(J, RPM) = propeller_coeff_model([J, RPM], fit_cq.param)
        D = 0.0254*parse(Float64, data[1,5])
        M = data."Massa (kg)"
        PropellerDB[sheet] = Propeller(sheet, D, M, ct, cq)
    end

end

# Função do modelo com termos até o quarto grau
function propeller_coeff_model(x, p)
    J = x[1, :]
    RPM = x[2, :]
    # Parâmetros do modelo (incluindo todos os termos de até 4º grau)
    a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p1, q, r, s, t, u = p  # 21 coeficientes
    return a .+ 
        b .* RPM .+ 
        c .* RPM.^2 .+ 
        d .* RPM.^3 .+ 
        e .* RPM.^4 .+ 
        f .* J .+ 
        g .* J.^2 .+ 
        h .* J.^3 .+ 
        i .* J.^4 .+ 
        j .* RPM .* J .+ 
        k .* (RPM .* J).^2 .+ 
        l .* (RPM .* J).^3 .+ 
        m .* (RPM .* J).^4 .+ 
        n .* (RPM.^2) .* J .+ 
        o .* (RPM.^2) .* J.^2 .+ 
        p1 .* (RPM.^2) .* J.^3 .+ 
        q .* (RPM.^2) .* J.^4 .+ 
        r .* (RPM.^3) .* J .+ 
        s .* (RPM.^3) .* J.^2 .+ 
        t .* (RPM.^3) .* J.^3 .+ 
        u .* (RPM.^4) .* J
end

end