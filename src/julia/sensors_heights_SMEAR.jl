using BarycentricInterpolation, FFTW, Statistics

# 1. Raw Data (Misaligned heights)
z_m, val_m = [2.0, 8.0, 32.0], [1.1, 1.5, 2.0]
z_h, val_h = [4.0, 16.0, 67.0], [1.2, 1.6, 2.1]

# 2. Create Barycentric Interpolants for each
itp_m = Barycentric(z_m, 1 ./ val_m)
itp_h = Barycentric(z_h, 1 ./ val_h)

# 3. Re-sample both to a UNIFIED 16-point Chebyshev grid
z_unified = [34.5 + 32.5 * cos(j * pi / 15) for j in 0:15]
vals_m_new = itp_m.(z_unified)
vals_h_new = itp_h.(z_unified)

# 4. Apply DCT (Convolution in Spectral Space)
c_m = dct(vals_m_new)
c_h = dct(vals_h_new)

# 5. Resulting joint transport (Product in physical space)
joint_conductance = vals_m_new .* vals_h_new