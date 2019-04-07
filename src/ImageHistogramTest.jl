module ImageHistogramTest

export
    calc_histogram_norm_factor,
    imhistogramGray,
    imhistogramRGB,
    imhistogramRGB3d_16bit,
    imhistogramRGB3d_new2,
    normalize_histogram,
    plot_imhi,
    plot_imhi_GrayRGB,
    plot_imhi_3D

using Images, Colors
using Plots #  necessary to be able include specials function for ploting histograms in 2D & 3D
# using Gnuplot; # this is currently better for 3D plots, but one can load one package only.
# ToDO: check if one can use 2 plot packages if they live in separate submodules. Mmaybe move into submodule 'imhi_plot3D' and 2D into submodule 'imhi_plot2D'
# Worst case:  make individual modules, one for 2D, one for 3D plus a file for common code which will be included from the module files.

#####
# TWA 2018-03-22 : CustomUnitRanges is not usable with julia 0.6.2 for me ; ==> use OffsetArrays
# using CustomUnitRanges: filename_for_zerorange
# include(filename_for_zerorange)

# ==> use OffsetArrays
#  BUT
#     package Plots cannot handle OffsetArrays
#     thus the need for a simple function to convert to common julia array
# flame on
#     and all this just because julia has 1 offset arrays - grrrr
# flame off
#

#=    ##### begin{OffsetArray off}
using OffsetArrays
t_oa = OffsetArray{Int32}(0:255); # defines an array with index 0 .. 255; values are not initialized
summary(t_oa); # gives some info about t_oa
t_oa = OffsetArray(Int32, 0:255);
summary(t_oa); # gives some info about t_oa
t_oa = OffsetArray(Int16, 0:255);
summary(t_oa); # gives some info about t_oa
t_oa = OffsetArray(UInt16, 0:255);
summary(t_oa); # gives some info about t_oa
t_oa = OffsetArray(zeros(Int16, 256), 0:255)
summary(t_oa); # gives some info about t_oa

#####
## From OffsetArrays package Readme:
#   If your package makes use of OffsetArrays, you can also add the following internal convenience definitions:
#   These versions should work for all types.

_size(A::AbstractArray) = map(length, indices(A))
_size(A) = size(A)

_length(A::AbstractArray) = length(linearindices(A))
_length(A) = length(A)


#####
# convert OffsetArray to Julia array
# flame on
#  julia has one major design mistake - array indices start at 1 instead of zero
# flame off
#

function conv_Offset_to_julia_Array(vma::OffsetArray)
    vma[0:end];
end
cOtjA(x) = conv_Offset_to_julia_Array(x); # short name for above
=#     ##### end{OffsetArray off}


#####
# convert sRGB (non-linear) to linearRGB (also used for sRGB to XYZ)
function linearRGB_from_sRGB(v)
    # v <= 0.04045 ? v/12.92 : ((v + 0.055) / 1.055)^2.4
    v <= 0.04045 ? v/12.92 : ((v + 0.055) / 1.055)^2.4
end

#####
# convert linearRGB to sRGB (non-linear) (also used for XYZ to sRGB)
function sRGB_from_linearRGB(v)
    # v <= 0.0031308 ? 12.92v : 1.055v^(1/2.4) - 0.055
    v <= 0.0031308 ? 12.92v : 1.055v^(inv(2.4)) - 0.055
end


#####
# histogram of 2D-array of image data
# only for internal use within module
#=
function _imhistogram(array2D::T) where T<:AbstractArray
    # I don't like fortran order - 1-offset arrays - driving on the left side
    ihist = ZeroRange(256);
    for j=1:size(array2D,2)
        for i=1:size(array2D,1)
            channel = Int(floor(array2D[i,j]));
            ihist[channel] += 1;
        end # i
    end # j
    
    return ihist;
