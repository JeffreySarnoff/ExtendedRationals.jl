@inline function _checked_int32(x::Integer)
    typemin(Int32) <= x <= typemax(Int32) || throw(OverflowError("value does not fit in Int32"))
    return Int32(x)
end

@inline function _checked_int64(x::Integer)
    typemin(Int64) <= x <= typemax(Int64) || throw(OverflowError("value does not fit in Int64"))
    return Int64(x)
end

@inline function _checked_int128(x::Integer)
    typemin(Int128) <= x <= typemax(Int128) || throw(OverflowError("value does not fit in Int128"))
    return Int128(x)
end

@inline _apply_sign(x::Rational{Int32}, negative::Bool) = negative ? -x : x
@inline _apply_sign(x::Rational{Int64}, negative::Bool) = negative ? -x : x
@inline _apply_sign(x::Rational{Int128}, negative::Bool) = negative ? -x : x

@inline function _tie_even(a::Rational{Int32}, b::Rational{Int32})
    a_even = iseven(numerator(a))
    b_even = iseven(numerator(b))
    if a_even != b_even
        return a_even ? a : b
    end
    return denominator(a) <= denominator(b) ? a : b
end

@inline function _tie_even(a::Rational{Int64}, b::Rational{Int64})
    a_even = iseven(numerator(a))
    b_even = iseven(numerator(b))
    if a_even != b_even
        return a_even ? a : b
    end
    return denominator(a) <= denominator(b) ? a : b
end

@inline function _tie_even(a::Rational{Int128}, b::Rational{Int128})
    a_even = iseven(numerator(a))
    b_even = iseven(numerator(b))
    if a_even != b_even
        return a_even ? a : b
    end
    return denominator(a) <= denominator(b) ? a : b
end

function _compare_distance(target::Rational, a::Rational{Int32}, b::Rational{Int32})
    tn = Int256(numerator(target))
    td = Int256(denominator(target))

    an = abs(tn * Int256(denominator(a)) - Int256(numerator(a)) * td)
    bn = abs(tn * Int256(denominator(b)) - Int256(numerator(b)) * td)

    lhs = an * Int256(denominator(b))
    rhs = bn * Int256(denominator(a))

    return lhs < rhs ? -1 : lhs > rhs ? 1 : 0
end

function _compare_distance(target::Rational{Int256}, a::Rational{Int64}, b::Rational{Int64})
    tn = Int512(numerator(target))
    td = Int512(denominator(target))

    an = abs(tn * Int512(denominator(a)) - Int512(numerator(a)) * td)
    bn = abs(tn * Int512(denominator(b)) - Int512(numerator(b)) * td)

    lhs = an * Int512(denominator(b))
    rhs = bn * Int512(denominator(a))

    return lhs < rhs ? -1 : lhs > rhs ? 1 : 0
end

function _compare_distance(target::Rational{Int512}, a::Rational{Int128}, b::Rational{Int128})
    tn = Int1024(numerator(target))
    td = Int1024(denominator(target))

    an = abs(tn * Int1024(denominator(a)) - Int1024(numerator(a)) * td)
    bn = abs(tn * Int1024(denominator(b)) - Int1024(numerator(b)) * td)

    lhs = an * Int1024(denominator(b))
    rhs = bn * Int1024(denominator(a))

    return lhs < rhs ? -1 : lhs > rhs ? 1 : 0
end

