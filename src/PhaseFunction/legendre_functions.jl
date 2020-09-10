

"""
$(FUNCTIONNAME)(μ,Lmax)
Computes the normalized Π matrix elements with generalized spherical functions (normalized by sqrt((l-m)!/(l+m)!)) ). See eq 15 in Sanghavi 2014
- `μ` cos(θ) of angle θ
- `Lmax` max `l` Polynomial degree to be computed (m adjusted accordingly) 
The function returns matrices containing ``P_l^m(\\mu)``,  ``R_l^m(\\mu)``, ``-T_l^m(\\mu)``, all normalized by ``\\sqrt{\\frac{(l-m)!}{(l+m)!}}``
""" 
function compute_Π_matrix(μ,Lmax)
    # Note: P_l^m(μ) double-checked against Matlab, really hard to find other benchmarks for R and T!
    # Can probably be sped up but it can be pre-computed anyhow as angles μ and Lmax will be fixed per run
    FT = eltype(μ)

    # Create Arrays for the associate legendre coefficients (Siewert, eq. 10)
    da = (zeros(FT,Lmax+1,Lmax+1));
    db = (zeros(FT,Lmax+1,Lmax+1));
    dc = (zeros(FT,Lmax+1,Lmax+1));

    # Following Suniti Sanghavi code, looks somewhat different than Siewert as normalization is built in. 
    smu = sqrt(1.0 - μ*μ)
    cmu = μ 
    for  m=0:Lmax
        for l=m:Lmax
            #indices for arrays:
            im = m+1;
            il = l+1;
            if m==0
                if l==0 # then !eq.28a
                    da[im,il] = 1
                    db[im,il] = 0
                    dc[im,il] = 0
                elseif l==1 # then !eq.28b
                    da[im,il] = cmu
                    db[im,il] = 0
                    dc[im,il] = 0
                elseif l==2 # then !eq.28c, 29, 30
                    cA = 0.5*(3.0*cmu*cmu-1.0)
                    cB = 0.5*sqrt(1.5)*smu*smu

                    da[im,il] = cA
                    db[im,il] = cB
                    dc[im,il] = 0.0
                else #!eq.30, 31a, 31b
                    Y_lm1 = l-1
                    X_lm1 = l

                    da[im,il] = (da[im,il-1] * (2l-1) * cmu -  da[im,il-2] * Y_lm1 ) / X_lm1

                    Y_lm1 = sqrt( (l+1) * (l-3) )
                    X_lm1 = sqrt( l*l - 4 )

                    db[im,il] = (db[im,il-1] * (2*l-1) * cmu -  db[im,il-2] * Y_lm1) / X_lm1
                    dc[im,il] = 0.0
                end

            elseif m==1 # then
                if l==1 # then !eq.32a
                    m1 = sqrt(0.5)
                    da[im,il] = m1*smu
                    db[im,il] = 0.0
                    dc[im,il] = 0.0
                elseif l==2 # then !eq.32b, 33a, 33b
                    m1 = sqrt(1/6)
                    cA = 3cmu*smu
                    cB = sqrt(1.5)*smu
                    da[im,il] = m1*cA
                    db[im,il] = -m1*cmu*cB
                    dc[im,il] = m1*cB
                else #!eq.34, 35a, 35b, 35c
                    m1 = sqrt((l-1)/(l+1))
                    m2 = m1 * sqrt( (l-2) / l )

                    Y_lm1 = (l-1+m)
                    X_lm1 = (l-m)

                    da[im,il] = (m1 * da[im,il-1] * (2l-1) * cmu 
                                - m2 * da[im,il-2] * Y_lm1 ) / X_lm1

                    Z_lm1 = (2m * (2l-1) ) / (l * (l-1))
                    Y_lm1 = ( (l+m-1) / (l-1)) * sqrt( (l-3) * (l+1) )
                    X_lm1 = ( (l-m)   /  l   ) * sqrt( (l*l-4) )

                    db[im,il] = (m1*db[im,il-1] * (2l-1) * cmu 
                                -m2 * db[im,il-2] * Y_lm1 +m1 * dc[im,il-1] * Z_lm1 ) /X_lm1

                    dc[im,il] = (m1*dc[im,il-1] * (2l-1) * cmu
                                -m2 * dc[im,il-2] * Y_lm1 +m1 * db[im,il-1] * Z_lm1 ) /X_lm1
                end
            else 
                if l==m # then !eq.36, 37
                    fact1=1.0
                    fact2=1.0

                    sfull = smu
                    shalf = sfull/2
                    for i=1:m
                        fact1 = fact1*((2i-1)*sfull) / sqrt((i*(i+m)))
                        if i>2  #then
                            fact2 = fact2 * shalf * sqrt((m+i)/(i-2))
                        else
                            fact2 = fact2 * shalf
                        end
                    end
                    if smu>1e-8  # then
                        Km = (fact2)
                        Aii= Km * (1.0+cmu*cmu) / (smu*smu)
                        Aij= Km * (2cmu) / (smu*smu)
                    else
                        if m==2 # then
                            Aii=0.5
                            Aij=0.5
                        else
                            Aii=0.0
                            Aij=0.0
                        end
                    end
                    da[im,il] = fact1
                    db[im,il] =  Aii
                    dc[im,il] = -Aij

                elseif l==(m+1) # then !eq.38, 35a, 35b
                    # typo 1 and l??
                    m1 = sqrt((1)/(l+m))

                    Y_lm1 = (l-1+m)
                    X_lm1 = (l-m)

                    da[im,il] = ( m1 * da[im,il-1] * (2l-1) * cmu ) / X_lm1

                    Z_lm1 = (2m * (2l-1)) / (l*(l-1))
                    Y_lm1 = ((l+m-1) / (l-1)) * sqrt( (l-3) * (l+1) ) 
                    X_lm1 = ( (l-m) /l ) * sqrt(l*l-4)

                    db[im,il] = ( m1 * db[im,il-1] * (2l-1) * cmu 
                                + m1 * dc[im,il-1] * Z_lm1 ) / X_lm1
                    dc[im,il] = ( m1 * dc[im,il-1] * (2l-1) * cmu 
                                + m1 * db[im,il-1] * Z_lm1 ) / X_lm1

                else #!eq.38, 35a, 35b
                    m1 = sqrt( (l-m) / (l+m) )
                    m2 = m1 * sqrt( (l-m-1) / (l+m-1) )

                    Y_lm1 = (l-1+m)
                    X_lm1 = (l-m)

                    da[im,il] = ( m1 * da[im,il-1] * (2l-1) * cmu 
                                - m2 * da[im,il-2] * Y_lm1 ) / X_lm1

                    Z_lm1 = (2m*(2l-1)) / (l*(l-1))
                    Y_lm1 = ( (l+m-1) / (l-1) ) * sqrt( (l-3) * (l+1) )
                    X_lm1 = ( (l-m) / l ) * sqrt( l*l-4 )

                    db[im,il] = ( m1 * db[im,il-1] * (2l-1) * cmu 
                                - m2 * db[im,il-2] * Y_lm1  
                                + m1 * dc[im,il-1] * Z_lm1) / X_lm1

                    dc[im,il] = ( m1 * dc[im,il-1] * (2l-1) * cmu 
                                - m2 * dc[im,il-2] * Y_lm1
                                + m1 * db[im,il-1] * Z_lm1) / X_lm1

                end
          end
       end
    end
    return da,db,dc