end # function histogram of gray image
=#
#=
function _imhistogram(array2D::T) where T<:AbstractArray
    # I don't like fortran order - 1-offset arrays - driving on the left side
    ihist = ZeroRange(256);
    ihist[1] = 1; #  dies with 'ERROR: LoadError: indexing not defined for ImageHistogram.ZeroRange{Int64}'
    #=
    for p in array2D
        channel = Int32(floor(p));
        ihist[channel] += 1;
    end # j
    =#
    return ihist;
end # function histogram of gray image
=#
function _imhistogram(array2D::T, ncolors) where T<:AbstractArray
    # I don't like fortran order - 1-offset arrays - driving on the left side
    ncolorsteps = ncolors - 1;
    ihist = zeros(Int32, ncolors); # zeros(UInt16, ncolors) or zeros(Int32, ncolors);
    # ihist = zeros(OffsetArray(UInt16, 0:ncolorsteps));
    for p in array2D
        # channel = Int32(floor(p * ncolorsteps));
        #channel = floor(UInt16, p * ncolorsteps); # using julia-0.6.2 : OK with RGB ; FAIL with Gray
        channel = UInt16(floor(p * ncolorsteps)); # using julia-0.6.2 : OK with Gray and RGB

        ihist[channel+1] += 1; # Bugfix : use 'channel+1' as channel can be 0 if no color. max(channel) is <= 255 for 'N0f8'
        #ihist[channel] += 1; # using OffsetArray the channel of black is a valid index
    end # for p

    return ihist;
end # function histogram of gray image

#####
# Capacity of a FixedPointNumber
#  Helper function, used in several functions; internal; not for export
#  Colors of images are encoded as FixedPointNumber of type N0f8, N6f10, N4f12, ...
#  The part after 'f' gives the number of bits 'nb' used per color.
#  The number of shades per coler are given by 2^nb.
function _capacity_of_FPNtype(array_elem)
    # ToDo: currently assume 8-bit per pixel per color
    # typname = string("t", zero(Gray(imarray[1]))); # string("t", zero(Gray.(imarray)));
    typname = string("t", zero(Gray(array_elem)));
    if searchindex(typname, "N0f8") > 0
        ncolorshades = 2^8;
        typref = N0f8;
    elseif searchindex(typname, "N6f10") > 0
        ncolorshades = 2^10;
        typref = N6f10;
    elseif searchindex(typname, "N4f12") > 0
        ncolorshades = 2^12;
        typref = N4f12;
    elseif searchindex(typname, "N2f14") > 0
        ncolorshades = 2^14;
        typref = N2f14;
    elseif searchindex(typname, "N0f16") > 0
        ncolorshades = 2^16;
        typref = N0f16;
    else
        println("WARNING: unknown FixedPointNumber type used");
        ncolorshades = 369; # artifical value to make the result worse
        typref = N0f16;
    end # if searchindex(typname, "N0f8") > 0

    return ncolorshades, typref;
end # function _capacity_of_FPNtype(array_elem)


#####
# histogram of gray image
# ToDo: simply convert Gray Image to 2d-array and call '_histogram'
#    Gray.(img_col256)+0
#
#geht net: function imhistogram(imarray::AbstractArray{C}) where C<:AbstractGray
function imhistogramGray(imarray::AbstractArray)
    (ncolors, typref) = _capacity_of_FPNtype(Gray(imarray[1]));

    histo_gray = _imhistogram(Gray.(imarray), ncolors);

    return histo_gray;
end # function histogram of gray image

#####
# histogram of rgb image
# returns 3 histograms
#geht net: function imhistogram(imarray::AbstractArray{C}) where C<:AbstractRGB
function imhistogramRGB(imarray::AbstractArray)
    (ncolors, typref) = _capacity_of_FPNtype(red(imarray[1]));

    histo_red   = _imhistogram(red.(imarray), ncolors);
    histo_green = _imhistogram(green.(imarray), ncolors);
    histo_blue  = _imhistogram(blue.(imarray), ncolors);

    return histo_red, histo_green, histo_blue;
end # function histogram of RGB image

