"""
$(FUNCTIONNAME)(mod::δBGE, aero::AerosolOptics))
Returns the truncated aerosol optical properties as [`AerosolOptics`](@ref) 
- `mod` a [`δBGE`](@ref) struct that defines the truncation order (new length of greek parameters) and exclusion angle
- `aero` a [`AerosolOptics`](@ref) set of aerosol optical properties that is to be truncated
"""
function truncate_phase(mod::δBGE, aero::AerosolOptics; reportFit=false, err_β=nothing,err_ϵ=nothing,err_γ=nothing)
    @unpack greek_coefs, ω̃, k = aero
    @unpack α, β, γ, δ, ϵ, ζ = greek_coefs
    @unpack l_max, Δ_angle =  mod

    FT = eltype(ω̃)

    # Obtain Gauss-Legendre quadrature points and weights for phase function:
    μ, w_μ = gausslegendre(length(β));

    # Reconstruct phase matrix elements:
    f₁₁, f₁₂, f₂₂, f₃₃, f₃₄, f₄₄, P, P² = reconstruct_phase(greek_coefs, μ; returnLeg=true)

    # Find elements that exclude the peak (if wanted!)
    iμ = findall(x -> x < cosd(Δ_angle), μ)

    # Prefactor for P2:
    fac = zeros(l_max);
    for l = 2:l_max - 1
        fac[l + 1] = sqrt(FT(1) / ( ( l - FT(1)) * l * (l + FT(1)) * (l + FT(2)) ));
    end

    # Create subsets (for Ax=y weighted least-squares fits):
    y₁₁ = view(f₁₁, iμ)
    y₁₂ = view(f₁₂, iμ)
    y₃₄ = view(f₃₄, iμ)
    A   = view(P, iμ, 1:l_max)
    B   = fac' .* view(P², iμ, 1:l_max)

    # Weights (also avoid division by 0)
    minY = zeros(length(iμ)) .+ FT(1e-8);
    W₁₁ = Diagonal(w_μ[iμ] ./ max(abs.(y₁₁), minY));
    W₁₂ = Diagonal(w_μ[iμ] ./ max(abs.(y₁₂), minY));
    W₃₄ = Diagonal(w_μ[iμ] ./ max(abs.(y₃₄), minY));
    
    # Julia backslash operator for least squares (just like Matlab);
    cl = ((W₁₁ * A) \ (W₁₁ * y₁₁))   # B in δ-BGR (β)
    γᵗ = ((W₁₂ * B) \ (W₁₂ * y₁₂))   # G in δ-BGE (γ)
    ϵᵗ = ((W₃₄ * B) \ (W₃₄ * y₃₄))   # E in δ-BGE (ϵ)
    if reportFit
        println("Errors in δ-BGE fits:")
        mod_y = convert.(FT, A * cl)
        mod_γ = convert.(FT, B * γᵗ)
        mod_ϵ = convert.(FT, B * ϵᵗ)
        # push!(err_β, StatsBase.rmsd(W₁₁ * mod_y, W₁₁ * y₁₁; normalize=true))
        # push!(err_γ, StatsBase.rmsd(W₁₂ * mod_γ, W₁₂ * y₁₂; normalize=true))
        # push!(err_ϵ, StatsBase.rmsd(W₃₄ * mod_ϵ, W₃₄ * y₃₄; normalize=true))
        @show StatsBase.rmsd(mod_y, y₁₁; normalize=true)
        @show StatsBase.rmsd(mod_γ, y₁₂; normalize=true)
        @show StatsBase.rmsd(mod_ϵ, y₃₄; normalize=true)
    end

    # Integrate truncated function for later renormalization (here: fraction that IS still scattered):
    c₀ = cl[1] # ( w_μ' * (P[:,1:l_max] * cl) ) / 2
    # @show c₀, cl[1]
    # Compute truncated greek coefficients:
    βᵗ = cl / c₀                                    # Eq. 38a, B in δ-BGR (β)
    δᵗ = (δ[1:l_max] .- (β[1:l_max] .- cl)) / c₀    # Eq. 38b, derived from β
    αᵗ = (α[1:l_max] .- (β[1:l_max] .- cl)) / c₀    # Eq. 38c, derived from β
    ζᵗ = (ζ[1:l_max] .- (β[1:l_max] .- cl)) / c₀    # Eq. 38d, derived from β

    # Adjust scattering and extinction cross section!
    greek_coefs = GreekCoefs(convert.(FT, αᵗ), 
                             convert.(FT, βᵗ), 
                             convert.(FT, γᵗ), 
                             convert.(FT, δᵗ), 
                             convert.(FT, ϵᵗ), 
                             convert.(FT, ζᵗ))
    # C_sca  = (ω̃ * k);
    # C_scaᵗ = C_sca * c₀; 
    # C_ext  = k - (C_sca - C_scaᵗ);
    
    # return AerosolOptics(greek_coefs = greek_coefs, ω̃=C_scaᵗ / C_ext, k=C_ext, fᵗ = 1-c₀) 
    return AerosolOptics(greek_coefs=greek_coefs, ω̃=FT(ω̃), k=FT(k), fᵗ=FT(FT(1) - c₀))
end

