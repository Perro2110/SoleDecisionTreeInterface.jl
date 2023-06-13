"""
A full memoization structure used for checking formulas of scalar conditions on
datasets with scalar features. This structure is the equivalent to [`Memoset`](@ref),
but with scalar features some important optimizations can be done.

TODO explain

See also
[`Memoset`](@ref),
[`SuportedLogiset`](@ref),
[`AbstractLogiset`](@ref).
"""
struct ScalarMemoset{
    W<:AbstractWorld,
    U,
    FR<:AbstractFrame{W},
    D<:AbstractVector{<:AbstractDict{<:AbstractFormula,U}},
} <: AbstractMemoset{W,U,F where F<:AbstractFeature,FR}

    d :: D

    function ScalarMemoset{W,U,FR,D}(
        d::D
    ) where {W<:AbstractWorld,U,FR<:AbstractFrame{W},D<:AbstractVector{<:AbstractDict{<:AbstractFormula,U}}}
        new{W,U,FR,D}(d)
    end

    function ScalarMemoset(
        X::AbstractLogiset{W,U,F,FR},
        perform_initialization = false,
    ) where {W<:AbstractWorld,U,F<:AbstractFeature,FR<:AbstractFrame{W}}
        d = [ThreadSafeDict{SyntaxTree,WorldSet{W}}() for i in 1:ninstances(X)]
        D = typeof(d)
        ScalarMemoset{W,U,FR,D}(d)
    end
end

ninstances(Xm::ScalarMemoset)      = length(Xm.d)

capacity(Xm::ScalarMemoset)        = Inf
nmemoizedvalues(Xm::ScalarMemoset) = sum(length.(Xm.d))


@inline function Base.haskey(
    Xm           :: ScalarMemoset,
    i_instance   :: Integer,
    f            :: AbstractFormula,
)
    haskey(Xm.d[i_instance], f)
end

@inline function Base.getindex(
    Xm           :: ScalarMemoset,
    i_instance   :: Integer,
)
    Xm.d[i_instance]
end
@inline function Base.getindex(
    Xm           :: ScalarMemoset,
    i_instance   :: Integer,
    f            :: AbstractFormula,
)
    Xm.d[i_instance][f]
end
@inline function Base.setindex!(
    Xm           :: ScalarMemoset,
    i_instance   :: Integer,
    f            :: AbstractFormula,
    threshold    :: U,
) where {U}
    Xm.d[i_instance][f] = threshold
end

function check(
    f::AbstractFormula,
    Xm::ScalarMemoset{W},
    i_instance::Integer,
    w::W;
    kwargs...
) where {W<:AbstractWorld}
    error("TODO implement chained threshold checking algorithm.")
end

function instances(
    Xm::ScalarMemoset,
    inds::AbstractVector{<:Integer},
    return_view::Union{Val{true},Val{false}} = Val(false);
    kwargs...
)
    ScalarMemoset(if return_view == Val(true) @view Xm.d[inds] else Xm.d[inds] end)
end

function concatdatasets(Xms::ScalarMemoset...)
    ScalarMemoset(vcat([Xm.d for Xm in Xms]...))
end

usesfullmemo(::ScalarMemoset) = true
fullmemo(Xm::ScalarMemoset) = Xm

hasnans(::ScalarMemoset) = false


############################################################################################

"""
Abstract type for one-step memoization structure for checking formulas of type `⟨R⟩ (f ⋈ t)`.
"""
abstract type AbstractScalarOneStepMemoset{U,W,F<:AbstractFeature,FR<:AbstractFrame{W}} <: AbstractMemoset{W,U,F,FR}     end

# Access inner structure
function innerstruct(Xm::AbstractScalarOneStepMemoset)
    error("Please, provide method innerstruct(::$(typeof(Xm))).")
end

isminifiable(::AbstractScalarOneStepMemoset) = true

function minify(Xm::AbstractScalarOneStepMemoset)
    minify(innerstruct(Xm))
end

"""
Abstract type for one-step memoization structure for checking formulas of type `⟨R⟩ (f ⋈ t)`,
for a generic relation `R`.
"""
abstract type AbstractScalarOneStepRelationalMemoset{U,W,FR<:AbstractFrame{W}} <: AbstractScalarOneStepMemoset{W,U,F where F<:AbstractFeature,FR}     end
"""
Abstract type for one-step memoization structure for checking "global" formulas
of type `⟨G⟩ (f ⋈ t)`.
"""
abstract type AbstractScalarOneStepGlobalMemoset{W,U} <: AbstractScalarOneStepMemoset{W,U,F where F<:AbstractFeature,FR<:AbstractFrame{W}} end

############################################################################################

