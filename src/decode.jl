
"""
    read_pcx(filename::AbstractString)

Read the file `filename`, interpret it as a PCX file, return a
`Matrix{RGB{N0f8}}` based on the content of the file.
"""
function read_pcx(filename::AbstractString)
    img = nothing
    open(filename) do io
        img = read_pcx(io)
    end
    return img
end

"""
    read_pcx(io::IO, end_of_data = 0)

Read the stream `io`, interpret it as PCX data, return a
`Matrix{RGB{N0f8}}` based on the content read from the stream.
"""
function read_pcx(io::IO, end_of_data = 0)
    startpos = position(io)
    hdr = PcxHeader(io, end_of_data)
    seek(io, startpos + 128)
    buffer = Vector{UInt8}(undef, hdr.blength)
    ctype = hdr.bpp == 8 && hdr.nplanes == 4 ? RGBA : RGB
    image = Matrix{ctype{N0f8}}(undef, hdr.height, hdr.width)

    if hdr.nplanes == 1
        single_plane_decode(io, hdr, buffer, image)
    elseif hdr.bpp == 1 || hdr.bpp == 4
        multi_plane_decode(io, hdr, buffer, image)
    elseif hdr.bpp == 8 && hdr.nplanes == 4
        decode_32bit(io, hdr, buffer, image)
    else
        decode_24bit(io, hdr, buffer, image)
    end
    return image
end

function single_plane_decode(io::IO, hdr::PcxHeader, buffer, image)
    mask::UInt8 = (1 << hdr.bpp) - 1
    ncolor = 2^hdr.bpp
    for y = 1:(hdr.height)
        rle_decode(io, buffer)
        shift::UInt8 = 8 - hdr.bpp
        index = 1
        for x = 1:(hdr.width)
            image[y, x] = hdr.palette[((buffer[index] >> shift) & mask) + 1]
            if shift == 0
                shift = 8 - hdr.bpp
                index += 1
            else
                shift -= hdr.bpp
            end
        end
    end
end

function multi_plane_decode(io::IO, hdr::PcxHeader, buffer, image)
    bpl = hdr.bpl
    for y = 1:(hdr.height)
        rle_decode(io, buffer)
        index = 1
        shift::UInt8 = 0
        for x = 1:(hdr.width)
            v::UInt8 = 0
            for i = 0:(hdr.nplanes - 1)
                k = bpl * i + index
                v = (v >> 1) | ((buffer[k] << shift) & 0x80)
            end
            v >>= 8 - hdr.nplanes
            image[y, x] = hdr.palette[v + 1]
            if shift == 7
                shift = 0
                index += 1
            else
                shift += 1
            end
        end
    end
end

function decode_24bit(io::IO, hdr::PcxHeader, buffer, image)
    for y = 1:(hdr.height)
        rle_decode(io, buffer)
        for x = 1:(hdr.width)
            r = buffer[x]
            g = buffer[x + hdr.bpl]
            b = buffer[x + 2 * hdr.bpl]
            image[y, x] = rgb(r, g, b)
        end
    end
end

function decode_32bit(io::IO, hdr::PcxHeader, buffer, image)
    for y = 1:(hdr.height)
        rle_decode(io, buffer)
        for x = 1:(hdr.width)
            r = buffer[x]
            g = buffer[x + hdr.bpl]
            b = buffer[x + 2 * hdr.bpl]
            a = buffer[x + 3 * hdr.bpl]
            image[y, x] = rgba(r, g, b, a)
        end
    end
end

function rle_decode(io::IO, out::AbstractVector{UInt8})
    off = firstindex(out)
    stop = lastindex(out)
    while off <= stop
        val = read(io, UInt8)
        run = 1
        if val >= 0xc0
            run = val & 0x3f
            val = read(io, UInt8)
        end
        for i = 1:run
            off > stop && error("pcx: RLE overrun")
            out[off] = val
            off += 1
        end
    end
end
