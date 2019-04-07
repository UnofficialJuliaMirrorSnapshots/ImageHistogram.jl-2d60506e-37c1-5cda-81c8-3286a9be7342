using ImageHistogram
@static if VERSION < v"0.7.0-DEV.2005"
    using Base.Test
else
    using Test
end

# just a simple test to pass
@test (1+1) == 2