end

"""
$(FUNCTIONNAME)(μ, nmax, π, τ)
Computes the associated Legendre functions  amplitude functions `π` and `τ` in Mie theory (stored internally). See eq 6 in Sanghavi 2014
- `μ` cosine of the scattering angle
- `nmax` max number of legendre terms (depends on size parameter, see [`get_n_max`](@ref))
Functions returns `π` and `τ` (of size `[nmax,length(μ)]`)
"""
function compute_mie_π_τ(μ, nmax)
    FT = eltype(μ)
    # Allocate arrays:
    π_ = zeros(FT,nmax,length(μ))
    τ_ = zeros(FT,nmax,length(μ))

    # BH book, pages 94-96:
    π_[1,:] .= 1.0;
    π_[2,:] .= 3μ;
    τ_[1,:] .= μ;
    # This is equivalent to 3*cos(2*acos(μ))
    τ_[2,:] .= 6μ.^2 .-3;
    for n=2:nmax-1
        for i in eachindex(μ)
            π_[n+1,i] = ((2n + 1) * μ[i] * π_[n,i] - (n+1) * π_[n-1,i]) / n 
            τ_[n+1,i] = (n+1) * μ[i] * π_[n+1,i] - (n+2)*π_[n,i]
            # @show n+1,μ[i], π_[n+1,i], τ_[n+1,i], π_[n,i]
        end
    end
    return π_, τ_
