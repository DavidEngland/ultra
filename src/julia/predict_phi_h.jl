"""
    predict_phi_h(a_coeffs::Vector{Float64}, T::Array{Float64, 3})

Takes momentum coefficients 'a' and returns heat coefficients 'b'
using the algebraic spectral squaring identity.
"""
function predict_phi_h(a::Vector{Float64}, T::Array{Float64, 3})
    N = length(a)
    K_limit = size(T, 3)
    b = zeros(Float64, K_limit)

    for k in 1:K_limit
        for m in 1:N, n in 1:N
            b[k] += a[m] * a[n] * T[m, n, k]
        end
    end
    return b
end