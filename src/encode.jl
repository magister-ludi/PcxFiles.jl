#

function color_less(c1::C, c2::C) where {C <: Colorant}
    r1, g1, b1 = red(c1), green(c1), blue(c1)
    r2, g2, b2 = red(c2), green(c2), blue(c2)
    if r1 == r2
        if g1 == g2
            return b1 < b2
        else
            return g1 < g2
        end
    else
        return r1 < r2
    end
end

"""
    write_pcx(
        filename::AbstractString,
        image::AbstractMatrix{<:Colorant},
        smallest::Bool = false;
        bpp::Integer = 0,
        nplanes::Integer = 0
    )

Save `image` in PCX format to `filename`.

If `smallest` is `true`, `bpp` and `nplanes` are ignored. Based on
the number of distinct colors in `image`, `bpp` and `nplanes` will be set to
try to make the stored PCX output as small as possible. Whether it is the
smallest output depends on `image`, experimentation is advised if that is
important.

If `smallest` is `false`, and `bpp` and `nplanes` are zero, the PCX output
will be stored as a 256-color image if the number of distinct colors in `image`
is less than 256, as a 24-bit image otherwise.

If `smallest` is `false`, and both `bpp` and `nplanes` are non-zero, those
values will be used for storing the PCX output. It is the responsibility of
the caller to ensure the values are large enough to accommodate all colors.

There is only one PCX format that allows transparency:
`bpp` = `8`, `nplanes` = `4`. If the pixels in `image` are transparent,
those values will be set and `smallest` will be ignored.
"""
function write_pcx(
        filename::AbstractString,
        image::AbstractMatrix{<:Colorant},
        smallest::Bool = false;
        bpp::Integer = 0,
        nplanes::Integer = 0,
    )
    open(filename, "w") do io
        write_pcx(io, image, smallest; bpp = bpp, nplanes = nplanes)
    end
    return
end

"""
    write_pcx(
        io::IO,
        image::AbstractMatrix{<:Colorant},
        smallest::Bool = false;
        bpp::Integer = 0,
        nplanes::Integer = 0
    )

Write `image` in PCX format to `io`. See
    write_pcx(::AbstractString, AbstractMatrix, Bool; bpp, nplanes::Integer)
for a description of other parameters.
"""
function write_pcx(
        io::IO,
        image::AbstractMatrix{C},
        smallest::Bool = false;
        bpp::Integer = 0,
        nplanes::Integer = 0,
    ) where {C <: Colorant}
    colors = unique(image)
    ncolors = length(colors)
    if C <: TransparentColor
        bpp = 8
        nplanes = 4
    end

    if (bpp == 8 && nplanes > 1) || ncolors > 256
        color_dict = nothing
    else
        sort!(colors; lt = color_less)
        if ncolors == 1
            # add a dummy color to make a "two color" image
            if isblack(colors[1])
                push!(colors, White)
            else
                pushfirst!(colors, Black)
            end
            ncolors = 2
        elseif ncolors == 2 && ((bpp == 1 && nplanes == 1) || smallest)
            if !isblack(colors[1])
                nplanes = 2  # fallback if black is not one of the colors
            end
        end

        # Construct map from color to palette index
        color_dict = Dict((c => UInt8(i - 1) for (i, c) in enumerate(colors)))
    end
    hdr = PcxHeader(image, colors, smallest; bpp=bpp, nplanes=nplanes)

    write(io, 0x0a)                      # magic number
    write(io, hdr.version)               # version
    write(io, 0x01)                      # run length encoding
    write(io, hdr.bpp)                   # bits/pixel
    writeint(io, zero(UInt16))           # xmin
    writeint(io, zero(UInt16))           # ymin
    writeint(io, hdr.width - 0x0001)     # xmax
    writeint(io, hdr.height - 0x0001)    # ymax
    writeint(io, zero(UInt16))           # hres
    writeint(io, zero(UInt16))           # vres
    # color map:
    palcount = 0
    #@show length(colors), hdr.bpp, hdr.nplanes
    if hdr.bpp == 1 && hdr.nplanes == 1
        r = reinterpret(UInt8, red(colors[2]))
        g = reinterpret(UInt8, green(colors[2]))
        b = reinterpret(UInt8, blue(colors[2]))
        write(io, r, g, b)
        palcount = 1
    elseif hdr.bpp == 1 || (hdr.nplanes == 1 && hdr.bpp <= 4) || hdr.nplanes == hdr.bpp == 4
        # 16 colors
        # (bpp, nplanes) ∈ ((1, 2), (1, 3), (1, 4), (2, 1), (3, 1), (4, 1), (4, 4))
        cset = Set{NTuple{3, UInt8}}()
        for i in 1:ncolors
            r = reinterpret(UInt8, red(colors[i]))
            g = reinterpret(UInt8, green(colors[i]))
            b = reinterpret(UInt8, blue(colors[i]))
            write(io, r, g, b)
            push!(cset, (r, g, b))
        end
        palcount = ncolors
        if hdr.bpp == 2 && hdr.nplanes == 1
            # avoid repeated values triggering CGA interpretation
            k = 0
            r::UInt8 = 0
            g::UInt8 = 0
            b::UInt8 = 0
            while length(cset) < 16
                while (r, g, b) ∈ cset
                    r3 = k % 3
                    if r3 == 0
                        r = (r + 1) % UInt8
                    elseif r3 == 1
                        g = (g + 1) % UInt8
                    else
                        b = (b + 1) % UInt8
                    end
                    k += 1
                end
                push!(cset, (r, g, b))
                write(io, r, g, b)
            end
            palcount = 16
        end
    end
    for _ in (palcount + 1):16
        write(io, 0x00, 0x00, 0x00)
    end
    write(io, 0x00)                      # reserved, unused
    write(io, hdr.nplanes)               # number of color planes
    writeint(io, hdr.bpl)                # Bytes per line
    writeint(io, one(UInt16))            # palette interpretation (usually ignored)
    writeint(io, zero(UInt16))           # HscreenSize, not set
    writeint(io, zero(UInt16))           # VscreenSize, not set
    # Fill to 128 bytes
    for _ in 1:54
        write(io, 0x00)
    end
    return write_pixeldata(io, hdr, color_dict, image)
