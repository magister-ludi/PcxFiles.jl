using ColorTypes
using FixedPointNumbers
using PcxImages
using Test

const test_size = 100
const n_iter = 10

@testset "PcxImages" begin
    bitkeys = [(1, 1), (1, 2), (1, 3), (1, 4), (4, 4), (2, 1), (4, 1), (8, 1), (8, 3)]

    max_colors = Dict(
        (1, 1) => 2,
        (1, 2) => 4,
        (1, 3) => 8,
        (1, 4) => 16,
        (2, 1) => 4,
        (4, 1) => 16,
        (4, 4) => 16,
        (8, 1) => 256,
        (8, 3) => 2^24,
    )

    function construct_image(ncolors, size)
        # construct ncolors different colors
        colors = Set{RGB{N0f8}}()
        if ncolors == 2
            # Force black
            push!(colors, RGB{N0f8}(0, 0, 0))
        end
        while length(colors) < ncolors
            push!(colors, rand(RGB{N0f8}))
        end
        # fill a matrix with a random set
        return rand(colors, size, size)
    end

    function construct_transparent_image(ncolors, size)
        # construct ncolors different transparent colors
        colors = Set{ARGB32}()
        if ncolors == 2
            # Force black
            push!(colors, ARGB32(0, 0, 0))
        end
        while length(colors) < ncolors
            push!(colors, rand(ARGB32))
        end
        # fill a matrix with a random set
        return rand(colors, size, size)
    end

    @testset "Save smallest" begin
        buf = IOBuffer()
        dcxdata = Vector{Matrix{RGB{N0f8}}}(undef, n_iter)
        for ncolors in (2, 4, 8, 16, 256, 512)
            for i in 1:n_iter
                img = construct_image(ncolors, test_size)
                take!(buf)
                write_pcx(buf, img, true)
                dcxdata[i] = img
                seekstart(buf)
                pixels = read_pcx(buf)
                @test size(pixels) == size(img)
                @test pixels == img
            end
            take!(buf)
            write_dcx(buf, dcxdata)
            seekstart(buf)
            dcx = read_dcx(buf)
            @test length(dcx) == length(dcxdata)
            for i in 1:n_iter
                @test size(dcx[i]) == size(dcxdata[i])
                @test dcx[i] == dcxdata[i]
            end
        end
    end

    @testset "Specific formats" begin
        buf = IOBuffer()
        dcxdata = Vector{Matrix{RGB{N0f8}}}(undef, n_iter)
        for ncolors in (2, 4, 8, 16, 256, 512)
            for (bpp, npl) in bitkeys
                if max_colors[(bpp, npl)] >= ncolors
                    for i in 1:n_iter
                        img = construct_image(ncolors, test_size)
                        take!(buf)
                        write_pcx(buf, img; bpp = bpp, nplanes = npl)
                        dcxdata[i] = img
                        seekstart(buf)
                        pixels = read_pcx(buf)
                        @test size(pixels) == size(img)
                        @test pixels == img
                    end
                    take!(buf)
                    write_dcx(buf, @view dcxdata[1:n_iter])
                    seekstart(buf)
                    dcx = read_dcx(buf)
                    @test length(dcx) == n_iter
                    for i in 1:n_iter
                        @test size(dcx[i]) == size(dcxdata[i])
                        @test dcx[i] == dcxdata[i]
                    end
                end
            end
        end
    end

    @testset "Transparency" begin
        buf = IOBuffer()
        dcxdata = Vector{Matrix{ARGB32}}(undef, n_iter)
        for ncolors in (2, 4, 8, 16, 256, 512)
            for (bpp, npl) in bitkeys
                for i in 1:n_iter
                    img = construct_transparent_image(ncolors, test_size)
                    take!(buf)
                    write_pcx(buf, img; bpp = bpp, nplanes = npl)
                    dcxdata[i] = img
                    seekstart(buf)
                    pixels = read_pcx(buf)
                    @test size(pixels) == size(img)
                    @test pixels == img
                end
                take!(buf)
                write_dcx(buf, @view dcxdata[1:n_iter])
                seekstart(buf)
                dcx = read_dcx(buf)
                @test length(dcx) == n_iter
                for i in 1:n_iter
                    @test size(dcx[i]) == size(dcxdata[i])
                    @test dcx[i] == dcxdata[i]
                end
            end
        end
    end
end