function imhistogramRGB3d_16bit(imarray::AbstractArray)
    # previous name of this func:  imhistogramRGB3d_old
    # use this function to support images with more than 8bits per color channel til package 'Colors' supports RGB48.
    # But the function will always support 8bits.  At least for speed tests, ...

    (ncolors, typref) = _capacity_of_FPNtype(red(imarray[1]));

    # 1st version
#    red_vector   = reshape(red.(imarray), :) .* myfactor; # reshape(red.(imarray), :, 1) * myfactor;
#    green_vector = reshape(green.(imarray), :) .* myfactor; # reshape(green.(imarray), :, 1) * myfactor;
#    blue_vector  = reshape(blue.(imarray), :) .* myfactor; # reshape(blue.(imarray), :, 1) * myfactor;
#    col_vector   = reshape(RGB24.(imarray), :); # reshape(RGB24.(imarray), :, 1);

    # make as 1 dim array
    red_vector   = reshape(red.(imarray), :); # reshape(red.(imarray), :, 1) * myfactor;
    green_vector = reshape(green.(imarray), :); # reshape(green.(imarray), :, 1) * myfactor;
    blue_vector  = reshape(blue.(imarray), :); # reshape(blue.(imarray), :, 1) * myfactor;

    # convert to ...
    if ncolors == 2^8 # searchindex(typname, "N0f8") > 0
        # ... 8-bit int
        red_ivector   = reinterpret.(N0f8.(red_vector));
        green_ivector = reinterpret.(N0f8.(green_vector));
        blue_ivector  = reinterpret.(N0f8.(blue_vector));

        col_ivector = (red_ivector .% UInt32) .<< 16 .+ (green_ivector .% UInt32) .<< 8 .+ (blue_ivector .% UInt32);

        # now do unique sort to reduce the number of color values
        # and prepare the data for the color cube
        col_cube_iv   = unique(sort!(col_ivector));
        red_cube_iv   = (col_cube_iv .& 0x00ff0000) .>> 16;
        green_cube_iv = (col_cube_iv .& 0x0000ff00) .>> 8;
        blue_cube_iv  = (col_cube_iv .& 0x000000ff);
    else # all colors here use 16bit for storage, but they may use not the full range.
        # ... 16-bit int ; currently raw images have 10, 12 or 14 bits per color, some image tools work with 16 bit
        # Depending on the used camera, one can have 10bit, 12bit or 14bit pictures.

        if ncolors == 2^10 # N6f10
            red_ivector   = reinterpret.(N6f10.(red_vector));
            green_ivector = reinterpret.(N6f10.(green_vector));
            blue_ivector  = reinterpret.(N6f10.(blue_vector));
        elseif ncolors == 2^12 # N4f12
            red_ivector   = reinterpret.(N4f12.(red_vector));
            green_ivector = reinterpret.(N4f12.(green_vector));
            blue_ivector  = reinterpret.(N4f12.(blue_vector));
        elseif ncolors == 2^14 # N2f14
            red_ivector   = reinterpret.(N2f14.(red_vector));
            green_ivector = reinterpret.(N2f14.(green_vector));
            blue_ivector  = reinterpret.(N2f14.(blue_vector));
        elseif ncolors == 2^16 # N0f16
            red_ivector   = reinterpret.(N0f16.(red_vector));
            green_ivector = reinterpret.(N0f16.(green_vector));
            blue_ivector  = reinterpret.(N0f16.(blue_vector));
        end # if ncolors == 2^10 # N6f10

        col_ivector = (red_ivector .% UInt64) .<< 32 .+ (green_ivector .% UInt64) .<< 16 .+ (blue_ivector .% UInt64);

        # now do unique sort to reduce the number of color values
        # and prepare the data for the color cube
        col_cube_iv   = unique(sort!(col_ivector));
        red_cube_iv   = (col_cube_iv .& 0x0000ffff00000000) .>> 32;
        green_cube_iv = (col_cube_iv .& 0x00000000ffff0000) .>> 16;
        blue_cube_iv  = (col_cube_iv .& 0x000000000000ffff);
    end # if ncolors == 2^8 # searchindex(typname, "N0f8") > 0


    # now this can be plotted as 3D using gnuplot from julia
    # with the command
    #   @gp(splot=true, redv[:], greenv[:], bluev[:], colv[:], "with points pt 13 ps 0.7 lc rgb variable")
    # since Gnuplot.jl v0.2.0
    #   @gsp(redv[7:10:end], greenv[7:10:end], bluev[7:10:end], gen_pcv(colv[7:10:end]), "with points pt 13 ps 0.7 lc rgb variable", xrange=(0,255), yrange=(0,255), zrange=(0,255), xlabel="red", ylabel="green", zlabel="blue", "set border -1", "set tics in mirror", "set grid", "set zticks out mirror", "set grid ztics", "set xyplane at 0.0")

    # to plot this with Plots
    # keep red_cube_iv, green_cube_iv, blue_cube_iv as is
    # convert col_cube_iv with
    #    colv_new=(RGB24.(N0f8.(UInt8.(redv)/255), N0f8.(UInt8.(greenv)/255), N0f8.(UInt8.(bluev)/255)))
    # then this can be plotted with
    #    scatter3d(redv[140000:1:end], greenv[140000:1:end], bluev[140000:1:end], color=colv_new[140000:1:end], ms=1, msw=0, marker=1, xlims=(0,255), ylims=(0,255), bg=:blue)