end

function write_pixeldata(io::IO, hdr::PcxHeader, colors, image)
    buffer = Vector{UInt8}(undef, hdr.blength)
    if hdr.nplanes == 1
        encode_single_plane(io, hdr, colors, buffer, image)
    elseif hdr.bpp == 1 || hdr.bpp == 4
        encode_multi_plane(io, hdr, colors, buffer, image)
    elseif hdr.bpp == 8 && hdr.nplanes == 4
        encode_32bit(io, hdr, buffer, image)
    else
        encode_24bit(io, hdr, buffer, image)
    end
    return
end

function encode_single_plane(io::IO, hdr::PcxHeader, colors, buffer, image)
    mask::UInt8 = (1 << hdr.bpp) - 1
    for y in 1:(hdr.height)
        fill!(buffer, 0x00)
        shift::UInt8 = 8 - hdr.bpp
        index = 1
        for x in 1:(hdr.width)
            palidx = colors[image[y, x]]
            buffer[index] |= (palidx & mask) << shift
            if shift == 0 && x != hdr.width
                shift = 8 - hdr.bpp
                index += 1
            else
                shift -= hdr.bpp
            end
        end
        rle_encode(io, buffer)
    end
    if hdr.bpp == 8
        write(io, PALETTE_256_ID_VALUE)
        for cl in hdr.palette
            write(io, reinterpret(UInt8, red(cl)))
            write(io, reinterpret(UInt8, green(cl)))
            write(io, reinterpret(UInt8, blue(cl)))
        end
        for _ in (length(hdr.palette) + 1):256
            write(io, 0x00, 0x00, 0x00)
        end
    end
    return
end

function encode_multi_plane(io::IO, hdr::PcxHeader, colors, buffer, image)
    bpl = hdr.bpl
    for y in 1:(hdr.height)
        fill!(buffer, 0x00)
        shift = 0x07
        index = 1
        for x in 1:(hdr.width)
            val = colors[image[y, x]]
            for i in 0:(hdr.nplanes - 1)
                k = bpl * i + index
                v = val & 0x01
                buffer[k] |= (val & 0x01) << shift
                val >>= 1
            end
            if shift == 0
                shift = 0x07
                index += 1
            else
                shift -= 0x01
            end
        end
        rle_encode(io, buffer)
    end

    if length(colors) > 16
        # write 256 color palette
        write(io, PALETTE_256_ID_VALUE)
        ncolors = length(hdr.palette)
        for cl in hdr.palette
            write(io, reinterpret(UInt8, red(cl)))
            write(io, reinterpret(UInt8, green(cl)))
            write(io, reinterpret(UInt8, blue(cl)))
        end
        for i in (1 + ncolors):256
            write(io, 0x00, 0x00, 0x00)
        end
    end
    return
end

function encode_24bit(io::IO, hdr::PcxHeader, buffer, image)
    for y in 1:(hdr.height)
        for x in 1:(hdr.width)
            pxl = image[y, x]
            buffer[x + 0 * hdr.bpl] = reinterpret(UInt8, red(pxl))
            buffer[x + 1 * hdr.bpl] = reinterpret(UInt8, green(pxl))
            buffer[x + 2 * hdr.bpl] = reinterpret(UInt8, blue(pxl))
        end
        rle_encode(io, buffer)
    end
    return
end

function encode_32bit(io::IO, hdr::PcxHeader, buffer, image)
    for y in 1:(hdr.height)
        for x in 1:(hdr.width)
            pxl = image[y, x]
            buffer[x + 0 * hdr.bpl] = reinterpret(UInt8, red(pxl))
            buffer[x + 1 * hdr.bpl] = reinterpret(UInt8, green(pxl))
            buffer[x + 2 * hdr.bpl] = reinterpret(UInt8, blue(pxl))
            buffer[x + 3 * hdr.bpl] = reinterpret(UInt8, alpha(pxl))
        end
        rle_encode(io, buffer)
    end
    return
end

function write_code(io::IO, ch::UInt8, n::UInt8)
    if n > 0
        if n == 1 && 0xc0 != (0xc0 & ch)
            write(io, ch)
        else
            write(io, 0xc0 | n, ch)
        end
    end
    return
end

function rle_encode(io::IO, picLine::AbstractVector{UInt8})
    curr::UInt8 = 0
    prev::UInt8 = picLine[1]
    run::UInt8 = 1

    for index in 2:lastindex(picLine)
        curr = picLine[index]
        if curr == prev
            run += 1
            if run == 63
                write_code(io, prev, run)
                run = 0
            end
        else
            if run > 0
                write_code(io, prev, run)
            end
            prev = curr
            run = 1
        end
    end
    if run > 0
        write_code(io, prev, run)
    end
    return
end