"""
A generic, one-step memoization structure used for checking specific formulas
of scalar conditions on
datasets with scalar features. The formulas are of type ⟨R⟩ (f ⋈ t)

TODO explain

See also
[`Memoset`](@ref),
[`SuportedLogiset`](@ref),
[`AbstractLogiset`](@ref).
"""
struct ScalarOneStepRelationalMemoset{
    W<:AbstractWorld,
    U,
    FR<:AbstractFrame{W},
    D<:AbstractArray{<:AbstractDict{W,VV}, 3} where VV<:Union{U,Nothing},
} <: AbstractScalarOneStepRelationalMemoset{W,U,FR}

    metaconditions :: Vector{<:ScalarMetaCondition}

    relations :: Vector{<:AbstractRelation}

    d :: D

    function ScalarOneStepRelationalMemoset{W,U,FR}(
        metaconditions::AbstractVector{<:ScalarMetaCondition},
        relations::AbstractVector{<:AbstractRelation},
        d::D,
    ) where {W<:AbstractWorld,U,FR<:AbstractFrame{W},D<:AbstractArray{U,2}}
        new{W,U,FR,D}(d)
    end

    function ScalarOneStepRelationalMemoset(
        X::AbstractLogiset{W,U,F,FR},
        metaconditions::AbstractVector{<:ScalarMetaCondition},
        relations::AbstractVector{<:AbstractRelation},
        perform_initialization = false
    ) where {W,U,F<:AbstractFeature,FR<:AbstractFrame{W}}
        nmetaconditions = length(metaconditions)
        nrelations = length(relations)
        d = begin
            if perform_initialization
                d = Array{Dict{W,Union{U,Nothing}}, 3}(undef, ninstances(X), nmetaconditions, nrelations)
                fill!(d, nothing)
            else
                Array{Dict{W,U}, 3}(undef, ninstances(X), nmetaconditions, nrelations)
            end
        end
        ScalarOneStepRelationalMemoset{W,U,FR}(d, metaconditions, relations)
    end
end


innerstruct(Xm::ScalarOneStepRelationalMemoset)     = Xm.d

metaconditions(Xm::ScalarOneStepRelationalMemoset)  = Xm.metaconditions
relations(Xm::ScalarOneStepRelationalMemoset)       = Xm.relations

ninstances(Xm::ScalarOneStepRelationalMemoset)      = size(Xm.d, 1)
nmetaconditions(Xm::ScalarOneStepRelationalMemoset) = size(Xm.d, 2)
nrelations(Xm::ScalarOneStepRelationalMemoset)      = size(Xm.d, 3)

capacity(Xm::ScalarOneStepRelationalMemoset)        = Inf
nmemoizedvalues(Xm::ScalarOneStepRelationalMemoset) = sum(length.(Xm.d))


usesfullmemo(::ScalarOneStepRelationalMemoset) = false

function hasnans(Xm::ScalarOneStepRelationalMemoset)
    any(map(d->(any(_isnan.(collect(values(d))))), Xm.d))
end

function check(
    f::AbstractFormula,
    Xm::ScalarOneStepRelationalMemoset{W},
    i_instance::Integer,
    w::W;
    kwargs...
) where {W<:AbstractWorld}
    error("TODO implement chained threshold checking algorithm.")
end

function instances(Xm::ScalarOneStepRelationalMemoset{W,U,FR}, inds::AbstractVector{<:Integer}, return_view::Union{Val{true},Val{false}} = Val(false)) where {W,U,FR}
    ScalarOneStepRelationalMemoset{W,U,FR}(if return_view == Val(true) @view Xm.d[inds,:,:] else Xm.d[inds,:,:] end)
end

function concatdatasets(Xms::ScalarOneStepRelationalMemoset...)
    ScalarOneStepRelationalMemoset(vcat([Xm.d for Xm in Xms]...))
end


