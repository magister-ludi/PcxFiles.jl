# PCXImages.jl

[![Build status](https://github.com/magister-ludi/PCXImages.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaIO/Netpbm.jl/actions/workflows/CI.yml)

Read and write [PCX](https://en.wikipedia.org/wiki/PCX) formats in pure Julia.
This package does not (yet) implement the
[FileIO](https://github.com/JuliaIO/FileIO.jl) interface for loading
and saving PCX images.

PCX is an image format developed by ZSoft and Microsoft for use by PC Paintbrush on DOS and Windows computers. DCX is an extension of the PCX format which can store multiple images in a single file. Format summaries for both formats are provided [here](https://www.fileformat.info/format/pcx/egff.htm). The format specification was first released in 1985; the final release was in 1991.

As [described by Adobe](https://www.adobe.com/creativecloud/file-types/image/raster/pcx-file.html) PCX format was useful as a lossless, compressed format. Compression was poor in comparison with modern formats, but easy to implement.

## PCX format

PCX can store image data up to 32 bytes per pixel (red, green, blue, alpha with 1 byte each). Few software implementations are able to read/write all PCX files, because the specifications are incomplete, and because some files extend the specifications (which, for instance, do not include an alpha channel).

PCXImages.jl will read and write PCX data with the following attributes:

| Bits per pixel  | Planes | Number of colours |
| :---: | :---: | :---: |
| 1  | 1  | 2 |
| 1  | 2  | 4 |
| 1  | 3  | 8 |
| 1  | 4  | 16 |
| 4  | 1  | 16 |
| 4  | 4  | 16<sup>*</sup> |
| 8  | 1  | 256 |
| 8  | 3  | 2<sup>24</sup> |
| 8  | 4  | 2<sup>32</sup> |

<sup>*</sup> Images with 4 bits per pixel plus 4 planes are rare (I have only discovered one in the wild). [Wikipedia](https://en.wikipedia.org/wiki/PCX#PCX_image_formats) says that the fourth plane represents an alpha-channel. ImageMagick and PCXImages.jl interpret the flags in a way that constructs a 16-colour image.

## DCX format

DCX data contain a concatenated set of PCX image data, plus a header to provide meta-information about the images in the set.

## PCXImages.jl API

The package exports four names. The signatures of the simplest invocations are:

 - `read_pcx(filename::AbstractString)`: read the file `filename` as a PCX file and return
 a `Matrix{<:Colorant}`.

 - `read_pcx(io::IO)`: read the stream `io` as a PCX stream and return a `Matrix{<:Colorant}`.

 - `write_pcx(filename::AbstractString, image::AbstractMatrix{<:Colorant})`: save `image` in PCX format to the file `filename`.

 - `write_pcx(io::IO, image::AbstractMatrix{<:Colorant})`: write `image` in PCX format to the stream `filename`.

 - `read_dcx(file::AbstractString)`: read the file `filename` as a DCX file and return
 a `Vector{Matrix{<:Colorant}}`.

 - `read_dcx(`: read the stream `io` as a DCX stream and return a `Vector{Matrix{<:Colorant}}`.

 - `write_dcx(filename::AbstractString, image::AbstractVector{AbstractMatrix{<:Colorant}})`: save `images` in DCX format to the file `filename`.

 - `write_dcx(io::IO, image::AbstractVector{AbstractMatrix{<:Colorant}})`: write `images` in DCX format to the stream `io`.

The methods whose names start with `read_` will throw an `ErrorException` if the format of the file/stream is incorrect.

The methods whose names start with `write_` take additional arguments and keyword arguments. See the docstring for `write_pcx(filename::AbstractString, image::AbstractMatrix{<:Colorant})` for a description of other parameters.

## Correctness

Most read/write results conform with other software I have tested. However, the specification is sometimes open to interpretation. Please open issues or pull requests if necessary.
