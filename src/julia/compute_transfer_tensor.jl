using LinearAlgebra
using StaticArrays
using WignerSymbols # For exact 3j symbols
using JLD2

"""
    compute_transfer_tensor(N::Int)

Computes the transfer tensor T[m, n, k] of size (N, N, N).
Maps (C_m^(1/4) * C_n^(1/4)) -> P_k.
"""
function compute_transfer_tensor(N::Int)
    # T[m, n, k] where indices are 0 to N-1
    T = zeros(Float64, N, N, 2N)

    # 1. Generate Gegenbauer coefficients alpha[m, j]
    # Representing C_m^(1/4) as a sum of alpha_mj * P_j
    # For simplicity, we use the values derived in the Monomial Bridge
    alpha = zeros(Float64, N, N)
    alpha[1, 1] = 1.0                # C_0 = P_0
    alpha[2, 2] = 0.5                # C_1 = 0.5 * P_1
    alpha[3, 1] = -1/24; alpha[3, 3] = 5/12 # C_2 = 5/12 P_2 - 1/24 P_0
    alpha[4, 2] = -1/16; alpha[4, 4] = 3/8  # C_3 = 3/8 P_3 - 1/16 P_1

    # 2. Triple Legendre Integral using Wigner 3j symbols
    # I(j, l, k) = ∫ Pj * Pl * Pk dx
    function triple_integral(j, l, k)
        # Selection rules
        if isodd(j + l + k) || (k > j + l) || (k < abs(j - l))
            return 0.0
        end
        # Using 2 * (3j_symbol)^2
        # Note: Wigner3j is (j1, j2, j3, m1, m2, m3)
        w3j = wigner3j(Float64, j, l, k, 0, 0, 0)
        return 2.0 * w3j^2
    end

    # 3. Fill the Tensor
    # T(m,n,k) = (2k+1)/2 * Σ_j Σ_l α_mj * α_nl * ∫ Pj * Pl * Pk dx
    for m in 1:N, n in 1:N
        # Only evaluate non-zero coefficients
        for j in 1:N, l in 1:N
            if alpha[m, j] == 0 || alpha[n, l] == 0
                continue
            end

            coeff_prod = alpha[m, j] * alpha[n, l]

            # The range of k is limited by triangle inequality of Legendre product
            for k_idx in 0:(j+l-2)
                k = k_idx
                integral = triple_integral(j-1, l-1, k)
                if integral != 0
                    # Standard Legendre normalization (2k+1)/2
                    val = ((2k + 1) / 2.0) * coeff_prod * integral
                    T[m, n, k+1] += val
                end
            end
        end
    end
    return T
end

"""
    save_transfer_tensor(path::AbstractString, T::AbstractArray{<:Real,3}; metadata=Dict())

Save a transfer tensor to a `.jld2` file. The file will contain:
- `T`: the tensor data
- `shape`: tensor dimensions
- `metadata`: optional user metadata dictionary
"""
function save_transfer_tensor(path::AbstractString, T::AbstractArray{<:Real,3}; metadata=Dict())
    jldsave(path; T=Array(T), shape=size(T), metadata=metadata)
    return path
end

"""
    load_transfer_tensor(path::AbstractString)

Load transfer tensor data from a `.jld2` file produced by `save_transfer_tensor`.
Returns a named tuple with fields: `T`, `shape`, `metadata`.
"""
function load_transfer_tensor(path::AbstractString)
    data = load(path)
    return (T=data["T"], shape=data["shape"], metadata=data["metadata"])
end

# Example Usage for N=4 (Degree 0 to 3)
const N_MAX = 4
const T_TENSOR = compute_transfer_tensor(N_MAX)

# Accessing T(1,1,2) -> maps C_1*C_1 to P_2
# Indices in Julia are 1-based, so m=1 (C_0), m=2 (C_1)
println("T(1,1,0) = ", T_TENSOR[2, 2, 1]) # Expected ~1/12
println("T(1,1,2) = ", T_TENSOR[2, 2, 3]) # Expected ~1/6

output_path = "transfer_tensor_N$(N_MAX).jld2"
save_transfer_tensor(output_path, T_TENSOR; metadata=Dict("N_MAX" => N_MAX, "generator" => "compute_transfer_tensor"))
loaded = load_transfer_tensor(output_path)
println("Saved tensor to ", output_path, " with shape ", loaded.shape)