#    return red_ivector, green_ivector, blue_ivector, col_ivector;
    return red_cube_iv, green_cube_iv, blue_cube_iv, col_cube_iv;
end # function imhistogramRGB3d_16bit of RGB image

function imhistogramRGB3d_new2(imarray::AbstractArray)
    # previous name of this func:  imhistogramRGB3d_new2
    (ncolors, typref) = _capacity_of_FPNtype(red(imarray[1]));

    if (ncolors > 256)
        println("Sorry, this function supports 8-bits per color channel only !!!");
        println("Please call / use function 'imhistogramRGB3d_16bit(imarray::AbstractArray)' !!!");

        # return red_cube_iv, green_cube_iv, blue_cube_iv, col_cube_iv;
        return [0], [0], [0], [0];
    end # if (ncolors > 256)

    # 1st version
#    red_vector   = reshape(red.(imarray), :) .* myfactor; # reshape(red.(imarray), :, 1) * myfactor;
#    green_vector = reshape(green.(imarray), :) .* myfactor; # reshape(green.(imarray), :, 1) * myfactor;
#    blue_vector  = reshape(blue.(imarray), :) .* myfactor; # reshape(blue.(imarray), :, 1) * myfactor;
#    col_vector   = reshape(RGB24.(imarray), :); # reshape(RGB24.(imarray), :, 1);

    # make as 1 dim array
    #red_vector   = reshape(red.(imarray), :); # reshape(red.(imarray), :, 1) * myfactor;
    #green_vector = reshape(green.(imarray), :); # reshape(green.(imarray), :, 1) * myfactor;
    #blue_vector  = reshape(blue.(imarray), :); # reshape(blue.(imarray), :, 1) * myfactor;

    ### the next uses too much mem
    #col_vector   = reshape(hex.(RGB24.(imarray)), :); # println(col_vector);
    #col_cube_us   = unique(sort!(col_vector));
    #col_cube_iv   = reinterpret.(RGB24, parse.(UInt32, string.("0x", col_cube_us)));

    ### another try => Bingo!
    # calling sort() with the special isless() related to RGB24 reduced used mem and time
    # and then use sort!() for another improvement
    col_vector  = reshape(RGB24.(imarray), :); # println(col_vector);
    col_cube_iv = unique(sort!(col_vector, lt = (x, y)->isless(x.color, y.color)));

    red_cube_iv   = red.(col_cube_iv);
    green_cube_iv = green.(col_cube_iv);
    blue_cube_iv  = blue.(col_cube_iv);


    # now this can be plotted as 3D using gnuplot from julia
    # with the command
    #   @gp(splot=true, redv[:], greenv[:], bluev[:], colv[:], "with points pt 13 ps 0.7 lc rgb variable")
    #
    #   much better
    # @gp(splot=true, redv[:], greenv[:], bluev[:], gen_pcv(colv[:]), "with points pt 13 ps 0.7 lc rgb variable", xlabel="red", ylabel="green", zlabel="blue", "set border -1", "set tics in mirror", "set grid", "set zticks out mirror", "set grid ztics", "set xyplane at 0.0")
    #
    # @gp(splot=true, redv[1:10:end], greenv[1:10:end], bluev[1:10:end], gen_pcv(colv[1:10:end]), "with points pt 13 ps 0.7 lc rgb variable", xrange=(0,255), yrange=(0,255), zrange=(0,255), xlabel="red", ylabel="green", zlabel="blue", "set border -1", "set tics in mirror", "set grid", "set zticks out mirror", "set grid ztics", "set xyplane at 0.0")
    #
    # befor plotting with gnuplot, some crafting is necessary
    # 1) convert colv using
    #   gen_pcv(cv24_a)=(pcv24=zeros(length(cv24_a));for i = 1:endof(cv24_a); pcv24[i]=cv24_a[i].color; end;return pcv24)
    # 2) convert red, green, blue parts
    #   redv=redv*255.0;
    #   greenv=greenv*255.0;
    #   bluev=bluev*255.0;
    #
    # damn - still no 3d-plot with @gp.  somewhere there was a significant change:
    #     !!!! the syntax is not accepted any more !!!!
    #     !!!! splot wants a function instead of data !!!!
    #
    # !!!!! Intermediate Solution no longer necessary; new Gnuplot.jl v-0.2.0 !!!!!
    # manually checkout commit  1665b78a54a0b67ce6b61c2b8ebfe0f409a47ae4  from Gnuplot.jl
    #
    # manually checkout commit  56b64fcef797cc337eb2d589edf5e95a9abd37f5  from Gnuplot.jl
    #   works also
    #
    # starting with commit 6a4e95f377e3da76026731a99f2c6a918cd87fe8 from Gnuplot.jl 'splot' stops working
    #
    # !!!!! !!!!!
    #

    # 1st own 3 plot
    # @gp("set hidden3d", "set grid", "splot 'data3d.txt' using 1:2:3 with points pt 13 ps 0.7 lc rgb variable")
    # @gp("set grid; set xlabel 'red'; set ylabel 'green'; set zlabel 'blue'", "splot 'data3d.txt' using 1:2:3 with points pt 13 ps 0.7 lc rgb variable")
    # still not possible to splot data. Worked last year !!!

    # since Gnuplot.jl v0.2.0
    #  @gsp(redv[7:10:end], greenv[7:10:end], bluev[7:10:end], gen_pcv(colv[7:10:end]), "with points pt 13 ps 0.7 lc rgb variable", xrange=(0,255), yrange=(0,255), zrange=(0,255), xlabel="red", ylabel="green", zlabel="blue", "set border -1", "set tics in mirror", "set grid", "set zticks out mirror", "set grid ztics", "set xyplane at 0.0")