function _nearest_rational32(target::Rational)
    iszero(target) && return zero(Rational{Int32})

    limit = Int128(typemax(Int32))
    negative = target < 0
    work = negative ? -target : target

    if Int256(numerator(work)) > Int256(limit) * Int256(denominator(work))
        return _apply_sign(_checked_int32(limit) // Int32(1), negative)
    end

    if numerator(work) <= limit && denominator(work) <= limit
        exact = _checked_int32(numerator(work)) // _checked_int32(denominator(work))
        return _apply_sign(exact, negative)
    end

    n = Int128(numerator(work))
    d = Int128(denominator(work))

    p0 = Int128(0)
    q0 = Int128(1)
    p1 = Int128(1)
    q1 = Int128(0)

    while true
        a = div(n, d)
        p2 = p0 + a * p1
        q2 = q0 + a * q1

        if p2 > limit || q2 > limit
            kp = iszero(p1) ? limit : div(limit - p0, p1)
            kq = iszero(q1) ? limit : div(limit - q0, q1)
            k = min(a, kp, kq)

            lower = _checked_int32(p0 + k * p1) // _checked_int32(q0 + k * q1)
            upper = _checked_int32(p1) // _checked_int32(q1)

            cmp = _compare_distance(work, lower, upper)
            best = cmp < 0 ? lower : cmp > 0 ? upper : _tie_even(lower, upper)
            return _apply_sign(best, negative)
        end

        if rem(n, d) == 0
            exact = _checked_int32(p2) // _checked_int32(q2)
            return _apply_sign(exact, negative)
        end

        p0, q0, p1, q1 = p1, q1, p2, q2
        n, d = d, rem(n, d)
    end
end

function _nearest_rational64(target::Rational{Int256})
    iszero(target) && return zero(Rational{Int64})

    limit = Int256(typemax(Int64))
    negative = target < 0
    work = negative ? -target : target

    if numerator(work) > limit * denominator(work)
        return _apply_sign(_checked_int64(limit) // Int64(1), negative)
    end

    if numerator(work) <= limit && denominator(work) <= limit
        exact = _checked_int64(numerator(work)) // _checked_int64(denominator(work))
        return _apply_sign(exact, negative)
    end

    n = numerator(work)
    d = denominator(work)

    p0 = Int256(0)
    q0 = Int256(1)
    p1 = Int256(1)
    q1 = Int256(0)

    while true
        a = div(n, d)
        p2 = p0 + a * p1
        q2 = q0 + a * q1

        if p2 > limit || q2 > limit
            kp = iszero(p1) ? limit : div(limit - p0, p1)
            kq = iszero(q1) ? limit : div(limit - q0, q1)
            k = min(a, kp, kq)

            lower = _checked_int64(p0 + k * p1) // _checked_int64(q0 + k * q1)
            upper = _checked_int64(p1) // _checked_int64(q1)

            cmp = _compare_distance(work, lower, upper)
            best = cmp < 0 ? lower : cmp > 0 ? upper : _tie_even(lower, upper)
            return _apply_sign(best, negative)
        end

        if rem(n, d) == 0
            exact = _checked_int64(p2) // _checked_int64(q2)
            return _apply_sign(exact, negative)
        end

        p0, q0, p1, q1 = p1, q1, p2, q2
        n, d = d, rem(n, d)
    end
end

function _nearest_rational128(target::Rational{Int512})
    iszero(target) && return zero(Rational{Int128})

    limit = Int512(typemax(Int128))
    negative = target < 0
    work = negative ? -target : target

    if numerator(work) > limit * denominator(work)
        return _apply_sign(_checked_int128(limit) // Int128(1), negative)
    end

    if numerator(work) <= limit && denominator(work) <= limit
        exact = _checked_int128(numerator(work)) // _checked_int128(denominator(work))
        return _apply_sign(exact, negative)
    end

    n = numerator(work)
    d = denominator(work)

    p0 = Int512(0)
    q0 = Int512(1)
    p1 = Int512(1)
    q1 = Int512(0)

    while true
        a = div(n, d)
        p2 = p0 + a * p1
        q2 = q0 + a * q1

        if p2 > limit || q2 > limit
            kp = iszero(p1) ? limit : div(limit - p0, p1)
            kq = iszero(q1) ? limit : div(limit - q0, q1)
            k = min(a, kp, kq)

            lower = _checked_int128(p0 + k * p1) // _checked_int128(q0 + k * q1)
            upper = _checked_int128(p1) // _checked_int128(q1)

            cmp = _compare_distance(work, lower, upper)
            best = cmp < 0 ? lower : cmp > 0 ? upper : _tie_even(lower, upper)
            return _apply_sign(best, negative)
        end

        if rem(n, d) == 0
            exact = _checked_int128(p2) // _checked_int128(q2)
            return _apply_sign(exact, negative)
        end

        p0, q0, p1, q1 = p1, q1, p2, q2
        n, d = d, rem(n, d)
    end
end