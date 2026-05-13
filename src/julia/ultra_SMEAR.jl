using SpecialFunctions

"""
    gegenbauer_polynomial(n, lambda, t)
Compute the value of the n-th Gegenbauer polynomial at point t.
"""
function gegenbauer_polynomial(n, λ, t)
    if n == 0 return 1.0 end
    if n == 1 return 2.0 * λ * t end
    # Three-term recurrence relation
    c_prev = 1.0
    c_curr = 2.0 * λ * t
    for j in 1:(n-1)
        next_c = (2(j + λ) * t * c_curr - (j + 2λ - 1) * c_prev) / (j + 1)
        c_prev = c_curr
        c_curr = next_c
    end
    return c_curr
end

"""
    optimize_spectral_lambda(phi_obs, zeta, b_range, lambda_range)
Scans for the (b, lambda) pair that minimizes the high-order spectral noise.
"""
function optimize_spectral_lambda(phi_obs, zeta, b_range, λ_range)
    results = []
    for b in b_range, λ in λ_range
        # 1. Transform to t-space
        t = sqrt.(clamp.(b .* abs.(zeta), 0, 0.99))

        # 2. Project onto first 4 Gegenbauer modes
        # We look for the lambda that minimizes the ratio of high-order to low-order energy
        a0 = mean(phi_obs .* (1 .- t.^2).^(λ - 0.5))
        # (Simplified projection for demonstration)

        # Calculate residuals against the lambda-profile
        phi_model = (1 .- b .* zeta).^(-λ)
        err = sum((phi_obs .- phi_model).^2)

        push!(results, (b=b, λ=λ, error=err))
    end
    return sort(results, by=x->x.error)[1]
end