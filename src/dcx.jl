#

const DCX_ID = 0x3ade68b1

struct DcxHeader
    id::UInt32
    table::Vector{UInt32}
end

function DcxHeader(io::IO)
    id = readint(io, UInt32)
    id == DCX_ID || error("Incorrect DCX id")
    table = zeros(UInt32, 1024)
    for i in eachindex(table)
        offset = readint(io, UInt32)
        iszero(offset) && break
        table[i] = offset
    end
    return DcxHeader(id, table)
end

function image_count(hdr::DcxHeader)
    n = 0
    for i in eachindex(hdr.table)
        hdr.table[i] == 0 && break
        n += 1
    end
    return n
end

"""
    read_dcx(filename::AbstractString)

Read the file `filename`, interpret it as a DCX file, return a
`Vector{Matrix{<:Colorant}}` based on the content of the file.
"""
function read_dcx(filename::AbstractString)
    imgs = nothing
    open(filename) do io
        imgs = read_dcx(io)
    end
    return imgs
end

"""
    read_dcx(io::IO)

Read the stream `io`, interpret it as DCX data, return a
`Vector{Matrix{<:Colorant}}` based on the content read from the stream.
"""
function read_dcx(io::IO)
    hdr = DcxHeader(io)
    nimages = image_count(hdr)
    images = Vector{Matrix{<:Colorant}}(undef, nimages)
    for i = 1:nimages
        seek(io, hdr.table[i])
        images[i] = read_pcx(io, hdr.table[i + 1])
    end
    return images
end

"""
    write_dcx(filename::AbstractString, images::AbstractVector{<:AbstractMatrix{<:Colorant}})

Write `images` to the file `filename` in DCX format. See
    write_pcx(::AbstractString, AbstractMatrix, Bool; bpp, nplanes::Integer)
for a description of other parameters.
"""
function write_dcx(
    filename::AbstractString,
    images::AbstractVector{<:AbstractMatrix{<:Colorant}},
    smallest::Bool = false;
    bpp::Integer = 0,
    nplanes::Integer = 0,
)
    open(filename, "w") do io
        return write_dcx(io, images, smallest; bpp = bpp, nplanes = nplanes)
    end
    return
end

"""
    write_dcx(io::IO, images::AbstractVector{<:AbstractMatrix{<:Colorant}})

Write `images` to the stream `io` in DCX format. See
    write_pcx(::AbstractString, AbstractMatrix, Bool; bpp, nplanes::Integer)
for a description of other parameters.
"""
function write_dcx(
    io::IO,
    images::AbstractVector{<:AbstractMatrix{<:Colorant}},
    smallest::Bool = false;
    bpp::Integer = 0,
    nplanes::Integer = 0,
)
    nimages = min(1023, length(images))
    hdr = DcxHeader(DCX_ID, zeros(UInt32, nimages + 1))
    write(io, hdr.id)
    write(io, hdr.table)
    for i = 1:nimages
        hdr.table[i] = position(io)
        write_pcx(io, images[i], smallest; bpp = bpp, nplanes = nplanes)
    end
    seek(io, sizeof(hdr.id))
    write(io, hdr.table)
    return
end
