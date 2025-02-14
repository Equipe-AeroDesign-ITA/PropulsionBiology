using XLSX, LsqFit, DataFrames, Statistics, Plots, PlotlyJS, LinearAlgebra

# Carregar os dados do Excel
file_path = "src/Propeller/Propeller_data.xlsx"
data = DataFrame(XLSX.readtable(file_path, "APC18x8E"))

# Converter colunas para Float64
RPM = Float64.(data.RPM)
J = Float64.(data.J)
Ct = Float64.(data.CT)
Cp = Float64.(data.CP)
Cq = Cp./(2π)

# Função do modelo com termos até o quarto grau
function model(x, p)
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


# Função para calcular R²
function r2_from_fit(fit, y_real)
    ss_res = sum(fit.resid .^ 2)
    ss_tot = sum((y_real .- mean(y_real)) .^ 2)
    return 1 - (ss_res / ss_tot)
end


# Chute inicial dos coeficientes 
p0 = zeros(21)

# Criando `x` corretamente (Matriz 2×N)
x = hcat(J, RPM)'

# Ajustando as 2 curvas corretamente
fit_ct = curve_fit(model, x, Ct, p0)
fit_cq = curve_fit(model, x, Cq, p0)

# Predições do modelo   
Ct_pred = model(x, fit_ct.param)
Cq_pred = model(x, fit_cq.param)

# Calculando R² para os ajustes
r2_ct = r2_from_fit(fit_ct, Ct)
r2_cq = r2_from_fit(fit_cq, Cq)

println("R² para Ct: ", r2_ct)
println("R² para Cp: ", r2_cq)

# 📌 Criando os resíduos (diferença entre valores reais e previstos)
residuals_Ct = Ct .- Ct_pred
residuals_Cq = Cq .- Cq_pred

# 📌 **Gráfico de resíduos**
p1 = Plots.scatter(RPM, residuals_Ct, markersize=3, label="Resíduos Ct", xlabel="RPM", ylabel="Resíduo Ct", title="Resíduos Ct x RPM")
Plots.hline!(p1, [0], linestyle=:dash, color=:black)

p2 = Plots.scatter(RPM, residuals_Cq, markersize=3, label="Resíduos Cq", xlabel="RPM", ylabel="Resíduo Cq", title="Resíduos Cp x RPM")
Plots.hline!(p2, [0], linestyle=:dash, color=:black)

# Salvar gráficos
Plots.savefig(p1, "residuos_Ct.png")
Plots.savefig(p2, "residuos_Cq.png")

# 📌 Criando uma malha 2D de J e RPM para a superfície
J_range = range(minimum(J), maximum(J), length=50)
RPM_range = range(minimum(RPM), maximum(RPM), length=50)
J_grid = repeat(J_range, 1, length(RPM_range))
RPM_grid = repeat(RPM_range', length(J_range), 1)

# Avaliando o modelo na malha gerada
x_grid = vcat(vec(J_grid)', vec(RPM_grid)')  # Convertendo para matriz 2×N
Ct_grid_pred = reshape(model(x_grid, fit_ct.param), size(J_grid))
Cq_grid_pred = reshape(model(x_grid, fit_cq.param), size(J_grid))

# 📌 **Gráfico 3D interativo para Ct**
scatter_ct = PlotlyJS.scatter3d(; x=J, y=RPM, z=Ct, mode="markers",
                                marker=attr(size=5, color="blue"), name="Dados reais Ct")

surface_ct = PlotlyJS.surface(; x=J_range, y=RPM_range, z=Cq_grid_pred,
                              colorscale="Viridis", name="Modelo Ajustado Ct")

plot_ct = PlotlyJS.plot([scatter_ct, surface_ct])
PlotlyJS.savefig(plot_ct, "3DxCt.html")  # Salvar como HTML interativo

# 📌 **Gráfico 3D interativo para Cp**
scatter_cq = PlotlyJS.scatter3d(; x=J, y=RPM, z=Cq, mode="markers",
                                marker=attr(size=5, color="red"), name="Dados reais Cp")

surface_cq = PlotlyJS.surface(; x=J_range, y=RPM_range, z=Cq_grid_pred,
                              colorscale="Plasma", name="Modelo Ajustado Cp")

plot_cq = PlotlyJS.plot([scatter_cq, surface_cq])
PlotlyJS.savefig(plot_cq, "3DxCp.html")  # Salvar como HTML interativo