#    return red_ivector, green_ivector, blue_ivector, col_ivector;
    return red_cube_iv, green_cube_iv, blue_cube_iv, col_cube_iv;
end # function imhistogramRGB3d_new2 of RGB image

#####
# Helper used in function plot_imhi_3D().  Needed to pass the RGB24 colors to Gnuplot.
# It extracts the RGB24 color value and stores it in the output array.
# This is understood as color to use for the related marker in plots
gen_pcv(cv24_a)=(pcv24=zeros(length(cv24_a));for i = 1:endof(cv24_a); pcv24[i]=cv24_a[i].color; end;return pcv24)

#####
# How to do the 3D plot.
# But encapsulation into one function does not work.
# Thus, it is not possible to use 2 different plotting tools.
# Try using sub-modules and try 'using' and 'import':  one for 2D another one for 3D
# Else make an appropriate example.
#
function plot_imhi_3D(imarray::AbstractArray; bg::Int = 0, range_step::Int = 50)
#    using Gnuplot; # ToDO: maybe move into submodule 'imhi_plot3D' and 2D into submodule 'imhi_plot2D'

    # default to dark theme; for 3D it looks funny, but still better to read
    # Hmm PlotTheme broken since 2018-04-21 ~22:00
#    if (bg == 0)
#        theme(:dark); # good for electronic media
#        GrayShade=:lightgray;
#    else
#        theme(:default); # good for paper
#        GrayShade=:gray71;
#    end

    redv, greenv, bluev, colv = ImageHistogramTest.imhistogramRGB3d_new2(imarray);

    # convert FixedPontNumbers to plain numbers. They are used as coordinates in 3D.
    # ToDo: extend to respect more than 8 bits per color
    max_color_value = 2^8 - 1.0; # need a float as result
    redv *= max_color_value; greenv *= max_color_value; bluev *= max_color_value;

    # the Gnuplot tools want simple RGB24 values encoded as 32bit ints.
    # colv = gen_pcv(colv);

    # do the plot with Plots
    # scatter3d(redv[1:50:end], greenv[1:50:end], bluev[1:50:end], color=colv[1:50:end], markersize=3, marker=:cross)
    # scatter3d(redv[1:range_step:end], greenv[1:range_step:end], bluev[1:range_step:end], color=colv[1:range_step:end], title="Color Cube with 3D Histogram, draft quality", grid = :all, markersize=3, marker=:cross)

    # With the hints of 'mkborregaard' (JuliaPlots member); thanks
    scatter3d(redv[1:range_step:end], greenv[1:range_step:end], bluev[1:range_step:end], color=colv[1:range_step:end], title="Color Cube with 3D RGB-Histogram, draft quality", xlims=(0,255), ylims=(0,255), zlims=(0,255), grid = :all, markerstrokewidth = 0, markersize = 0.1, bg = :black, camera = (60, 60), marker=:circle)  # disable border of marker with 'markerstrokewidth = 0'

    # do the plot with Gnuplot manually in case the arrays are larger than 3000 - 4000 elements each.
    # @gp(splot=true, redv[1:10:end], greenv[1:10:end], bluev[1:10:end], gen_pcv(colv[1:10:end]), "with points pt 13 ps 0.7 lc rgb variable", xrange=(0,255), yrange=(0,255), zrange=(0,255), xlabel="red", ylabel="green", zlabel="blue", "set border -1", "set tics in mirror", "set grid", "set zticks out mirror", "set grid ztics", "set xyplane at 0.0")
    # since Gnuplot.jl v0.2.0
    #  @gsp(redv[7:10:end], greenv[7:10:end], bluev[7:10:end], gen_pcv(colv[7:10:end]), "with points pt 13 ps 0.7 lc rgb variable", xrange=(0,255), yrange=(0,255), zrange=(0,255), xlabel="red", ylabel="green", zlabel="blue", "set border -1", "set tics in mirror", "set grid", "set zticks out mirror", "set grid ztics", "set xyplane at 0.0")

