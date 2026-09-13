module PCXImages

using ColorTypes
using FixedPointNumbers

export read_pcx, write_pcx, read_dcx, write_dcx

# some utility values and functions...

const Black = RGB{N0f8}(0, 0, 0)
const White = RGB{N0f8}(1, 1, 1)

isblack(c::RGB{N0f8}) = c == Black

readint(io::IO, ::Type{T}) where {T <: Integer} = ltoh(read(io, T))

writeint(io::IO, x::Integer) = write(io, htol(x))

rgb(r::UInt8, g::UInt8, b::UInt8) = RGB{N0f8}(r / 255, g / 255, b / 255)

rgba(r::UInt8, g::UInt8, b::UInt8, a::UInt8) = RGBA{N0f8}(r / 255, g / 255, b / 255, a / 255)

const PALETTE_256_ID_VALUE = 0x0c

#! format: off
const EGA_DEFAULT_PALETTE = [
    rgb(0x00, 0x00, 0x00), # black
    rgb(0x00, 0x00, 0xaa), # blue
    rgb(0x00, 0xaa, 0x00), # green
    rgb(0x00, 0xaa, 0xaa), # cyan
    rgb(0xaa, 0x00, 0x00), # red
    rgb(0xaa, 0x00, 0xaa), # magenta
    rgb(0xaa, 0x55, 0x00), # brown
    rgb(0xaa, 0xaa, 0xaa), # light gray
    rgb(0x55, 0x55, 0x55), # gray
    rgb(0x55, 0x55, 0xff), # light blue
    rgb(0x55, 0xff, 0x55), # light green
    rgb(0x55, 0xff, 0xff), # light cyan
    rgb(0xff, 0x55, 0x55), # light red
    rgb(0xff, 0x55, 0xff), # light magenta
    rgb(0xff, 0xff, 0x55), # yellow
    rgb(0xff, 0xff, 0xff), # white
]

const CGA_PALETTE_ZERO_DARK = [
    rgb(0x00, 0xaa, 0x00), # green
    rgb(0xaa, 0x00, 0x00), # red
    rgb(0xaa, 0x55, 0x00), # brown
]

const CGA_PALETTE_ONE_DARK = [
    rgb(0x00, 0xaa, 0xaa), # cyan
    rgb(0xaa, 0x00, 0xaa), # magenta
    rgb(0xaa, 0xaa, 0xaa), # light gray
]

const CGA_PALETTE_ZERO_LIGHT = [
    rgb(0x55, 0xff, 0x55), # light green
    rgb(0xff, 0x55, 0x55), # light red
    rgb(0xff, 0xff, 0x55), # yellow
]

const CGA_PALETTE_ONE_LIGHT = [
    rgb(0x55, 0xff, 0xff), # light cyan
    rgb(0xff, 0x55, 0xff), # light magenta
    rgb(0xff, 0xff, 0xff), # white
]

const CGA_DEFAULT_PALETTES = (
    CGA_PALETTE_ZERO_DARK,
    CGA_PALETTE_ZERO_LIGHT,
    CGA_PALETTE_ONE_DARK,
    CGA_PALETTE_ONE_LIGHT,
)

#! format: on

include("pcx_header.jl")
include("decode.jl")
include("encode.jl")
include("dcx.jl")

end # module PCXImages