function displaystructure(Xm::ScalarOneStepRelationalMemoset; indent_str = "", include_ninstances = true)
    padattribute(l,r) = string(l) * lpad(r,32+length(string(r))-(length(indent_str)+2+length(l)))
    pieces = []
    push!(pieces, "")
    push!(pieces, "$(padattribute("worldtype:", worldtype(Xm)))")
    push!(pieces, "$(padattribute("featvaltype:", featvaltype(Xm)))")
    push!(pieces, "$(padattribute("featuretype:", featuretype(Xm)))")
    push!(pieces, "$(padattribute("frametype:", frametype(Xm)))")
    if include_ninstances
        push!(pieces, "$(padattribute("# instances:", ninstances(Xm)))")
    end
    push!(pieces, "$(padattribute("# memoized values:", nmemoizedvalues(Xm)))")
    push!(pieces, "$(padattribute("# metaconditions:", nmetaconditions(Xm)))")
    push!(pieces, "$(padattribute("# relations:", nrelations(Xm)))")
    push!(pieces, "")
    push!(pieces, "$(padattribute("metaconditions:", metaconditions(Xm)))")
    push!(pieces, "$(padattribute("relations:", relations(Xm)))")

    return "ScalarOneStepRelationalMemoset ($(humansize(Xm)))" *
        join(pieces, "\n$(indent_str)├ ", "\n$(indent_str)└ ") * "\n"
end


# @inline function Base.getindex(
#     Xm      :: ScalarOneStepRelationalMemoset{W,U},
#     i_instance   :: Integer,
#     w            :: W,
#     i_featsnaggr :: Integer,
#     i_relation   :: Integer
# ) where {W<:AbstractWorld,U}
#     Xm.d[i_instance, i_featsnaggr, i_relation][w]
# end
# Base.size(Xm::ScalarOneStepRelationalMemoset, args...) = size(Xm.d, args...)

# fwd_rs_init_world_slice(Xm::ScalarOneStepRelationalMemoset{W,U}, i_instance::Integer, i_featsnaggr::Integer, i_relation::Integer) where {W,U} =
#     Xm.d[i_instance, i_featsnaggr, i_relation] = Dict{W,U}()
# @inline function Base.setindex!(Xm::ScalarOneStepRelationalMemoset{W,U}, threshold::U, i_instance::Integer, w::AbstractWorld, i_featsnaggr::Integer, i_relation::Integer) where {W,U}
#     Xm.d[i_instance, i_featsnaggr, i_relation][w] = threshold
# end

############################################################################################

# Note: the global Xm is world-agnostic
struct ScalarOneStepGlobalMemoset{
    W<:AbstractWorld,
    U,
    D<:AbstractArray{U,2}
} <: AbstractScalarOneStepGlobalMemoset{W,U}

    d :: D

    function ScalarOneStepGlobalMemoset{W,U,D}(d::D) where {U,D<:AbstractArray{U,2}}
        new{W,U,D}(d)
    end
    function ScalarOneStepGlobalMemoset{W,U}(d::D) where {U,D<:AbstractArray{U,2}}
        ScalarOneStepGlobalMemoset{W,U,D}(d)
    end

    function ScalarOneStepGlobalMemoset(X::AbstractLogiset{W,U}) where {W<:AbstractWorld,U}
        @assert worldtype(X) != OneWorld "TODO adjust this note: note that you should not use a global Xm when not using global decisions"
        _nfeatsnaggrs = nfeatsnaggrs(X)
        ScalarOneStepGlobalMemoset{W,U}(Array{U,2}(undef, ninstances(X), _nfeatsnaggrs))
    end
end

capacity(Xm::ScalarOneStepGlobalMemoset)        = prod(size(Xm.d))
nmemoizedvalues(Xm::ScalarOneStepGlobalMemoset) = sum(Xm.d)
innerstruct(Xm::ScalarOneStepGlobalMemoset)        = Xm.d

# default_fwd_gs_type(::Type{<:AbstractWorld}) = ScalarOneStepGlobalMemoset # TODO implement similar pattern used for fwd

function hasnans(Xm::ScalarOneStepGlobalMemoset)
    # @show any(_isnan.(Xm.d))
    any(_isnan.(Xm.d))
end

ninstances(Xm::ScalarOneStepGlobalMemoset)  = size(Xm, 1)
nfeatsnaggrs(Xm::ScalarOneStepGlobalMemoset) = size(Xm, 2)
Base.getindex(
    Xm      :: ScalarOneStepGlobalMemoset,
    i_instance   :: Integer,
    i_featsnaggr  :: Integer) = Xm.d[i_instance, i_featsnaggr]
Base.size(Xm::ScalarOneStepGlobalMemoset{U}, args...) where {U} = size(Xm.d, args...)

Base.setindex!(Xm::ScalarOneStepGlobalMemoset{U}, threshold::U, i_instance::Integer, i_featsnaggr::Integer) where {U} =
    Xm.d[i_instance, i_featsnaggr] = threshold
function instances(Xm::ScalarOneStepGlobalMemoset{U}, inds::AbstractVector{<:Integer}, return_view::Union{Val{true},Val{false}} = Val(false)) where {U}
    ScalarOneStepGlobalMemoset{U}(if return_view == Val(true) @view Xm.d[inds,:] else Xm.d[inds,:] end)
end

abstract type FeaturedMemoset{U<:Number,W<:AbstractWorld,FR<:AbstractFrame{W}} <: AbstractMemoset{W,U,F where F<:AbstractFeature,FR} end