end

"""
$(FUNCTIONNAME)(x,nmax)
Returns the associated legendre functions Pᵢ, P²ᵢ, R²ᵢ, and T²ᵢ as a function of x and i=1:nmax 
- `x` array of locations to be evaluated [-1,1]
- `nmax` max number of legendre terms (depends on size parameter, see [`get_n_max`](@ref))
The function returns `Pᵢ`, `P²ᵢ`, `R²ᵢ`, and `T²ᵢ`, for a size distribution, this can be pre-computed with nmax derived from the maximum size parameter.
"""
function compute_legendre_poly(x,nmax)
    FT = eltype(x)
    @assert nmax > 1
    #@assert size(P) == (nmax,length(x))
    P⁰ = zeros(nmax,length(x));
    P² = zeros(nmax,length(x));
    R² = zeros(nmax,length(x));
    T² = zeros(nmax,length(x));
    # 0th Legendre polynomial, a constant
    P⁰[1,:] .= 1;
    P²[1,:] .= 0;
    R²[1,:] .= 0;
    T²[1,:] .= 0; 
    # 1st Legendre polynomial, x
    P⁰[2,:]  = x;
    P²[2,:] .= 0;
    R²[2,:] .= 0;
    T²[2,:] .= 0;

    # 2nd Legendre polynomial, x
    #P¹[2,:] = x;
    P²[3,:] .= 3   * (1 .- x.^2);
    R²[3,:] .= sqrt(1.5) * (1 .+ x.^2);
    T²[3,:] .= sqrt(6) * x;

    for n=2:nmax-1
        for i in eachindex(x)
            l = n-1;
            P⁰[n+1,i] = ((2l + 1) * x[i] * P⁰[n,i] - l * P⁰[n-1,i])/(l+1)
            if n>2
                ia = (2l+1) * x[i];
	            ib = sqrt( (l+2) * (l-2) ) * (l+2) / (l);
	            ic = 4.0 * (2l+1) / ( (l+1)*l );
	            id = sqrt( (l+3) * (l-1) ) * (l-1) / (l+1);
                P²[n+1,i] = ( ia * P²[n,i] - (l+2) * P²[n-1,i] ) / (l-1)
                R²[n+1,i] = ( ia * R²[n,i] - ib * R²[n-1,i] - ic * T²[n,i] ) / id;
	            T²[n+1,i] = ( ia * T²[n,i] - ib * T²[n-1,i] - ic * R²[n,i] ) / id;
            end  
        end
    end
    return P⁰, P², R², T²
end

# Following Milthorpe, 2014, includes the Condon–Shortley phase
function compute_legendre_P(μ , Lmax)
    FT = eltype(μ)
    da = zeros(FT,Lmax+1,Lmax+1)
    sintheta = sqrt(1.0 .- μ*μ)
    temp = sqrt(0.5/π)
    da[1,1] = sqrt(0.5/π);
    if Lmax > 0
        SQRT3 = sqrt(3.0)
        da[1,2] = μ * SQRT3 * temp
        SQRT3DIV2 = -sqrt(3.0 / 2.0)
        temp = SQRT3DIV2 * sintheta * temp
        da[2,2] = temp

        for l=2:Lmax
            il = l+1
            for m=0:l-2
                im = m+1
                A =  sqrt( (4l^2-1) / (l^2 - m^2) )
                B = -sqrt( ((l-1)^2-m^2) / (4*(l-1)^2 - 1) )  
                da[im,il] = A * (μ * da[im,il-1] + B * da[im,il-2] )
            end
            da[il-1,il] = μ * sqrt(2*(l-1)+3) * temp;
            temp = -sqrt(1 + 0.5/l ) * sintheta * temp
            da[il,il] = temp
        end
    end
    ll = collect(Float64,0:Lmax)
    ll = sqrt.( (2*ll .+ 1)/2π)

    return da./ll'
end



