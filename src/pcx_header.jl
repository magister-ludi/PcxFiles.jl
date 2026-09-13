#=
`enc_choice` maps the values of the required number of colors
to a '(bpp, nplanes)` pair that is often a good choice for
minimising file size.
=#
const enc_choice =
    Dict(
    2 => (1, 1),
    4 => (1, 2),
    8 => (1, 3),
    16 => (1, 4),
    256 => (8, 1),
    2^24 => (8, 3)
)

function choose_encoding(ncolors, smallest)
    if smallest
        if ncolors <= 2
            return enc_choice[2]
        elseif ncolors <= 4
            return enc_choice[4]
        elseif ncolors <= 8
            return enc_choice[8]
        elseif ncolors <= 16
            return enc_choice[16]
        elseif ncolors <= 256
            return enc_choice[256]
        else
            return enc_choice[2^24]
        end
    else
        return (8, ncolors <= 256 ? 1 : 3)
    end
end

struct PcxHeader
    version::UInt8
    bpp::UInt8                    # bits/pixel
    width::UInt16
    height::UInt16
    colormap::Vector{UInt8}       # 16 RGB triples
    nplanes::UInt8                # number of color planes
    bpl::UInt16                   # bytes/line/plane
    blength::UInt16               # length of i/o buffer
    palette::Vector{RGB{N0f8}}    # colors in image
end

"""
    PcxFiles.PcxHeader(filename::AbstractString)

Construct a `PcxFiles.PcxHeader` from the PCX file `filename`.
"""
function PcxHeader(filename::AbstractString)
    hdr=nothing
    open(filename) do io
        hdr= PcxHeader(io)
    end
    return hdr
end

"""
    PcxFiles.PcxHeader(io::IO, end_of_data = 0)

Construct a `PcxFiles.PcxHeader` from the input stream `io`.
"""
function PcxHeader(io::IO, end_of_data = 0)
    start_of_data = position(io)
    if read(io, UInt8) != 10
        error("file is not a pcx image!")
    end
    version = read(io, UInt8)
    if read(io, UInt8) != 1
        error("unsupported encoding scheme")
    end
    bpp = read(io, UInt8) # color bits
    xMin = readint(io, UInt16)
    yMin = readint(io, UInt16)
    xMax = readint(io, UInt16)
    yMax = readint(io, UInt16)
    xMax >= xMin || error("Invalid PCX data")
    yMax >= yMin || error("Invalid PCX data")
    width = xMax - xMin + one(UInt16)
    height = yMax - yMin + one(UInt16)
    readint(io, UInt16) # hRes, unused
    readint(io, UInt16) # vRes, unused

    colormap = read(io, 48)
    read(io, UInt8) # should be 0, ignored
    nplanes = read(io, UInt8)

    bpl = readint(io, UInt16)
    bytesPerScanLine = bpl * nplanes

    if bpp == 1 && nplanes == 1
        # 2 colors
        c1 = rgb(colormap[1:3]...)
        c2 = rgb(colormap[4:6]...)
        if isblack(c1)
            if isblack(c2)
                c2 = White
            end
            palette = [c1, c2]
        else
            palette = [Black, c1]
        end
    elseif bpp == 2 && nplanes == 1
        # 4 colors
        palette = read_16color_palette(colormap, 4)
        if length(Set(palette)) != length(palette)
            # file palette has duplicated entries, use a system palette
            background = 1 + (colormap[1] & 0xf0) >> 4
            paletteNumber = 1 + (colormap[1 + 3] & 0x60) >> 5
            cga_palette = CGA_DEFAULT_PALETTES[paletteNumber]
            palette[1:3] .= cga_palette
            palette[4] = EGA_DEFAULT_PALETTE[background]
        end
    elseif bpp == 4 && nplanes == 1
        # 16 colors
        if version == 5
            palette = read_16color_palette(colormap, 16)
        else
            palette = EGA_DEFAULT_PALETTE
        end
    elseif bpp == 8 && nplanes == 1
        # 256 colors
        palette = read_256color_palette(io, end_of_data)
    elseif bpp == 1 && nplanes == 2
        # 4 colors
        if version == 5
            palette = read_16color_palette(colormap, 4)
        else
            palette = EGA_DEFAULT_PALETTE
        end
    elseif bpp == 1 && nplanes == 3
        # 8 colors
        if version == 5
            palette = read_16color_palette(colormap, 8)
        else
            palette = EGA_DEFAULT_PALETTE
        end
    elseif bpp == 1 && nplanes == 4
        # 16 colors
        if version == 5
            palette = read_16color_palette(colormap, 16)
        else
            palette = EGA_DEFAULT_PALETTE
        end
    elseif bpp == 4 && nplanes == 4
        # 16 colors
        if version == 2 || version == 5
            palette = read_16color_palette(colormap, 16)
        else
            palette = EGA_DEFAULT_PALETTE
        end
    elseif bpp == 8 && nplanes == 3
        # 2^24 colors
        palette = RGB{N0f8}[]
    elseif bpp == 8 && nplanes == 4
        # 2^24 colors
        palette = RGB{N0f8}[]
    else
        error("Unsupported scheme: $bpp bits/pixel, $nplanes color planes")
    end

    return PcxHeader(version, bpp, width, height, colormap, nplanes, bpl, bytesPerScanLine, palette)
end

"""
    PcxFiles.PcxHeader(image::AbstractMatrix{C},
                    colors::AbstractArray{C},
                    smallest = false;
                    bpp = 0,
                    nplanes = 0,

) where {C <: Colorant}

Construct a `PcxFiles.PcxHeader` suitable for storing `image` in PCX format
(used internally by `write_pcx`). `colors` is assumed to contain the distict
colors in `image`. See `write_pcx` for the meaning of other parameters.
"""
function PcxHeader(
        image::AbstractMatrix{C},
        colors::AbstractArray{C},
        smallest = false;
        bpp::Integer = 0,
        nplanes::Integer = 0,
    ) where {C <: Colorant}
    height, width = size(image)
    version = 5
    ncolors = length(colors)

    if C <: TransparentColor
        bpp, nplanes = 8, 4
    elseif iszero(bpp) && iszero(nplanes)
        bpp, nplanes = choose_encoding(ncolors, smallest)
    elseif ncolors > 2^(bpp * nplanes)
        error("Image has $ncolors colors. Encoding with $bpp bits/pixel, $nplanes is not possible")
    end

    bpl = ceil(Int, width * bpp / 8)
    if isodd(bpl)
        bpl += 1 # bpl mut be even
    end
    blength = bpl * nplanes
    return PcxHeader(version, bpp, width, height, UInt8[], nplanes, bpl, blength, colors)
end

read_16color_palette(colormap, colorsCount) =
    @views reinterpret(RGB{N0f8}, colormap[1:(3 * colorsCount)])

function read_256color_palette(io::IO, end_of_data)
    pos = position(io)
    if end_of_data == 0
        seekend(io)
    else
        seek(io, end_of_data)
    end
    seek(io, position(io) - 3 * 256 - 1)
    flag = read(io, UInt8)
    # Check flag
    flag != PALETTE_256_ID_VALUE && error("256 palette missing id!")
    palette = read(io, 3 * 256)
    # reset read position
    seek(io, pos)
    return reinterpret(RGB{N0f8}, palette)
end