end # function plot_imhi_3D(imarray::AbstractArray; how::Int = 2, bg::Int = 0)

function calc_histogram_norm_factor(ImHi1::AbstractArray, ImHi2::AbstractArray = [0], ImHi3::AbstractArray = [0], ImHi4::AbstractArray = [0])
    # calculat the norm-factor for the histograms.
    # expect up to 4 histograms : Gray, Red, Green, Blue
    # the order does not matter, thus name it 1 2 3 4
    # at minimum, one histogram - the 1st -  with data must be given via 'ImHi1'.

    if length(ImHi1) != 0
        norm_factor_overall = max(maximum(ImHi1), maximum(ImHi2), maximum(ImHi3), maximum(ImHi4));
    else
        norm_factor_overall = 1;
    end

    return norm_factor_overall;
end # function calc_histogram_norm_factor(...)

#=
# No.  In most cases input and output type differ
function normalize_histogram!(imhisto::AbstractArray, ih_nf = 0.0)
    # normalize the histogram
    #   ih_nf := 0 => max of all channels is set to 1
    #   ih_nf > 0 => use as scale factor

    # modification of arguments does not work this way
    # TWA ToDo : Bug or Feature ???
    # norm_factor = maximum(imhisto);
    # imhisto /= norm_factor;
    #
    # only this way
    if (ih_nf != 0)
        norm_factor = ih_nf;
    else
        norm_factor = typeof(ih_nf)(maximum(imhisto));
    end

    for i = 1:endof(imhisto) # ToDo: change julia-0.6.2 notation to julia-0.7.0 notation if the latter is public.
        imhisto[i] /= norm_factor;
    end

    return imhisto;
