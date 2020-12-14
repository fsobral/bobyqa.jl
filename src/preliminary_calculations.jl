using LinearAlgebra

"""

    check_initial_room(Δ, a, b)

    Checks whether the limits satisfy the conditions b[i] >= a[i]+2*Δ

    - 'Δ': positive real value (trust-region radius)
    - 'a': n-dimensional vector with the lower bounds
    - 'b': n-dimensional vector with the upper bounds

    Returns a boolean (true if satisfy the conditions above or false otherwise)

"""
function check_initial_room(Δ, a, b)
    n = length(a)

    for i = 1:n
        if b[i] < (a[i] + 2.0 * Δ)
            return false
        end
    end

    return true

end

"""

    correct_initial_guess(x0, Δ, a, b)

    Checks whether the limits satisfy the conditions b[i] >= a[i]+2*Δ

    - 'x0': n-dimensional vector (first iterate)
    - 'Δ': positive real value (trust-region radius)
    - 'a': n-dimensional vector with the lower bounds
    - 'b': n-dimensional vector with the upper bounds

    Returns a n-dimensional vector

"""
function correct_initial_guess(x0, Δ, a, b)
    n = length(x0)
    x = copy(x0)

    for i = 1:n
        if x0[i] < a[i]
            x[i] = a[i]
        elseif x0[i] > b[i]
            x[i] = b[i]
        elseif (a[i] < x0[i]) && (x0[i] < a[i] + Δ)
            x[i] = a[i] + Δ
        elseif (b[i] - Δ < x0[i]) && (x0[i] < b[i])
            x[i] = b[i] - Δ
        end
    end

    return x

end

"""

    construct_set!(x0, Δ, a, b, p, set)

    Partially builds the set of interpolation points of the first model

    - 'x0': n-dimensional vector (first iterate)
    - 'Δ': positive real value (trust-region radius)
    - 'a': n-dimensional vector with the lower bounds
    - 'b': n-dimensional vector with the upper bounds
    - 'p': integer (number of pairs of points to be generated)
    - 'set': n × m matrix (set of interpolation points)

    Returns a modified version of the matrix set

"""
function construct_set!(x0, Δ, a, b, p, set)
    n = length(x0)

    for i=1:p
        if x0[i] == a[i]
            set[:, i + 1] = x0
            set[i, i + 1] += Δ
            set[:, n + i + 1] = x0
            set[i, n + i + 1] += 2.0 * Δ
        elseif x0[i] == b[i]
            set[:, i + 1] = x0
            set[i, i + 1] += -Δ
            set[:, n + i + 1] = x0
            set[i, n + i + 1] += -2.0 * Δ
        else
            set[:, i + 1] = x0
            set[i, i + 1] += Δ
            set[:, n + i + 1] = x0
            set[i, n + i + 1] += -Δ
        end
    end

end

"""

    construct_set_aux!(x0, Δ, a, b, q, set)

    Changes the qth point of the set of interpolation points

    - 'x0': n-dimensional vector (first iterate)
    - 'Δ': positive real value (trust-region radius)
    - 'a': n-dimensional vector with the lower bounds
    - 'b': n-dimensional vector with the upper bounds
    - 'q': point index to be changed
    - 'set': n × m matrix (set of interpolation points)

    Returns a modified version of the matrix set

"""
function construct_set_aux!(x0, Δ, a, b, q, set)

    if x0[q] == a[q]
        set[:, q + 1] = x0
        set[q, q + 1] += Δ
    elseif x0[p] == b[p]
        set[:, q + 1] = x0
        set[q, q + 1] += -Δ
    else
        set[:, q + 1] = x0
        set[q, q + 1] += Δ
    end

end

"""

    initial_set(f, x0, Δ, a, b, m)

    Builds the set of interpolation points of the first model and
    compute the function values in these points
    
    - 'f': objective function
    - 'x0': n-dimensional vector (first iterate)
    - 'Δ': positive real value (trust-region radius)
    - 'a': n-dimensional vector with the lower bounds
    - 'b': n-dimensional vector with the upper bounds
    - 'm': integer (number of interpolation conditions)

    Returns a n × m matrix, and a m-dimensional vector

"""
function initial_set(f, x0, Δ, a, b, m)
    n = length(x0)
    set = zeros(n, m)
    f_values = zeros(m)
    set[:, 1] = x0
    aux_vector = zeros(n)
    aux = 0.0
    p = 0
    q = 0

    if m <= (2*n + 1)
        if mod(m-1, 2)
            p = convert(Int, (m - 1) / 2)
            construct_set!(x0, Δ, a, b, p, set)
        else
            p = convert(Int, (m - 2) / 2)
            construct_set!(x0, Δ, a, b, p, set)
            construct_set_aux!(x0, Δ, a, b, p + 1, set)
        end

        for i=1:m
            f_values[i] = f(set[:, i])
        end

    else
        construct_set!(x0, Δ, a, b, n, set)
        for i=1:convert(Int, 2 * n + 1)
            f_values[i] = f(set[:, i])
        end

        for i = 1:n
            if (a[i] < x0[i]) && (x0[i] < b[i]) && (f_values[n + i + 1] < f_values[i + 1])
                aux_vector .= set[:, i + 1]
                set[:, i + 1] .= set[:, n + i + 1]
                set[:, n + i + 1] .= aux_vector
                aux = f_values[i + 1]
                f_values[i + 1] = f_values[n + i + 1]
                f_values[i + 1] = aux
            end
        end

        c = convert(Int, div(m - 2 * n - 1, n) - 1)

        for l = 0:c
            for j = ((2 + l) * n + 2):((3 + l) * n + 1)
                p = convert(Int, j - (l + 2) * n - 1)
                if (1 <= p + l + 1) && (p + l + 1 <= n)
                    q = p + l + 1
                else
                    q = p + l + 1 - n
                end

                set[:, j] .= set[:, p + 1] .+ set[:, q + 1] .- x0

            end
        end
        for j = ((3 + c) * n + 2 ):m
            p = convert(Int, j - (3 + c) * n - 1)
            if (1 <= p + c + 2) && (p + c + 2 <= n)
                q = p + c + 2
            else
                q = p + c + 2 - n
            end

            set[:, j] .= set[:, p + 1] .+ set[:, q + 1] .- x0

        end

        for i=convert(Int, 2 * n + 2):m
           f_values = f(set[:, j]) 
        end
        
    end
 
    return set, f_values

end