end # function normalize_histogram!(imhisto_raw::AbstractArray, ih_nf = 0.0)
=#

function normalize_histogram(imhisto_raw::AbstractArray, ih_nf::Real = 0.0)
    # normalize the histogram
    #   ih_nf := 0 => max of all channels is set to 1
    #   ih_nf > 0 => use as scale factor
    #
    # the output is always an array of reals. Thus in most cases different from input.
    # => no normalize_histogram!()-function

    if (ih_nf != zero(ih_nf))
        norm_factor = ih_nf;
    else
        norm_factor = typeof(ih_nf)(maximum(imhisto_raw));
    end

    imhisto_normed = imhisto_raw / norm_factor;

    return imhisto_normed;
end # function normalize_histogram(imhisto_raw::AbstractArray, ih_nf::Real = 0.0)

function combine_color_slots(imhisto_in::AbstractArray, nslots::Int = 0)
    # imhisto_in :== input of a histogram. It is a 1D array
    # nslots :== how much color slots shall be combined
    #      0 : auto (do nothing for histograms of 8 bit colors having a length of 256)
    #          if larger than 1024 scale down.
    #     >0 : combine. Best if a power of 2.

    if (mod(nslots, 2) != 0)
        println("Number of color slots to combine is best if a pwer of 2");
        println("You feed me with something else, be sure you know what you are doing");
    end

    imhisto_out = zeros(imhisto_in);
    len_ih_in = length(imhisto_in);

    if (nslots == 0)
        if (len_ih_in > 1024) # 2^10
            nslots = div(len_ih_in, 1024);
        else
            nslots = 1;
        end
    else
        nslots = abs(nslots);
        if (nslots > len_ih_in)
            println("The given 'nslots' is larger than the length of the histogram => using 1 instead");
        end
    end

    for i = 1:len_ih_in
        imhisto_out[div(i, nslots)] += imhisto_in[i];
    end
end # function combine_color_slots(imhisto_in::AbstractArray, nslots::Int = 0)

# ToDo : => no, array tooooo large
# my_rgb24int = Int32.(floor.(red.(colv)*255)) .<< 16 .+ Int32.(floor.(green.(colv)*255)) .<< 8 .+ Int32.(floor.(blue.(colv)*255))

function plot_imhi(;ihGray_cooked::AbstractArray = [0], ihR_cooked::AbstractArray = [0],
                   ihG_cooked::AbstractArray = [0], ihB_cooked::AbstractArray = [0],
                   how::Int = 4, bg::Int = 0)
    # default to dark theme
    if (bg == 0)
        theme(:dark); # good for electronic media
        GrayShade=:lightgray;
    else
        theme(:default); # good for paper
        GrayShade=:gray71;
    end

    if (how == 1)
        plot(ihGray_cooked, color=GrayShade, w=3, line=:sticks);
        plot!(ihR_cooked, color=:red, w=3);
        plot!(ihG_cooked, color=:green, w=3);
        plot!(ihB_cooked, color=:blue, w=3);
    elseif (how == 2)
        pl_Gray = plot(ihGray_cooked, color=GrayShade, w=3, line=:sticks);
        pl_RGB = plot(ihR_cooked, color=:red, w=3);
        pl_RGB = plot!(ihG_cooked, color=:green, w=3);
        pl_RGB = plot!(ihB_cooked, color=:blue, w=3);

        plot(pl_Gray, pl_RGB, layout=(2,1), legend=false);
    elseif (how == 3)
        nf = calc_histogram_norm_factor(ihR_cooked, ihG_cooked, ihB_cooked); # ToDo : make it optional

        pl_R = plot(ihR_cooked, ylims=(0,nf), color=:red, w=3);
        pl_G = plot(ihG_cooked, ylims=(0,nf), color=:green, w=3);
        pl_B = plot(ihB_cooked, ylims=(0,nf), color=:blue, w=3);

        plot(pl_R, pl_G, pl_B, layout=(3,1), legend=false);
    elseif (how == 4)
        nf = calc_histogram_norm_factor(ihGray_cooked, ihR_cooked, ihG_cooked, ihB_cooked); # ToDo : make it optional

        pl_Gray = plot(ihGray_cooked, ylims=(0,nf), color=GrayShade, w=3, line=:sticks);
        pl_R = plot(ihR_cooked, ylims=(0,nf), color=:red, w=3);
        pl_G = plot(ihG_cooked, ylims=(0,nf), color=:green, w=3);
        pl_B = plot(ihB_cooked, ylims=(0,nf), color=:blue, w=3);

        plot(pl_Gray, pl_R, pl_G, pl_B, layout=(2,2), legend=false);
    end # if (how == 1)
end # function plot_imhi(...)


function plot_imhi_GrayRGB(imarray::AbstractArray; how::Int = 2, bg::Int = 0)
    # bg := 0 => dark theme as background <=> see PlotThemes package for details
    # bg := 1 => default theme as background
    #
    # how := 1 => plot 4 graphs in 1 diagram
    #     := 2 => 2 subplots : Gray + RGB
    #     := 3 => 3 subplots : Red, Green, Blue
    #     := 4 => 4 subplots : Gray, Red, Green, Blue
    #
    # ToDo:  change how & background to keyword args.
    #

    ihR, ihG, ihB = ImageHistogramTest.imhistogramRGB(imarray);
    ihGray        = ImageHistogramTest.imhistogramGray(imarray);

    plot_imhi(ihGray_cooked=ihGray, ihR_cooked=ihR, ihG_cooked=ihG, ihB_cooked=ihB, how=how, bg=bg)

    #=
    # das folgende braucht noch 'using Plots'
    # Plot examples:
    # or using as subplot
    # plot_red = plot(ihr, line=:red, w=2);
    # plot(plot_red, plot_green, plot_blue, plot_gray, layout=(2,2), legend=false)

    # WATCH OUT !!  WATCH OUT !!
    # after switching to use OffsetArrays
    # plot needs another syntax
    #     plot(ihR[0:end], line=:red)
    #

    ploting into a 3d RGB-cube:
    using Images, TestImages ; import ImageHistogram ; img_col256 = testimage("lena_color_256");
    redv, greenv, bluev, colv = ImageHistogram.imhistogramRGB3d(img_col256);
    redv1=redv[1:32:65536]; greenv1=greenv[1:32:65536]; bluev1=bluev[1:32:65536]; colv1=colv[1:32:65536];

    plot using Plots:
    scatter3d(redv1, greenv1, bluev1, xlabel="red", ylabel="green", zlabel="blue"; color=colv1)
    scatter3d(redv[1:50:end], greenv[1:50:end], bluev[1:50:end], color=colv[1:50:end], markersize=3, marker=:cross)

    plot using GR:
    setmarkersize=1; setmarkertype(GR.MARKERTYPE_DOT)
    scatter3(redv1, greenv1, bluev1, xlabel="red", ylabel="green", zlabel="blue"; color=colv1)

    the previous is not as good as using gnuplot
    some reasons:
    Plots and GR do not support x-, y-, z-lables as expected
    take too long
    ? grid ?
    ? user defined view angle ?

    =#
end # function plot_imhi_GrayRGB


end # module ImageHistoryTest
